import Foundation
import SceneKit
import SceneKit.ModelIO

// ============================================================================
// 1:1 Hardware CAD Generator & AABB Collision Verifier
// Pocket Wi-Fi Spotify Streamer & Gemini Assistant (No 3D-Print Enclosure)
// Units: millimeters (1 SceneKit unit = 1 mm, scaled 0.001x on USDZ export = 1:1 meters)
// Coordinate System (Right-Handed CAD):
//   X = Width  [0 .. 65.5 mm] (Left = 18650 Shield Bay, Right = Pi Zero + Audio)
//   Y = Length [0 .. 107.5 mm] (Front/Bottom Ports = Y=0, Top Edge = Y=99..107.5)
//   Z = Height [0 .. 21.5 mm] (Bottom PCB = Z=0, Screen/Buttons Top = Z=21.5)
// SceneKit maps: scnX = cadX, scnY = cadZ (up), scnZ = -cadY
// ============================================================================

enum HatVariant: String, CaseIterable {
    case displayHatMini = "display_hat_mini"
    case waveshareOled13 = "waveshare_oled_13"
    case adafruitPitft114 = "adafruit_pitft_114"
    case pirateAudio = "pirate_audio"

    var outputFilename: String {
        switch self {
        case .displayHatMini: return "hardware_cad_A_display_hat_mini_wide_ips.usdz"
        case .waveshareOled13: return "hardware_cad_B_waveshare_13_oled_joystick.usdz"
        case .adafruitPitft114: return "hardware_cad_C_adafruit_114_wide_pitft.usdz"
        case .pirateAudio: return "hardware_cad_D_pirate_audio_comparison.usdz"
        }
    }

    var title: String {
        switch self {
        case .displayHatMini: return "Variant A: Pimoroni Display HAT Mini (2.0\" Wide 320x240 IPS)"
        case .waveshareOled13: return "Variant B: Waveshare 1.3\" Wide OLED (128x64) + 5-Way Joystick"
        case .adafruitPitft114: return "Variant C: Adafruit Mini PiTFT 1.14\" (240x135 Wide IPS)"
        case .pirateAudio: return "Variant D: Pimoroni Pirate Audio (1.3\" Square 240x240 Reference)"
        }
    }
}

struct AABB {
    let minX: Double, maxX: Double
    let minY: Double, maxY: Double
    let minZ: Double, maxZ: Double

    var dx: Double { maxX - minX }
    var dy: Double { maxY - minY }
    var dz: Double { maxZ - minZ }
    var cx: Double { (minX + maxX) * 0.5 }
    var cy: Double { (minY + maxY) * 0.5 }
    var cz: Double { (minZ + maxZ) * 0.5 }

    func overlaps(_ other: AABB, eps: Double = 0.01) -> (Bool, Double) {
        let ox = min(maxX, other.maxX) - max(minX, other.minX)
        let oy = min(maxY, other.maxY) - max(minY, other.minY)
        let oz = min(maxZ, other.maxZ) - max(minZ, other.minZ)
        if ox > eps && oy > eps && oz > eps {
            return (true, ox * oy * oz)
        }
        return (false, 0.0)
    }
}

enum Axis {
    case x, y, z
}

enum Shape {
    case box
    case cylinder(axis: Axis)
}

struct MaterialStyle {
    let r: Double, g: Double, b: Double, a: Double
    let metalness: Double
    let roughness: Double
    let emission: (Double, Double, Double)?

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1.0,
         metalness: Double = 0.1, roughness: Double = 0.5,
         emission: (Double, Double, Double)? = nil) {
        self.r = r; self.g = g; self.b = b; self.a = a
        self.metalness = metalness; self.roughness = roughness
        self.emission = emission
    }
}

struct Part {
    let id: String
    let label: String
    let box: AABB
    let shape: Shape
    let style: MaterialStyle
    let skipCollisionCheck: Bool

    init(_ id: String, _ label: String,
         _ x0: Double, _ x1: Double,
         _ y0: Double, _ y1: Double,
         _ z0: Double, _ z1: Double,
         shape: Shape = .box,
         style: MaterialStyle,
         skipCollisionCheck: Bool = false) {
        self.id = id
        self.label = label
        self.box = AABB(minX: x0, maxX: x1, minY: y0, maxY: y1, minZ: z0, maxZ: z1)
        self.shape = shape
        self.style = style
        self.skipCollisionCheck = skipCollisionCheck
    }
}

// Palette
let matV3PCB     = MaterialStyle(0.11, 0.13, 0.16, metalness: 0.15, roughness: 0.65)
let matPiPCB     = MaterialStyle(0.08, 0.42, 0.22, metalness: 0.15, roughness: 0.55)
let matHatPCB    = MaterialStyle(0.10, 0.16, 0.28, metalness: 0.15, roughness: 0.55)
let matCradle    = MaterialStyle(0.16, 0.17, 0.19, metalness: 0.05, roughness: 0.75)
let matCell18650 = MaterialStyle(0.12, 0.44, 0.85, metalness: 0.35, roughness: 0.30)
let matMetal     = MaterialStyle(0.76, 0.78, 0.82, metalness: 0.88, roughness: 0.24)
let matGold      = MaterialStyle(0.88, 0.70, 0.22, metalness: 0.90, roughness: 0.25)
let matBlackPlas = MaterialStyle(0.10, 0.10, 0.12, metalness: 0.05, roughness: 0.60)
let matRibbon    = MaterialStyle(0.84, 0.54, 0.18, metalness: 0.20, roughness: 0.45) // Kapton/FPC amber
let matUSBCable  = MaterialStyle(0.24, 0.26, 0.30, metalness: 0.10, roughness: 0.55)
let matButton    = MaterialStyle(0.92, 0.36, 0.16, metalness: 0.10, roughness: 0.40)
let matScreenIPS = MaterialStyle(0.06, 0.12, 0.22, metalness: 0.10, roughness: 0.12, emission: (0.04, 0.18, 0.32))
let matScreenOLED = MaterialStyle(0.04, 0.05, 0.07, metalness: 0.10, roughness: 0.10, emission: (0.08, 0.24, 0.30))
let matLEDGreen  = MaterialStyle(0.15, 0.88, 0.35, metalness: 0.0, roughness: 0.25, emission: (0.10, 0.65, 0.22))
let matLEDRed    = MaterialStyle(0.92, 0.20, 0.20, metalness: 0.0, roughness: 0.25, emission: (0.65, 0.10, 0.10))
let matMicroSD   = MaterialStyle(0.18, 0.19, 0.22, metalness: 0.10, roughness: 0.50)
let matAudioBody = MaterialStyle(0.18, 0.20, 0.24, metalness: 0.25, roughness: 0.45)
let matFireGhost = MaterialStyle(0.45, 0.50, 0.58, 0.28, metalness: 0.10, roughness: 0.50)

// Mated/intentional touching pairs that are allowed to overlap slightly for mechanical seating
let allowedMatedPairs: Set<String> = Set([
    pairKey("v3_usba_port", "usb_power_plug"),
    pairKey("micro_usb_pwr", "fpc_pwr_plug"),
    pairKey("micro_usb_otg", "fpc_otg_plug"),
    pairKey("gpio_header", "hat_female_socket"),
    pairKey("pi_sd_slot", "microsd_card"),
    pairKey("usb_audio_body", "usb_audio_otg_socket")
])

func pairKey(_ a: String, _ b: String) -> String {
    return a < b ? "\(a)|\(b)" : "\(b)|\(a)"
}

func buildParts(for variant: HatVariant, includeFireStickRef: Bool = true) -> [Part] {
    var parts: [Part] = []

    // ------------------------------------------------------------------------
    // 1. LEFT BAY: 18650 Battery Shield V3 (Type-C) + Removable 18650 Cell
    // ------------------------------------------------------------------------
    parts.append(Part("v3_pcb", "18650 Battery Shield V3 PCB (99x29.2x1.6mm)",
                      0.0, 29.2, 0.0, 99.0, 0.0, 1.6, style: matV3PCB))

    parts.append(Part("v3_usbc_port", "USB-C Charge Input Port",
                      10.1, 19.1, -0.5, 7.0, 1.6, 4.8, style: matMetal))

    parts.append(Part("v3_led_red", "Charge Status LED (Red)",
                      6.0, 7.2, 2.4, 3.6, 1.6, 2.4, style: matLEDRed))

    parts.append(Part("v3_led_green", "Full Charge LED (Green)",
                      7.6, 8.8, 2.4, 3.6, 1.6, 2.4, style: matLEDGreen))

    // Open-top U-shaped 18650 cradle (zero collision with removable 18650 cell)
    parts.append(Part("v3_cradle_base", "18650 Cradle Floor",
                      4.0, 25.2, 11.0, 88.0, 1.6, 1.95, style: matCradle))
    parts.append(Part("v3_cradle_neg_end", "18650 Cradle (-) End Wall",
                      4.0, 25.2, 11.0, 16.2, 1.95, 20.6, style: matCradle))
    parts.append(Part("v3_cradle_pos_end", "18650 Cradle (+) End Wall",
                      4.0, 25.2, 82.8, 88.0, 1.95, 20.6, style: matCradle))
    parts.append(Part("v3_cradle_left_rail", "18650 Cradle Left Side Rail",
                      4.0, 5.2, 16.2, 82.8, 1.95, 13.5, style: matCradle))
    parts.append(Part("v3_cradle_right_rail", "18650 Cradle Right Side Rail",
                      24.0, 25.2, 16.2, 82.8, 1.95, 13.5, style: matCradle))
    parts.append(Part("v3_contact_neg", "18650 Negative Spring Contact (-)",
                      10.6, 18.6, 16.2, 17.0, 7.2, 15.2, style: matMetal))
    parts.append(Part("v3_contact_pos", "18650 Positive Leaf Contact (+)",
                      10.6, 18.6, 82.0, 82.8, 7.2, 15.2, style: matMetal))

    // Removable 18650 Li-ion cell (18.5mm diameter x 65mm length along Y)
    parts.append(Part("cell_18650", "Removable 18650 Li-ion Cell (18.5x65mm)",
                      5.35, 23.85, 17.0, 82.0, 1.95, 20.45,
                      shape: .cylinder(axis: .y), style: matCell18650))

    parts.append(Part("v3_power_switch", "V3 5V Output Slide Switch",
                      4.5, 10.5, 93.0, 100.2, 1.6, 5.6, style: matBlackPlas))

    parts.append(Part("v3_usba_port", "V3 5V USB-A Output Port",
                      13.5, 27.5, 89.0, 99.5, 1.6, 8.6, style: matMetal))

    // Low-profile 90-deg USB-A plug & routed flat power ribbon to Pi PWR IN
    parts.append(Part("usb_power_plug", "Low-Profile 90-deg USB-A Power Plug",
                      14.0, 27.0, 99.0, 107.5, 1.8, 8.4, style: matUSBCable))
    parts.append(Part("pwr_ribbon_top", "5V Power Ribbon Top Exit",
                      27.0, 32.3, 99.6, 104.0, 2.0, 4.0, style: matRibbon))
    parts.append(Part("pwr_ribbon_spine", "5V Power Ribbon Spine Run (X=29.3..32.3)",
                      29.3, 32.3, 45.0, 99.6, 2.0, 4.0, style: matRibbon))
    parts.append(Part("pwr_ribbon_riser", "5V Power Ribbon Riser to FPC Plug",
                      29.3, 31.8, 42.0, 48.0, 4.0, 6.8, style: matRibbon))

    // ------------------------------------------------------------------------
    // 2. UPPER-RIGHT BAY: Raspberry Pi Zero 2 WH (Rotated 90° CW: 30x65mm)
    // ------------------------------------------------------------------------
    parts.append(Part("pi_pcb", "Raspberry Pi Zero 2 WH PCB (30x65x1.6mm)",
                      33.0, 63.0, 34.0, 99.0, 6.0, 7.6, style: matPiPCB))

    parts.append(Part("pi_cpu_rf", "RP3A0-AU SiP + Wi-Fi/BT RF Shield",
                      43.0, 54.0, 58.0, 74.0, 7.6, 9.2, style: matMetal))

    parts.append(Part("pi_sd_slot", "Pi Zero MicroSD Card Slot",
                      43.5, 55.5, 87.0, 99.0, 7.6, 9.4, style: matMetal))

    parts.append(Part("microsd_card", "MicroSD Card (OS + MP3 Library)",
                      44.0, 55.0, 91.0, 101.5, 8.0, 9.0, style: matMicroSD))

    parts.append(Part("gpio_header", "40-Pin Pre-Soldered Male GPIO Header",
                      56.9, 62.0, 41.1, 91.9, 7.6, 16.1, style: matGold))

    parts.append(Part("mini_hdmi", "Mini-HDMI Port (Unused)",
                      32.5, 40.0, 81.0, 92.2, 7.6, 10.8, style: matMetal))

    parts.append(Part("micro_usb_otg", "Micro-USB OTG Data Port",
                      32.5, 38.2, 53.8, 61.4, 7.6, 10.2, style: matMetal))

    parts.append(Part("micro_usb_pwr", "Micro-USB 5V Power Port",
                      32.5, 38.2, 41.2, 48.8, 7.6, 10.2, style: matMetal))

    parts.append(Part("fpc_pwr_plug", "90-deg Flat FPC Micro-USB Power Plug",
                      26.2, 33.0, 40.9, 49.1, 6.8, 10.6, style: matUSBCable))

    parts.append(Part("fpc_otg_plug", "90-deg Flat FPC Micro-USB OTG Plug",
                      26.2, 33.0, 53.5, 61.7, 6.8, 10.6, style: matUSBCable))

    // OTG FPC ribbon routed down into under-Pi tunnel (Z=4.3..5.7) to Lower-Right Bay
    parts.append(Part("otg_ribbon_drop", "OTG FPC Ribbon Drop",
                      26.2, 29.0, 54.0, 61.2, 5.7, 6.8, style: matRibbon))
    parts.append(Part("otg_ribbon_cross", "OTG FPC Ribbon Cross Under Pi",
                      26.2, 43.0, 54.0, 61.2, 4.3, 5.7, style: matRibbon))
    parts.append(Part("otg_ribbon_tunnel", "OTG FPC Ribbon Under-Pi Tunnel",
                      35.5, 43.0, 31.0, 54.0, 4.3, 5.7, style: matRibbon))

    // ------------------------------------------------------------------------
    // 3. PLUG-AND-PLAY DISPLAY HAT VARIANTS (Mated to 40-pin GPIO Header)
    // ------------------------------------------------------------------------
    switch variant {
    case .displayHatMini:
        parts.append(Part("hat_female_socket", "HAT 40-Pin Female Socket",
                          56.5, 62.4, 40.8, 92.2, 12.5, 16.1, style: matBlackPlas))
        parts.append(Part("hat_pcb", "Pimoroni Display HAT Mini PCB (35x65.5mm)",
                          30.5, 65.5, 33.75, 99.25, 16.1, 17.7, style: matHatPCB))
        parts.append(Part("hat_screen_bezel", "2.0\" Wide IPS LCD Bezel",
                          31.7, 64.3, 44.5, 88.5, 17.7, 19.8, style: matBlackPlas))
        parts.append(Part("hat_screen_active", "2.0\" Wide 320x240 Color IPS Active Screen",
                          32.7, 63.3, 46.1, 86.9, 19.8, 20.2, style: matScreenIPS))
        parts.append(Part("hat_btn_a", "Tactile Button A (Top-Left)",
                          33.5, 37.5, 92.0, 96.0, 17.7, 21.2, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_btn_x", "Tactile Button X (Top-Right)",
                          58.5, 62.5, 92.0, 96.0, 17.7, 21.2, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_btn_b", "Tactile Button B (Bottom-Left)",
                          33.5, 37.5, 37.0, 41.0, 17.7, 21.2, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_btn_y", "Tactile Button Y (Bottom-Right)",
                          58.5, 62.5, 37.0, 41.0, 17.7, 21.2, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_rgb_led", "RGB Status LED",
                          47.0, 49.0, 93.0, 95.0, 17.7, 18.8, style: matLEDGreen))

    case .waveshareOled13:
        parts.append(Part("hat_female_socket", "HAT 40-Pin Female Socket",
                          56.5, 62.4, 40.8, 92.2, 12.5, 16.1, style: matBlackPlas))
        parts.append(Part("hat_pcb", "Waveshare 1.3\" OLED HAT PCB (30x65mm)",
                          33.0, 63.0, 34.0, 99.0, 16.1, 17.7, style: matHatPCB))
        parts.append(Part("hat_screen_bezel", "1.3\" Wide OLED Glass Module",
                          39.2, 56.7, 50.0, 83.4, 17.7, 19.4, style: matBlackPlas))
        parts.append(Part("hat_screen_active", "1.3\" Wide 128x64 OLED Active Area",
                          40.6, 55.3, 52.0, 81.4, 19.4, 19.8, style: matScreenOLED))
        parts.append(Part("hat_joystick", "5-Way Thumb Joystick (Nav + Click)",
                          44.0, 52.0, 85.0, 93.0, 17.7, 21.5, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_key1", "Tactile Button KEY1",
                          35.2, 38.8, 38.2, 41.8, 17.7, 21.0, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_key2", "Tactile Button KEY2",
                          43.2, 46.8, 38.2, 41.8, 17.7, 21.0, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_key3", "Tactile Button KEY3",
                          51.2, 54.8, 38.2, 41.8, 17.7, 21.0, shape: .cylinder(axis: .z), style: matButton))

    case .adafruitPitft114:
        parts.append(Part("hat_female_socket", "26-Pin Mini HAT Female Socket",
                          56.5, 62.4, 58.8, 92.0, 12.5, 16.1, style: matBlackPlas))
        parts.append(Part("hat_pcb", "Adafruit Mini PiTFT 1.14\" PCB (28.5x35mm)",
                          34.5, 63.0, 58.5, 93.5, 16.1, 17.7, style: matHatPCB))
        parts.append(Part("hat_screen_bezel", "1.14\" Wide IPS Bezel",
                          38.5, 55.4, 62.0, 89.9, 17.7, 19.5, style: matBlackPlas))
        parts.append(Part("hat_screen_active", "1.14\" Wide 240x135 Color IPS Screen",
                          39.5, 54.4, 63.5, 88.4, 19.5, 19.9, style: matScreenIPS))
        parts.append(Part("hat_btn_1", "Tactile Button 1",
                          35.0, 38.0, 63.5, 66.5, 17.7, 21.0, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_btn_2", "Tactile Button 2",
                          35.0, 38.0, 85.0, 88.0, 17.7, 21.0, shape: .cylinder(axis: .z), style: matButton))

    case .pirateAudio:
        parts.append(Part("hat_female_socket", "HAT 40-Pin Female Socket",
                          56.5, 62.4, 40.8, 92.2, 12.5, 16.1, style: matBlackPlas))
        parts.append(Part("hat_pcb", "Pimoroni Pirate Audio PCB (30.5x65mm)",
                          32.5, 63.0, 34.0, 99.0, 16.1, 17.7, style: matHatPCB))
        parts.append(Part("hat_screen_bezel", "1.3\" Square IPS Bezel",
                          35.0, 61.0, 53.5, 79.5, 17.7, 19.5, style: matBlackPlas))
        parts.append(Part("hat_screen_active", "1.3\" Square 240x240 IPS Screen",
                          36.3, 59.7, 54.8, 78.2, 19.5, 19.9, style: matScreenIPS))
        parts.append(Part("hat_btn_a", "Tactile Button A",
                          34.0, 37.5, 91.5, 95.0, 17.7, 21.0, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_btn_x", "Tactile Button X",
                          57.5, 61.0, 91.5, 95.0, 17.7, 21.0, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_btn_b", "Tactile Button B",
                          34.0, 37.5, 38.0, 41.5, 17.7, 21.0, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("hat_btn_y", "Tactile Button Y",
                          57.5, 61.0, 38.0, 41.5, 17.7, 21.0, shape: .cylinder(axis: .z), style: matButton))
        parts.append(Part("pirate_underside_jack", "Onboard I2S DAC + 3.5mm Jack (Underside)",
                          33.5, 42.0, 33.5, 46.5, 11.0, 16.1, style: matAudioBody))
    }

    // ------------------------------------------------------------------------
    // 4. LOWER-RIGHT BAY: Plug-and-Play USB Audio DAC + Mic Module
    // ------------------------------------------------------------------------
    if variant == .pirateAudio {
        parts.append(Part("usb_audio_otg_socket", "USB-A OTG Coupling Socket",
                          38.0, 52.0, 18.0, 31.0, 4.0, 11.5, style: matBlackPlas))
        parts.append(Part("usb_mini_mic", "Compact USB Mini Mic (Gemini Voice Input)",
                          39.0, 51.0, 0.0, 18.0, 5.0, 12.0, style: matAudioBody))
    } else {
        parts.append(Part("usb_audio_otg_socket", "USB-A OTG Coupling Socket",
                          35.0, 51.0, 22.0, 31.0, 4.0, 12.2, style: matBlackPlas))
        parts.append(Part("usb_audio_body", "CM108 USB Stereo Audio + Mic DAC Adapter",
                          35.0, 61.0, 4.0, 22.0, 4.0, 12.5, style: matAudioBody))
        parts.append(Part("jack_35mm", "3.5mm Stereo Headphone Jack",
                          38.5, 44.5, -1.0, 4.0, 5.2, 11.2,
                          shape: .cylinder(axis: .y), style: matMetal))
        parts.append(Part("mic_capsule", "Plug-in Mini Electret/MEMS Mic Capsule",
                          51.5, 57.5, -0.5, 4.0, 5.2, 11.2,
                          shape: .cylinder(axis: .y), style: matGold))
    }

    // ------------------------------------------------------------------------
    // 5. OPTIONAL 1:1 SCALE REFERENCE: Amazon Fire TV Stick (99 x 30 x 14 mm)
    // ------------------------------------------------------------------------
    if includeFireStickRef {
        parts.append(Part("firestick_body_ref", "Scale Ref: Fire TV Stick Body (99x30x14mm)",
                          -38.0, -8.0, 0.0, 99.0, 0.0, 14.0,
                          style: matFireGhost, skipCollisionCheck: true))
        parts.append(Part("firestick_hdmi_ref", "Scale Ref: Fire TV Stick HDMI Plug",
                          -30.0, -16.0, -9.0, 0.0, 4.5, 9.0,
                          style: matFireGhost, skipCollisionCheck: true))
    }

    return parts
}

func checkCollisions(parts: [Part], variant: HatVariant) -> Bool {
    let active = parts.filter { !$0.skipCollisionCheck }
    var violations: [String] = []

    for i in 0..<active.count {
        for j in (i + 1)..<active.count {
            let a = active[i]
            let b = active[j]
            let key = pairKey(a.id, b.id)
            if allowedMatedPairs.contains(key) { continue }
            let (hit, vol) = a.box.overlaps(b.box, eps: 0.01)
            if hit {
                violations.append(String(format: "  OVERLAP: %@ <-> %@ (volume: %.2f mm^3)", a.id, b.id, vol))
            }
        }
    }

    if violations.isEmpty {
        print("[\(variant.rawValue)] COLLISION CHECK PASSED: 0 overlaps across \(active.count) components.")
        return true
    } else {
        print("[\(variant.rawValue)] COLLISION CHECK FAILED (\(violations.count) overlaps):")
        for v in violations { print(v) }
        return false
    }
}

func makeSCNMaterial(_ style: MaterialStyle) -> SCNMaterial {
    let mat = SCNMaterial()
    mat.lightingModel = .physicallyBased
    mat.diffuse.contents = NSColor(red: style.r, green: style.g, blue: style.b, alpha: style.a)
    mat.metalness.contents = style.metalness
    mat.roughness.contents = style.roughness
    if let em = style.emission {
        mat.emission.contents = NSColor(red: em.0, green: em.1, blue: em.2, alpha: 1.0)
    }
    if style.a < 0.99 {
        mat.transparency = style.a
        mat.isDoubleSided = true
    }
    return mat
}

func exportUSDZ(parts: [Part], to url: URL) throws {
    let scene = SCNScene()
    let root = SCNNode()
    // Export at 1:1 physical meter scale (1 mm = 0.001 m) so Apple Quick Look / RealityKit shows exact true palm size
    root.scale = SCNVector3(0.001, 0.001, 0.001)

    for part in parts {
        let b = part.box
        let geo: SCNGeometry
        let node = SCNNode()
        node.name = part.id

        switch part.shape {
        case .box:
            let boxGeo = SCNBox(width: b.dx, height: b.dz, length: b.dy, chamferRadius: min(0.25, min(b.dx, b.dy, b.dz) * 0.15))
            geo = boxGeo
        case .cylinder(let axis):
            switch axis {
            case .y:
                let r = min(b.dx, b.dz) * 0.5
                geo = SCNCylinder(radius: r, height: b.dy)
                node.eulerAngles = SCNVector3(Float.pi * 0.5, 0, 0)
            case .x:
                let r = min(b.dy, b.dz) * 0.5
                geo = SCNCylinder(radius: r, height: b.dx)
                node.eulerAngles = SCNVector3(0, 0, Float.pi * 0.5)
            case .z:
                let r = min(b.dx, b.dy) * 0.5
                geo = SCNCylinder(radius: r, height: b.dz)
            }
        }

        geo.materials = [makeSCNMaterial(part.style)]
        node.geometry = geo
        // Map CAD (X, Y, Z) -> SceneKit (X, Z, -Y)
        node.position = SCNVector3(b.cx, b.cz, -b.cy)
        root.addChildNode(node)
    }

    scene.rootNode.addChildNode(root)
    if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
    }

    let ok = scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
    if !ok {
        throw NSError(domain: "USDZExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to write \(url.path)"])
    }
}

let outputDir = URL(fileURLWithPath: "/Users/benfox/Development/3D Design/Pocket Streamer Hardware CAD")
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

var allPassed = true
for variant in HatVariant.allCases {
    let parts = buildParts(for: variant, includeFireStickRef: true)
    let ok = checkCollisions(parts: parts, variant: variant)
    if !ok { allPassed = false }
    let outURL = outputDir.appendingPathComponent(variant.outputFilename)
    try exportUSDZ(parts: parts, to: outURL)
    let attrs = try FileManager.default.attributesOfItem(atPath: outURL.path)
    let size = attrs[.size] as? Int64 ?? 0
    print("  Exported \(variant.outputFilename) (\(size) bytes)")
}

if !allPassed {
    print("ERROR: Collision verification failed.")
    exit(1)
}
print("ALL 4 HARDWARE CAD ASSEMBLIES VERIFIED AND EXPORTED.")
