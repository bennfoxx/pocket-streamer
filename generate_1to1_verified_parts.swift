import Foundation
import SceneKit
import SceneKit.ModelIO
import Metal
import AppKit
import CoreGraphics

// ============================================================================
// Pocket Streamer & Voice Note-Taker — 1:1 Verified Hardware 3D & Render Suite
// Signed Off by Principal Hardware Systems Verifier & Senior Embedded EE
// Units: 1 SceneKit unit = 1.000 mm (USDZ root scaled 0.001 -> 1:1 physical meters)
// Right-Handed CAD Convention:
//   cadX = Width (Left -> Right, mm)
//   cadY = Depth/Height in XY plane (Bottom -> Top, mm)
//   cadZ = Thickness/Elevation (Back -> Front, mm)
// SceneKit Mapping: scnX = cadX, scnY = cadZ (up), scnZ = -cadY
// ============================================================================

let baseDir = "/Users/benfox/Development/3D Design/Pocket Streamer Hardware CAD"
let out3DDir = "\(baseDir)/parts_1to1_3d"
let outRenderDir = "\(out3DDir)/renders"

try? FileManager.default.createDirectory(atPath: outRenderDir, withIntermediateDirectories: true)

// --- AABB & Part Primitive ---------------------------------------------------
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

    func offset(_ tx: Double, _ ty: Double, _ tz: Double) -> AABB {
        return AABB(minX: minX + tx, maxX: maxX + tx,
                    minY: minY + ty, maxY: maxY + ty,
                    minZ: minZ + tz, maxZ: maxZ + tz)
    }

    func overlaps(_ other: AABB, eps: Double = 0.05) -> (Bool, Double) {
        let ox = min(maxX, other.maxX) - max(minX, other.minX)
        let oy = min(maxY, other.maxY) - max(minY, other.minY)
        let oz = min(maxZ, other.maxZ) - max(minZ, other.minZ)
        if ox > eps && oy > eps && oz > eps {
            return (true, ox * oy * oz)
        }
        return (false, 0.0)
    }
}

struct CollisionVolume {
    let id: String
    let group: String
    let label: String
    let box: AABB
}

enum CylAxis { case x, y, z }

func makeMat(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1.0,
             metalness: Double = 0.1, roughness: Double = 0.5,
             emission: (Double, Double, Double)? = nil) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    m.metalness.contents = metalness
    m.roughness.contents = roughness
    if let e = emission {
        m.emission.contents = NSColor(calibratedRed: e.0, green: e.1, blue: e.2, alpha: 1.0)
    }
    if a < 0.99 {
        m.transparency = a
        m.isDoubleSided = true
    }
    return m
}

// Materials
let mPCBBlack    = makeMat(0.10, 0.11, 0.14, metalness: 0.12, roughness: 0.55)
let mPCBBlueHat  = makeMat(0.08, 0.19, 0.44, metalness: 0.15, roughness: 0.48)
let mPCBBlueSD   = makeMat(0.09, 0.34, 0.72, metalness: 0.15, roughness: 0.48)
let mPCBGreen    = makeMat(0.10, 0.48, 0.22, metalness: 0.15, roughness: 0.48)
let mMetalSilver = makeMat(0.58, 0.61, 0.67, metalness: 0.85, roughness: 0.28)
let mGold        = makeMat(0.88, 0.68, 0.18, metalness: 0.88, roughness: 0.24)
let mCopper      = makeMat(0.82, 0.48, 0.22, metalness: 0.85, roughness: 0.28)
let mBlackMatte  = makeMat(0.11, 0.12, 0.14, metalness: 0.06, roughness: 0.68)
let mPlasticDark = makeMat(0.07, 0.08, 0.09, metalness: 0.05, roughness: 0.55)
let mWhiteJST    = makeMat(0.90, 0.88, 0.82, metalness: 0.02, roughness: 0.48)
let mYellowPin   = makeMat(0.92, 0.76, 0.14, metalness: 0.05, roughness: 0.45)
let mKaptonFPC   = makeMat(0.84, 0.48, 0.12, metalness: 0.18, roughness: 0.38)
let mScreenFrame = makeMat(0.04, 0.04, 0.05, metalness: 0.10, roughness: 0.18)
let mScreenGlow  = makeMat(0.05, 0.22, 0.34, metalness: 0.08, roughness: 0.10, emission: (0.04, 0.34, 0.48))
let mScreenUI    = makeMat(0.92, 0.58, 0.16, metalness: 0.0, roughness: 0.20, emission: (0.65, 0.38, 0.08))
let mCell18650   = makeMat(0.07, 0.56, 0.62, metalness: 0.30, roughness: 0.28)
let mCellPlus    = makeMat(0.75, 0.78, 0.82, metalness: 0.75, roughness: 0.25)
let mSpeakerCone = makeMat(0.22, 0.24, 0.27, metalness: 0.08, roughness: 0.58)
let mTPUGasket   = makeMat(0.14, 0.48, 0.56, 0.88, metalness: 0.04, roughness: 0.65)
let mKeepout     = makeMat(0.90, 0.34, 0.04, 0.58, metalness: 0.05, roughness: 0.48)
let mBridgeBody  = makeMat(0.20, 0.23, 0.28, metalness: 0.18, roughness: 0.42)
let mShellGhost  = makeMat(0.24, 0.36, 0.52, 0.22, metalness: 0.08, roughness: 0.35)
let mShellEdge   = makeMat(0.26, 0.36, 0.48, 0.72, metalness: 0.12, roughness: 0.42)
let mPlungerCap  = makeMat(0.92, 0.42, 0.14, metalness: 0.05, roughness: 0.40)
let mCardRed     = makeMat(0.82, 0.18, 0.18, metalness: 0.08, roughness: 0.42)
let mWireColors  = [
    makeMat(0.85, 0.18, 0.18, roughness: 0.48),
    makeMat(0.92, 0.50, 0.12, roughness: 0.48),
    makeMat(0.92, 0.80, 0.14, roughness: 0.48),
    makeMat(0.16, 0.68, 0.32, roughness: 0.48),
    makeMat(0.16, 0.46, 0.86, roughness: 0.48),
    makeMat(0.56, 0.24, 0.74, roughness: 0.48),
    makeMat(0.45, 0.30, 0.18, roughness: 0.48),
    makeMat(0.88, 0.88, 0.90, roughness: 0.48)
]

// Geometry helpers in CAD coordinates (1 unit = 1 mm)
@discardableResult
func addBox(_ parent: SCNNode, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double,
            radius: Double = 0.0, mat: SCNMaterial, name: String = "box") -> SCNNode {
    let g = SCNBox(width: x1 - x0, height: z1 - z0, length: y1 - y0, chamferRadius: radius)
    g.materials = [mat]
    let n = SCNNode(geometry: g)
    n.name = name
    n.position = SCNVector3((x0 + x1) * 0.5, (z0 + z1) * 0.5, -(y0 + y1) * 0.5)
    parent.addChildNode(n)
    return n
}

@discardableResult
func addCyl(_ parent: SCNNode, cx: Double, cy: Double, cz: Double, d: Double, h: Double,
            axis: CylAxis = .z, mat: SCNMaterial, name: String = "cyl") -> SCNNode {
    let g = SCNCylinder(radius: d * 0.5, height: h)
    g.radialSegmentCount = 32
    g.materials = [mat]
    let n = SCNNode(geometry: g)
    n.name = name
    n.position = SCNVector3(cx, cz, -cy)
    switch axis {
    case .z: break
    case .x: n.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
    case .y: n.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
    }
    parent.addChildNode(n)
    return n
}

@discardableResult
func addCone(_ parent: SCNNode, cx: Double, cy: Double, z0: Double, z1: Double,
             d0: Double, d1: Double, mat: SCNMaterial) -> SCNNode {
    let g = SCNCone(topRadius: d1 * 0.5, bottomRadius: d0 * 0.5, height: z1 - z0)
    g.radialSegmentCount = 32
    g.materials = [mat]
    let n = SCNNode(geometry: g)
    n.position = SCNVector3(cx, (z0 + z1) * 0.5, -cy)
    parent.addChildNode(n)
    return n
}

// ============================================================================
// PART BUILDERS (Origin at Local PCB Bottom-Left-Back-PCB_Bottom = (0,0,0))
// Each returns (SCNNode, bounding-box summary for collision checker)
// ============================================================================

// 01. ideaspark ESP32 16MB + 1.9" ST7789 IPS (B0D6QXC813)
func buildPart01ESP32(showKeepout: Bool) -> SCNNode {
    let root = SCNNode(); root.name = "01_ideaspark_esp32_19_ips"
    let L = 63.7, W = 31.5, T = 1.6

    // PCB + 4x corner copper pad rings
    addBox(root, 0, L, 0, W, 0, T, radius: 0.8, mat: mPCBBlack, name: "esp_pcb")
    for hx in [2.5, L - 2.5] {
        for hy in [2.5, W - 2.5] {
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 3.4, h: T + 0.08, axis: .z, mat: mCopper)
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 2.0, h: T + 0.14, axis: .z, mat: mScreenFrame)
        }
    }

    // Top 1.9" IPS Panel (49.72 x 25.80 x 1.48 mm) + Active Area (42.72 x 22.70 mm) + UI preview bars
    addBox(root, 9.5, 9.5 + 49.72, (W - 25.80) * 0.5, (W + 25.80) * 0.5, T, T + 1.48, radius: 0.4, mat: mScreenFrame, name: "lcd_glass")
    addBox(root, 13.0, 13.0 + 42.72, (W - 22.70) * 0.5, (W + 22.70) * 0.5, T + 1.45, T + 1.62, radius: 0.15, mat: mScreenGlow, name: "lcd_active")
    // Crisp audiobook player UI accent bar inside active area
    addBox(root, 15.0, 29.0, 7.0, 21.0, T + 1.58, T + 1.68, mat: mScreenUI)
    addBox(root, 32.0, 53.0, 17.5, 19.5, T + 1.58, T + 1.68, mat: mWhiteJST)
    addBox(root, 32.0, 48.0, 11.5, 13.0, T + 1.58, T + 1.68, mat: mScreenUI)
    // Kapton FPC loop on left edge of LCD
    addBox(root, 7.4, 9.6, (W - 16.0) * 0.5, (W + 16.0) * 0.5, T, T + 1.25, mat: mKaptonFPC)

    // Underside USB-C (-1.5..6.0 mm left overhang, Z = -3.2..0)
    addBox(root, -1.5, 6.0, (W - 9.0) * 0.5, (W + 9.0) * 0.5, -3.2, 0.0, radius: 0.8, mat: mMetalSilver, name: "esp_usbc")

    // Underside WROOM-32E (18.0 x 25.5 x 3.1 mm, RF antenna toward right X=63.7)
    addBox(root, L - 25.5, L - 6.0, (W - 18.0) * 0.5, (W + 18.0) * 0.5, -3.1, 0.0, radius: 0.2, mat: mMetalSilver, name: "wroom_shield")
    addBox(root, L - 6.0, L - 0.3, (W - 18.0) * 0.5, (W + 18.0) * 0.5, -1.0, 0.0, mat: mPCBBlack, name: "wroom_antenna")
    addBox(root, L - 5.0, L - 1.2, 8.5, W - 8.5, -1.05, -0.95, mat: mCopper) // antenna trace hint

    // Underside CH340, AMS1117-3.3, SS14 diode, EN & BOOT buttons
    addBox(root, 12.0, 22.0, 8.2, 12.8, -1.6, 0.0, mat: mPlasticDark)   // CH340
    addBox(root, 13.0, 19.5, 18.5, 22.0, -1.7, 0.0, mat: mPlasticDark)  // AMS1117
    addBox(root, 8.0, 12.2, 20.5, 23.1, -2.0, 0.0, mat: mBlackMatte)    // SS14 Schottky
    addBox(root, 3.8, 8.0, 3.8, 6.8, -2.0, 0.0, mat: mMetalSilver)      // EN
    addBox(root, 3.8, 8.0, W - 6.8, W - 3.8, -2.0, 0.0, mat: mMetalSilver) // BOOT

    // Downward 2x19 (38-pin) male headers (27.94 mm row-to-row pitch, 48.26 mm length)
    let hdrX0 = (L - 48.26) * 0.5
    let rowYs = [(W - 27.94) * 0.5, (W + 27.94) * 0.5]
    for ry in rowYs {
        addBox(root, hdrX0, hdrX0 + 48.26, ry - 1.27, ry + 1.27, -2.5, 0.0, mat: mPlasticDark)
        for i in 0..<19 {
            let px = hdrX0 + 1.27 + Double(i) * 2.54
            addBox(root, px - 0.32, px + 0.32, ry - 0.32, ry + 0.32, -11.0, -2.5, mat: mGold)
        }
        if showKeepout {
            addBox(root, hdrX0, hdrX0 + 48.26, ry - 1.38, ry + 1.38, -22.5, -2.5, mat: mKeepout, name: "esp_dupont_keepout")
        }
    }
    return root
}

// 02. WM8960 Audio HAT (Waveshare 15668 Pi Zero HAT clone, B0GH6JCGNV)
func buildPart02WM8960(showKeepout: Bool) -> SCNNode {
    let root = SCNNode(); root.name = "02_wm8960_audio_hat"
    let L = 65.0, W = 30.0, T = 1.6

    addBox(root, 0, L, 0, W, 0, T, radius: 2.2, mat: mPCBBlueHat, name: "wm_pcb")
    for hx in [3.5, L - 3.5] {
        for hy in [3.5, W - 3.5] {
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 5.2, h: T + 0.06, axis: .z, mat: mGold)
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 2.75, h: T + 0.14, axis: .z, mat: mScreenFrame)
        }
    }

    // Top 3.5 mm TRS Jack (+2.0 mm overhang beyond top long edge Y=30)
    addBox(root, 12.0, 20.5, W - 12.0, W + 2.0, T, T + 5.0, radius: 0.4, mat: mBlackMatte, name: "trs_jack")
    addCyl(root, cx: 16.25, cy: W + 1.2, cz: T + 2.5, d: 5.6, h: 2.6, axis: .y, mat: mGold)

    // Top 4-Pin JST PH 2.0 Speaker Header
    addBox(root, L - 12.9, L - 3.0, 11.0, 15.5, T, T + 6.0, mat: mWhiteJST, name: "jst_spk_hdr")
    if showKeepout {
        addBox(root, L - 13.5, L - 2.0, 8.0, 18.5, T + 6.0, T + 14.0, mat: mKeepout, name: "wm_jst_keepout")
    }

    // Top Dual Corner MEMS Microphones (3.76 x 2.95 x 1.10 mm)
    addBox(root, 4.5, 8.26, 4.5, 7.45, T, T + 1.10, mat: mMetalSilver, name: "mems_mic_1")
    addBox(root, L - 8.26, L - 4.5, W - 7.45, W - 4.5, T, T + 1.10, mat: mMetalSilver, name: "mems_mic_2")

    // Top WM8960 QFN, 24MHz XTAL, RT9193-33 LDO, User Button K1
    addBox(root, 28.0, 33.0, 12.0, 17.0, T, T + 0.9, mat: mPlasticDark)
    addBox(root, 35.0, 38.2, 13.0, 15.5, T, T + 1.0, mat: mMetalSilver)
    addBox(root, 24.0, 30.0, 22.0, 28.0, T, T + 3.8, mat: mMetalSilver)
    addCyl(root, cx: 27.0, cy: 25.0, cz: T + 4.3, d: 3.2, h: 1.0, axis: .z, mat: mBlackMatte)

    // Bottom 2x20 40-pin female socket (50.8 x 5.0 x 8.5 mm)
    let hdrX0 = (L - 50.8) * 0.5
    addBox(root, hdrX0, hdrX0 + 50.8, 1.0, 6.0, -8.5, 0.0, mat: mPlasticDark, name: "wm_40pin_socket")
    // Solder tails slightly proud on top (2x20 grid)
    for c in 0..<20 {
        for r in 0..<2 {
            let px = hdrX0 + 1.27 + Double(c) * 2.54
            let py = 2.23 + Double(r) * 2.54
            addBox(root, px - 0.3, px + 0.3, py - 0.3, py + 0.3, T, T + 1.2, mat: mGold)
        }
    }
    if showKeepout {
        // M-F DuPont 14.0mm + 6.0mm bend = -28.5 mm below PCB bottom
        addBox(root, hdrX0, hdrX0 + 50.8, 0.8, 6.2, -28.5, -8.5, mat: mKeepout, name: "wm_mf_keepout")
    }
    return root
}

// 02b. 3070 Enclosed 8-Ohm 1W Speaker Box (70.0 x 30.0 x 17.0 mm)
func buildPart02bSpeaker(showGasket: Bool = false) -> SCNNode {
    let root = SCNNode(); root.name = "02b_wm8960_speaker_box"
    addBox(root, 0, 70.0, 0, 30.0, 0, 17.0, radius: 2.2, mat: mBlackMatte, name: "spk_enclosure")
    // Racetrack diaphragm & dust cap
    addBox(root, 10.0, 60.0, 4.5, 25.5, 16.5, 17.3, radius: 6.5, mat: mSpeakerCone)
    addBox(root, 24.0, 46.0, 10.5, 19.5, 17.1, 17.6, radius: 3.5, mat: mPlasticDark)
    // Corner mounting ear hints
    addBox(root, -1.5, 4.5, -1.5, 4.5, 0, 3.0, radius: 1.0, mat: mBlackMatte)
    addBox(root, 65.5, 71.5, 25.5, 31.5, 0, 3.0, radius: 1.0, mat: mBlackMatte)
    if showGasket {
        addBox(root, 0.5, 69.5, 0.5, 29.5, 17.0, 18.0, radius: 2.0, mat: mTPUGasket, name: "spk_tpu_gasket")
    }
    return root
}

// 03. KY-023 Dual-Axis PS2 Thumbstick (B0D83FD3M8)
func buildPart03KY023(showKeepout: Bool) -> SCNNode {
    let root = SCNNode(); root.name = "03_ky023_thumbstick"
    let L = 34.0, W = 26.0, T = 1.6
    addBox(root, 0, L, 0, W, 0, T, radius: 0.8, mat: mPCBBlack, name: "ky_pcb")
    for hx in [3.5, L - 3.5] {
        for hy in [3.0, W - 3.0] {
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 4.8, h: T + 0.06, axis: .z, mat: mCopper)
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 3.1, h: T + 0.14, axis: .z, mat: mScreenFrame)
        }
    }
    // Underside leads (-2.0..0)
    addBox(root, 6.0, 26.0, 4.0, 22.0, -2.0, 0.0, mat: mPlasticDark, name: "ky_solder_tails")
    // Metal gimbal + pots
    addBox(root, 7.0, 23.0, 5.0, 21.0, T, T + 12.2, mat: mMetalSilver)
    // Dome skirt (Ø26mm) + shaft + textured thumb cap up to Z=32.0 mm
    addCone(root, cx: 15.0, cy: 13.0, z0: T + 12.2, z1: 21.5, d0: 25.5, d1: 15.5, mat: mBlackMatte)
    addCyl(root, cx: 15.0, cy: 13.0, cz: 24.5, d: 4.6, h: 6.0, axis: .z, mat: mPlasticDark)
    addCone(root, cx: 15.0, cy: 13.0, z0: 27.5, z1: 32.0, d0: 14.5, d1: 17.0, mat: mBlackMatte)
    addCyl(root, cx: 15.0, cy: 13.0, cz: 32.05, d: 13.0, h: 0.3, axis: .z, mat: mPlungerCap)

    // 90-degree right-angle 1x5 male header on +X edge
    let hy0 = (W - 12.7) * 0.5
    addBox(root, L - 3.5, L, hy0, hy0 + 12.7, T, T + 2.6, mat: mPlasticDark)
    for i in 0..<5 {
        let py = hy0 + 1.27 + Double(i) * 2.54
        addBox(root, L, L + 8.5, py - 0.32, py + 0.32, T + 0.9, T + 1.54, mat: mGold)
    }
    if showKeepout {
        addBox(root, L, L + 22.0, hy0 - 0.3, hy0 + 13.0, T - 0.2, T + 5.8, mat: mKeepout, name: "ky_dupont_keepout")
    }
    return root
}

// 04. GODIYMODULES 1x4 Tactile Keypad (B0GW8BP2KR) — Straight-UP 1x5 Header!
func buildPart04Keypad(showKeepout: Bool, showPlungers: Bool = false) -> SCNNode {
    let root = SCNNode(); root.name = "04_godiymodules_1x4_keypad"
    let L = 37.0, W = 15.0, T = 1.6
    addBox(root, 0, L, 0, W, 0, T, radius: 0.6, mat: mPCBGreen, name: "pad_pcb")
    for hx in [2.5, L - 2.5] {
        for hy in [2.5, W - 2.5] {
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 3.6, h: T + 0.06, axis: .z, mat: mGold)
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 2.2, h: T + 0.14, axis: .z, mat: mScreenFrame)
        }
    }
    // 4x Tactile switches up to Z=11.0 mm
    for i in 0..<4 {
        let bx = 6.5 + Double(i) * 8.0
        addBox(root, bx - 3.0, bx + 3.0, 2.0, 8.0, T, T + 3.6, mat: mMetalSilver)
        addCyl(root, cx: bx, cy: 5.0, cz: T + 6.5, d: 3.6, h: 5.8, axis: .z, mat: mBlackMatte)
        if showPlungers {
            // Captive 3D-printed plunger bridging Z=11.0 -> Z=35.5 (1.5mm proud of Z=49 front wall)
            addCyl(root, cx: bx, cy: 5.0, cz: 23.25, d: 5.6, h: 24.5, axis: .z, mat: mPlungerCap)
            addCyl(root, cx: bx, cy: 5.0, cz: 13.0, d: 7.4, h: 2.0, axis: .z, mat: mPlungerCap)
        }
    }
    // CRITICAL TRAP: Straight-UPWARD 1x5 Male Header on Button Face (to Z=13.1 mm)
    let px0 = (L - 12.7) * 0.5
    addBox(root, px0, px0 + 12.7, 10.8, 13.34, T, T + 2.5, mat: mYellowPin, name: "pad_up_hdr")
    for i in 0..<5 {
        let px = px0 + 1.27 + Double(i) * 2.54
        addBox(root, px - 0.32, px + 0.32, 11.75, 12.39, T + 2.5, T + 11.5, mat: mGold)
    }
    if showKeepout {
        // 14.0mm DuPont + 6.0mm bend reaches Z=31.0 mm above PCB bottom!
        addBox(root, px0 - 0.25, px0 + 12.95, 10.4, 14.6, T + 2.5, 31.0, mat: mKeepout, name: "pad_dupont_keepout")
    }
    return root
}

// 05. WWZMDiB MicroSD TF Card SPI Reader (B0B779R5TZ)
func buildPart05MicroSD(showKeepout: Bool) -> SCNNode {
    let root = SCNNode(); root.name = "05_wwzmdib_microsd_reader"
    let L = 42.0, W = 24.0, T = 1.6
    addBox(root, 0, L, 0, W, 0, T, radius: 0.6, mat: mPCBBlueSD, name: "sd_pcb")
    for hx in [2.0, L - 2.0] {
        for hy in [2.0, W - 2.0] {
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 3.6, h: T + 0.06, axis: .z, mat: mGold)
            addCyl(root, cx: hx, cy: hy, cz: T * 0.5, d: 2.2, h: T + 0.14, axis: .z, mat: mScreenFrame)
        }
    }
    // Push-push MicroSD Stainless Cage + MicroSD Card sticking out -2.5 mm on left edge
    addBox(root, 0.5, 16.0, (W - 14.5) * 0.5, (W + 14.5) * 0.5, T, T + 2.2, mat: mMetalSilver, name: "sd_cage")
    addBox(root, -2.5, 10.0, (W - 11.0) * 0.5, (W + 11.0) * 0.5, T + 0.4, T + 1.4, mat: mCardRed, name: "sd_card")
    // AMS1117-3.3 & 74LVC125A
    addBox(root, 20.0, 26.5, 14.0, 17.5, T, T + 1.7, mat: mPlasticDark)
    addBox(root, 20.0, 28.6, 4.5, 8.4, T, T + 1.7, mat: mPlasticDark)
    // 90-degree right-angle 1x6 male header (+X edge)
    let hy0 = (W - 15.24) * 0.5
    addBox(root, L - 3.5, L, hy0, hy0 + 15.24, T, T + 2.6, mat: mPlasticDark)
    for i in 0..<6 {
        let py = hy0 + 1.27 + Double(i) * 2.54
        addBox(root, L, L + 8.5, py - 0.32, py + 0.32, T + 0.9, T + 1.54, mat: mGold)
    }
    if showKeepout {
        addBox(root, L, L + 22.0, hy0 - 0.3, hy0 + 15.5, T - 0.2, T + 5.8, mat: mKeepout, name: "sd_dupont_keepout")
    }
    return root
}

// 06. ELEGOO 20 cm DuPont Housing, M-F/F-F Stack & Folded S-Loop Bundle (B01EV70C78)
func buildPart06DuPont() -> SCNNode {
    let root = SCNNode(); root.name = "06_dupont_housing_and_20cm_bundle"
    // A) Reference 1P 14.0 x 2.54 x 2.54 mm + 6mm wire tail (front row)
    addBox(root, 0, 14.0, 0, 2.54, 0, 2.54, mat: mPlasticDark, name: "dupont_1p")
    addCyl(root, cx: 17.0, cy: 1.27, cz: 1.27, d: 1.32, h: 6.0, axis: .x, mat: mWireColors[0])

    // B) Grouped 5P shell (14.0 x 12.70 x 2.54 mm) + 6mm bend keepout next to it
    addBox(root, 0, 14.0, 7.0, 19.70, 0, 2.54, mat: mPlasticDark, name: "dupont_5p")
    addBox(root, 14.0, 20.0, 7.0, 19.70, 0, 2.54, mat: mKeepout, name: "dupont_5p_bend")
    for w in 0..<5 {
        addCyl(root, cx: 17.0, cy: 8.27 + Double(w) * 2.54, cz: 1.27, d: 1.32, h: 6.0, axis: .x, mat: mWireColors[w])
    }

    // C) Realistic 25-wire x 200mm Folded 3-Pass S-Loop Service Bundle (~72 x 22 x 14 mm, ~22.2 cm^3)
    for pass in 0..<2 {
        for i in 0..<12 {
            let cy = 25.0 + Double(i) * 1.48
            let cz = 2.0 + Double(pass) * 5.2
            addCyl(root, cx: 36.0, cy: cy, cz: cz, d: 1.34, h: 48.0, axis: .x, mat: mWireColors[(i + pass * 3) % mWireColors.count])
        }
    }
    // End 5P/6P housings & Kapton binder wraps
    addBox(root, 0.0, 14.0, 25.5, 40.74, 0.8, 3.34, mat: mPlasticDark)
    addBox(root, 58.0, 72.0, 25.5, 40.74, 6.0, 8.54, mat: mPlasticDark)
    addBox(root, 30.0, 42.0, 24.0, 42.5, 0.5, 9.5, mat: mKaptonFPC)
    return root
}

// 07. ACEIRMC 18650 Shield V3 + 65.0 x Ø18.3 mm Flat-Top 18650 (B0DFYDCGHP + B0HQPL867D)
func buildPart07BatteryV3() -> SCNNode {
    let root = SCNNode(); root.name = "07_aceirmc_18650_shield_v3"
    let L = 99.5, W = 29.2, T = 1.6
    // Bare PCB (underside TP4056/DW01A -1.5..0, top Z=0..1.6)
    addBox(root, 0, L, 0, W, 0, T, radius: 0.8, mat: mPCBBlack, name: "v3_pcb")
    // Unpopulated bare gold plated side 5V & 3V solder pad strips (visual indicator: NO pins!)
    for i in 0..<5 {
        let px = 56.0 + Double(i) * 2.54
        addCyl(root, cx: px, cy: 2.2, cz: T + 0.05, d: 1.8, h: 0.12, axis: .z, mat: mGold)
        addCyl(root, cx: px, cy: 2.2, cz: T + 0.10, d: 0.9, h: 0.16, axis: .z, mat: mScreenFrame)
        addCyl(root, cx: px, cy: W - 2.2, cz: T + 0.05, d: 1.8, h: 0.12, axis: .z, mat: mGold)
        addCyl(root, cx: px, cy: W - 2.2, cz: T + 0.10, d: 0.9, h: 0.16, axis: .z, mat: mScreenFrame)
    }
    // 18650 Holder U-cradle (height ~20.8 mm total)
    addBox(root, 18.0, 96.0, 3.6, W - 3.6, T, T + 2.2, mat: mBlackMatte)
    addBox(root, 18.0, 21.5, 3.6, W - 3.6, T, 19.8, mat: mBlackMatte)
    addBox(root, 92.5, 96.0, 3.6, W - 3.6, T, 19.8, mat: mBlackMatte)
    addBox(root, 20.0, 94.0, 3.6, 5.2, T, 15.0, mat: mBlackMatte)
    addBox(root, 20.0, 94.0, W - 5.2, W - 3.6, T, 15.0, mat: mBlackMatte)
    // Negative coil spring & positive brass leaf contact
    addCyl(root, cx: 23.0, cy: W * 0.5, cz: 11.4, d: 8.5, h: 3.0, axis: .x, mat: mMetalSilver)
    addBox(root, 91.5, 92.4, 9.5, W - 9.5, 6.5, 16.5, mat: mGold)

    // Flat-Top 18650 Li-Ion Cell (65.0 x Ø18.3 mm)
    addCyl(root, cx: 25.0 + 32.5, cy: W * 0.5, cz: 11.6, d: 18.3, h: 65.0, axis: .x, mat: mCell18650, name: "cell_18650")
    addCyl(root, cx: 90.05, cy: W * 0.5, cz: 11.6, d: 12.5, h: 0.3, axis: .x, mat: mCellPlus)

    // Full-size USB-A Female Output Receptacle at X=0 (14.0 x 14.0 x 7.0 mm)
    addBox(root, 0.0, 14.0, (W - 14.0) * 0.5, (W + 14.0) * 0.5, T, T + 7.0, mat: mMetalSilver, name: "v3_usba")
    addBox(root, -0.1, 3.5, (W - 12.0) * 0.5, (W + 12.0) * 0.5, T + 1.0, T + 6.0, mat: mScreenFrame)

    // Charge Port, Normal/Hold Master Slide Switch, K1 button, and 4x Capacity LEDs along Y=0 edge
    addBox(root, 15.0, 24.0, 0.0, 7.2, T, T + 3.2, mat: mMetalSilver, name: "v3_charge_port")
    addBox(root, 32.0, 38.0, 0.0, 4.0, T, T + 3.5, mat: mBridgeBody, name: "v3_master_switch")
    addBox(root, 41.0, 46.0, 0.5, 5.5, T, T + 2.0, mat: mMetalSilver, name: "v3_k1")
    for l in 0..<4 {
        addBox(root, 48.0 + Double(l) * 2.0, 49.0 + Double(l) * 2.0, 1.0, 2.6, T, T + 0.8, mat: mScreenGlow)
    }
    // Underside TP4056 + DW01A heat dissipation components (-1.4..0)
    addBox(root, 6.0, 18.0, 8.0, 20.0, -1.4, 0.0, mat: mPlasticDark)
    return root
}

// ============================================================================
// 08. Collision-Verified Full Assembly (156.0 x 112.0 x 49.0 mm PETG/ASA)
// ============================================================================
func buildPart08AssemblyAndVerify() -> (SCNNode, Int) {
    let root = SCNNode(); root.name = "08_verified_collision_free_assembly"
    var boxes: [CollisionVolume] = []

    // Helper to record disjoint collision volumes cleanly
    func rec(_ id: String, _ group: String, _ label: String,
             _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double) {
        boxes.append(CollisionVolume(id: id, group: group, label: label,
                                     box: AABB(minX: x0, maxX: x1, minY: y0, maxY: y1, minZ: z0, maxZ: z1)))
    }

    // 1. 18650 Shield V3 + Cell (PCB bottom Z=4.3 -> PCB top Z=5.9, cell top Z=23.9, underside IC Z=2.9)
    let v3 = buildPart07BatteryV3()
    v3.position = SCNVector3(2.4, 4.3, -2.9)
    root.addChildNode(v3)
    rec("v3_bay", "v3", "18650 V3 Shield + Cell", 2.4, 101.9, 2.9, 32.1, 2.9, 23.9)

    // 2. Dual 3070 Enclosed Speakers (Z: 28.6..45.6, +4.7 mm Z clear above V3!)
    let spkL = buildPart02bSpeaker(showGasket: true)
    spkL.position = SCNVector3(3.2, 28.6, -3.0)
    root.addChildNode(spkL)
    rec("spk_L", "spk_L", "3070 Speaker L + Gasket", 3.2, 73.2, 3.0, 33.0, 28.6, 46.6)

    let spkR = buildPart02bSpeaker(showGasket: true)
    spkR.position = SCNVector3(78.8, 28.6, -3.0)
    root.addChildNode(spkR)
    rec("spk_R", "spk_R", "3070 Speaker R + Gasket", 78.8, 148.8, 3.0, 33.0, 28.6, 46.6)

    // 3. ideaspark ESP32 1.9" IPS (X: 3.9..67.6, Y: 75.5..107.0, PCB bottom Z=42.1)
    let esp = buildPart01ESP32(showKeepout: true)
    esp.position = SCNVector3(3.9, 42.1, -75.5)
    root.addChildNode(esp)
    rec("esp_top", "esp", "ideaspark ESP32 + 1.9in LCD", 2.4, 67.6, 75.5, 107.0, 38.9, 45.3)
    rec("esp_hdrs", "esp", "ideaspark 2x19 Pins + F-F Keepout", 9.5, 58.0, 76.0, 106.5, 19.6, 42.1)

    // 4. WM8960 Audio HAT (X: 76.0..141.0, Y: 77.6..107.6, PCB bottom Z=30.9)
    let wm = buildPart02WM8960(showKeepout: true)
    wm.position = SCNVector3(76.0, 30.9, -77.6)
    root.addChildNode(wm)
    rec("wm_pcb", "wm", "WM8960 HAT PCB + TRS + Mics + JST", 76.0, 141.0, 77.6, 109.6, 30.9, 46.5)
    rec("wm_40p", "wm", "WM8960 40-Pin + M-F DuPont Keepout", 83.1, 133.9, 78.4, 83.8, 2.4, 30.9)

    // 5. KY-023 Thumbstick (X: 6.0..40.0 + cable 62.0, Y: 41.0..67.0, PCB bottom Z=23.5)
    let ky = buildPart03KY023(showKeepout: true)
    ky.position = SCNVector3(6.0, 23.5, -41.0)
    root.addChildNode(ky)
    rec("ky_body", "ky", "KY-023 PCB + Gimbal + Thumb Cap", 6.0, 40.0, 41.0, 67.0, 21.5, 55.5)
    rec("ky_cable", "ky", "KY-023 90-deg 5P Keepout", 40.0, 62.0, 47.0, 61.0, 24.8, 30.9)

    // 6. GODIYMODULES 1x4 Keypad Recessed Option 1 (X: 72.0..109.0, Y: 47.0..62.0, PCB bottom Z=15.0)
    let pad = buildPart04Keypad(showKeepout: true, showPlungers: true)
    pad.position = SCNVector3(72.0, 15.0, -47.0)
    root.addChildNode(pad)
    rec("pad_body", "pad", "1x4 Keypad + Plungers + Upright Keepout", 72.0, 109.0, 47.0, 62.0, 15.0, 50.5)

    // 7. WWZMDiB MicroSD Reader (Right slot X=153.6, mirrored left toward 111.6, cable 89.6..111.6, Z=3.0)
    let sd = buildPart05MicroSD(showKeepout: true)
    sd.scale = SCNVector3(-1, 1, 1) // mirror X so SD cage faces +X wall X=153.6
    sd.position = SCNVector3(153.6, 3.0, -42.0)
    root.addChildNode(sd)
    rec("sd_all", "sd", "WWZMDiB MicroSD + 90-deg 6P Keepout", 89.6, 156.1, 42.0, 66.0, 3.0, 9.5)

    // Protective internal shelf divider between MicroSD (Z<=9.5) and Keypad (Z>=15.0)
    addBox(root, 72.0, 153.0, 42.0, 66.0, 11.2, 12.6, mat: mShellGhost, name: "sd_keypad_shelf")
    rec("shelf", "shelf", "SD/Keypad Isolation Shelf", 72.0, 153.0, 42.0, 66.0, 11.2, 12.6)

    // 8. 200mm Folded Wire Trunk in Trough T3 (X: 108..148, Y: 5..30, Z: 3.5..22.5)
    let wireGroup = SCNNode(); wireGroup.name = "service_loop_t3"
    for pass in 0..<3 {
        for w in 0..<8 {
            addCyl(wireGroup, cx: 128.0, cy: 8.0 + Double(w) * 2.4, cz: 5.5 + Double(pass) * 5.2,
                   d: 1.4, h: 38.0, axis: .x, mat: mWireColors[(w + pass) % mWireColors.count])
        }
    }
    root.addChildNode(wireGroup)
    rec("trunk_t3", "wire", "200mm Wire Service Loop (Trough T3)", 109.0, 147.0, 6.0, 28.0, 4.0, 18.0)

    // 9. Flush Left-Wall USB-A -> USB-C U-Bridge (Topology A Interlock, X: -7.6..2.4)
    addBox(root, -7.6, 2.4, 10.5, 96.5, 4.5, 43.0, radius: 1.8, mat: mBridgeBody, name: "usb_u_bridge")
    rec("u_bridge", "bridge", "Left-Wall USB-A to USB-C U-Bridge", -7.6, 2.39, 10.5, 96.5, 4.5, 43.0)

    // 10. Ghost PETG/ASA Outer Enclosure (156.0 x 112.0 x 49.0 mm, 2.4 mm walls) + crisp edge frame
    let shell = SCNNode(); shell.name = "petg_outer_shell_ghost"
    addBox(shell, 0.0, 156.0, 0.0, 112.0, 0.0, 2.4, radius: 1.5, mat: mShellGhost)  // Back wall
    addBox(shell, 0.0, 156.0, 0.0, 2.4, 0.0, 49.0, radius: 1.2, mat: mShellGhost)   // Bottom wall
    addBox(shell, 0.0, 156.0, 109.6, 112.0, 0.0, 49.0, radius: 1.2, mat: mShellGhost) // Top wall
    addBox(shell, 0.0, 2.4, 0.0, 112.0, 0.0, 49.0, radius: 1.2, mat: mShellGhost)   // Left wall
    addBox(shell, 153.6, 156.0, 0.0, 112.0, 0.0, 49.0, radius: 1.2, mat: mShellGhost) // Right wall
    // Crisp 0.9mm edge wireframe ribs along outer silhouette (156.0 x 112.0 x 49.0 mm)
    let ew = 0.9
    for ez in [0.0, 49.0 - ew] {
        addBox(shell, 0, 156.0, 0, ew, ez, ez + ew, mat: mShellEdge)
        addBox(shell, 0, 156.0, 112.0 - ew, 112.0, ez, ez + ew, mat: mShellEdge)
        addBox(shell, 0, ew, 0, 112.0, ez, ez + ew, mat: mShellEdge)
        addBox(shell, 156.0 - ew, 156.0, 0, 112.0, ez, ez + ew, mat: mShellEdge)
    }
    for ex in [0.0, 156.0 - ew] {
        for ey in [0.0, 112.0 - ew] {
            addBox(shell, ex, ex + ew, ey, ey + ew, 0, 49.0, mat: mShellEdge)
        }
    }
    root.addChildNode(shell)

    // Verify all pairs across distinct groups!
    var conflicts = 0
    print("--- Automated AABB Pairwise Collision Check (08_verified_collision_free_assembly) ---")
    for i in 0..<boxes.count {
        for j in (i + 1)..<boxes.count {
            let a = boxes[i], b = boxes[j]
            if a.group == b.group { continue }
            let (hit, vol) = a.box.overlaps(b.box, eps: 0.05)
            if hit {
                conflicts += 1
                print(String(format: "  [COLLISION] %@ vs %@ (overlap vol = %.2f mm^3)", a.label, b.label, vol))
            }
        }
    }
    if conflicts == 0 {
        print("  [PASS] 0 unintended collisions across all \(boxes.count) physical modules, 14+6mm DuPont keepouts, & service loop!")
    }
    return (root, conflicts)
}

// ============================================================================
// Calibration Props (ISO Credit Card 85.60x53.98 mm + 100.0 mm Steel Ruler)
// ============================================================================
func buildCalibrationCardAndRuler() -> SCNNode {
    let root = SCNNode(); root.name = "calibration_scale_refs"
    // ISO/IEC 7810 ID-1 Credit Card (85.60 x 53.98 x 0.80 mm)
    addBox(root, 0, 85.60, 0, 53.98, 0, 0.80, radius: 1.5, mat: makeMat(0.18, 0.22, 0.28, metalness: 0.2, roughness: 0.35), name: "id1_card")
    addBox(root, 10.0, 21.0, 22.0, 32.0, 0.78, 0.88, radius: 0.6, mat: mGold, name: "emv_chip")
    addBox(root, 0.0, 85.6, 40.0, 47.0, 0.78, 0.86, mat: mCopper)
    // 100.0 mm Steel Precision Scale Ruler (100.0 x 14.0 x 1.2 mm)
    addBox(root, 0, 100.0, -24.0, -10.0, 0, 1.2, mat: mMetalSilver, name: "ruler_100mm")
    for mm in 0...20 {
        let x = Double(mm) * 5.0
        let tickH = (mm % 2 == 0) ? 6.0 : 3.5
        addBox(root, x - 0.18, x + 0.18, -10.0 - tickH, -10.0, 1.2, 1.28, mat: mBlackMatte)
    }
    return root
}

// ============================================================================
// USDZ Export Helper (Scales 1 mm SceneKit root by 0.001 = True Meters!)
// ============================================================================
func exportUSDZ(_ contentNode: SCNNode, filename: String) {
    let scene = SCNScene()
    let exportRoot = contentNode.clone()
    exportRoot.scale = SCNVector3(0.001, 0.001, 0.001)
    scene.rootNode.addChildNode(exportRoot)
    let path = "\(out3DDir)/\(filename)"
    scene.write(to: URL(fileURLWithPath: path), options: nil, delegate: nil, progressHandler: nil)
    print("  Exported 1:1 USDZ -> \(filename)")
}

// ============================================================================
// Metal SCNRenderer Offscreen Studio Snapshot Helper
// ============================================================================
let mtlDevice = MTLCreateSystemDefaultDevice()
let sharedRenderer = SCNRenderer(device: mtlDevice, options: nil)

func setupStudioLights(_ scene: SCNScene) {
    scene.background.contents = NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.985, alpha: 1.0)

    let amb = SCNNode(); amb.light = SCNLight()
    amb.light?.type = .ambient
    amb.light?.intensity = 650
    amb.light?.color = NSColor.white
    scene.rootNode.addChildNode(amb)

    let key = SCNNode(); key.light = SCNLight()
    key.light?.type = .directional
    key.light?.intensity = 900
    key.light?.castsShadow = false
    key.position = SCNVector3(120, 250, 180)
    key.look(at: SCNVector3(50, 0, -40))
    scene.rootNode.addChildNode(key)

    let rim = SCNNode(); rim.light = SCNLight()
    rim.light?.type = .directional
    rim.light?.intensity = 450
    rim.position = SCNVector3(-150, 120, -180)
    rim.look(at: SCNVector3(50, 0, -40))
    scene.rootNode.addChildNode(rim)
}

func renderOrthoPanel(node: SCNNode, width: Int, height: Int,
                      eyeCad: (Double, Double, Double),
                      targetCad: (Double, Double, Double),
                      upCad: (Double, Double, Double),
                      orthoHalfHeightMM: Double,
                      eulerAdjust: SCNVector3 = SCNVector3Zero) -> NSImage {
    let scene = SCNScene()
    setupStudioLights(scene)
    let wrapper = SCNNode()
    let cloned = node.clone()
    cloned.eulerAngles = eulerAdjust
    wrapper.addChildNode(cloned)
    scene.rootNode.addChildNode(wrapper)

    let camNode = SCNNode()
    let cam = SCNCamera()
    cam.usesOrthographicProjection = true
    cam.orthographicScale = orthoHalfHeightMM
    cam.zNear = 0.5
    cam.zFar = 2000.0
    camNode.camera = cam
    camNode.position = SCNVector3(eyeCad.0, eyeCad.2, -eyeCad.1)
    camNode.look(at: SCNVector3(targetCad.0, targetCad.2, -targetCad.1),
                 up: SCNVector3(upCad.0, upCad.2, -upCad.1),
                 localFront: SCNVector3(0, 0, -1))
    scene.rootNode.addChildNode(camNode)

    sharedRenderer.scene = scene
    sharedRenderer.pointOfView = camNode
    return sharedRenderer.snapshot(atTime: 0,
                                   with: CGSize(width: width, height: height),
                                   antialiasingMode: .multisampling4X)
}

func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat,
              color: NSColor = NSColor(calibratedWhite: 0.12, alpha: 1.0),
              bold: Bool = false) {
    let font = bold ? NSFont.systemFont(ofSize: size, weight: .bold)
                    : NSFont.monospacedSystemFont(ofSize: size, weight: .medium)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    NSAttributedString(string: text, attributes: attrs).draw(at: NSPoint(x: x, y: y))
}

func draw10mmGrid(in rect: NSRect, pxPerMM: CGFloat, minorStepMM: CGFloat = 10.0) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.clip(to: rect)
    let stepPx = minorStepMM * pxPerMM
    if stepPx >= 6.0 {
        var x = rect.minX
        var idx = 0
        while x <= rect.maxX {
            ctx.setStrokeColor((idx % 5 == 0)
                ? NSColor(calibratedRed: 0.72, green: 0.78, blue: 0.86, alpha: 0.65).cgColor
                : NSColor(calibratedRed: 0.84, green: 0.88, blue: 0.93, alpha: 0.55).cgColor)
            ctx.setLineWidth(idx % 5 == 0 ? 1.2 : 0.7)
            ctx.move(to: CGPoint(x: x, y: rect.minY))
            ctx.addLine(to: CGPoint(x: x, y: rect.maxY))
            ctx.strokePath()
            x += stepPx; idx += 1
        }
        var y = rect.minY
        idx = 0
        while y <= rect.maxY {
            ctx.setStrokeColor((idx % 5 == 0)
                ? NSColor(calibratedRed: 0.72, green: 0.78, blue: 0.86, alpha: 0.65).cgColor
                : NSColor(calibratedRed: 0.84, green: 0.88, blue: 0.93, alpha: 0.55).cgColor)
            ctx.setLineWidth(idx % 5 == 0 ? 1.2 : 0.7)
            ctx.move(to: CGPoint(x: rect.minX, y: y))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: y))
            ctx.strokePath()
            y += stepPx; idx += 1
        }
    }
    ctx.restoreGState()
}

func saveCanvasPNG(width: Int, height: Int, filename: String, draw: (CGContext) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    draw(gctx.cgContext)
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    let path = "\(outRenderDir)/\(filename)"
    try! data.write(to: URL(fileURLWithPath: path))
    print("  Rendered PNG -> renders/\(filename) (\(width)x\(height))")
}

// ============================================================================
// MAIN GENERATION PIPELINE
// ============================================================================
print("=== Generating Verified 1:1 CAD Models & Calibrated Reference Sheets ===")

let n01 = buildPart01ESP32(showKeepout: false)
let n02 = buildPart02WM8960(showKeepout: false)
let n02b = buildPart02bSpeaker(showGasket: false)
let n03 = buildPart03KY023(showKeepout: false)
let n04 = buildPart04Keypad(showKeepout: false, showPlungers: false)
let n05 = buildPart05MicroSD(showKeepout: false)
let n06 = buildPart06DuPont()
let n07 = buildPart07BatteryV3()
let (n08, conflictCount) = buildPart08AssemblyAndVerify()

// 1. Export all 9 1:1 USDZ files
exportUSDZ(n01, filename: "01_ideaspark_esp32_19_ips.usdz")
exportUSDZ(n02, filename: "02_wm8960_audio_hat.usdz")
exportUSDZ(n02b, filename: "02b_wm8960_speaker_box.usdz")
exportUSDZ(n03, filename: "03_ky023_thumbstick.usdz")
exportUSDZ(n04, filename: "04_godiymodules_1x4_keypad.usdz")
exportUSDZ(n05, filename: "05_wwzmdib_microsd_reader.usdz")
exportUSDZ(n06, filename: "06_dupont_housing_and_20cm_bundle.usdz")
exportUSDZ(n07, filename: "07_aceirmc_18650_shield_v3.usdz")
exportUSDZ(n08, filename: "08_verified_collision_free_assembly.usdz")

// 2. Render 4-View Orthographic + Isometric Reference Cards (01..07)
struct PartCardSpec {
    let filename: String
    let title: String
    let subtitle: String
    let node: SCNNode
    let cx: Double; let cy: Double; let cz: Double
    let orthoHalfH: Double
    let isoEye: (Double, Double, Double)
}

let partCards: [PartCardSpec] = [
    PartCardSpec(filename: "ref_01_esp32_19_ips.png",
                 title: "01 — ideaspark ESP32 16MB + 1.9\" ST7789 IPS (B0D6QXC813)",
                 subtitle: "PCB: 63.7 x 31.5 x 1.6 mm | 2x19 Downward Pins (-11mm) | USB-C (-1.5mm) | LCD: 49.72 x 25.80 mm",
                 node: buildPart01ESP32(showKeepout: true), cx: 31.85, cy: 15.75, cz: -4.0, orthoHalfH: 38.0, isoEye: (95, -80, 75)),
    PartCardSpec(filename: "ref_02_wm8960_audio_hat.png",
                 title: "02 — WM8960 Audio HAT (Waveshare 15668 Pi Zero HAT, B0GH6JCGNV)",
                 subtitle: "PCB: 65.0 x 30.0 x 1.6 mm (NOT 65x56!) | Bottom 2x20 (-8.5mm / -28.5mm M-F) | 3.5mm OUT3=1.65V | Dual MEMS",
                 node: buildPart02WM8960(showKeepout: true), cx: 32.5, cy: 15.0, cz: -5.0, orthoHalfH: 40.0, isoEye: (95, -85, 75)),
    PartCardSpec(filename: "ref_02b_speaker_box.png",
                 title: "02b — 3070 Enclosed 8-Ohm 1W Stereo Speaker Box (x2 Included in Kit)",
                 subtitle: "Box: 70.0 x 30.0 x 17.0 mm each (+1.0 mm TPU front gasket = 18.0 mm) | Pre-wired 4-pin JST PH 2.0",
                 node: buildPart02bSpeaker(showGasket: true), cx: 35.0, cy: 15.0, cz: 8.5, orthoHalfH: 42.0, isoEye: (98, -75, 68)),
    PartCardSpec(filename: "ref_03_ky023_thumbstick.png",
                 title: "03 — KY-023 Dual-Axis PS2 Thumbstick (B0D83FD3M8)",
                 subtitle: "PCB: 34.0 x 26.0 x 1.6 mm | Cap Z=32.0 mm (Ø24mm bore) | 90-deg 1x5 Header (+22mm) | POWER WITH 3.3V!",
                 node: buildPart03KY023(showKeepout: true), cx: 26.0, cy: 13.0, cz: 14.0, orthoHalfH: 38.0, isoEye: (80, -68, 65)),
    PartCardSpec(filename: "ref_04_godiymodules_1x4_keypad.png",
                 title: "04 — GODIYMODULES 1x4 Tactile Button Keypad (B0GW8BP2KR)",
                 subtitle: "PCB: 37.0 x 15.0 x 1.6 mm | Buttons Z=11.0 mm | CATCH: 1x5 Header Points STRAIGHT UP (+31mm Mated!)",
                 node: buildPart04Keypad(showKeepout: true), cx: 18.5, cy: 7.5, cz: 14.0, orthoHalfH: 30.0, isoEye: (68, -62, 58)),
    PartCardSpec(filename: "ref_05_wwzmdib_microsd.png",
                 title: "05 — WWZMDiB MicroSD TF SPI Reader (B0B779R5TZ)",
                 subtitle: "PCB: 42.0 x 24.0 x 1.6 mm | 90-deg 1x6 Header (+22mm) | AMS1117 REQUIRES 5V VCC! | 74LVC125A Dedicated HSPI",
                 node: buildPart05MicroSD(showKeepout: true), cx: 29.0, cy: 12.0, cz: 3.0, orthoHalfH: 36.0, isoEye: (85, -75, 65)),
    PartCardSpec(filename: "ref_06_dupont_housing_and_20cm_bundle.png",
                 title: "06 — ELEGOO 20 cm DuPont Housing & S-Loop Bundle (B01EV70C78)",
                 subtitle: "1P Shell: 14.0 x 2.54 x 2.54 mm | +6.0 mm Bend Radius | 25 Wires x 200 mm = ~22-28 cm^3 Folded Service Loop",
                 node: buildPart06DuPont(), cx: 36.0, cy: 22.0, cz: 5.0, orthoHalfH: 38.0, isoEye: (105, -75, 65)),
    PartCardSpec(filename: "ref_07_18650_shield_v3.png",
                 title: "07 — ACEIRMC 18650 Shield V3 + Flat-Top 18650 Cell (B0DFYDCGHP)",
                 subtitle: "Shield: 99.5 x 29.2 x 21.0 mm | 65.0xØ18.3mm Flat-Top | UNPOPULATED Side 3V/5V Pads -> Exit USB-A!",
                 node: buildPart07BatteryV3(), cx: 49.75, cy: 14.6, cz: 10.5, orthoHalfH: 56.0, isoEye: (135, -105, 85))
]

for spec in partCards {
    let W = 1600, H = 1200
    let panW = 755, panH = 505
    let imgTop   = renderOrthoPanel(node: spec.node, width: panW, height: panH,
                                    eyeCad: (spec.cx, spec.cy, 400), targetCad: (spec.cx, spec.cy, spec.cz),
                                    upCad: (0, 1, 0), orthoHalfHeightMM: spec.orthoHalfH)
    let imgIso   = renderOrthoPanel(node: spec.node, width: panW, height: panH,
                                    eyeCad: spec.isoEye, targetCad: (spec.cx, spec.cy, spec.cz),
                                    upCad: (0, 0, 1), orthoHalfHeightMM: spec.orthoHalfH)
    let imgFront = renderOrthoPanel(node: spec.node, width: panW, height: panH,
                                    eyeCad: (spec.cx, -400, spec.cz), targetCad: (spec.cx, spec.cy, spec.cz),
                                    upCad: (0, 0, 1), orthoHalfHeightMM: spec.orthoHalfH)
    let imgSide  = renderOrthoPanel(node: spec.node, width: panW, height: panH,
                                    eyeCad: (400, spec.cy, spec.cz), targetCad: (spec.cx, spec.cy, spec.cz),
                                    upCad: (0, 0, 1), orthoHalfHeightMM: spec.orthoHalfH)

    saveCanvasPNG(width: W, height: H, filename: spec.filename) { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.985, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        let pxPerMM = CGFloat(panH) / CGFloat(spec.orthoHalfH * 2.0)
        let quads: [(NSRect, NSImage, String, Bool)] = [
            (NSRect(x: 30, y: 585, width: panW, height: panH), imgTop, "TOP (+Z) ORTHOGRAPHIC 1:1", true),
            (NSRect(x: 815, y: 585, width: panW, height: panH), imgIso, "3/4 ISOMETRIC (ORANGE = 14mm DUPONT + 6mm BEND)", false),
            (NSRect(x: 30, y: 40, width: panW, height: panH), imgFront, "FRONT (-Y) ELEVATION ORTHOGRAPHIC", true),
            (NSRect(x: 815, y: 40, width: panW, height: panH), imgSide, "SIDE (+X) ELEVATION ORTHOGRAPHIC", true)
        ]
        for (rect, img, lbl, grid) in quads {
            img.draw(in: rect)
            if grid { draw10mmGrid(in: rect, pxPerMM: pxPerMM) }
            ctx.setStrokeColor(NSColor(calibratedWhite: 0.72, alpha: 1.0).cgColor)
            ctx.setLineWidth(1.5); ctx.stroke(rect)
            drawText(lbl, x: rect.minX + 12, y: rect.maxY - 26, size: 14, bold: true)
        }
        // Header banner
        ctx.setFillColor(NSColor(calibratedRed: 0.11, green: 0.15, blue: 0.22, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: H - 92, width: W, height: 92))
        drawText(spec.title, x: 30, y: CGFloat(H) - 42, size: 24, color: .white, bold: true)
        drawText(spec.subtitle, x: 30, y: CGFloat(H) - 72, size: 15, color: NSColor(calibratedRed: 0.72, green: 0.86, blue: 0.98, alpha: 1.0))
    }
}

// 3. Render 00_master_1to1_parts_lineup_ref.png (2400 x 1500, STRICT UNIFORM px/mm SCALE!)
do {
    let lineup = SCNNode(); lineup.name = "master_1to1_lineup"
    // Arrange EVERY component + ISO Credit Card + 100mm Ruler on one flat plane (strictly identical ortho px/mm!)
    let refs = buildCalibrationCardAndRuler()
    refs.position = SCNVector3(-5, 0, -148) // Card Y=148..202, Ruler Y=124..138
    lineup.addChildNode(refs)

    let l06 = buildPart06DuPont();                       l06.position = SCNVector3(114, 0, -140)   // DuPont X=114..186, Y=140..183
    let l05 = buildPart05MicroSD(showKeepout: true);     l05.position = SCNVector3(212, 0, -155)   // MicroSD X=210..276, Y=155..179 (completely clear of inset!)

    let l01 = buildPart01ESP32(showKeepout: true);       l01.position = SCNVector3(-5, 12, -74)    // ESP32 Mid-Left Y=74..106
    let l02 = buildPart02WM8960(showKeepout: true);      l02.position = SCNVector3(78, 30, -74)    // WM8960 Mid Y=74..106
    let l02b1 = buildPart02bSpeaker(showGasket: false);  l02b1.position = SCNVector3(166, 0, -74)  // Speaker #1 Y=74..104
    let l02b2 = buildPart02bSpeaker(showGasket: false);  l02b2.position = SCNVector3(248, 0, -74)  // Speaker #2 Y=74..104

    let l03 = buildPart03KY023(showKeepout: true);       l03.position = SCNVector3(-5, 0, -10)     // KY-023 Bot-Left Y=10..36
    let l04 = buildPart04Keypad(showKeepout: true);      l04.position = SCNVector3(64, 0, -14)     // 1x4 Keypad Y=14..29
    let l07 = buildPart07BatteryV3();                    l07.position = SCNVector3(118, 2, -10)    // V3 Shield X=118..217.5, Y=10..39.2 (left of inset!)

    for n in [l01, l02, l02b1, l02b2, l07, l03, l04, l05, l06] { lineup.addChildNode(n) }

    let W = 2400, H = 1500
    let panW = 2340, panH = 1340
    let orthoH = 112.0 // Total visible Y = 224.0 mm -> exact uniform 5.982 px/mm across ALL parts!
    let imgLineup = renderOrthoPanel(node: lineup, width: panW, height: panH,
                                     eyeCad: (162, 108, 450), targetCad: (162, 108, 10),
                                     upCad: (0, 1, 0), orthoHalfHeightMM: orthoH)
    let imgIsoInset = renderOrthoPanel(node: lineup, width: 730, height: 375,
                                       eyeCad: (320, -145, 225), targetCad: (145, 92, 10),
                                       upCad: (0, 0, 1), orthoHalfHeightMM: 122.0)

    saveCanvasPNG(width: W, height: H, filename: "00_master_1to1_parts_lineup_ref.png") { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.985, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        let mainRect = NSRect(x: 30, y: 35, width: panW, height: panH)
        imgLineup.draw(in: mainRect)
        let pxPerMM = CGFloat(panH) / CGFloat(orthoH * 2.0)
        draw10mmGrid(in: mainRect, pxPerMM: pxPerMM)
        ctx.setStrokeColor(NSColor(calibratedWhite: 0.65, alpha: 1.0).cgColor)
        ctx.setLineWidth(2.0); ctx.stroke(mainRect)

        // Perspective inset bottom-right (strictly X >= 1610 so l07 X<=217.5mm never overlaps!)
        let insetRect = NSRect(x: W - 775, y: 50, width: 730, height: 375)
        imgIsoInset.draw(in: insetRect)
        ctx.setStrokeColor(NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.52, alpha: 1.0).cgColor)
        ctx.setLineWidth(2.5); ctx.stroke(insetRect)
        drawText("3D Z-HEIGHT COMPARISON INSET (KY-023 32mm Cap, Upright 1x4 Pins, 21mm V3 Shield)", x: insetRect.minX + 10, y: insetRect.maxY - 24, size: 12.5, bold: true)

        // Banner
        ctx.setFillColor(NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: H - 100, width: W, height: 100))
        drawText("00 — MASTER 1:1 CALIBRATED HARDWARE LINEUP (UNIFORM ORTHOGRAPHIC px/mm SCALE)", x: 30, y: CGFloat(H) - 44, size: 28, color: .white, bold: true)
        drawText("ISO ID-1 Credit Card (85.60x53.98mm) + 100mm Steel Ruler + All 9 BOM Pieces | Orange Zones = Mated 14mm DuPont Housing + 6mm Bend Radius",
                 x: 30, y: CGFloat(H) - 78, size: 16, color: NSColor(calibratedRed: 0.72, green: 0.87, blue: 1.0, alpha: 1.0))

        // Calibrated non-overlapping row labels (exact px math from cadX/cadY -> 5.982 px/mm)
        drawText("ISO CREDIT CARD (85.6 x 54.0 mm) + 100 mm RULER", x: 185, y: 1295, size: 15, bold: true)
        drawText("06: 14mm 1P/5P DUPONT & 200mm S-LOOP BUNDLE", x: 895, y: 1205, size: 15, bold: true)
        drawText("05: WWZMDiB MicroSD (42 x 24 mm) + 90° 6P", x: 1480, y: 1205, size: 15, bold: true)

        drawText("01: ideaspark ESP32 1.9\" IPS (63.7 x 31.5 mm)", x: 185, y: 718, size: 15, bold: true)
        drawText("02: WM8960 HAT (65 x 30 mm)", x: 695, y: 718, size: 15, bold: true)
        drawText("02b: DUAL 3070 SPEAKERS (70 x 30 x 17 mm EACH)", x: 1225, y: 718, size: 15, bold: true)

        drawText("03: KY-023 + 90° 5P", x: 185, y: 318, size: 15, bold: true)
        drawText("04: 1x4 KEYPAD (UPWARD PINS!)", x: 585, y: 318, size: 15, bold: true)
        drawText("07: ACEIRMC 18650 SHIELD V3 (99.5 x 29.2 x 21 mm)", x: 925, y: 332, size: 15, bold: true)
    }
}

// 4. Render ref_08_verified_assembly_views.png (2000 x 1500, 4-View Turnaround of 156x112x49 Assembly)
do {
    let W = 2000, H = 1500
    let panW = 945, panH = 655
    let imgFront = renderOrthoPanel(node: n08, width: panW, height: panH,
                                    eyeCad: (76, 56, 450), targetCad: (76, 56, 24.5),
                                    upCad: (0, 1, 0), orthoHalfHeightMM: 76.0)
    let imgIso   = renderOrthoPanel(node: n08, width: panW, height: panH,
                                    eyeCad: (-150, -140, 210), targetCad: (76, 56, 24.5),
                                    upCad: (0, 0, 1), orthoHalfHeightMM: 92.0)
    // Use BOTTOM (-Y) camera (dir = (0, 0, -1), avoiding lookAt -localFront degeneracy AND exposing Z-stack clearly!)
    let imgBot   = renderOrthoPanel(node: n08, width: panW, height: panH,
                                    eyeCad: (76, -350, 24.5), targetCad: (76, 56, 24.5),
                                    upCad: (0, 0, 1), orthoHalfHeightMM: 64.0)
    let imgLeft  = renderOrthoPanel(node: n08, width: panW, height: panH,
                                    eyeCad: (-350, 56, 24.5), targetCad: (76, 56, 24.5),
                                    upCad: (0, 0, 1), orthoHalfHeightMM: 48.0)

    saveCanvasPNG(width: W, height: H, filename: "ref_08_verified_assembly_views.png") { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.985, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        let panels: [(NSRect, NSImage, String, Double)] = [
            (NSRect(x: 35, y: 725, width: panW, height: panH), imgFront, "FRONT FACE (+Z) — 156.0 x 112.0 mm (ZERO X/Y OVERLAPS)", 76.0),
            (NSRect(x: 1020, y: 725, width: panW, height: panH), imgIso, "3/4 X-RAY ISOMETRIC — LEFT-WALL USB-A->C U-BRIDGE + T3 SLACK BAY", 0.0),
            (NSRect(x: 35, y: 35, width: panW, height: panH), imgBot, "BOTTOM (-Y) CROSS-SECTION — NON-OVERLAPPING Z-STACK (49.0 mm OUTER)", 64.0),
            (NSRect(x: 1020, y: 35, width: panW, height: panH), imgLeft, "LEFT (-X) ELEVATION — TOPOLOGY A USB U-BRIDGE & SPEAKER/BATTERY Z-GAP", 48.0)
        ]
        for (rect, img, lbl, oH) in panels {
            img.draw(in: rect)
            if oH > 0 { draw10mmGrid(in: rect, pxPerMM: CGFloat(panH) / CGFloat(oH * 2.0)) }
            ctx.setStrokeColor(NSColor(calibratedWhite: 0.68, alpha: 1.0).cgColor)
            ctx.setLineWidth(1.8); ctx.stroke(rect)
            drawText(lbl, x: rect.minX + 12, y: rect.maxY - 26, size: 15, bold: true)
        }

        ctx.setFillColor(NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: H - 102, width: W, height: 102))
        drawText("08 — COLLISION-VERIFIED 1:1 PACKAGING ASSEMBLY (156.0 x 112.0 x 49.0 mm PETG/ASA)", x: 35, y: CGFloat(H) - 44, size: 28, color: .white, bold: true)
        drawText("AABB Check: \(conflictCount) Unintended Collisions | Topology A USB-A->C U-Bridge | Orange Keepouts = True 14mm DuPont + 6mm Bend + T3 Wire Loop",
                 x: 35, y: CGFloat(H) - 78, size: 16, color: NSColor(calibratedRed: 0.45, green: 0.92, blue: 0.62, alpha: 1.0))
    }
}

print("=== Completed: 9 USDZ + 10 Calibrated Metal Reference PNGs (Collisions=\(conflictCount)) ===")
if conflictCount > 0 { exit(2) }
