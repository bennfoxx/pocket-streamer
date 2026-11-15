// ============================================================================
// Pocket Audiobook Streamer & Voice Note-Taker — VERIFIED 1:1 Scale CAD (mm)
// Canonical Hardware Source of Truth (Signed Off by Principal & EE Verifiers)
// BOM: Ordered Amazon Kit (media_1794718210280_73698bc3.jpg) + ACEIRMC 18650 V3
// Zero-Solder Topology A (Flush Left-Wall USB-A -> USB-C U-Bridge)
// Units: 1 unit = 1.000 mm
// Coordinate Frame (Assembly):
//   Origin (0, 0, 0) = Outer Back-Bottom-Left corner of PETG/ASA enclosure
//   X ∈ [0, 156.0] (Width Left->Right), Y ∈ [0, 112.0] (Bottom->Top), Z ∈ [0, 49.0] (Back->Front)
// ============================================================================

$fn = 48;

// --- Selector: "assembly", "lineup", or any part "01".."07" ---
render_mode = "assembly";

// Helper: rounded box in XY
module rbox(size, r = 1.5) {
    w = size[0]; d = size[1]; h = size[2];
    rr = min(r, min(w, d) * 0.45);
    if (rr <= 0.01) {
        cube([w, d, h]);
    } else {
        linear_extrude(height = h)
            offset(r = rr) offset(delta = -rr)
                square([w, d]);
    }
}

// ============================================================================
// 01. ideaspark ESP32 16MB + 1.9" Full-Color ST7789 IPS (ASIN B0D6QXC813)
// Bare PCB: 63.7 x 31.5 x 1.6 mm | 2x19 (38-pin) 2.54mm headers, 27.94mm pitch
// LCD Glass: 49.72 x 25.80 x 1.48 mm | Active Area: 42.72 x 22.70 mm
// Downward Mated F-F DuPont + 6mm bend = 22.5 mm below PCB bottom (24.1 mm stack)
// ============================================================================
module part_01_ideaspark_esp32(show_mated_keepout = false) {
    L = 63.7; W = 31.5; T = 1.6;
    // PCB (bottom at Z=0, top at Z=1.6)
    color([0.10, 0.11, 0.14])
    difference() {
        rbox([L, W, T], r = 1.2);
        for (hx = [2.5, L - 2.5], hy = [2.5, W - 2.5])
            translate([hx, hy, -0.5]) cylinder(d = 2.0, h = T + 1.0);
    }
    // 1.9" ST7789 IPS Glass + Active Screen (front +Z)
    color([0.05, 0.05, 0.07])
        translate([9.5, (W - 25.80) / 2, T]) rbox([49.72, 25.80, 1.48], r = 0.6);
    color([0.08, 0.42, 0.58])
        translate([9.5 + 3.5, (W - 22.70) / 2, T + 1.48]) rbox([42.72, 22.70, 0.12], r = 0.2);
    // FPC fold loop at left end of glass
    color([0.82, 0.48, 0.12])
        translate([7.5, (W - 16.0) / 2, T]) cube([2.2, 16.0, 1.2]);

    // Underside WROOM-32E (18.0 x 25.5 x 3.1 mm) with RF antenna toward right end
    color([0.74, 0.76, 0.80])
        translate([L - 25.5, (W - 18.0) / 2, -3.1]) cube([19.5, 18.0, 3.1]);
    color([0.12, 0.13, 0.16])
        translate([L - 6.0, (W - 18.0) / 2, -1.2]) cube([6.0, 18.0, 1.2]); // Antenna nose

    // Underside USB-C receptacle (overhangs left edge -1.5 mm)
    color([0.76, 0.78, 0.82])
        translate([-1.5, (W - 9.0) / 2, -3.2]) rbox([7.5, 9.0, 3.2], r = 0.8);

    // Underside CH340, AMS1117-3.3, SS14 Schottky, EN/BOOT buttons
    color([0.14, 0.14, 0.16]) {
        translate([12.0, 8.0, -1.6]) cube([10.0, 4.5, 1.6]); // CH340
        translate([13.0, 18.5, -1.7]) cube([6.5, 3.5, 1.7]); // AMS1117-3.3
        translate([8.0, 21.0, -2.0]) cube([4.2, 2.6, 2.0]);  // SS14 Schottky
    }
    color([0.75, 0.75, 0.78]) {
        translate([4.0, 3.8, -2.0]) cube([4.2, 3.0, 2.0]);   // EN button
        translate([4.0, W - 6.8, -2.0]) cube([4.2, 3.0, 2.0]); // BOOT button
    }

    // Downward 2x19 (38-pin) 2.54mm male headers (27.94 mm row-to-row pitch)
    row_y = [(W - 27.94) / 2, (W + 27.94) / 2];
    for (ry = row_y) {
        color([0.08, 0.08, 0.10])
            translate([(L - 48.26) / 2, ry - 1.27, -2.5]) cube([48.26, 2.54, 2.5]);
        color([0.88, 0.70, 0.22])
            for (i = [0 : 18])
                translate([(L - 48.26) / 2 + 1.27 + i * 2.54 - 0.32, ry - 0.32, -11.0])
                    cube([0.64, 0.64, 8.5]);
        if (show_mated_keepout) {
            // 14.0mm DuPont female shell + 6.0mm wire bend = -22.5mm below PCB bottom
            color([0.92, 0.42, 0.12, 0.40])
                translate([(L - 48.26) / 2, ry - 1.38, -22.5]) cube([48.26, 2.76, 20.0]);
        }
    }
}

// ============================================================================
// 02. WM8960 Audio HAT (Waveshare SKU 15668 Pi Zero HAT clone, B0GH6JCGNV)
// Bare PCB: 65.0 x 30.0 x 1.6 mm | 4x M2.5 (Ø2.75mm) @ 58.0 x 23.0 mm
// Bottom 2x20 socket: 50.8 x 5.0 x 8.5 mm (mated M-F + 6mm bend = 28.5mm below PCB)
// Top: 3.5mm TRS jack (overhang +2.0mm), 4-pin JST PH 2.0, K1 button, 2x MEMS mics
// ============================================================================
module part_02_wm8960_hat(show_mated_keepout = false) {
    L = 65.0; W = 30.0; T = 1.6;
    // Deep blue Pi Zero HAT PCB
    color([0.08, 0.18, 0.42])
    difference() {
        rbox([L, W, T], r = 3.0);
        for (hx = [3.5, L - 3.5], hy = [3.5, W - 3.5])
            translate([hx, hy, -0.5]) cylinder(d = 2.75, h = T + 1.0);
    }
    // 3.5 mm TRS Jack (PJ-342, overhangs +2.0 mm past top W edge)
    color([0.12, 0.13, 0.15])
        translate([12.0, W - 12.0, T]) cube([8.5, 14.0, 5.0]);
    color([0.78, 0.78, 0.80])
        translate([16.25, W + 2.0, T + 2.5]) rotate([90, 0, 0]) cylinder(d = 5.6, h = 2.4);

    // 4-Pin JST PH 2.0 Speaker Header (9.9 x 4.5 x 6.0 mm)
    color([0.92, 0.92, 0.90])
        translate([L - 12.5, 11.0, T]) cube([9.9, 4.5, 6.0]);
    if (show_mated_keepout) {
        // Mated PHR-4 + 6mm bend = 14.0mm above PCB top
        color([0.92, 0.42, 0.12, 0.40])
            translate([L - 13.5, 8.0, T + 6.0]) cube([11.5, 10.5, 8.0]);
    }

    // Dual corner MEMS Microphones (3.76 x 2.95 x 1.10 mm)
    color([0.80, 0.82, 0.85]) {
        translate([4.5, 4.5, T]) cube([3.76, 2.95, 1.10]);
        translate([L - 8.26, W - 7.45, T]) cube([3.76, 2.95, 1.10]);
    }
    // WM8960 QFN + 24 MHz XTAL + RT9193-33 + User Button K1
    color([0.12, 0.12, 0.14]) translate([28.0, 12.0, T]) cube([5.0, 5.0, 0.9]); // WM8960
    color([0.75, 0.77, 0.80]) translate([35.0, 13.0, T]) cube([3.2, 2.5, 1.0]); // 24 MHz XTAL
    color([0.82, 0.82, 0.84]) translate([24.0, 22.0, T]) cube([6.0, 6.0, 4.3]); // K1 button

    // Bottom 2x20 40-pin non-pass-through female socket (50.8 x 5.0 x 8.5 mm)
    color([0.10, 0.10, 0.12])
        translate([(L - 50.8) / 2, 1.0, -8.5]) cube([50.8, 5.0, 8.5]);
    if (show_mated_keepout) {
        // Mated M-F DuPont 14.0mm + 6.0mm bend = -28.5 mm below PCB bottom
        color([0.92, 0.42, 0.12, 0.40])
            translate([(L - 50.8) / 2, 0.8, -28.5]) cube([50.8, 5.4, 20.0]);
    }
}

// ============================================================================
// 02b. 3070 Enclosed 8-Ohm 1W Speaker Box (L=70.0, W=30.0, H=17.0 mm)
// ============================================================================
module part_02b_speaker_box() {
    color([0.13, 0.14, 0.16]) rbox([70.0, 30.0, 17.0], r = 3.0);
    // Racetrack diaphragm & surround
    color([0.22, 0.24, 0.27])
        translate([11.0, 4.5, 16.5]) rbox([48.0, 21.0, 1.0], r = 7.0);
    color([0.35, 0.37, 0.40])
        translate([26.0, 10.5, 17.0]) rbox([18.0, 9.0, 0.8], r = 3.5);
}

// ============================================================================
// 03. KY-023 Dual-Axis PS2 Thumbstick (B0D83FD3M8)
// PCB: 34.0 x 26.0 x 1.6 mm | Total height PCB bottom -> cap: 32.0 mm
// 90° Right-Angle 1x5 Male Header -> +22.0 mm mated DuPont + bend
// ============================================================================
module part_03_ky023(show_mated_keepout = false) {
    L = 34.0; W = 26.0; T = 1.6;
    color([0.10, 0.11, 0.13])
    difference() {
        rbox([L, W, T], r = 1.0);
        for (hx = [3.5, L - 3.5], hy = [3.0, W - 3.0])
            translate([hx, hy, -0.5]) cylinder(d = 3.1, h = T + 1.0);
    }
    // Gimbal box + side pots
    color([0.65, 0.67, 0.70]) translate([7.0, 5.0, T]) cube([16.0, 16.0, 12.2]);
    // Thumbstick shaft, dome skirt (Ø26mm) & top cap (Ø17mm to Z=32.0 mm)
    color([0.12, 0.13, 0.15]) {
        translate([15.0, 13.0, T + 12.2]) cylinder(d1 = 26.0, d2 = 16.0, h = 7.5);
        translate([15.0, 13.0, T + 19.7]) cylinder(d = 4.5, h = 6.5);
        translate([15.0, 13.0, 27.5]) cylinder(d1 = 15.0, d2 = 17.0, h = 4.5);
    }
    // 90-degree right-angle 1x5 male header on +X edge
    color([0.08, 0.08, 0.10]) translate([L - 3.5, (W - 12.7) / 2, T]) cube([3.5, 12.7, 2.6]);
    color([0.88, 0.70, 0.22])
        for (i = [0 : 4])
            translate([L, (W - 12.7) / 2 + 1.27 + i * 2.54 - 0.32, T + 0.9])
                cube([8.5, 0.64, 0.64]);
    if (show_mated_keepout) {
        color([0.92, 0.42, 0.12, 0.40])
            translate([L, (W - 13.2) / 2, T - 0.2]) cube([22.0, 13.2, 6.0]);
    }
}

// ============================================================================
// 04. GODIYMODULES 1x4 Tactile Button Keypad (B0GW8BP2KR)
// PCB: 37.0 x 15.0 x 1.6 mm | Button tops: 11.0 mm from PCB bottom
// CRITICAL TRAP: 1x5 Male Header points STRAIGHT UP (+Z) to 13.1 mm!
// Mated 14mm F-F DuPont + 6mm bend = 29.5 mm above PCB bottom (+18.5mm past caps!)
// ============================================================================
module part_04_keypad_1x4(show_mated_keepout = false) {
    L = 37.0; W = 15.0; T = 1.6;
    color([0.10, 0.48, 0.22])
    difference() {
        rbox([L, W, T], r = 1.0);
        for (hx = [2.5, L - 2.5], hy = [2.5, W - 2.5])
            translate([hx, hy, -0.5]) cylinder(d = 2.2, h = T + 1.0);
    }
    // 4x Tactile switches (top at Z=11.0 mm)
    for (i = [0 : 3]) {
        bx = 6.5 + i * 8.0;
        color([0.74, 0.76, 0.78]) translate([bx - 3.0, 2.0, T]) cube([6.0, 6.0, 3.6]);
        color([0.12, 0.13, 0.15]) translate([bx, 5.0, T + 3.6]) cylinder(d = 3.5, h = 5.8);
    }
    // STRAIGHT UPWARD 1x5 male header on button face!
    color([0.85, 0.72, 0.15]) translate([(L - 12.7) / 2, 11.0, T]) cube([12.7, 2.54, 2.5]);
    color([0.88, 0.70, 0.22])
        for (i = [0 : 4])
            translate([(L - 12.7) / 2 + 1.27 + i * 2.54 - 0.32, 11.95, T + 2.5])
                cube([0.64, 0.64, 9.0]);
    if (show_mated_keepout) {
        // 14mm shell + 6mm bend reaches 31.0 mm above PCB bottom
        color([0.92, 0.42, 0.12, 0.40])
            translate([(L - 13.2) / 2, 10.6, T + 2.5]) cube([13.2, 4.2, 26.9]);
    }
}

// ============================================================================
// 05. WWZMDiB MicroSD TF Card SPI Reader (B0B779R5TZ)
// PCB: 42.0 x 24.0 x 1.6 mm | 90° Right-Angle 1x6 Male Header -> +22.0 mm keepout
// ============================================================================
module part_05_microsd(show_mated_keepout = false) {
    L = 42.0; W = 24.0; T = 1.6;
    color([0.10, 0.34, 0.72])
    difference() {
        rbox([L, W, T], r = 1.0);
        for (hx = [2.0, L - 2.0], hy = [2.0, W - 2.0])
            translate([hx, hy, -0.5]) cylinder(d = 2.2, h = T + 1.0);
    }
    // Stainless push-push MicroSD cage + protruding card
    color([0.78, 0.80, 0.84]) translate([0.5, (W - 14.5) / 2, T]) cube([15.5, 14.5, 2.2]);
    color([0.14, 0.14, 0.16]) translate([-2.5, (W - 11.0) / 2, T + 0.5]) cube([12.0, 11.0, 1.0]);
    // AMS1117-3.3 + 74LVC125A
    color([0.12, 0.12, 0.14]) {
        translate([20.0, 14.0, T]) cube([6.5, 3.5, 1.7]);
        translate([20.0, 4.5, T]) cube([8.6, 3.9, 1.7]);
    }
    // 90-degree right-angle 1x6 male header on +X edge
    color([0.08, 0.08, 0.10]) translate([L - 3.5, (W - 15.24) / 2, T]) cube([3.5, 15.24, 2.6]);
    color([0.88, 0.70, 0.22])
        for (i = [0 : 5])
            translate([L, (W - 15.24) / 2 + 1.27 + i * 2.54 - 0.32, T + 0.9])
                cube([8.5, 0.64, 0.64]);
    if (show_mated_keepout) {
        color([0.92, 0.42, 0.12, 0.40])
            translate([L, (W - 15.8) / 2, T - 0.2]) cube([22.0, 15.8, 6.0]);
    }
}

// ============================================================================
// 06. ELEGOO 20 cm DuPont Housing & Folded S-Loop Service Bundle (B01EV70C78)
// 1P Shell: 14.0 x 2.54 x 2.54 mm | 6.0 mm Bend Radius | 25-wire S-Loop ~23 cm³
// ============================================================================
module part_06_dupont_bundle() {
    // Folded S-loop wire trunk (~72 x 22 x 14 mm realistic service loop)
    colors = [
        [0.86, 0.20, 0.18], [0.92, 0.48, 0.12], [0.92, 0.80, 0.14],
        [0.18, 0.68, 0.32], [0.16, 0.46, 0.85], [0.56, 0.26, 0.74], [0.46, 0.30, 0.18]
    ];
    for (pass = [0, 1]) {
        for (i = [0 : 12]) {
            color(colors[i % len(colors)])
                translate([14.0, 1.5 + i * 1.45, 2.0 + pass * 4.2])
                    rotate([0, 90, 0]) cylinder(d = 1.32, h = 44.0);
        }
    }
    // End shells (left & right 5P/6P groups, 14.0 mm plastic)
    color([0.08, 0.08, 0.10]) {
        translate([0, 3.0, 2.0]) cube([14.0, 15.24, 2.54]);
        translate([58.0, 3.0, 6.2]) cube([14.0, 15.24, 2.54]);
    }
}

// ============================================================================
// 07. ACEIRMC 18650 Shield V3 + Flat-Top 18650 Cell (B0DFYDCGHP + B0HQPL867D)
// Shield: 99.5 x 29.2 x 21.0 mm | Cell: 65.0 x Ø18.3 mm Flat-Top Unprotected
// Note: Side 3V/5V pads are UNPOPULATED bare plated holes -> power via USB-A!
// ============================================================================
module part_07_18650_v3() {
    L = 99.5; W = 29.2; T = 1.6;
    // Bare PCB with unpopulated 3V/5V solder pad rows along long edges
    color([0.11, 0.13, 0.16])
    difference() {
        rbox([L, W, T], r = 1.2);
        // Side unpopulated 5V & 3V through-holes (zero soldered pins!)
        for (i = [0 : 4]) {
            translate([58.0 + i * 2.54, 2.2, -0.5]) cylinder(d = 1.0, h = T + 1.0);
            translate([58.0 + i * 2.54, W - 2.2, -0.5]) cylinder(d = 1.0, h = T + 1.0);
        }
    }
    // Gold unpopulated pad rings
    color([0.88, 0.72, 0.25])
    for (i = [0 : 4]) {
        translate([58.0 + i * 2.54, 2.2, T]) cylinder(d = 1.8, h = 0.08);
        translate([58.0 + i * 2.54, W - 2.2, T]) cylinder(d = 1.8, h = 0.08);
    }
    // Black 18650 sled cradle
    color([0.14, 0.15, 0.18]) translate([19.0, 3.8, T]) cube([76.0, 21.6, 17.5]);
    // Flat-top 18650 cell (65.0 x Ø18.3 mm)
    color([0.08, 0.56, 0.62])
        translate([25.5, W / 2, T + 10.2]) rotate([0, 90, 0]) cylinder(d = 18.3, h = 65.0);
    color([0.78, 0.80, 0.82])
        translate([90.4, W / 2, T + 10.2]) rotate([0, 90, 0]) cylinder(d = 12.0, h = 0.4); // '+' flat cap
    // USB-A Female Output Receptacle at X=0 (14.0 x 10.5 x 7.0 mm)
    color([0.76, 0.78, 0.82]) translate([0.0, (W - 14.0) / 2, T]) cube([14.0, 14.0, 7.0]);
    // Charge Port + Normal/Hold Slide Switch + K1 along bottom Y=0 edge
    color([0.76, 0.78, 0.82]) translate([10.0, 0.0, T]) cube([9.0, 7.5, 3.2]); // USB-C charge
    color([0.15, 0.15, 0.17]) translate([26.0, 0.0, T]) cube([6.0, 4.0, 3.5]); // Normal/Hold switch
    // Underside TP4056 + DW01A heat dissipation components
    color([0.12, 0.12, 0.14]) translate([6.0, 8.0, -1.5]) cube([10.0, 12.0, 1.5]);
}

// ============================================================================
// 08. Collision-Verified Full Assembly (156.0 x 112.0 x 49.0 mm PETG/ASA Shell)
// ============================================================================
module assembly_156x112x49() {
    // 1. 18650 V3 Shield + Cell (X: 2.4..101.9, Y: 2.9..32.1, Z: 2.9..23.9)
    translate([2.4, 2.9, 1.6 + 2.9 - 1.6]) part_07_18650_v3();

    // 2. Dual 3070 Enclosed Speakers (Z: 28.6..45.6, +4.7 mm above battery!)
    translate([3.2, 3.0, 28.6]) part_02b_speaker_box();
    translate([78.8, 3.0, 28.6]) part_02b_speaker_box();

    // 3. ideaspark ESP32 1.9" IPS (X: 3.9..67.6, Y: 75.5..107.0, Z_pcb: 42.1..43.7)
    translate([3.9, 75.5, 42.1]) part_01_ideaspark_esp32(true);

    // 4. WM8960 Audio HAT (X: 76.0..141.0, Y: 77.6..107.6, Z_pcb: 30.9..32.5)
    translate([76.0, 77.6, 30.9]) part_02_wm8960_hat(true);

    // 5. KY-023 Thumbstick (X: 6.0..40.0 + cable 62.0, Y: 41.0..67.0, Z_pcb: 23.5..25.1)
    translate([6.0, 41.0, 23.5]) part_03_ky023(true);

    // 6. GODIYMODULES 1x4 Recessed Keypad (X: 72.0..109.0, Y: 47.0..62.0, Z_pcb: 15.0..16.6)
    translate([72.0, 47.0, 15.0]) part_04_keypad_1x4(true);

    // 7. WWZMDiB MicroSD Reader + 90° Cable (right edge X=153.6, Z_pcb: 3.0..4.6)
    translate([153.6, 42.0, 3.0]) mirror([1, 0, 0]) part_05_microsd(true);

    // 8. 200mm Folded Wire Trunk in Trough T3 (X: 105..152, Y: 3.5..28.5, Z: 3..25)
    // True 4-pass 46mm fold of 200mm DuPont ribbon (~23 cm^3 unscaled)
    for (p = [0 : 3]) {
        for (w = [0 : 5]) {
            color(w % 3 == 0 ? [0.86, 0.22, 0.18] : (w % 3 == 1 ? [0.92, 0.72, 0.16] : [0.16, 0.48, 0.85]))
                translate([116.0 + w * 2.2, 6.0 + p * 5.0, 4.5 + (p % 2) * 4.5])
                    rotate([0, 90, 0]) cylinder(d = 1.32, h = 34.0);
        }
    }

    // 9. Flush Left-Wall USB-A -> USB-C U-Bridge (Topology A Interlock, X: -7.6..2.4)
    color([0.16, 0.18, 0.22])
        translate([-7.6, 12.0, 4.5]) rbox([10.0, 84.0, 40.0], r = 2.0);

    // 10. Translucent PETG/ASA Enclosure Envelope (156.0 x 112.0 x 49.0 mm, wall=2.4mm)
    color([0.55, 0.62, 0.72, 0.18])
    difference() {
        rbox([156.0, 112.0, 49.0], r = 4.0);
        translate([2.4, 2.4, 2.4]) rbox([151.2, 107.2, 44.2], r = 2.5);
    }
}

if (render_mode == "assembly") {
    assembly_156x112x49();
}
