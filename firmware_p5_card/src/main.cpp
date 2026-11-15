#include <Arduino.h>
#include <SPI.h>
#include <SD.h>
#include <driver/i2s.h>

// ============================================================================
// Option P5-Card — Day-1 Hardware Bring-Up & Verification Firmware
// Board: LILYGO T-Display-S3 AMOLED (1.91" RM67162, ESP32-S3R8, 8MB OPI PSRAM)
// ============================================================================

// 1. Internal T-Display-S3 AMOLED Pins (DO NOT REWIRE)
static constexpr int PIN_AMOLED_EN = 38; // MUST be HIGH to power AMOLED
static constexpr int PIN_BAT_ADC   = 4;  // Onboard 2:1 battery voltage divider

// 2. KY-023 Analog Thumbstick (Powered strictly from 3.3V!)
static constexpr int PIN_KY_VRX    = 1;  // ADC1_CH0 (Wi-Fi safe)
static constexpr int PIN_KY_VRY    = 10; // ADC1_CH9 (Wi-Fi safe)
static constexpr int PIN_KY_SW     = 11; // INPUT_PULLUP

// 3. Shared I2S0 Bus (GY-PCM5102 DAC + INMP441 MEMS Mic)
static constexpr int PIN_I2S_BCK   = 12; // Shared BCK / SCK
static constexpr int PIN_I2S_WS    = 13; // Shared LCK / WS
static constexpr int PIN_I2S_DOUT  = 14; // -> GY-PCM5102 DIN (VIN=5V)
static constexpr int PIN_I2S_DIN   = 15; // <- INMP441 SD (VDD=3.3V, 100k pull-down)

// 4. Mini 3.3V MicroSD Reader (SPI2 / HSPI)
static constexpr int PIN_SD_CS     = 16;
static constexpr int PIN_SD_MOSI   = 39;
static constexpr int PIN_SD_SCK    = 40;
static constexpr int PIN_SD_MISO   = 41;

// 5. 2x4 Tactile Keypad Matrix (8 buttons, headers desoldered)
static constexpr int ROW_PINS[2]   = {42, 43};
static constexpr int COL_PINS[4]   = {44, 45, 2, 3};
static const char* BTN_NAMES[2][4] = {
    {"BACK", "PLAY", "MARK", "REC"},
    {"LEFT", "UP",   "DOWN", "RIGHT"}
};

SPIClass sdSPI(HSPI);

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

void playTestChime440Hz(int durationMs = 250) {
    const int totalSamples = (44100 * durationMs) / 1000;
    int32_t frame[2];
    size_t written = 0;
    for (int i = 0; i < totalSamples; ++i) {
        float env = 1.0f - (float)i / (float)totalSamples;
        float s = sinf(2.0f * PI * 440.0f * (float)i / 44100.0f) * env * 0.20f;
        int32_t val = (int32_t)(s * 2147483647.0f);
        frame[0] = val;
        frame[1] = val;
        i2s_write(I2S_NUM_0, frame, sizeof(frame), &written, portMAX_DELAY);
    }
    i2s_zero_dma_buffer(I2S_NUM_0);
}

void scanKeypad() {
    for (int r = 0; r < 2; ++r) {
        pinMode(ROW_PINS[r], OUTPUT);
        digitalWrite(ROW_PINS[r], LOW);
        delayMicroseconds(10);
        for (int c = 0; c < 4; ++c) {
            if (digitalRead(COL_PINS[c]) == LOW) {
                Serial.printf("[KEY] %s (R%d C%d)\n", BTN_NAMES[r][c], r + 1, c + 1);
            }
        }
        pinMode(ROW_PINS[r], INPUT);
    }
}

void setup() {
    Serial.begin(115200);
    delay(400);
    Serial.println("\n=== Option P5-Card Day-1 Hardware Bring-Up ===");

    // 1. Enable AMOLED Power Rail (Critical!)
    pinMode(PIN_AMOLED_EN, OUTPUT);
    digitalWrite(PIN_AMOLED_EN, HIGH);
    Serial.printf("[PSRAM] Total: %u bytes | Free: %u bytes\n",
                  ESP.getPsramSize(), ESP.getFreePsram());

    // 2. Init Controls
    pinMode(PIN_KY_SW, INPUT_PULLUP);
    for (int r = 0; r < 2; ++r) pinMode(ROW_PINS[r], INPUT);
    for (int c = 0; c < 4; ++c) pinMode(COL_PINS[c], INPUT_PULLUP);

    // 3. Init MicroSD (3.3V Mini Module)
    sdSPI.begin(PIN_SD_SCK, PIN_SD_MISO, PIN_SD_MOSI, PIN_SD_CS);
    if (SD.begin(PIN_SD_CS, sdSPI, 20000000)) {
        Serial.printf("[SD] Mounted! Size: %llu MB\n", SD.cardSize() / (1024ULL * 1024ULL));
    } else {
        Serial.println("[SD] Not detected (check FAT32 card & 3.3V wiring).");
    }

    // 4. Init Shared I2S0 (PCM5102 + INMP441) & Play Chime
    setupI2SFullDuplex();
    playTestChime440Hz();
    Serial.println("[I2S] 440Hz test chime sent to GY-PCM5102.");
}

void loop() {
    static uint32_t lastPrint = 0;
    scanKeypad();

    if (digitalRead(PIN_KY_SW) == LOW) {
        Serial.println("[STICK] Click (SW)");
    }

    // Read a short block from INMP441 to verify mic activity
    int32_t rxBuf[64];
    size_t bytesRead = 0;
    i2s_read(I2S_NUM_0, rxBuf, sizeof(rxBuf), &bytesRead, 10);

    if (millis() - lastPrint > 500) {
        lastPrint = millis();
        int vrx = analogRead(PIN_KY_VRX);
        int vry = analogRead(PIN_KY_VRY);
        float batV = (analogReadMilliVolts(PIN_BAT_ADC) * 2.0f) / 1000.0f;

        int32_t peak = 0;
        for (size_t i = 0; i < bytesRead / 4; i += 2) {
            int32_t sample = abs(rxBuf[i] >> 14);
            if (sample > peak) peak = sample;
        }
        Serial.printf("[TELEMETRY] Stick=(%4d,%4d) | MicPeak=%5ld | VBat=%.2fV\n",
                      vrx, vry, (long)peak, batV);
    }
    delay(25);
}
