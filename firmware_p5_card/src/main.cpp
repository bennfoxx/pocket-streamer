#include <Arduino.h>
#include <SPI.h>
#include <SD.h>
#include <driver/i2s.h>
#include <esp_sleep.h>
#include <math.h>
#include <string.h>

// ============================================================================
// fbox OS (Option P5-Card) — ESP32-S3 AMOLED Firmware & Display Architecture
// Board: LILYGO T-Display-S3 AMOLED (1.91" RM67162 536x240, ESP32-S3R8, 8MB OPI PSRAM)
// ============================================================================

// 1. Display Geometry & True-Black AMOLED RGB565 Palette ("fbox OS")
static constexpr int FBOX_W = 536;
static constexpr int FBOX_H = 240;

static constexpr uint16_t COL_VOID      = 0x0000; // #000000 True Black
static constexpr uint16_t COL_CARD      = 0x0882; // #0D1117 Surface Card
static constexpr uint16_t COL_BORDER    = 0x1947; // #1E293B Card Border
static constexpr uint16_t COL_TEXT      = 0xFFDF; // #F8FAFC Primary Text
static constexpr uint16_t COL_MUTED     = 0x9517; // #94A3B8 Secondary Text
static constexpr uint16_t COL_CORAL     = 0xE329; // #E0634E fbox Coral (B8 / Stick / AI)
static constexpr uint16_t COL_AMBER     = 0xE549; // #E3A84B fbox Amber (B5 / ABS)
static constexpr uint16_t COL_GOLD      = 0xEE8B; // #EBD15E fbox Gold (B7 / Play / Star)
static constexpr uint16_t COL_TEAL      = 0x4593; // #45B09C fbox Teal (B6 / Spotify / SD)
static constexpr uint16_t COL_BT_CYAN   = 0x3DF9; // #38BDF8 KCX BT TX Cyan

// 2. Internal T-Display-S3 AMOLED Pins (DO NOT REWIRE)
static constexpr int PIN_AMOLED_EN = 38; // MUST be HIGH to power AMOLED
static constexpr int PIN_BAT_ADC   = 4;  // Onboard 2:1 battery voltage divider

// 3. KY-023 Analog Thumbstick (Powered strictly from 3.3V!)
static constexpr int PIN_KY_VRX    = 1;  // ADC1_CH0 (Wi-Fi safe)
static constexpr int PIN_KY_VRY    = 10; // ADC1_CH9 (Wi-Fi safe)
static constexpr int PIN_KY_SW     = 11; // INPUT_PULLUP

// 4. Shared I2S0 Bus (GY-PCM5102 DAC + INMP441 MEMS Mic)
static constexpr int PIN_I2S_BCK   = 12; // Shared BCK / SCK
static constexpr int PIN_I2S_WS    = 13; // Shared LCK / WS
static constexpr int PIN_I2S_DOUT  = 14; // -> GY-PCM5102 DIN (VIN=5V)
static constexpr int PIN_I2S_DIN   = 15; // <- INMP441 SD (VDD=3.3V, 100k pull-down)

// 5. Mini 3.3V MicroSD Reader (SPI2 / HSPI)
static constexpr int PIN_SD_CS     = 16;
static constexpr int PIN_SD_MOSI   = 39;
static constexpr int PIN_SD_SCK    = 40;
static constexpr int PIN_SD_MISO   = 41;

// 6. Option A Direct Tactile Keypads (B1 = Hardware V713 K 5V Audio Power; B2..B8 = Direct INPUT_PULLUP)
// Top Strip: K1 (B1) -> AOICRIE V713 K pad only (1-click 5V ON / 2-click OFF); K2..K4 -> GPIO 42, 43, 44
// Bottom Strip: K1..K4 -> GPIO 45, 2, 3, 46 (strapping pins 45/46 configured post-boot in setup())
static constexpr int DIRECT_KEY_PINS[7] = {42, 43, 44, 45, 2, 3, 46};
static const char* KEY_LABELS[8]        = {
    "B1:5V-PWR(HW)", "B2:LIB/HOME", "B3:OUT", "B4:MARK",
    "B5:-15s", "B6:PREV", "B7:PLAY", "B8:AI/REC"
};

// Timing thresholds (ms)
static constexpr uint32_t DEBOUNCE_MS      = 24;
static constexpr uint32_t HOLD_MS          = 380;
static constexpr uint32_t PTT_HOLD_MS      = 180;
static constexpr uint32_t LOCK_COMBO_MS    = 600;
static constexpr uint32_t SLEEP_HOLD_MS    = 2000;

// 7. fbox OS Finite State Machine & Shared Runtime State
enum class FBoxState : uint8_t {
    HOME_LAUNCHER = 0,
    NOW_PLAYING,
    LIBRARY_BROWSER,
    VOICE_AI_PTT,
    SYSTEM_OUTPUT,
    POCKET_LOCK
};

enum class AudioSource : uint8_t {
    ABS = 0,
    SPOTIFY,
    MICROSD
};

enum class VoiceSubMode : uint8_t {
    GEMINI_AI = 0,
    WAV_VOICE_NOTE
};

enum class PttPhase : uint8_t {
    IDLE = 0,
    LISTENING,
    THINKING,
    RESPONSE
};

struct FBoxRuntime {
    FBoxState screen = FBoxState::NOW_PLAYING;
    FBoxState prevScreen = FBoxState::NOW_PLAYING;
    AudioSource activeSource = AudioSource::ABS;
    VoiceSubMode voiceSubMode = VoiceSubMode::GEMINI_AI;
    PttPhase pttPhase = PttPhase::IDLE;

    uint8_t launcherIdx = 0;
    uint8_t libTabIdx = 0;
    uint16_t libCursor = 0;
    uint8_t speedIdx = 1; // 1.15x
    uint8_t volume = 74;
    bool playing = true;
    bool btTxOn = true;
    bool locked = false;
    bool sdMounted = false;

    uint32_t positionSec = 1458;
    uint32_t durationSec = 3420;
    float batteryVolts = 3.98f;
    uint8_t batteryPct = 86;

    // KY-023 Normalized & Physics State
    float stickX = 0.0f;
    float stickY = 0.0f;
    int32_t scrubDeltaSec = 0;
    float scrollVelRowsPerSec = 0.0f;
    float scrollAccum = 0.0f;
    uint32_t lastStepMs = 0;

    // Live Mic Waveform (32 bands)
    float micBins[32] = {0};
};

static FBoxRuntime gState;
static uint16_t* gFrameBuffer = nullptr; // 536x240 RGB565 in OPI PSRAM (257,280 bytes)
static bool gFrameDirty = true;
SPIClass sdSPI(HSPI);

// ----------------------------------------------------------------------------
// 8. PSRAM 536x240 Framebuffer Primitives & RM67162 Layout Renderers
// ----------------------------------------------------------------------------
static inline void fbClear(uint16_t color) {
    if (!gFrameBuffer) return;
    if (color == 0) {
        memset(gFrameBuffer, 0, FBOX_W * FBOX_H * sizeof(uint16_t));
        return;
    }
    for (int i = 0; i < FBOX_W * FBOX_H; ++i) gFrameBuffer[i] = color;
}

static inline void fbFillRect(int x, int y, int w, int h, uint16_t color) {
    if (!gFrameBuffer || w <= 0 || h <= 0) return;
    int x0 = max(0, x);
    int y0 = max(0, y);
    int x1 = min(FBOX_W, x + w);
    int y1 = min(FBOX_H, y + h);
    for (int row = y0; row < y1; ++row) {
        uint16_t* dst = gFrameBuffer + row * FBOX_W + x0;
        for (int col = x0; col < x1; ++col) {
            *dst++ = color;
        }
    }
}

static inline void fbStrokeRect(int x, int y, int w, int h, uint16_t color) {
    fbFillRect(x, y, w, 1, color);
    fbFillRect(x, y + h - 1, w, 1, color);
    fbFillRect(x, y, 1, h, color);
    fbFillRect(x + w - 1, y, 1, h, color);
}

static void drawTopStatusBar() {
    fbFillRect(0, 0, FBOX_W, 28, COL_VOID);
    fbFillRect(0, 27, FBOX_W, 1, COL_BORDER);
    // fbox pill + active source pill + output target pill + battery bar
    fbFillRect(10, 5, 48, 18, COL_CARD);
    fbStrokeRect(10, 5, 48, 18, COL_CORAL);

    uint16_t srcCol = (gState.activeSource == AudioSource::ABS) ? COL_AMBER
                    : (gState.activeSource == AudioSource::SPOTIFY ? COL_TEAL : COL_BT_CYAN);
    fbFillRect(64, 5, 92, 18, COL_CARD);
    fbStrokeRect(64, 5, 92, 18, srcCol);

    uint16_t outCol = gState.btTxOn ? COL_BT_CYAN : COL_TEAL;
    fbFillRect(334, 5, 96, 18, COL_CARD);
    fbStrokeRect(334, 5, 96, 18, outCol);

    // Battery bar
    fbStrokeRect(496, 8, 28, 12, COL_BORDER);
    int fillW = (24 * gState.batteryPct) / 100;
    fbFillRect(498, 10, fillW, 8, (gState.batteryPct > 20) ? COL_TEAL : COL_CORAL);
}

static void drawBottomKeyStrip() {
    fbFillRect(0, 214, FBOX_W, 26, COL_CARD);
    fbFillRect(0, 214, FBOX_W, 1, COL_BORDER);
    const uint16_t keyCols[5] = {COL_CORAL, COL_AMBER, COL_TEAL, COL_GOLD, COL_CORAL};
    for (int i = 0; i < 5; ++i) {
        int bx = 14 + i * 102;
        fbFillRect(bx, 224, 6, 6, keyCols[i]);
        fbFillRect(bx + 10, 221, 76, 12, COL_VOID);
        fbStrokeRect(bx + 10, 221, 76, 12, COL_BORDER);
    }
}

static void renderHomeLauncher() {
    fbClear(COL_VOID);
    drawTopStatusBar();
    const uint16_t cardCols[4] = {COL_AMBER, COL_TEAL, COL_BT_CYAN, COL_CORAL};
    for (int i = 0; i < 4; ++i) {
        int cx = 14 + i * 129;
        fbFillRect(cx, 38, 121, 134, COL_CARD);
        fbStrokeRect(cx, 38, 121, 134, (i == gState.launcherIdx) ? cardCols[i] : COL_BORDER);
        fbFillRect(cx + 12, 52, 32, 32, cardCols[i]);
    }
    // Mini-player ticker
    fbFillRect(14, 180, FBOX_W - 28, 26, COL_CARD);
    fbStrokeRect(14, 180, FBOX_W - 28, 26, COL_BORDER);
    drawBottomKeyStrip();
}

static void renderNowPlaying() {
    fbClear(COL_VOID);
    drawTopStatusBar();

    // Left 142x142 procedural album / audiobook art tile
    uint16_t artCol = (gState.activeSource == AudioSource::ABS) ? COL_AMBER : COL_TEAL;
    fbFillRect(14, 36, 142, 142, COL_CARD);
    fbStrokeRect(14, 36, 142, 142, artCol);
    fbFillRect(26, 48, 118, 118, artCol);

    // Right metadata + quick pill row
    fbFillRect(172, 42, 280, 18, COL_TEXT);
    fbFillRect(172, 68, 210, 12, COL_MUTED);
    for (int p = 0; p < 4; ++p) {
        int px = 172 + p * 84;
        fbFillRect(px, 108, 76, 24, COL_CARD);
        fbStrokeRect(px, 108, 76, 24, COL_BORDER);
    }

    // Scrubber track + preview position
    fbFillRect(172, 156, 350, 6, COL_BORDER);
    uint32_t previewPos = (uint32_t)constrain((int32_t)gState.positionSec + gState.scrubDeltaSec, 0, (int32_t)gState.durationSec);
    int progW = gState.durationSec > 0 ? (int)((350ULL * previewPos) / gState.durationSec) : 0;
    fbFillRect(172, 156, progW, 6, (gState.scrubDeltaSec != 0) ? COL_CORAL : artCol);
    fbFillRect(172 + max(0, progW - 4), 152, 8, 14, COL_TEXT);

    drawBottomKeyStrip();
}

static void renderLibraryBrowser() {
    fbClear(COL_VOID);
    drawTopStatusBar();

    const uint16_t tabCols[5] = {COL_AMBER, COL_GOLD, COL_TEAL, COL_BT_CYAN, COL_CORAL};
    for (int t = 0; t < 5; ++t) {
        int tx = 14 + t * 98;
        fbFillRect(tx, 33, 92, 22, (t == gState.libTabIdx) ? tabCols[t] : COL_CARD);
        fbStrokeRect(tx, 33, 92, 22, tabCols[t]);
    }

    // 4 visible 34px list rows (x=12..502)
    for (int r = 0; r < 4; ++r) {
        int ry = 62 + r * 36;
        bool focused = (r == (gState.libCursor % 4));
        fbFillRect(12, ry, 490, 34, COL_CARD);
        fbStrokeRect(12, ry, 490, 34, focused ? tabCols[gState.libTabIdx] : COL_BORDER);
        if (focused) fbFillRect(12, ry, 4, 34, tabCols[gState.libTabIdx]);
    }

    // Right-edge KY-023 Analog Velocity HUD (x=508..528)
    fbFillRect(508, 62, 20, 146, COL_CARD);
    fbStrokeRect(508, 62, 20, 146, COL_BORDER);
    int barH = (int)(fabsf(gState.stickY) * 60.0f);
    int midY = 135;
    if (gState.stickY < -0.14f) fbFillRect(512, midY - barH, 12, barH, COL_CORAL);
    else if (gState.stickY > 0.14f) fbFillRect(512, midY, 12, barH, COL_GOLD);

    drawBottomKeyStrip();
}

static void renderVoiceAiPtt() {
    fbClear(COL_VOID);
    drawTopStatusBar();

    // Sub-mode tabs (Gemini AI vs WAV Voice Note)
    fbFillRect(14, 33, 152, 22, (gState.voiceSubMode == VoiceSubMode::GEMINI_AI) ? COL_CORAL : COL_CARD);
    fbFillRect(172, 33, 174, 22, (gState.voiceSubMode == VoiceSubMode::WAV_VOICE_NOTE) ? COL_AMBER : COL_CARD);

    if (gState.pttPhase == PttPhase::LISTENING) {
        // 32-bar INMP441 spectrum visualizer
        fbFillRect(56, 86, 80, 80, COL_CORAL);
        for (int b = 0; b < 32; ++b) {
            int amp = 6 + (int)(gState.micBins[b] * 68.0f);
            fbFillRect(180 + b * 10, 122 - amp / 2, 7, amp, (b % 2 == 0) ? COL_CORAL : COL_TEAL);
        }
    } else {
        fbFillRect(14, 62, 312, 146, COL_CARD);
        fbStrokeRect(14, 62, 312, 146, COL_CORAL);
        fbFillRect(334, 62, 188, 146, COL_CARD);
        fbStrokeRect(334, 62, 188, 146, COL_BORDER);
    }

    drawBottomKeyStrip();
}

static void renderSystemOutput() {
    fbClear(COL_VOID);
    drawTopStatusBar();
    fbFillRect(14, 38, 248, 86, COL_CARD);
    fbStrokeRect(14, 38, 248, 86, !gState.btTxOn ? COL_TEAL : COL_BORDER);
    fbFillRect(274, 38, 248, 86, COL_CARD);
    fbStrokeRect(274, 38, 248, 86, gState.btTxOn ? COL_BT_CYAN : COL_BORDER);
    fbFillRect(14, 134, 508, 72, COL_CARD);
    fbStrokeRect(14, 134, 508, 72, COL_BORDER);
    drawBottomKeyStrip();
}

static void renderPocketLock() {
    fbClear(COL_VOID);
    fbStrokeRect(4, 4, FBOX_W - 8, FBOX_H - 8, COL_AMBER);
    fbFillRect(248, 74, 40, 44, COL_AMBER);
    fbFillRect(188, 138, 160, 14, COL_TEXT);
}

static void renderCurrentFrame() {
    if (!gFrameBuffer || !gFrameDirty) return;
    gFrameDirty = false;
    switch (gState.screen) {
        case FBoxState::HOME_LAUNCHER:   renderHomeLauncher();   break;
        case FBoxState::NOW_PLAYING:     renderNowPlaying();     break;
        case FBoxState::LIBRARY_BROWSER: renderLibraryBrowser(); break;
        case FBoxState::VOICE_AI_PTT:    renderVoiceAiPtt();    break;
        case FBoxState::SYSTEM_OUTPUT:   renderSystemOutput();   break;
        case FBoxState::POCKET_LOCK:     renderPocketLock();     break;
    }
    // Push gFrameBuffer (536x240 RGB565) to RM67162 QSPI panel via DMA here.
}

// ----------------------------------------------------------------------------
// 9. Full-Duplex I2S0 Audio, Earcon Chimes & WAV Header Generator
// ----------------------------------------------------------------------------
void setupI2SFullDuplex() {
    i2s_config_t cfg = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX | I2S_MODE_RX),
        .sample_rate = 44100,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT,
        .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = 6,
        .dma_buf_len = 256,
        .use_apll = false,
        .tx_desc_auto_clear = true,
        .fixed_mclk = 0
    };
    i2s_pin_config_t pins = {
        .bck_io_num = PIN_I2S_BCK,
        .ws_io_num = PIN_I2S_WS,
        .data_out_num = PIN_I2S_DOUT,
        .data_in_num = PIN_I2S_DIN
    };
    i2s_driver_install(I2S_NUM_0, &cfg, 0, nullptr);
    i2s_set_pin(I2S_NUM_0, &pins);
    i2s_zero_dma_buffer(I2S_NUM_0);
}

void playTone(float freqHz, int durationMs, float gain = 0.14f) {
    const int totalSamples = (44100 * durationMs) / 1000;
    int32_t frame[2];
    size_t written = 0;
    for (int i = 0; i < totalSamples; ++i) {
        float env = 1.0f - (float)i / (float)totalSamples;
        float s = sinf(2.0f * PI * freqHz * (float)i / 44100.0f) * env * gain;
        int32_t val = (int32_t)(s * 2147483647.0f);
        frame[0] = val;
        frame[1] = val;
        i2s_write(I2S_NUM_0, frame, sizeof(frame), &written, portMAX_DELAY);
    }
}

void playEarconTwoNote(float f1, float f2, int ms1 = 70, int ms2 = 90) {
    playTone(f1, ms1, 0.13f);
    playTone(f2, ms2, 0.13f);
    i2s_zero_dma_buffer(I2S_NUM_0);
}

void writeWavHeader(File& f, uint32_t dataBytes, uint32_t sampleRate = 44100, uint16_t bits = 16, uint16_t channels = 1) {
    uint8_t hdr[44];
    uint32_t fileSize = dataBytes + 36;
    uint32_t byteRate = sampleRate * channels * (bits / 8);
    uint16_t blockAlign = channels * (bits / 8);

    memcpy(hdr + 0, "RIFF", 4);
    memcpy(hdr + 4, &fileSize, 4);
    memcpy(hdr + 8, "WAVEfmt ", 8);
    uint32_t fmtSize = 16;
    uint16_t audioFmt = 1; // PCM
    memcpy(hdr + 16, &fmtSize, 4);
    memcpy(hdr + 20, &audioFmt, 2);
    memcpy(hdr + 22, &channels, 2);
    memcpy(hdr + 24, &sampleRate, 4);
    memcpy(hdr + 28, &byteRate, 4);
    memcpy(hdr + 32, &blockAlign, 2);
    memcpy(hdr + 34, &bits, 2);
    memcpy(hdr + 36, "data", 4);
    memcpy(hdr + 40, &dataBytes, 4);

    f.seek(0);
    f.write(hdr, 44);
}

// ----------------------------------------------------------------------------
// 10. Non-Blocking Option A Direct Button Scanner (B2..B8 + B2+B5 Pocket Lock)
// ----------------------------------------------------------------------------
struct KeyState {
    bool rawPressed = false;
    bool stablePressed = false;
    bool holdFired = false;
    bool pttStarted = false;
    bool comboConsumed = false;
    uint32_t lastEdgeMs = 0;
    uint32_t pressStartMs = 0;
};

static KeyState gKeys[8];
static bool gComboLockHandled = false;
static uint32_t gComboStartMs = 0;

void togglePocketLock() {
    if (gState.locked) {
        gState.locked = false;
        gState.screen = (gState.prevScreen == FBoxState::POCKET_LOCK) ? FBoxState::NOW_PLAYING : gState.prevScreen;
        playEarconTwoNote(330.0f, 659.25f);
        Serial.println("[fbox] Unlocked");
    } else {
        gState.prevScreen = gState.screen;
        gState.locked = true;
        gState.screen = FBoxState::POCKET_LOCK;
        playEarconTwoNote(330.0f, 261.63f);
        Serial.println("[fbox] Pocket Locked");
    }
    gFrameDirty = true;
}

void handleKeyTap(int idx) {
    if (gState.locked) {
        playTone(220.0f, 50, 0.08f);
        return;
    }
    switch (idx) {
        case 0: // B1: HOME
            gState.screen = (gState.screen == FBoxState::HOME_LAUNCHER) ? FBoxState::NOW_PLAYING : FBoxState::HOME_LAUNCHER;
            break;
        case 1: // B2: LIB / UP
            if (gState.screen == FBoxState::LIBRARY_BROWSER) {
                if (gState.libCursor > 0) gState.libCursor--;
            } else {
                gState.screen = FBoxState::LIBRARY_BROWSER;
            }
            break;
        case 2: // B3: OUT / DOWN
            if (gState.screen == FBoxState::LIBRARY_BROWSER) {
                gState.libCursor++;
            } else {
                gState.btTxOn = !gState.btTxOn;
                playEarconTwoNote(440.0f, 659.25f);
            }
            break;
        case 3: // B4: MARK
            playEarconTwoNote(440.0f, 659.25f);
            Serial.printf("[fbox] ★ Bookmark saved @ %lu s\n", (unsigned long)gState.positionSec);
            break;
        case 4: // B5: -15s / BACK
            if (gState.screen == FBoxState::NOW_PLAYING) {
                gState.positionSec = (gState.positionSec > 15) ? (gState.positionSec - 15) : 0;
            } else {
                gState.screen = FBoxState::NOW_PLAYING;
            }
            break;
        case 5: // B6: PREV
            gState.positionSec = 0;
            break;
        case 6: // B7: PLAY / CONFIRM
            if (gState.screen == FBoxState::HOME_LAUNCHER) {
                gState.screen = (gState.launcherIdx == 3) ? FBoxState::VOICE_AI_PTT : FBoxState::NOW_PLAYING;
            } else if (gState.screen == FBoxState::LIBRARY_BROWSER) {
                gState.screen = FBoxState::NOW_PLAYING;
                gState.playing = true;
            } else {
                gState.playing = !gState.playing;
            }
            break;
        case 7: // B8: AI / REC
            if (gState.screen != FBoxState::VOICE_AI_PTT) {
                gState.screen = FBoxState::VOICE_AI_PTT;
            } else {
                gState.voiceSubMode = (gState.voiceSubMode == VoiceSubMode::GEMINI_AI)
                                    ? VoiceSubMode::WAV_VOICE_NOTE : VoiceSubMode::GEMINI_AI;
            }
            break;
    }
    Serial.printf("[KEY TAP] %s -> state=%d\n", KEY_LABELS[idx], (int)gState.screen);
    gFrameDirty = true;
}

void handleKeyHold(int idx) {
    if (gState.locked) return;
    if (idx == 1) {
        gState.screen = (gState.screen == FBoxState::HOME_LAUNCHER) ? FBoxState::NOW_PLAYING : FBoxState::HOME_LAUNCHER;
    } else if (idx == 0 || idx == 2) {
        gState.screen = FBoxState::SYSTEM_OUTPUT;
    } else if (idx == 3) {
        gState.libTabIdx = 4;
        gState.screen = FBoxState::LIBRARY_BROWSER;
    } else if (idx == 5) {
        gState.speedIdx = (gState.speedIdx + 1) % 5;
    } else if (idx == 6) {
        gState.positionSec = min(gState.durationSec, gState.positionSec + 30);
    }
    gFrameDirty = true;
}

void scanKeypadNonBlocking(uint32_t nowMs) {
    for (int i = 0; i < 7; ++i) {
        int idx = i + 1; // B2..B8 (idx 0 = B1 wired to hardware V713 Boost K pad)
        bool pressed = (digitalRead(DIRECT_KEY_PINS[i]) == LOW);
        KeyState& ks = gKeys[idx];

        if (pressed != ks.rawPressed) {
            ks.rawPressed = pressed;
            ks.lastEdgeMs = nowMs;
        } else if ((nowMs - ks.lastEdgeMs) >= DEBOUNCE_MS && pressed != ks.stablePressed) {
            ks.stablePressed = pressed;
            if (pressed) {
                ks.pressStartMs = nowMs;
                ks.holdFired = false;
                ks.pttStarted = false;
                ks.comboConsumed = false;
            } else {
                if (!ks.comboConsumed) {
                    if (idx == 7 && ks.pttStarted) {
                        gState.pttPhase = PttPhase::THINKING;
                        playEarconTwoNote(783.99f, 659.25f, 60, 80);
                        Serial.println("[fbox AI] PTT Released -> Processing");
                        gFrameDirty = true;
                    } else if (!ks.holdFired) {
                        handleKeyTap(idx);
                    }
                }
            }
        }

        if (ks.stablePressed && !ks.comboConsumed) {
            if (idx == 7 && !ks.pttStarted && !gState.locked && (nowMs - ks.pressStartMs) >= PTT_HOLD_MS) {
                ks.pttStarted = true;
                ks.holdFired = true;
                gState.screen = FBoxState::VOICE_AI_PTT;
                gState.pttPhase = PttPhase::LISTENING;
                playEarconTwoNote(523.25f, 783.99f);
                Serial.println("[fbox AI] PTT Listening (INMP441)");
                gFrameDirty = true;
            } else if (idx != 7 && !ks.holdFired && !(gKeys[1].stablePressed && gKeys[4].stablePressed) && (nowMs - ks.pressStartMs) >= HOLD_MS) {
                ks.holdFired = true;
                handleKeyHold(idx);
            }
        }
    }

    // B2 (idx 1) + B5 (idx 4) -> 600ms Pocket Lock Combo
    if (gKeys[1].stablePressed && gKeys[4].stablePressed) {
        if (gComboStartMs == 0) gComboStartMs = nowMs;
        if (!gComboLockHandled && (nowMs - gComboStartMs) >= LOCK_COMBO_MS) {
            gComboLockHandled = true;
            gKeys[1].comboConsumed = true;
            gKeys[4].comboConsumed = true;
            togglePocketLock();
        }
    } else {
        gComboStartMs = 0;
        gComboLockHandled = false;
    }
}

// ----------------------------------------------------------------------------
// 11. KY-023 Analog Deadzone, Timeline Scrub & List Scroll Physics
// ----------------------------------------------------------------------------
void updateStickPhysics(uint32_t nowMs) {
    float dt = (gState.lastStepMs == 0) ? 0.02f : min(0.1f, (nowMs - gState.lastStepMs) / 1000.0f);
    gState.lastStepMs = nowMs;

    int vrx = analogRead(PIN_KY_VRX);
    int vry = analogRead(PIN_KY_VRY);
    float nx = (vrx - 2048) / 2048.0f;
    float ny = (2048 - vry) / 2048.0f;
    gState.stickX = (fabsf(nx) < 0.14f) ? 0.0f : constrain(nx, -1.0f, 1.0f);
    gState.stickY = (fabsf(ny) < 0.14f) ? 0.0f : constrain(ny, -1.0f, 1.0f);

    if (gState.locked) return;

    if (gState.screen == FBoxState::NOW_PLAYING) {
        if (gState.stickX != 0.0f) {
            float mag = (fabsf(gState.stickX) - 0.14f) / 0.86f;
            float rate = (1.0f + mag * mag * 15.0f) * ((gState.stickX > 0.0f) ? 1.0f : -1.0f);
            gState.scrubDeltaSec += (int32_t)roundf(rate * dt * 2.0f);
            gFrameDirty = true;
        } else if (gState.scrubDeltaSec != 0) {
            int32_t nextPos = (int32_t)gState.positionSec + gState.scrubDeltaSec;
            gState.positionSec = (uint32_t)constrain(nextPos, 0, (int32_t)gState.durationSec);
            gState.scrubDeltaSec = 0;
            gFrameDirty = true;
        }
    } else if (gState.screen == FBoxState::LIBRARY_BROWSER) {
        if (gState.stickY != 0.0f) {
            float mag = (fabsf(gState.stickY) - 0.14f) / 0.86f;
            gState.scrollVelRowsPerSec = 1.0f + mag * 5.0f; // 1x..6x velocity
            gState.scrollAccum += gState.scrollVelRowsPerSec * dt * ((gState.stickY > 0.0f) ? 1.0f : -1.0f);
            while (gState.scrollAccum >= 1.0f) {
                gState.libCursor++;
                gState.scrollAccum -= 1.0f;
                gFrameDirty = true;
            }
            while (gState.scrollAccum <= -1.0f) {
                if (gState.libCursor > 0) gState.libCursor--;
                gState.scrollAccum += 1.0f;
                gFrameDirty = true;
            }
        } else {
            gState.scrollVelRowsPerSec = 0.0f;
            gState.scrollAccum = 0.0f;
        }
    }
}

void setup() {
    Serial.begin(115200);
    delay(350);
    Serial.println("\n=== fbox OS (Option P5-Card) Bring-Up ===");

    pinMode(PIN_AMOLED_EN, OUTPUT);
    digitalWrite(PIN_AMOLED_EN, HIGH);

    if (psramFound()) {
        gFrameBuffer = (uint16_t*)ps_malloc(FBOX_W * FBOX_H * sizeof(uint16_t));
    }
    Serial.printf("[PSRAM] Total: %u bytes | Free: %u bytes | FrameBuf: %s\n",
                  ESP.getPsramSize(), ESP.getFreePsram(), gFrameBuffer ? "OK (257KB)" : "FAIL");

    pinMode(PIN_KY_SW, INPUT_PULLUP);
    for (int i = 0; i < 7; ++i) pinMode(DIRECT_KEY_PINS[i], INPUT_PULLUP);

    sdSPI.begin(PIN_SD_SCK, PIN_SD_MISO, PIN_SD_MOSI, PIN_SD_CS);
    gState.sdMounted = SD.begin(PIN_SD_CS, sdSPI, 20000000);
    Serial.printf("[SD] %s\n", gState.sdMounted ? "Mounted (20MHz HSPI)" : "Not detected");

    setupI2SFullDuplex();
    playEarconTwoNote(440.0f, 659.25f);
    renderCurrentFrame();
}

void loop() {
    static uint32_t lastTelemetry = 0;
    static bool swPrev = false;
    static uint32_t swPressMs = 0;
    static bool swSleepArmed = false;
    uint32_t now = millis();

    scanKeypadNonBlocking(now);
    updateStickPhysics(now);

    bool swDown = (digitalRead(PIN_KY_SW) == LOW);
    if (swDown && !swPrev) {
        swPressMs = now;
        swSleepArmed = true;
    } else if (swDown && swSleepArmed && (now - swPressMs) >= SLEEP_HOLD_MS) {
        playEarconTwoNote(440.0f, 220.0f, 90, 120);
        Serial.println("[fbox PWR] KY-023 2s hold -> Deep Sleep (ext0 GPIO 11 wake)");
        digitalWrite(PIN_AMOLED_EN, LOW);
        while (digitalRead(PIN_KY_SW) == LOW) { delay(10); }
        delay(40);
        esp_sleep_enable_ext0_wakeup(GPIO_NUM_11, 0);
        esp_deep_sleep_start();
    } else if (!swDown && swPrev && swSleepArmed) {
        swSleepArmed = false;
        if (!gState.locked && (now - swPressMs) < SLEEP_HOLD_MS) {
            handleKeyTap(6); // Confirm / Play-Pause parity with B7
        }
    }
    swPrev = swDown;

    // Read INMP441 I2S0 block for live voice visualization
    int32_t rxBuf[64];
    size_t bytesRead = 0;
    i2s_read(I2S_NUM_0, rxBuf, sizeof(rxBuf), &bytesRead, 5);
    if (gState.pttPhase == PttPhase::LISTENING && bytesRead > 0) {
        int32_t peak = 0;
        for (size_t i = 0; i < bytesRead / 4; i += 2) {
            int32_t s = abs(rxBuf[i] >> 14);
            if (s > peak) peak = s;
        }
        memmove(gState.micBins, gState.micBins + 1, 31 * sizeof(float));
        gState.micBins[31] = constrain((float)peak / 8192.0f, 0.05f, 1.0f);
        gFrameDirty = true;
    }

    renderCurrentFrame();

    if (now - lastTelemetry > 500) {
        lastTelemetry = now;
        gState.batteryVolts = (analogReadMilliVolts(PIN_BAT_ADC) * 2.0f) / 1000.0f;
        gState.batteryPct = (uint8_t)constrain((int)roundf(((gState.batteryVolts - 3.35f) / 0.85f) * 100.0f), 0, 100);
    }
    delay(15);
}
