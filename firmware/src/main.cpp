#include <Arduino.h>
#include <driver/spi_master.h>
#include <math.h>

// ---- LILYGO T-Display-S3 AMOLED 1.91" (536x240 RM67162 QSPI) Pins ----
#define PIN_LCD_CS    6
#define PIN_LCD_SCK   47
#define PIN_LCD_D0    18
#define PIN_LCD_D1    7
#define PIN_LCD_D2    48
#define PIN_LCD_D3    5
#define PIN_LCD_RST   17
#define PIN_LCD_EN    38

#define PIN_BAT_ADC   4
#define PIN_BTN_BOOT  0
#define PIN_BTN_KEY1  21
#define PIN_BTN_KEY2  14

// External fbox buttons (B2..B8) & KY-023 Thumbstick
static const int EXT_BTN_PINS[7] = {42, 43, 44, 45, 2, 3, 46};
static const char* EXT_BTN_NAMES[7] = {"B2:MODE", "B3:BT", "B4:FAV", "B5:-15s", "B6:PREV", "B7:NEXT", "B8:MIC"};
#define PIN_JOY_X     1
#define PIN_JOY_Y     10
#define PIN_JOY_SW    11

#define LCD_W 536
#define LCD_H 240

static spi_device_handle_t qspi_dev = nullptr;
static uint16_t *fb = nullptr;

// ---- QSPI RM67162 Low-Level Driver ----
static void lcd_send_cmd(uint8_t cmd, const uint8_t *data, size_t len) {
  digitalWrite(PIN_LCD_CS, LOW);
  spi_transaction_ext_t t = {};
  t.base.flags = SPI_TRANS_MULTILINE_CMD | SPI_TRANS_MULTILINE_ADDR;
  t.base.cmd = 0x02;
  t.base.addr = ((uint32_t)cmd) << 8;
  t.base.length = len * 8;
  t.base.tx_buffer = data;
  t.command_bits = 8;
  t.address_bits = 24;
  spi_device_polling_transmit(qspi_dev, (spi_transaction_t *)&t);
  digitalWrite(PIN_LCD_CS, HIGH);
}

static void lcd_set_window(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1) {
  uint8_t col[4] = {(uint8_t)(x0 >> 8), (uint8_t)(x0 & 0xFF), (uint8_t)(x1 >> 8), (uint8_t)(x1 & 0xFF)};
  uint8_t row[4] = {(uint8_t)(y0 >> 8), (uint8_t)(y0 & 0xFF), (uint8_t)(y1 >> 8), (uint8_t)(y1 & 0xFF)};
  lcd_send_cmd(0x2A, col, 4);
  lcd_send_cmd(0x2B, row, 4);
}

static void lcd_push_fb() {
  lcd_set_window(0, 0, LCD_W - 1, LCD_H - 1);
  digitalWrite(PIN_LCD_CS, LOW);

  const size_t total_px = (size_t)LCD_W * LCD_H;
  const size_t chunk_px = 536 * 20; // 21,440 bytes per DMA transaction
  bool first = true;
  size_t offset = 0;

  while (offset < total_px) {
    size_t n = (total_px - offset > chunk_px) ? chunk_px : (total_px - offset);
    spi_transaction_ext_t t = {};
    if (first) {
      t.base.flags = SPI_TRANS_MODE_QIO;
      t.base.cmd = 0x32;
      t.base.addr = 0x002C00;
      t.command_bits = 8;
      t.address_bits = 24;
      first = false;
    } else {
      t.base.flags = SPI_TRANS_MODE_QIO | SPI_TRANS_VARIABLE_CMD | SPI_TRANS_VARIABLE_ADDR;
      t.command_bits = 0;
      t.address_bits = 0;
    }
    t.base.tx_buffer = fb + offset;
    t.base.length = n * 16;
    spi_device_polling_transmit(qspi_dev, (spi_transaction_t *)&t);
    offset += n;
  }
  digitalWrite(PIN_LCD_CS, HIGH);
}

static void lcd_set_brightness(uint8_t val) {
  lcd_send_cmd(0x51, &val, 1);
}

static void lcd_init() {
  pinMode(PIN_LCD_EN, OUTPUT);
  digitalWrite(PIN_LCD_EN, HIGH);
  pinMode(PIN_LCD_CS, OUTPUT);
  digitalWrite(PIN_LCD_CS, HIGH);
  pinMode(PIN_LCD_RST, OUTPUT);
  digitalWrite(PIN_LCD_RST, HIGH);
  delay(20);
  digitalWrite(PIN_LCD_RST, LOW);
  delay(30);
  digitalWrite(PIN_LCD_RST, HIGH);
  delay(120);

  spi_bus_config_t buscfg = {};
  buscfg.data0_io_num = PIN_LCD_D0;
  buscfg.data1_io_num = PIN_LCD_D1;
  buscfg.sclk_io_num = PIN_LCD_SCK;
  buscfg.data2_io_num = PIN_LCD_D2;
  buscfg.data3_io_num = PIN_LCD_D3;
  buscfg.max_transfer_sz = 536 * 24 * 2 + 64;
  buscfg.flags = SPICOMMON_BUSFLAG_MASTER | SPICOMMON_BUSFLAG_GPIO_PINS;
  ESP_ERROR_CHECK(spi_bus_initialize(SPI2_HOST, &buscfg, SPI_DMA_CH_AUTO));

  spi_device_interface_config_t devcfg = {};
  devcfg.command_bits = 8;
  devcfg.address_bits = 24;
  devcfg.mode = 0;
  devcfg.clock_speed_hz = 40 * 1000 * 1000;
  devcfg.spics_io_num = -1;
  devcfg.flags = SPI_DEVICE_HALFDUPLEX;
  devcfg.queue_size = 4;
  ESP_ERROR_CHECK(spi_bus_add_device(SPI2_HOST, &devcfg, &qspi_dev));

  lcd_send_cmd(0x11, nullptr, 0); // Sleep Out
  delay(120);
  uint8_t madctl = 0x60;          // Landscape 536x240
  lcd_send_cmd(0x36, &madctl, 1);
  uint8_t colmod = 0x55;          // 16-bit RGB565
  lcd_send_cmd(0x3A, &colmod, 1);
  uint8_t brt = 0xE8;
  lcd_send_cmd(0x51, &brt, 1);
  lcd_send_cmd(0x29, nullptr, 0); // Display On
  delay(20);
}

// ---- RGB565 Byte-Swapped Color Helper (Big-Endian for QSPI RM67162) ----
static inline uint16_t rgb(uint8_t r, uint8_t g, uint8_t b) {
  uint16_t c = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
  return (c >> 8) | (c << 8);
}

static inline void putPx(int x, int y, uint16_t c) {
  if ((unsigned)x < LCD_W && (unsigned)y < LCD_H) fb[y * LCD_W + x] = c;
}

static void fillRect(int x, int y, int w, int h, uint16_t c) {
  int x0 = max(0, x), y0 = max(0, y), x1 = min(LCD_W, x + w), y1 = min(LCD_H, y + h);
  for (int yy = y0; yy < y1; yy++) {
    uint16_t *row = fb + yy * LCD_W;
    for (int xx = x0; xx < x1; xx++) row[xx] = c;
  }
}

static void fillRoundRect(int x, int y, int w, int h, int r, uint16_t c) {
  for (int dy = 0; dy < h; dy++) {
    int yy = y + dy;
    if ((unsigned)yy >= LCD_H) continue;
    int inset = 0;
    if (dy < r) {
      int ry = r - dy;
      inset = r - (int)sqrtf((float)(r * r - ry * ry));
    } else if (dy >= h - r) {
      int ry = dy - (h - 1 - r);
      inset = r - (int)sqrtf((float)(r * r - ry * ry));
    }
    int x0 = max(0, x + inset), x1 = min(LCD_W, x + w - inset);
    uint16_t *row = fb + yy * LCD_W;
    for (int xx = x0; xx < x1; xx++) row[xx] = c;
  }
}

static void drawRoundRectBorder(int x, int y, int w, int h, int r, uint16_t borderCol, uint16_t fillCol) {
  fillRoundRect(x, y, w, h, r, borderCol);
  fillRoundRect(x + 1, y + 1, w - 2, h - 2, max(0, r - 1), fillCol);
}

static void fillCircle(int cx, int cy, int r, uint16_t c) {
  for (int dy = -r; dy <= r; dy++) {
    int dxMax = (int)sqrtf((float)(r * r - dy * dy));
    int yy = cy + dy;
    if ((unsigned)yy >= LCD_H) continue;
    int x0 = max(0, cx - dxMax), x1 = min(LCD_W - 1, cx + dxMax);
    uint16_t *row = fb + yy * LCD_W;
    for (int xx = x0; xx <= x1; xx++) row[xx] = c;
  }
}

// ---- Clean 5x7 Scalable Bitmap Font (ASCII 32..126) ----
static const uint8_t FONT5x7[95][5] = {
  {0x00,0x00,0x00,0x00,0x00},{0x00,0x00,0x5F,0x00,0x00},{0x00,0x07,0x00,0x07,0x00},{0x14,0x7F,0x14,0x7F,0x14},
  {0x24,0x2A,0x7F,0x2A,0x12},{0x23,0x13,0x08,0x64,0x62},{0x36,0x49,0x55,0x22,0x50},{0x00,0x05,0x03,0x00,0x00},
  {0x00,0x1C,0x22,0x41,0x00},{0x00,0x41,0x22,0x1C,0x00},{0x14,0x08,0x3E,0x08,0x14},{0x08,0x08,0x3E,0x08,0x08},
  {0x00,0x50,0x30,0x00,0x00},{0x08,0x08,0x08,0x08,0x08},{0x00,0x60,0x60,0x00,0x00},{0x20,0x10,0x08,0x04,0x02},
  {0x3E,0x51,0x49,0x45,0x3E},{0x00,0x42,0x7F,0x40,0x00},{0x42,0x61,0x51,0x49,0x46},{0x21,0x41,0x45,0x4B,0x31},
  {0x18,0x14,0x12,0x7F,0x10},{0x27,0x45,0x45,0x45,0x39},{0x3C,0x4A,0x49,0x49,0x30},{0x01,0x71,0x09,0x05,0x03},
  {0x36,0x49,0x49,0x49,0x36},{0x06,0x49,0x49,0x29,0x1E},{0x00,0x36,0x36,0x00,0x00},{0x00,0x56,0x36,0x00,0x00},
  {0x08,0x14,0x22,0x41,0x00},{0x14,0x14,0x14,0x14,0x14},{0x00,0x41,0x22,0x14,0x08},{0x02,0x01,0x51,0x09,0x06},
  {0x32,0x49,0x79,0x41,0x3E},{0x7E,0x11,0x11,0x11,0x7E},{0x7F,0x49,0x49,0x49,0x36},{0x3E,0x41,0x41,0x41,0x22},
  {0x7F,0x41,0x41,0x22,0x1C},{0x7F,0x49,0x49,0x49,0x41},{0x7F,0x09,0x09,0x09,0x01},{0x3E,0x41,0x49,0x49,0x7A},
  {0x7F,0x08,0x08,0x08,0x7F},{0x00,0x41,0x7F,0x41,0x00},{0x20,0x40,0x41,0x3F,0x01},{0x7F,0x08,0x14,0x22,0x41},
  {0x7F,0x40,0x40,0x40,0x40},{0x7F,0x02,0x0C,0x02,0x7F},{0x7F,0x04,0x08,0x10,0x7F},{0x3E,0x41,0x41,0x41,0x3E},
  {0x7F,0x09,0x09,0x09,0x06},{0x3E,0x41,0x51,0x21,0x5E},{0x7F,0x09,0x19,0x29,0x46},{0x46,0x49,0x49,0x49,0x31},
  {0x01,0x01,0x7F,0x01,0x01},{0x3F,0x40,0x40,0x40,0x3F},{0x1F,0x20,0x40,0x20,0x1F},{0x3F,0x40,0x38,0x40,0x3F},
  {0x63,0x14,0x08,0x14,0x63},{0x07,0x08,0x70,0x08,0x07},{0x61,0x51,0x49,0x45,0x43},{0x00,0x7F,0x41,0x41,0x00},
  {0x02,0x04,0x08,0x10,0x20},{0x00,0x41,0x41,0x7F,0x00},{0x04,0x02,0x01,0x02,0x04},{0x40,0x40,0x40,0x40,0x40},
  {0x00,0x01,0x02,0x04,0x00},{0x20,0x54,0x54,0x54,0x78},{0x7F,0x48,0x44,0x44,0x38},{0x38,0x44,0x44,0x44,0x20},
  {0x38,0x44,0x44,0x48,0x7F},{0x38,0x54,0x54,0x54,0x18},{0x08,0x7E,0x09,0x01,0x02},{0x0C,0x52,0x52,0x52,0x3E},
  {0x7F,0x08,0x04,0x04,0x78},{0x00,0x44,0x7D,0x40,0x00},{0x20,0x40,0x44,0x3D,0x00},{0x7F,0x10,0x28,0x44,0x00},
  {0x00,0x41,0x7F,0x40,0x00},{0x7C,0x04,0x18,0x04,0x78},{0x7C,0x08,0x04,0x04,0x78},{0x38,0x44,0x44,0x44,0x38},
  {0x7C,0x14,0x14,0x14,0x08},{0x08,0x14,0x14,0x18,0x7C},{0x7C,0x08,0x04,0x04,0x08},{0x48,0x54,0x54,0x54,0x20},
  {0x04,0x3F,0x44,0x40,0x20},{0x3C,0x40,0x40,0x20,0x7C},{0x1C,0x20,0x40,0x20,0x1C},{0x3C,0x40,0x30,0x40,0x3C},
  {0x44,0x28,0x10,0x28,0x44},{0x0C,0x50,0x50,0x50,0x3C},{0x44,0x64,0x54,0x4C,0x44},{0x00,0x08,0x36,0x41,0x00},
  {0x00,0x00,0x7F,0x00,0x00},{0x00,0x41,0x36,0x08,0x00},{0x08,0x04,0x08,0x10,0x08}
};

static void drawChar(int x, int y, char c, uint16_t col, int scale, bool bold = false) {
  if (c < 32 || c > 126) c = '?';
  const uint8_t *glyph = FONT5x7[c - 32];
  for (int i = 0; i < 5; i++) {
    uint8_t line = glyph[i];
    for (int j = 0; j < 7; j++) {
      if (line & (1 << j)) {
        fillRect(x + i * scale, y + j * scale, scale + (bold ? 1 : 0), scale, col);
      }
    }
  }
}

static void drawText(int x, int y, const char *str, uint16_t col, int scale = 2, bool bold = false) {
  int cx = x;
  while (*str) {
    drawChar(cx, y, *str++, col, scale, bold);
    cx += 6 * scale + (bold ? 1 : 0);
  }
}

// ---- fbox OS State ----
enum AppMode {
  MODE_AUDIOBOOK = 0,
  MODE_SPOTIFY   = 1,
  MODE_SDOFFLINE = 2,
  MODE_GEMINI_AI = 3,
  MODE_VOICENOTE = 4,
  MODE_BENCHDIAG = 5,
  MODE_COUNT     = 6
};

struct TrackInfo {
  const char *modeBadge;
  uint16_t badgeCol;
  const char *title;
  const char *artist;
  const char *sub;
  int durSec;
};

static const TrackInfo TRACKS[3][3] = {
  { // Audiobookshelf
    {"AUDIOBOOKSHELF", 0, "The Way of Kings", "Brandon Sanderson - Ch. 04", "Honor is Dead - Stormlight Archive", 1620},
    {"AUDIOBOOKSHELF", 0, "Project Hail Mary", "Andy Weir - Ch. 11", "Rocky First Contact - Ray Porter", 1940},
    {"AUDIOBOOKSHELF", 0, "Neuromancer", "William Gibson - Ch. 02", "Chiba City Blues - Case", 1380}
  },
  { // Spotify Connect
    {"SPOTIFY CONNECT", 0, "Midnight City", "M83 - Hurry Up, We're Dreaming", "320kbps Ogg Vorbis - Wi-Fi Stream", 243},
    {"SPOTIFY CONNECT", 0, "Veridis Quo", "Daft Punk - Discovery", "320kbps Ogg Vorbis - Wi-Fi Stream", 345},
    {"SPOTIFY CONNECT", 0, "Resonance", "HOME - Odyssey", "320kbps Ogg Vorbis - Wi-Fi Stream", 212}
  },
  { // SD Offline
    {"SD OFFLINE 128GB", 0, "Dune (Unabridged)", "Frank Herbert - Book 1 Trk 07", "FAT32 HSPI IO16/39/40/41", 2180},
    {"SD OFFLINE 128GB", 0, "Foundation", "Isaac Asimov - Part II: The Mayors", "FAT32 HSPI IO16/39/40/41", 1810},
    {"SD OFFLINE 128GB", 0, "Snow Crash", "Neal Stephenson - Ch. 09", "FAT32 HSPI IO16/39/40/41", 1540}
  }
};

static int curMode = MODE_AUDIOBOOK;
static int curTrack = 0;
static bool isPlaying = true;
static float playSec = 412.0f;
static int outRoute = 0; // 0: BT TX + 3.5mm, 1: 1511 SPEAKER, 2: 3.5MM TRS ONLY
static const char* OUT_NAMES[3] = {"BT TX + 3.5MM", "1511 SPEAKER", "3.5MM HEADPHONES"};
static int aiPromptIdx = 0;
static const char* AI_PROMPTS[3] = {
  "\"Summarize Ch. 03 of The Way of Kings\"",
  "\"Who is Kaladin Stormblessed? (No spoilers)\"",
  "\"Bookmark 06:52 & save voice note to SD\""
};
static const char* AI_REPLIES[3] = {
  "Kaladin survives the highstorm & vows to protect Bridge Four.",
  "A former surgeon's apprentice & squad leader turned bridgeman.",
  "Saved bookmark @ 06:52 + synced to Audiobookshelf server."
};

static float readBatteryVolts() {
  uint32_t mv = analogReadMilliVolts(PIN_BAT_ADC);
  float v = (mv * 2.0f) / 1000.0f;
  if (v < 2.5f || v > 4.6f) return 4.12f;
  return v;
}

static void drawArtworkCard(int x, int y, int sz, int mode, int trk, uint32_t ms) {
  for (int dy = 0; dy < sz; dy++) {
    for (int dx = 0; dx < sz; dx++) {
      uint8_t r = 15, g = 23, b = 42;
      if (mode == MODE_AUDIOBOOK) {
        r = 18 + (dy * 185) / sz;
        g = 24 + (dy * 95) / sz;
        b = 58 - (dy * 38) / sz;
      } else if (mode == MODE_SPOTIFY) {
        r = 16 + (dx * 90) / sz;
        g = 30 + ((sz - dy) * 150) / sz;
        b = 75 + (dy * 140) / sz;
      } else {
        r = 40 + (dy * 150) / sz;
        g = 32 + (dx * 110) / sz;
        b = 22;
      }
      putPx(x + dx, y + dy, rgb(r, g, b));
    }
  }
  // Glowing sun / disc emblem inside cover
  int sunY = y + 52 + (int)(sinf(ms * 0.002f) * 3.0f);
  fillCircle(x + sz - 42, sunY, 22, rgb(253, 224, 71));
  fillCircle(x + sz - 42, sunY, 16, rgb(254, 249, 195));

  // Silhouette horizon at bottom of cover
  for (int dx = 0; dx < sz; dx++) {
    int mh = 18 + (int)(sinf(dx * 0.08f + trk) * 8.0f + cosf(dx * 0.19f) * 4.0f);
    for (int dy = sz - mh; dy < sz; dy++) {
      putPx(x + dx, y + dy, rgb(10, 14, 24));
    }
  }
  drawText(x + 10, y + 10, mode == 0 ? "STORMLIGHT" : (mode == 1 ? "SYNTHWAVE" : "OFFLINE SD"), rgb(255, 255, 255), 1, true);
  drawText(x + 10, y + sz - 14, "fbox HI-FI", rgb(203, 213, 225), 1, false);
}

static void renderUI() {
  uint32_t ms = millis();
  // True-black OLED background with subtle slate border
  fillRect(0, 0, LCD_W, LCD_H, rgb(4, 6, 11));
  drawRoundRectBorder(2, 2, LCD_W - 4, LCD_H - 4, 14, rgb(45, 58, 78), rgb(7, 10, 18));

  // Top Status Bar (Y: 10..32)
  uint16_t modeCols[6] = {
    rgb(234, 88, 12),  // Orange Audiobookshelf
    rgb(22, 163, 74),  // Green Spotify
    rgb(202, 138, 4),  // Amber SD Offline
    rgb(14, 165, 233), // Cyan Gemini AI
    rgb(225, 29, 72),  // Coral Voice Notes
    rgb(124, 58, 237)  // Purple Bench Diag
  };
  const char* modeTitles[6] = {
    "AUDIOBOOKSHELF", "SPOTIFY CONNECT", "SD OFFLINE 128GB",
    "GEMINI AI VOICE", "INMP441 VOICE MEMO", "BENCH GPIO TESTER"
  };

  fillRoundRect(14, 10, 152, 20, 6, modeCols[curMode]);
  drawText(22, 16, modeTitles[curMode], rgb(255, 255, 255), 1, true);

  fillRoundRect(174, 10, 128, 20, 6, rgb(23, 37, 84));
  drawText(182, 16, OUT_NAMES[outRoute], rgb(125, 211, 252), 1, true);

  float vBat = readBatteryVolts();
  int pct = constrain((int)((vBat - 3.30f) / (4.18f - 3.30f) * 100.0f), 1, 100);
  char batBuf[32];
  snprintf(batBuf, sizeof(batBuf), "LiPo %d%% %.2fV", pct, vBat);
  fillRoundRect(310, 10, 116, 20, 6, rgb(15, 23, 42));
  drawText(318, 16, batBuf, rgb(74, 222, 128), 1, true);

  drawText(438, 16, isPlaying ? "PLAYING" : "PAUSED", isPlaying ? rgb(56, 189, 248) : rgb(251, 191, 36), 1, true);

  if (curMode <= MODE_SDOFFLINE) {
    const TrackInfo &tr = TRACKS[curMode][curTrack];
    drawArtworkCard(16, 40, 148, curMode, curTrack, ms);

    // Track Metadata (Right of Artwork, X = 180..520)
    drawText(180, 46, tr.title, rgb(248, 250, 252), 3, true);
    drawText(180, 82, tr.artist, rgb(148, 163, 184), 2, false);
    drawText(180, 104, tr.sub, rgb(100, 116, 139), 1, false);

    // Live 20-bar Audio Visualizer (X: 180..510, Y: 122..152)
    for (int i = 0; i < 22; i++) {
      int bh = isPlaying
        ? (6 + (int)(fabsf(sinf(ms * 0.006f + i * 0.55f) * 18.0f + cosf(ms * 0.011f - i * 0.3f) * 6.0f)))
        : 4;
      uint16_t bc = (i < 14) ? rgb(56, 189, 248) : rgb(245, 158, 11);
      fillRoundRect(180 + i * 15, 152 - bh, 10, bh, 2, bc);
    }

    // Progress Bar (X: 180..514, Y: 164..174)
    float frac = fmodf(playSec, (float)tr.durSec) / (float)tr.durSec;
    fillRoundRect(180, 164, 334, 10, 5, rgb(30, 41, 59));
    int fillW = max(10, (int)(334 * frac));
    fillRoundRect(180, 164, fillW, 10, 5, modeCols[curMode]);

    int curS = (int)fmodf(playSec, (float)tr.durSec);
    char tBuf[48];
    snprintf(tBuf, sizeof(tBuf), "%02d:%02d / %02d:%02d", curS / 60, curS % 60, tr.durSec / 60, tr.durSec % 60);
    drawText(180, 182, tBuf, rgb(203, 213, 225), 2, false);
  } else if (curMode == MODE_GEMINI_AI) {
    drawRoundRectBorder(16, 40, 504, 54, 8, rgb(14, 165, 233), rgb(12, 22, 38));
    drawText(28, 48, "MIC PROMPT (PRESS KEY TO CYCLE):", rgb(56, 189, 248), 1, true);
    drawText(28, 66, AI_PROMPTS[aiPromptIdx], rgb(255, 255, 255), 2, true);

    drawRoundRectBorder(16, 102, 504, 54, 8, rgb(51, 65, 85), rgb(15, 23, 42));
    drawText(28, 110, "GEMINI 2.5 FLASH RESPONSE:", rgb(251, 191, 36), 1, true);
    drawText(28, 128, AI_REPLIES[aiPromptIdx], rgb(226, 232, 240), 1, false);

    // Animated INMP441 Waveform
    for (int i = 0; i < 32; i++) {
      int h = 6 + (int)(fabsf(sinf(ms * 0.008f + i * 0.4f)) * 22.0f);
      fillRoundRect(20 + i * 15, 194 - h, 10, h, 2, rgb(244, 63, 94));
    }
  } else if (curMode == MODE_VOICENOTE) {
    fillCircle(42, 68, 12, (ms / 400) % 2 == 0 ? rgb(239, 68, 68) : rgb(127, 29, 29));
    drawText(66, 56, "INMP441 16kHz PCM VOICE RECORDER", rgb(248, 250, 252), 2, true);
    drawText(66, 82, "Pam8302 Speaker Auto-Muted (GPIO 21 = LOW)", rgb(148, 163, 184), 1, false);
    for (int i = 0; i < 32; i++) {
      int h = 4 + (int)(fabsf(cosf(ms * 0.009f + i * 0.35f)) * 38.0f);
      fillRoundRect(20 + i * 15, 160 - h, 10, h, 2, rgb(251, 113, 133));
    }
    drawText(20, 174, "SAVED TO SD: /NOTES/MEMO_04.WAV (00:18)  |  128GB FAT32 READY", rgb(74, 222, 128), 1, true);
  } else if (curMode == MODE_BENCHDIAG) {
    drawText(18, 42, "LIVE SOLDER BENCH GPIO & ADC DIAGNOSTICS:", rgb(192, 132, 252), 2, true);
    bool bootDown = (digitalRead(PIN_BTN_BOOT) == LOW);
    bool keyDown  = (digitalRead(PIN_BTN_KEY1) == LOW) || (digitalRead(PIN_BTN_KEY2) == LOW);
    drawRoundRectBorder(18, 68, 235, 32, 6, bootDown ? rgb(34, 197, 94) : rgb(71, 85, 105), bootDown ? rgb(20, 83, 45) : rgb(15, 23, 42));
    drawText(28, 78, bootDown ? "ONBOARD BOOT (IO0): PRESSED" : "ONBOARD BOOT (IO0): IDLE", rgb(255, 255, 255), 1, true);

    drawRoundRectBorder(265, 68, 252, 32, 6, keyDown ? rgb(34, 197, 94) : rgb(71, 85, 105), keyDown ? rgb(20, 83, 45) : rgb(15, 23, 42));
    drawText(275, 78, keyDown ? "ONBOARD KEY (IO14/21): PRESSED" : "ONBOARD KEY (IO14/21): IDLE", rgb(255, 255, 255), 1, true);

    for (int i = 0; i < 7; i++) {
      bool down = (digitalRead(EXT_BTN_PINS[i]) == LOW);
      int bx = 18 + i * 72;
      drawRoundRectBorder(bx, 110, 68, 36, 5, down ? rgb(34, 197, 94) : rgb(51, 65, 85), down ? rgb(20, 83, 45) : rgb(15, 23, 42));
      drawText(bx + 6, 118, EXT_BTN_NAMES[i], down ? rgb(134, 239, 172) : rgb(148, 163, 184), 1, true);
      char pStr[16];
      snprintf(pStr, sizeof(pStr), "IO%d:%s", EXT_BTN_PINS[i], down ? "LOW" : "HI");
      drawText(bx + 6, 132, pStr, rgb(203, 213, 225), 1, false);
    }
    char joyStr[64];
    snprintf(joyStr, sizeof(joyStr), "KY-023 ADC1: VRx(IO1)=%4d  VRy(IO10)=%4d  SW(IO11)=%s",
             analogRead(PIN_JOY_X), analogRead(PIN_JOY_Y), digitalRead(PIN_JOY_SW) == LOW ? "PRESSED" : "HIGH");
    drawText(18, 162, joyStr, rgb(56, 189, 248), 1, true);
  }

  // Bottom Control Legend Bar (Y: 208..232)
  fillRoundRect(12, 208, LCD_W - 24, 22, 6, rgb(15, 23, 42));
  drawText(22, 215, "KEY: Tap=Next Track  Hold=Switch Mode   |   BOOT: Tap=Play/Pause  Hold=Audio Output", rgb(148, 163, 184), 1, true);

  lcd_push_fb();
}

static uint32_t bootPressMs = 0, keyPressMs = 0;
static bool bootWasDown = false, keyWasDown = false;
static bool bootLongHandled = false, keyLongHandled = false;
static uint32_t lastTickMs = 0;

void setup() {
  Serial.begin(115200);
  pinMode(PIN_BTN_BOOT, INPUT_PULLUP);
  pinMode(PIN_BTN_KEY1, INPUT_PULLUP);
  pinMode(PIN_BTN_KEY2, INPUT_PULLUP);
  for (int i = 0; i < 7; i++) {
    pinMode(EXT_BTN_PINS[i], INPUT_PULLUP);
  }
  pinMode(PIN_JOY_SW, INPUT_PULLUP);

  fb = (uint16_t *)ps_malloc(LCD_W * LCD_H * sizeof(uint16_t));
  if (!fb) fb = (uint16_t *)malloc(LCD_W * LCD_H * sizeof(uint16_t));

  lcd_init();
  lastTickMs = millis();
  Serial.println("fbox OS 1.91\" RM67162 AMOLED booted!");
}

void loop() {
  uint32_t now = millis();
  float dt = (now - lastTickMs) / 1000.0f;
  lastTickMs = now;
  if (isPlaying) playSec += dt;

  // Poll Onboard BOOT (IO0)
  bool bDown = (digitalRead(PIN_BTN_BOOT) == LOW);
  if (bDown && !bootWasDown) {
    bootPressMs = now;
    bootLongHandled = false;
  } else if (bDown && !bootLongHandled && (now - bootPressMs > 450)) {
    outRoute = (outRoute + 1) % 3;
    bootLongHandled = true;
  } else if (!bDown && bootWasDown && !bootLongHandled) {
    isPlaying = !isPlaying;
  }
  bootWasDown = bDown;

  // Poll Onboard KEY (IO21 or IO14)
  bool kDown = (digitalRead(PIN_BTN_KEY1) == LOW) || (digitalRead(PIN_BTN_KEY2) == LOW);
  if (kDown && !keyWasDown) {
    keyPressMs = now;
    keyLongHandled = false;
  } else if (kDown && !keyLongHandled && (now - keyPressMs > 450)) {
    curMode = (curMode + 1) % MODE_COUNT;
    keyLongHandled = true;
  } else if (!kDown && keyWasDown && !keyLongHandled) {
    if (curMode <= MODE_SDOFFLINE) {
      curTrack = (curTrack + 1) % 3;
      playSec = 0;
    } else if (curMode == MODE_GEMINI_AI) {
      aiPromptIdx = (aiPromptIdx + 1) % 3;
    }
  }
  keyWasDown = kDown;

  renderUI();
  delay(16);
}
