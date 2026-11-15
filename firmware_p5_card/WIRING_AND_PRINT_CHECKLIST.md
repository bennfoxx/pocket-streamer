# Option P5-Card (`72.0 × 98.0 × 18.0 mm`) — Day-1 Solder & Bambu P2S Print Checklist

> **Screenshot-Verified Dimensions & Safety Audit:** See [`COMPONENT_DIMENSIONS_AND_SCREENSHOT_AUDIT.md`](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/COMPONENT_DIMENSIONS_AND_SCREENSHOT_AUDIT.md) for the complete `53`-screenshot repository, electrical limits, and CAD verification delta.

## 1. Bambu Lab P2S Single-Plate Print Files (`stl_p5_card/`, All Verified `minZ = 0.00 mm`)

| File | Tris | Size (`mm`) | Slicer Notes |
|---|---|---|---|
| [`p5_card_single_plate_all_parts.stl`](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/stl_p5_card/p5_card_single_plate_all_parts.stl) | `4048` | `210.80 × 183.00 × 16.20` | **All `11` parts pre-laid out on 1 plate** (`~38 cm³`, `~47 g`) in 4 separated AMS color zones (`Matte Black`, `Coral`, `Amber`, `Teal`) |
| [`p5_card_bottom_tray.stl`](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/stl_p5_card/p5_card_bottom_tray.stl) | `648` | `72.00 × 98.00 × 16.20` | Back-plate down; **1 external USB-C port only** (Left Wall); Top Wall sealed over `V713` Boost (`3.5 mm` jack only); includes `4×` hollow `M2` corner bosses & all internal PCB cradles |
| [`p5_card_top_faceplate.stl`](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/stl_p5_card/p5_card_top_faceplate.stl) | `2280` | `72.00 × 98.00 × 3.40` | Exterior faceplate down (rigid `180°` X-flip aligned to tray); `4× 2.2 × 2.2 mm` M2 holes, `Ø25.0 mm` recessed stick well, `21`-hole `Ø9.6 mm` mic grille, `INMP441` ring (`Z: 1.8..3.4 mm`) |
| [`p5_card_concave_thumb_disc.stl`](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/stl_p5_card/p5_card_concave_thumb_disc.stl) | `928` | `16.00 × 16.00 × 3.80` | Pre-oriented **stem-down** (`Z: 0..1.6 mm` collar, `1.6..2.6` floor, `2.6..3.8` rim; leaves `4.5 mm` open moat inside `Ø25 mm` well) |
| [`p5_card_keycaps_8x.stl`](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/stl_p5_card/p5_card_keycaps_8x.stl) | `192` | `45.40 × 21.40 × 3.60` | Flat on `0.8 mm` captive base flanges (`2×4` grid); optional brim if bed adhesion is low |

**Exact Bambu Studio P2S Slicer Settings (All `11` Parts on One `256 × 256 mm` Plate):**
- **Visual Plate Layout:** [`ref_15g_p5_card_internal_cradles_and_print_plate.png`](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/parts_1to1_3d/renders/ref_15g_p5_card_internal_cradles_and_print_plate.png)
- **Fastest Single-Plate AMS Workflow (`3` Swaps Total, Zero Purge Tower Waste):** Drop [`p5_card_single_plate_all_parts.stl`](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/stl_p5_card/p5_card_single_plate_all_parts.stl) onto a `256 × 256 mm` plate → right-click **`Split → To Objects`** (creates all `11` parts already pre-grouped in 4 widely spaced color zones) → assign filament slots (`Matte Black`: tray + faceplate + top `4` caps; `Coral`: thumb-disc + `B8`; `Amber`: `B5 + B7`; `Teal`: `B6`) → set **`Print sequence = By object`** (or leave `By layer` — all accent caps stop at `Z = 3.6–3.8 mm`, so filament swaps only happen in the bottom `3.8 mm`). Or skip splitting completely for a zero-swap monochrome print.
- **Material:** Matte Black / Dark Charcoal `PETG` (recommended for drop resistance) or `PLA+`
- **Layer Height:** `0.20 mm` Standard (`0.4 mm` nozzle) | **Wall Loops:** `3` | **Infill:** `20%` Gyroid
- **Supports:** **Normal (auto) -> Snug -> On build plate only** (supports the `3` remaining side port roof bridges on `p5_card_bottom_tray.stl` — Left `AMOLED` USB-C, Top `3.5 mm` jack, Right `MicroSD` — and the short elevated shelves for `GY-PCM5102`, `AMOLED` right split shelves, and `MicroSD` left step; zero supports needed inside the hollow `M2` bores).
- **Hardware:** `4× M2 × 12 mm` socket-head screws (self-tap directly into the `2.0 × 2.0 mm` boss pilot bores or heat-set `M2` brass inserts).

**Internal Cradle Drop-In Assembly Order:**
1. Seat `503759` LiPo (`1300 mAh`, `59.0 × 37.0 × 5.0 mm`) between lateral rails (`Y: 38.0..75.0 mm`, `Z: 1.8..7.0 mm`) and cap with `0.8 mm` Kapton/printed `shield_rib` (`Y: 37.7..75.2 mm`, `Z: 7.0..7.8 mm`).
2. Drop `Acxico` (`KCX_BT_EMITTER`, `23.5 × 15.5 mm`) + **`AOICRIE V713` (`FM5324GA`) `5V 2A Boost`** (`25.0 × 20.0 × 4.8 mm`) onto the Top Bay floor (`Z: 2.0 mm`): orient `V713` **100% internally** against stop-lip `cradle_boost_stop` (`Y: 75.3..75.7 mm`) with its internal USB-C port facing `+X` — the Top Wall USB-C is **sealed** (`Only 1 external USB-C port on Left Wall`).
3. Screw/adhere `KY-023` (`33.0 × 25.0 mm`) onto `4×` `0.6 mm` corner standoffs (`Z: 2.4 mm`); drop `2×` `1×4` keypads onto the `3` support rails (`Z: 6.4 mm`, wires routed through the open channels).
4. Seat `GY-PCM5102` onto Left L-bracket & Right divider pillar (`Z: 9.5 mm`, `3.5 mm` jack flush in Top Wall) and `Mini 3.3V MicroSD` (`17.9 × 17.9 mm`) onto its split U-pedestal (`Z: 9.8 mm`, left step `Z: 8.0..9.8 mm` clearing the internal `V713` Boost USB-C `Z <= 6.8 mm`, slot flush in Right Wall).
5. Drop `T-Display-S3 AMOLED` (`60.0 × 25.5 mm`) onto Left twin ledges & Right split L-bracket shelves (`Z: 12.0 mm`, clearing rear `JST-GH`/`Qwiic`/`RES` and `3D` metal antenna, Left USB-C flush in Left Wall), seat `INMP441` into faceplate alignment collar (`Z: 14.6..16.2 mm`) with gasket, capture `8×` keycaps & thumb-disc under faceplate, and tighten `4× M2` corner screws.

---

## 2. Pre-Assembly Hardware Prep (`30 AWG` Silicone Wire)
1. **`GODIYMODULES 1×4` Keypads (`2×`)**: Desolder or flush-cut the tall yellow `1×5` headers; solder `30 AWG` wires flat to the underside pads.
2. **`KY-023` Thumbstick**: Remove the tall mushroom cap and `90°` `1×5` header; solder `30 AWG` wires flat to the 5 pads.
3. **`GY-PCM5102` Backside Solder-Bridge Pads**:
   - `SCK → GND` (enables internal PLL — 3-wire I2S)
   - `H1L (FLT) → GND`, `H2L (DEMP) → GND`, `H3L (XSMT) → 3.3V` (**mandatory un-mute!**), `H4L (FMT) → GND`.
4. **`INMP441` MEMS Mic**:
   - Tie `L/R → GND` (Left channel).
   - Add **`100 kΩ` pull-down resistor** from `SD` (`GPIO 15`) → `GND`.
   - Seal flat pinhole side against a `0.6 mm` foam/TPU gasket ring aligned inside the `INMP441` collar under the faceplate `Ø9.6 mm` `21`-hole grille.

---

## 3. Exact Wiring Table (`LILYGO T-Display-S3 AMOLED` + Option A Direct Buttons)
| Module | Pin | `T-Display-S3 AMOLED` Pin | Power / Note |
|---|---|---|---|
| `KY-023` | `VCC / +5V` | **`3.3V`** | Strictly `3.3V`! |
| `KY-023` | `VRx` | **`GPIO 1`** | `ADC1` |
| `KY-023` | `VRy` | **`GPIO 10`** | `ADC1` |
| `KY-023` | `SW` | **`GPIO 11`** | `INPUT_PULLUP` *(+ `ext0` Deep Sleep / Wake)* |
| `GY-PCM5102` | `VIN` | **`5V` Boost `OUT+`** | Clean analog LDO |
| `GY-PCM5102` + `INMP441` | `BCK` / `SCK` | **`GPIO 12`** | Shared `I2S0` |
| `GY-PCM5102` + `INMP441` | `LCK` / `WS` | **`GPIO 13`** | Shared `I2S0` |
| `GY-PCM5102` | `DIN` | **`GPIO 14`** | Playback |
| `INMP441` | `VDD` | **`3.3V`** | Strictly `3.3V`! |
| `INMP441` | `SD` | **`GPIO 15`** | `+ 100 kΩ` → `GND` |
| `Mini 3.3V MicroSD` | `3V3` | **`3.3V`** | Strictly `3.3V`! |
| `Mini 3.3V MicroSD` | `CS / MOSI / CLK / MISO` | **`16 / 39 / 40 / 41`** | Dedicated `HSPI` |
| `1×4` Keypad Strips (`2×`) | `GND` (both strips) | **`GND`** | Common ground bus for all 8 switches |
| `1×4` Top Strip (`K1`) | **`K1` (1 button)** | **`V713` Boost `K` pad** | **Hardware `5V` Power (`1-click ON / 2-click OFF`)** — do *not* wire to ESP32! |
| `1×4` Strips (`7` UI keys) | `K2..K4` (top) + `K1..K4` (bot) | **`GPIO 42, 43, 44, 45, 2, 3, 46`** | Direct `INPUT_PULLUP` *(no matrix scanning; don't hold `45`/`46` during boot)* |
| `Liter 503759` (`1300 mAh`) | `BAT+` / `BAT-` | **`T-Display-S3` `BAT` (`JST-GH`)** + **`V713` `B+`/`B-`** | **Charge ONLY via `T-Display-S3` USB-C (`~500 mA`)** — never `V713` USB-C (`2.4A` > `0.5C` max!) |

> **Power Architecture Note:** Keeping `5V` Boost `OUT+` off `VSYS` (feeding `T-Display-S3` directly from `BAT`) lets you flash/charge via `T-Display-S3` USB-C anytime with zero `VSYS` back-feed, while **double-clicking `K1`** cuts `5V` (`GY-PCM5102` + `Acxico`) to `0 mA` and **long-pressing `KY-023 SW` (`GPIO 11`)** puts `ESP32-S3` + AMOLED into `< 1 mA` Deep Sleep.

---

## 4. `Acxico` (`KCX_BT_EMITTER`) Internal Bluetooth Audio TX (`5` Short Wires Under `GY-PCM5102`)
| `KCX_BT_EMITTER` Pad | Wire To | Note |
|---|---|---|
| **`+5V`** | **`V713` `5V` Boost `OUT+`** | Controlled by `K1` (`1-click ON / 2-click OFF`) |
| **`PGND`** | **`V713` `5V` Boost `OUT-` (`GND`)** | Power ground |
| **`IN_L` (`AUDIO_L`)** | **`GY-PCM5102` `L` pad** | `~15 mm` jumper straight up to DAC |
| **`IN_R` (`AUDIO_R`)** | **`GY-PCM5102` `R` pad** | `~15 mm` jumper straight up to DAC |
| **`AGND`** | **`GY-PCM5102` `G` pad** | Dedicated audio ground |
