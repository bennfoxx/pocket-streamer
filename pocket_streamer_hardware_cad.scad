// ============================================================================
// Pocket Wi-Fi Spotify Streamer & Gemini Assistant — 1:1 Hardware CAD Assembly
// Pure Internal Electronics Model (Zero Soldering, No 3D-Printed Shell Yet)
//
// Right-Handed Coordinate System (mm):
//   X = Width  [0 .. 65.5 mm] (Left = 18650 Shield Bay, Right = Pi Zero + Audio)
//   Y = Length [0 .. 107.5 mm] (Front/Bottom Ports = Y=0, Top Edge = Y=99..107.5)
//   Z = Height [0 .. 21.5 mm]  (Bottom PCB = Z=0, Screen/Buttons Top = Z=21.5)
//
// Key Plug-and-Play Insight:
//   Replacing Pirate Audio + USB Mic (2 plug-in connections) with a Wide Screen
//   HAT + CM108 USB Audio/Mic Adapter uses the EXACT SAME 2 plug-in connections
//   while fixing the tiny square screen and needing zero I2S driver overlays.
// ============================================================================

/* [1. Display HAT Variant & Assembly Preview] */
hat_variant         = "display_hat_mini"; // ["display_hat_mini", "waveshare_oled_13", "adafruit_pitft_114", "pirate_audio"]
explode_factor      = 0.0;                // [0.0 : 0.05 : 1.0]
show_fire_stick_ref = true;
$fn                 = 48;

/* [2. Left Bay — 18650 Battery Shield V3 (Type-C) + Removable 18650 Cell (mm)] */
v3_pcb_w       = 29.2;
v3_pcb_l       = 99.0;
v3_pcb_t       = 1.6;
cell_dia       = 18.5;
cell_len       = 65.0;
cell_cx        = 14.6;
cell_cz        = 11.2;

/* [3. Upper-Right Bay — Raspberry Pi Zero 2 WH (Rotated 90 deg CW: 30 x 65 mm)] */
pi_x0          = 33.0;
pi_y0          = 34.0;
pi_z0          = 6.0;   // Leaves 6.0 mm under-Pi tunnel for flat FPC OTG/Power ribbons
pi_w           = 30.0;
pi_l           = 65.0;
pi_t           = 1.6;

// Helpers
module box_bounds(x0, x1, y0, y1, z0, z1, col=[0.5, 0.5, 0.5, 1.0]) {
    color(col)
    translate([x0, y0, z0])
        cube([x1 - x0, y1 - y0, z1 - z0], center=false);
}

module cyl_y(cx, y0, y1, cz, dia, col=[0.5, 0.5, 0.5, 1.0]) {
    color(col)
    translate([cx, y0, cz])
        rotate([-90, 0, 0])
            cylinder(d=dia, h=y1 - y0, center=false);
}

module cyl_z(cx, cy, z0, z1, dia, col=[0.5, 0.5, 0.5, 1.0]) {
    color(col)
    translate([cx, cy, z0])
        cylinder(d=dia, h=z1 - z0, center=false);
}

// ============================================================================
// 1. 18650 Battery Shield V3 (Type-C) + Removable 18650 Cell
// ============================================================================
module module_18650_shield_v3(explode=0.0) {
    c_pcb    = [0.11, 0.13, 0.16, 1.0];
    c_cradle = [0.18, 0.19, 0.21, 1.0];
    c_metal  = [0.78, 0.80, 0.84, 1.0];
    c_cell   = [0.12, 0.44, 0.85, 1.0];
    c_ribbon = [0.84, 0.54, 0.18, 1.0];
    c_cable  = [0.24, 0.26, 0.30, 1.0];

    // V3 PCB & USB-C charging port (front/bottom edge Y=0)
    box_bounds(0.0, v3_pcb_w, 0.0, v3_pcb_l, 0.0, v3_pcb_t, c_pcb);
    box_bounds(10.1, 19.1, -0.5, 7.0, 1.6, 4.8, c_metal);
    box_bounds(6.0, 7.2, 2.4, 3.6, 1.6, 2.4, [0.92, 0.20, 0.20, 1.0]); // Charge Red LED
    box_bounds(7.6, 8.8, 2.4, 3.6, 1.6, 2.4, [0.15, 0.88, 0.35, 1.0]); // Full Green LED

    // Open-top U-shaped 18650 cradle + spring/leaf contacts
    box_bounds(4.0, 25.2, 11.0, 88.0, 1.6, 1.95, c_cradle);
    box_bounds(4.0, 25.2, 11.0, 16.2, 1.95, 20.6, c_cradle);
    box_bounds(4.0, 25.2, 82.8, 88.0, 1.95, 20.6, c_cradle);
    box_bounds(4.0, 5.2, 16.2, 82.8, 1.95, 13.5, c_cradle);
    box_bounds(24.0, 25.2, 16.2, 82.8, 1.95, 13.5, c_cradle);
    box_bounds(10.6, 18.6, 16.2, 17.0, 7.2, 15.2, c_metal);
    box_bounds(10.6, 18.6, 82.0, 82.8, 7.2, 15.2, c_metal);

    // Removable 18650 Cell (lifts upward in exploded mode)
    translate([0, 0, explode * 22.0]) {
        cyl_y(cell_cx, 17.0, 82.0, cell_cz, cell_dia, c_cell);
        // Raised polarity emboss guides on ends for reference
        color([0.92, 0.92, 0.95, 1.0]) {
            translate([cell_cx, 80.5, 20.5]) linear_extrude(0.4) text("+", size=4, halign="center", valign="center");
            translate([cell_cx, 18.5, 20.5]) linear_extrude(0.4) text("-", size=4, halign="center", valign="center");
        }
    }

    // Power switch & 5V USB-A output port (top edge Y=99)
    box_bounds(4.5, 10.5, 93.0, 100.2, 1.6, 5.6, [0.10, 0.10, 0.12, 1.0]);
    box_bounds(13.5, 27.5, 89.0, 99.5, 1.6, 8.6, c_metal);

    // Low-profile 90-deg USB-A plug & routed flat 5V power ribbon
    translate([0, explode * 10.0, 0])
        box_bounds(14.0, 27.0, 99.0, 107.5, 1.8, 8.4, c_cable);
    box_bounds(27.0, 32.3, 99.6, 104.0, 2.0, 4.0, c_ribbon);
    box_bounds(29.3, 32.3, 45.0, 99.6, 2.0, 4.0, c_ribbon);
    box_bounds(29.3, 31.8, 42.0, 48.0, 4.0, 6.8, c_ribbon);
}

// ============================================================================
// 2. Raspberry Pi Zero 2 WH (Rotated 90 deg CW) + Pre-Soldered 40-Pin Header
// ============================================================================
module module_pi_zero_2wh(explode=0.0) {
    c_pi     = [0.08, 0.42, 0.22, 1.0];
    c_metal  = [0.78, 0.80, 0.84, 1.0];
    c_gold   = [0.88, 0.70, 0.22, 1.0];
    c_ribbon = [0.84, 0.54, 0.18, 1.0];
    c_cable  = [0.24, 0.26, 0.30, 1.0];

    // Pi Zero PCB with 4x M2.5 mounting hole cutouts
    color(c_pi)
    difference() {
        translate([pi_x0, pi_y0, pi_z0])
            cube([pi_w, pi_l, pi_t], center=false);
        for (hx = [36.5, 59.5], hy = [37.5, 95.5]) {
            translate([hx, hy, pi_z0 - 0.5])
                cylinder(d=2.75, h=pi_t + 1.0);
        }
    }

    // RP3A0-AU SiP + RF shield
    box_bounds(43.0, 54.0, 58.0, 74.0, 7.6, 9.2, c_metal);

    // Externally accessible MicroSD slot & card (top edge Y=99)
    box_bounds(43.5, 55.5, 87.0, 99.0, 7.6, 9.4, c_metal);
    translate([0, explode * 8.0, 0])
        box_bounds(44.0, 55.0, 91.0, 101.5, 8.0, 9.0, [0.18, 0.19, 0.22, 1.0]);

    // Pre-soldered 40-pin GPIO header
    box_bounds(56.9, 62.0, 41.1, 91.9, 7.6, 16.1, c_gold);

    // Left-edge ports facing central spine
    box_bounds(32.5, 40.0, 81.0, 92.2, 7.6, 10.8, c_metal); // Mini-HDMI
    box_bounds(32.5, 38.2, 53.8, 61.4, 7.6, 10.2, c_metal); // Micro-USB OTG
    box_bounds(32.5, 38.2, 41.2, 48.8, 7.6, 10.2, c_metal); // Micro-USB PWR

    // 90-deg flat FPC plugs + under-Pi OTG tunnel ribbon
    translate([-explode * 8.0, 0, 0]) {
        box_bounds(26.2, 33.0, 40.9, 49.1, 6.8, 10.6, c_cable);
        box_bounds(26.2, 33.0, 53.5, 61.7, 6.8, 10.6, c_cable);
    }
    box_bounds(26.2, 29.0, 54.0, 61.2, 5.7, 6.8, c_ribbon);
    box_bounds(26.2, 43.0, 54.0, 61.2, 4.3, 5.7, c_ribbon);
    box_bounds(35.5, 43.0, 31.0, 54.0, 4.3, 5.7, c_ribbon);
}

// ============================================================================
// 3. Display & Button HAT Variants (Mated on 40-Pin GPIO Header)
// ============================================================================
module module_display_hat(variant="display_hat_mini", explode=0.0) {
    c_hat    = [0.10, 0.16, 0.28, 1.0];
    c_bezel  = [0.09, 0.09, 0.11, 1.0];
    c_ips    = [0.06, 0.22, 0.42, 1.0];
    c_oled   = [0.05, 0.26, 0.30, 1.0];
    c_btn    = [0.92, 0.36, 0.16, 1.0];

    translate([0, 0, explode * 18.0]) {
        if (variant == "display_hat_mini") {
            box_bounds(56.5, 62.4, 40.8, 92.2, 12.5, 16.1, c_bezel);
            box_bounds(30.5, 65.5, 33.75, 99.25, 16.1, 17.7, c_hat);
            box_bounds(31.7, 64.3, 44.5, 88.5, 17.7, 19.8, c_bezel);
            box_bounds(32.7, 63.3, 46.1, 86.9, 19.8, 20.2, c_ips);
            for (bx = [35.5, 60.5], by = [39.0, 94.0]) {
                cyl_z(bx, by, 17.7, 21.2, 4.0, c_btn);
            }
            box_bounds(47.0, 49.0, 93.0, 95.0, 17.7, 18.8, [0.15, 0.88, 0.35, 1.0]);
        } else if (variant == "waveshare_oled_13") {
            box_bounds(56.5, 62.4, 40.8, 92.2, 12.5, 16.1, c_bezel);
            box_bounds(33.0, 63.0, 34.0, 99.0, 16.1, 17.7, c_hat);
            box_bounds(39.2, 56.7, 50.0, 83.4, 17.7, 19.4, c_bezel);
            box_bounds(40.6, 55.3, 52.0, 81.4, 19.4, 19.8, c_oled);
            cyl_z(48.0, 89.0, 17.7, 21.5, 8.0, c_btn);
            for (bx = [37.0, 45.0, 53.0]) {
                cyl_z(bx, 40.0, 17.7, 21.0, 3.6, c_btn);
            }
        } else if (variant == "adafruit_pitft_114") {
            box_bounds(56.5, 62.4, 58.8, 92.0, 12.5, 16.1, c_bezel);
            box_bounds(34.5, 63.0, 58.5, 93.5, 16.1, 17.7, c_hat);
            box_bounds(38.5, 55.4, 62.0, 89.9, 17.7, 19.5, c_bezel);
            box_bounds(39.5, 54.4, 63.5, 88.4, 19.5, 19.9, c_ips);
            cyl_z(36.5, 65.0, 17.7, 21.0, 3.0, c_btn);
            cyl_z(36.5, 86.5, 17.7, 21.0, 3.0, c_btn);
        } else {
            // pirate_audio reference
            box_bounds(56.5, 62.4, 40.8, 92.2, 12.5, 16.1, c_bezel);
            box_bounds(32.5, 63.0, 34.0, 99.0, 16.1, 17.7, c_hat);
            box_bounds(35.0, 61.0, 53.5, 79.5, 17.7, 19.5, c_bezel);
            box_bounds(36.3, 59.7, 54.8, 78.2, 19.5, 19.9, c_ips);
            for (bx = [35.75, 59.25], by = [39.75, 93.25]) {
                cyl_z(bx, by, 17.7, 21.0, 3.5, c_btn);
            }
            box_bounds(33.5, 42.0, 33.5, 46.5, 11.0, 16.1, [0.18, 0.20, 0.24, 1.0]);
        }
    }
}

// ============================================================================
// 4. Lower-Right Bay: Plug-and-Play USB Audio DAC + Mic Module
// ============================================================================
module module_usb_audio(variant="display_hat_mini", explode=0.0) {
    c_body  = [0.18, 0.20, 0.24, 1.0];
    c_plug  = [0.10, 0.10, 0.12, 1.0];
    c_metal = [0.78, 0.80, 0.84, 1.0];
    c_gold  = [0.88, 0.70, 0.22, 1.0];

    translate([0, -explode * 10.0, 0]) {
        if (variant == "pirate_audio") {
            box_bounds(38.0, 52.0, 18.0, 31.0, 4.0, 11.5, c_plug);
            box_bounds(39.0, 51.0, 0.0, 18.0, 5.0, 12.0, c_body);
        } else {
            box_bounds(35.0, 51.0, 22.0, 31.0, 4.0, 12.2, c_plug);
            box_bounds(35.0, 61.0, 4.0, 22.0, 4.0, 12.5, c_body);
            cyl_y(41.5, -1.0, 4.0, 8.2, 6.0, c_metal); // 3.5mm stereo headphone jack
            cyl_y(54.5, -0.5, 4.0, 8.2, 6.0, c_gold);  // Mini capsule mic
        }
    }
}

// ============================================================================
// 5. Optional 1:1 Scale Reference: Amazon Fire TV Stick (99 x 30 x 14 mm)
// ============================================================================
module fire_stick_reference() {
    c_ghost = [0.45, 0.50, 0.58, 0.28];
    box_bounds(-38.0, -8.0, 0.0, 99.0, 0.0, 14.0, c_ghost);
    box_bounds(-30.0, -16.0, -9.0, 0.0, 4.5, 9.0, c_ghost);
}

// Assemble full hardware layout
module_18650_shield_v3(explode_factor);
module_pi_zero_2wh(explode_factor);
module_display_hat(hat_variant, explode_factor);
module_usb_audio(hat_variant, explode_factor);
if (show_fire_stick_ref) {
    fire_stick_reference();
}
