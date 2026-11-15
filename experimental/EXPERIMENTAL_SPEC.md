# Pocket Streamer `/experimental/` — Centered-Screen & Edge-Keypad Exploration (`19.5 mm` Dual-Grip Edition)

> **Status:** Experimental exploration isolated strictly inside `/experimental/` (main `Option P5-Card` and `Option P5-Horizontal` assemblies outside `/experimental/` are untouched).

---

## 1. `/grill-me` Architecture Decisions (All 5 Locked)

1. **Dead-Centered `1.91"` AMOLED (`X_mid = 36.0 mm` Portrait / `X_mid = 49.0 mm` Horizontal):**
   - **Portrait (`72.0 × 98.0 × 19.5 mm`):** `amoled_pcb` at `X: 4.5..64.5` (`amoled_glass` `11.0..61.0`, active `44.2 × 19.8 mm` window `13.9..58.1`), leaving a **`4.5 mm` recessed chamfered USB-C plug funnel** in the left wall (`Y: 54.0..64.4`, `Z: 13.5..16.7`) with zero extra parts.
   - **Horizontal (`98.0 × 72.0 × 19.5 mm`):** `amoled_pcb` at `X: 17.5..77.5` (`amoled_glass` `24.0..74.0`, active `44.2 × 19.8 mm` window `26.9..71.1`), bridged to the sole flush Left-wall USB-C port (`X = 0.0`, `Y: 46.0..56.4`, `Z: 11.6..15.6`) via an **internal USB-C panel-mount pigtail** (`X: 0.0..17.5`, `Z: 12.0..15.2`).
2. **Thickness (`19.5 mm` / `15.9 mm` internal Z cavity):**
   - Bumped from `18.0 mm` to **`19.5 mm`** so the unmodified `37.0 × 15.0 × 1.6 mm` `GODIYMODULES 1×4` keypad mounts vertically on the edge wall (`Z: 2.2..17.2 mm`) with zero PCB trimming, preserving `R = 5.4 mm` rounded corners and `4×` circular `M2` corner bosses (`Ø2.0 mm` pilot bores, `Ø2.2 mm` lid holes).
3. **Edge Keypad Placement:**
   - **Portrait:** Right edge (`X = 72.0 mm`, `Y: 24.0..61.0 mm`) below upper-right `MicroSD` — natural right-thumb reach when held like a handheld cassette field recorder, or Game Boy grip with the front controls.
   - **Horizontal:** Top edge (`Y = 72.0 mm`, `X: 30.5..67.5 mm`) centered above the AMOLED as cassette-transport / shoulder keys, keeping Left = single USB-C, Right = `MicroSD` + `3.5 mm` TRS, Bottom = 100% solid.
4. **Keycap Color Split & Profile:**
   - **Front `1×4`:** Color-coded (`Warm Amber`, `Retro Teal`, `Warm Amber`, `Coral`, `Z: 17.7..20.5 mm`).
   - **Side / Top `1×4`:** `4× Matte Black` low-profile (`~0.8 mm` proud of outer wall) with **`B1` (`V713` 5V Audio Power)** positioned at the topmost (`Y = 56.3 mm` Portrait) / outermost right (`X = 62.6 mm` Horizontal) key to prevent pocket bumps.
5. **Dual Deliverables:**
   - Full Swift 1:1 CAD + collision checks (`0` collisions), 6 Bambu P2S STLs per variant (`minZ = 0.00`), 3 USDZs per variant, interactive HTML 3D explorers, and side-by-side Matte Charcoal + Atomic Smoked Translucent studio renders.

---

## 2. Side-by-Side Comparison

| Parameter | `Option P5-Exp-Portrait` | `Option P5-Exp-Horizontal` |
|---|---|---|
| **Outer Dimensions** | `72.0 × 98.0 × 19.5 mm` (`R = 5.4 mm`) | `98.0 × 72.0 × 19.5 mm` (`R = 5.4 mm`) |
| **1.91" AMOLED Active Center** | `X = 36.0 mm` (dead center) | `X = 49.0 mm` (dead center) |
| **USB-C Routing** | Direct left-wall `4.5 mm` recessed funnel | Internal USB-C pigtail to flush Left wall |
| **Front Keypad (`1×4`)** | Lower-right (`Amber/Teal/Amber/Coral`) | Lower-center (`Amber/Teal/Amber/Coral`) |
| **Edge Keypad (`1×4` Matte Black)** | Right edge (`X = 72.0`, `Y: 28.7..56.3`) | Top edge (`Y = 72.0`, `X: 35.0..62.6`) |
| **3.5 mm TRS Jack** | Top-Left (`Y = 98.0`) | Right-Lower (`X = 98.0`, `Y = 30.75`) |
| **MicroSD Slot** | Right-Upper (`X = 72.0`, `Y: 73.5..91.4`) | Right-Upper (`X = 98.0`, `Y: 44.8..62.7`) |
| **Collision Check** | `45` boxes, `Collisions=0` | `69` boxes, `Collisions=0` |

---

## 3. Verified Deliverables

- **CAD Generators:**
  - [generate_exp_portrait.swift](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/experimental/generate_exp_portrait.swift)
  - [generate_exp_horizontal.swift](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/experimental/generate_exp_horizontal.swift)
- **Interactive 3D Explorers (`node --check` passed, cross-linked):**
  - [p5_exp_portrait_preview.html](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/experimental/p5_exp_portrait_preview.html)
  - [p5_exp_horizontal_preview.html](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/experimental/p5_exp_horizontal_preview.html)
- **Bambu P2S STLs (`minZ = 0.00`, binary `struct` verified):**
  - `experimental/stl_p5_exp_portrait/` (`6` STLs, `7020` plate tris)
  - `experimental/stl_p5_exp_horizontal/` (`6` STLs, `7104` plate tris)
- **Side-by-Side Photorealistic Renders:**
  - [exp_18c_photoreal_opaque.png](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/experimental/renders/exp_18c_photoreal_opaque.png) — Matte Charcoal PLA-CF
  - [exp_18d_photoreal_smoke.png](file:///Users/benfox/Development/3D%20Design/Pocket%20Streamer%20Hardware%20CAD/experimental/renders/exp_18d_photoreal_smoke.png) — Atomic Smoked-Charcoal Translucent
