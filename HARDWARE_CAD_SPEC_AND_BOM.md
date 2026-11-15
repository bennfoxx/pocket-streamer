# Pocket Spotify Streamer & Gemini Assistant — 1:1 Hardware CAD & AliExpress BOM

> **Scope:** Pure internal hardware layout & zero-solder plug-in architecture (**no 3D-printed shell yet**).  
> **Overall Bare Electronics Envelope:** `65.5 × 107.5 × 21.5 mm` (`63.0 mm` wide with Waveshare OLED / Mini PiTFT) — roughly the length of your **Amazon Fire TV Stick (`99 × 30 × 14 mm`, `~108 mm` w/ HDMI)**, ~2× wide, and slim enough to share a pocket cleanly with a phone.

---

## 1. Why Switch from Pirate Audio to a Wide Screen + USB Audio?

Replacing **Pirate Audio + USB Mini Mic** (`2` plug-in connections) with a **Wide Screen HAT + Compact USB 3.5mm Audio/Mic Adapter** uses the **exact same 2 plug-in connections**, requires **zero soldering**, and is actually *simpler* in Linux software (standard plug-and-play USB Audio Class in PipeWire/ALSA—no I2S `dtoverlay` config needed).

| HAT Option | Screen Size & Aspect | Active Area (`mm`) | Physical Controls | Total Envelope (`W × L × H mm`) | Audio + Mic Path | Plugs & Soldering | Est. Total Build Cost |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A. Pimoroni Display HAT Mini** *(Recommended Wide IPS)* | **2.0" Color IPS** (`320 × 240`) | `40.8 × 30.6 mm` *(~2.3× Pirate Audio)* | **4 tactile buttons** + RGB status LED | `65.5 × 107.5 × 21.5` | CM108 USB 3.5mm + Mic | **2 plugs** (`GPIO` + `OTG`), **0 solder** | **~$48–$55** |
| **B. Waveshare 1.3" OLED HAT** *(Best Sub-$50 / Blind Pocket Control)* | **1.3" Wide OLED** (`128 × 64`) | `29.4 × 14.7 mm` *(2:1 wide bar)* | **5-way joystick** + **3 tactile buttons** | `63.0 × 107.5 × 21.5` | CM108 USB 3.5mm + Mic | **2 plugs** (`GPIO` + `OTG`), **0 solder** | **~$42–$48** |
| **C. Adafruit Mini PiTFT 1.14"** *(Budget Compact Wide Color)* | **1.14" Color IPS** (`240 × 135`) | `24.9 × 14.9 mm` *(16:9 wide)* | **2 tactile buttons** | `63.0 × 107.5 × 21.5` | CM108 USB 3.5mm + Mic | **2 plugs** (`GPIO` + `OTG`), **0 solder** | **~$40–$46** |
| **D. Pimoroni Pirate Audio** *(Reference)* | **1.3" Square IPS** (`240 × 240`) | `23.4 × 23.4 mm` *(1:1 square)* | **4 tactile buttons** | `63.0 × 107.5 × 21.5` | HAT I2S DAC + USB Mini Mic | **2 plugs** (`GPIO` + `OTG`), **0 solder** | **~$48–$55** |

---

## 2. Zero-Solder Plug-and-Play Block & Routing Layout

```text
  X = 0..29.2 mm (Left Bay)            X = 29.2..33 mm      X = 33..63 mm (Right Bay)
  ┌──────────────────────────┐         ┌───────────┐      ┌──────────────────────────┐
  │ USB-A 5V Out + Switch    ├────────►│ 90° Flat  │      │ MicroSD Slot (Top Edge)  │
  │                          │ 5V Rib. │  Spine    │      │                          │
  │ ┌──────────────────────┐ │ (Z=2..4)│  Channel  │      │   Raspberry Pi Zero 2 WH │
  │ │  Removable 18650     │ │         │           ├─────►│  (Rotated 90° CW, Z=6mm) │
  │ │   Ø18.5 × 65 mm      │ │         │  90° FPC  │ PWR  │   + Display HAT on GPIO  │
  │ │  (Tool-Free Swap)    │ │         │  Micro-   │      │     (Z = 12.5..21.5 mm)  │
  │ └──────────────────────┘ │         │  USB OTG  ├─────►│                          │
  │                          │         │  (DOWN)   │ OTG  ├──────────────────────────┤
  │ USB-C Charge Port (Y=0)  │         └─────┬─────┘      │ Under-Pi Tunnel (Z=4.3.. │
  └──────────────────────────┘               │            │ 5.7 mm) -> USB Audio/Mic │
                                             └───────────►│  3.5mm Jack │ Mini Mic   │
                                                          └──────┬──────┴─────┬──────┘
                                                              Headphones    Voice
```

- **Why the Pi Zero sits at `Z = 6.0 mm`:** Leaving a `6.0 mm` clearance floor beneath the Pi Zero PCB lets the **90° flat FPC OTG ribbon** tuck cleanly underneath the board (`Z = 4.3..5.7 mm`) straight down into the lower-right `34 mm` audio bay without widening the device or crowding the 18650 cradle.
- **Zero-collision verification:** Verified in `generate_hardware_cad.swift` across all 4 variants (**0 non-mated overlaps**).

---

## 3. AliExpress / Retailer Zero-Solder Buying Checklist

| Component | Exact Search / Spec to Buy | Est. Cost | Critical Gotcha to Check |
| :--- | :--- | :--- | :--- |
| **Compute + Wireless** | **Raspberry Pi Zero 2 WH** *(pre-soldered 40-pin male header, `SC0721`)* | ~$19–$23 | Must say **Zero 2 WH** (or "with pre-soldered header"). Do **not** buy the un-headered `Zero 2 W` unless you want to solder 40 pins. |
| **Display + Buttons HAT** | **Pimoroni Display HAT Mini** (`PIM589`) **OR** **Waveshare 1.3" OLED HAT** *(for Raspberry Pi)* **OR** **Adafruit Mini PiTFT 1.14"** (`4393`) | ~$10–$23 | Verify it includes the **pre-soldered 40-pin female socket** (`Waveshare 1.3inch OLED HAT` and `Display HAT Mini` both ship pre-soldered). |
| **Removable Battery Shield** | **18650 Battery Shield V3 (Type-C USB)** | ~$2–$6 | Buy the **USB-C input** revision (`Type-C` + `USB-A 5V out` + `slide switch`). **No reverse-polarity protection on budget clones**—always verify `+`/`-` before snapping in the cell! |
| **Removable Battery** | **1× Protected or Flat-Top 18650 Li-ion Cell** (`3000–3500 mAh`, e.g., Samsung 35E / Molicel / Panasonic) | ~$5–$7 | Check your shield's cradle length: un-protected flat-top `65.0 mm` cells fit every standard V3 cradle without crushing spring tabs (`69 mm` protected cells are often too tight). |
| **USB Audio + Mic** | **Compact USB 2.0 to 3.5mm Audio + Mic Adapter** (`CM108` / USB Audio Class) + **3.5mm mini plug-in condenser mic** (or integrated TRRS/USB mic) | ~$4–$7 | Look for **"Driverless / Plug-and-Play Linux / Raspberry Pi compatible"** (`CM108` or `UAC1.0` chipset). Avoid gaming adapters requiring Windows drivers. |
| **Low-Profile Ribbons (×2)** | **1× 90° Micro-USB Male to USB-A Male Flat FPC Ribbon** (`10–15 cm` for 5V power) + **1× 90° Micro-USB OTG Male to USB-A Female Flat FPC Ribbon** (`5–10 cm`) | ~$4–$6 | **CRITICAL ANGLE CHECK:** Micro-USB ports are trapezoidal! Look closely at the connector photo so the **90° FPC exits DOWNWARD (toward the narrow bottom face of the Micro-USB plug / under the Pi PCB)**—not upward into the Display HAT or horizontally into the 18650 cradle. |
| **MicroSD Card** | **32 GB or 64 GB MicroSDHC/XC** (Class 10 / U1) | ~$5–$7 | Holds Raspberry Pi OS Lite, `raspotify`, Gemini assistant, and your personal MP3s (top-edge accessible!). |

---

## 4. Why AliExpress Pi Zero 2 WH Beats Pi Pico 2 W for This Build

| Capability | **Raspberry Pi Zero 2 WH** *(AliExpress / Authorized)* | **Raspberry Pi Pico 2 W** *(RP2350 Microcontroller)* |
| :--- | :--- | :--- |
| **Spotify Audio Streaming (`Spotify Connect`)** | **Yes** (`librespot`/`raspotify` runs natively and reliably on Linux) | **No** (no standalone `librespot` port; can only send remote Web API play/pause commands to your phone) |
| **Spotify Controller Mode (trigger AirPods on phone)** | **Yes** (Spotify Web API + instant switch to local player mode) | **Yes** (Spotify Web API over Wi-Fi) |
| **Bluetooth Audio to Headphones (`A2DP`)** | **Yes** (full Linux BlueZ + PipeWire BT audio + phone hotspot/work WPA2-Enterprise Wi-Fi) | Partial (`arduino-pico` BTstack A2DP works for raw PCM/MP3, tight CPU budget when paired with Wi-Fi + TLS + UI) |
| **Zero-Solder Stackability** | **True 1-plug HAT + 1 OTG USB plug** (no pin conflicts) | **Pin conflicts** (`Pico-Audio` uses GP26–28, `Pico-LCD` uses SPI/GP8–13, adding `MicroSD` causes header/MISO collisions) |
| **Gemini Integration + Companion App** | **Native Python `google-genai` SDK**, Live WebSockets, BLE Wi-Fi provisioning, web MP3 uploader | Tight TLS memory limits; requires custom C/C++ or MicroPython chunking |

---

## 5. Generated CAD Files in This Folder

- **Interactive Browser CAD & Blueprint Workbench:** [`hardware_cad_workbench.html`](./hardware_cad_workbench.html)
- **Parametric OpenSCAD Hardware Assembly:** [`pocket_streamer_hardware_cad.scad`](./pocket_streamer_hardware_cad.scad)
- **Swift 1:1 USDZ Generator + Collision Verifier:** [`generate_hardware_cad.swift`](./generate_hardware_cad.swift)
- **1:1 True-Scale Apple Quick Look 3D Models (`.usdz`):**
  - [`hardware_cad_A_display_hat_mini_wide_ips.usdz`](./hardware_cad_A_display_hat_mini_wide_ips.usdz) *(2.0" Wide 320×240 IPS)*
  - [`hardware_cad_B_waveshare_13_oled_joystick.usdz`](./hardware_cad_B_waveshare_13_oled_joystick.usdz) *(1.3" Wide 128×64 OLED + Joystick)*
  - [`hardware_cad_C_adafruit_114_wide_pitft.usdz`](./hardware_cad_C_adafruit_114_wide_pitft.usdz) *(1.14" Wide 240×135 IPS)*
  - [`hardware_cad_D_pirate_audio_comparison.usdz`](./hardware_cad_D_pirate_audio_comparison.usdz) *(1.3" Square Pirate Audio Reference)*
