#!/usr/bin/env swift
// ============================================================================
// generate_1to1_enclosure_scene.swift
// Pocket Streamer Hardware CAD — Verified 1:1 Enclosure Variants:
//   - Option A: 0-Speaker Slim Pocket Walkman (106.0 × 132.0 × 32.0 / 40.5 mm)
//   - Option B: 1-Speaker Slim Field Recorder (119.0 × 134.0 × 32.0 / 48.5 mm)
//   - Baseline: 2-Speaker Field Portable (156.0 × 112.0 × 49.0 mm)
// Uses exact verified 1:1 component dimensions, Option-2 90°-bent 1×4 Keypad
// headers (12.5 mm Z), automated pairwise AABB collision verification, USDZ
// 1:1 export (1 unit = 1 mm -> 0.001 m), and Metal SceneKit calibrated guides.
// ============================================================================

import Foundation
import SceneKit
import SceneKit.ModelIO
import Metal
import AppKit
import CoreGraphics

// ----------------------------------------------------------------------------
// 0. Paths & Directories
// ----------------------------------------------------------------------------
let baseDir = "/Users/benfox/Development/3D Design/Pocket Streamer Hardware CAD"
let usdzDir = "\(baseDir)/parts_1to1_3d/usdz"
let renderDir = "\(baseDir)/parts_1to1_3d/renders"
let artifactDir = "/Users/benfox/.gemini/antigravity/brain/d773b1b3-4405-4408-8ad7-b59f103e4218"

try? FileManager.default.createDirectory(atPath: usdzDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: renderDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: artifactDir, withIntermediateDirectories: true)

// ----------------------------------------------------------------------------
// 1. Coordinate & Collision Primitives (Global CAD frame: X right, Y up, Z front)
//    SceneKit mapping: scnX = cadX, scnY = cadZ (up), scnZ = -cadY
// ----------------------------------------------------------------------------
struct AABB {
    let name: String
    let minX, maxX, minY, maxY, minZ, maxZ: Double

    func overlaps(_ o: AABB, eps: Double = 0.05) -> (Bool, Double, String) {
        let ox = min(maxX, o.maxX) - max(minX, o.minX)
        let oy = min(maxY, o.maxY) - max(minY, o.minY)
        let oz = min(maxZ, o.maxZ) - max(minZ, o.minZ)
        if ox > eps && oy > eps && oz > eps {
            let minPen = min(ox, min(oy, oz))
            return (true, minPen, String(format: "dx=%.2f dy=%.2f dz=%.2f", ox, oy, oz))
        }
        return (false, 0.0, "")
    }
}

func makeAABB(origin: (Double, Double, Double), rotZDeg: Int = 0, name: String,
              _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double) -> AABB {
    let corners: [(Double, Double)] = [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]
    var xs: [Double] = []
    var ys: [Double] = []
    for (lx, ly) in corners {
        let rx, ry: Double
        switch ((rotZDeg % 360) + 360) % 360 {
        case 90:   rx = -ly; ry = lx
        case 180:  rx = -lx; ry = -ly
        case 270:  rx = ly;  ry = -lx
        default:   rx = lx;  ry = ly
        }
        xs.append(origin.0 + rx)
        ys.append(origin.1 + ry)
    }
    return AABB(name: name,
                minX: xs.min()!, maxX: xs.max()!,
                minY: ys.min()!, maxY: ys.max()!,
                minZ: origin.2 + z0, maxZ: origin.2 + z1)
}

func verifyAABBs(label: String, boxes: [(String, AABB)]) -> Int {
    var conflicts = 0
    for i in 0..<boxes.count {
        for j in (i + 1)..<boxes.count {
            let (grpA, a) = boxes[i]
            let (grpB, b) = boxes[j]
            if grpA == grpB { continue }
            let (hit, pen, detail) = a.overlaps(b, eps: 0.05)
            if hit {
                conflicts += 1
                print(String(format: "  ❌ [COLLISION] %@: [%@:%@] <-> [%@:%@] (minPen=%.2f mm, %@)",
                             label, grpA, a.name, grpB, b.name, pen, detail))
            }
        }
    }
    print("🔍 \(label) AABB Audit -> Pairwise Box Groups Checked: \(boxes.count) | Collisions: \(conflicts)")
    return conflicts
}

// ----------------------------------------------------------------------------
// 2. Material Palette (Matte Studio Hardware Look)
// ----------------------------------------------------------------------------
func pbrMat(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0,
            roughness: CGFloat = 0.65, metalness: CGFloat = 0.05,
            emissive: NSColor? = nil) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    m.roughness.contents = roughness
    m.metalness.contents = metalness
    if let e = emissive { m.emission.contents = e }
    if a < 0.99 {
        m.isDoubleSided = true
        m.transparencyMode = .aOne
    }
    return m
}

let matStoneGray   = pbrMat(0.84, 0.83, 0.80, roughness: 0.72, metalness: 0.03)
let matStoneStep   = pbrMat(0.79, 0.78, 0.75, roughness: 0.68, metalness: 0.05)
let matCharcoal    = pbrMat(0.18, 0.19, 0.21, roughness: 0.68, metalness: 0.08)
let matDarkSlate   = pbrMat(0.12, 0.13, 0.15, roughness: 0.58, metalness: 0.12)
let matRecOrange   = pbrMat(0.95, 0.34, 0.08, roughness: 0.45, metalness: 0.05)
let matBezelBlack  = pbrMat(0.05, 0.05, 0.06, roughness: 0.18, metalness: 0.08)
let matSmokedShell = pbrMat(0.14, 0.15, 0.17, 0.30, roughness: 0.35, metalness: 0.06)
let matSmokedTop   = pbrMat(0.45, 0.45, 0.43, 0.34, roughness: 0.38, metalness: 0.04)

let matPCBBlack    = pbrMat(0.08, 0.09, 0.10, roughness: 0.55, metalness: 0.10)
let matPCBBlue     = pbrMat(0.08, 0.24, 0.52, roughness: 0.50, metalness: 0.08)
let matPCBGreen    = pbrMat(0.09, 0.38, 0.18, roughness: 0.52, metalness: 0.08)
let matSteel       = pbrMat(0.76, 0.78, 0.80, roughness: 0.28, metalness: 0.90)
let matBrushedAl   = pbrMat(0.78, 0.80, 0.83, roughness: 0.36, metalness: 0.85)
let matGold        = pbrMat(0.88, 0.70, 0.22, roughness: 0.24, metalness: 0.92)
let matPurple18650 = pbrMat(0.48, 0.20, 0.58, roughness: 0.42, metalness: 0.10)
let matCopperWire  = pbrMat(0.80, 0.36, 0.16, roughness: 0.42, metalness: 0.72)
let matJSTWhite    = pbrMat(0.92, 0.91, 0.88, roughness: 0.45, metalness: 0.02)
let matFoamBlack   = pbrMat(0.10, 0.10, 0.11, roughness: 0.90, metalness: 0.00)
let matMeshDark    = pbrMat(0.07, 0.07, 0.08, roughness: 0.85, metalness: 0.18)

let matScreenActive: SCNMaterial = {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    // Procedural crisp UI artwork image for 1.9" IPS 170x320 screen
    let w = 320, h = 170
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    NSColor(srgbRed: 0.06, green: 0.08, blue: 0.11, alpha: 1.0).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: w, height: h)).fill()
    // Left warm orange audiobook cover thumbnail
    NSColor(srgbRed: 0.92, green: 0.36, blue: 0.10, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 16, y: 24, width: 88, height: 112), xRadius: 8, yRadius: 8).fill()
    NSColor(srgbRed: 0.98, green: 0.86, blue: 0.65, alpha: 1.0).setFill()
    NSBezierPath(ovalIn: NSRect(x: 42, y: 78, width: 36, height: 36)).fill()
    // Status bar top
    NSColor(srgbRed: 0.14, green: 0.78, blue: 0.58, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 120, y: 132, width: 64, height: 14), xRadius: 4, yRadius: 4).fill()
    NSColor(srgbRed: 0.55, green: 0.62, blue: 0.72, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 248, y: 132, width: 54, height: 14), xRadius: 4, yRadius: 4).fill()
    // Track text bars
    NSColor(srgbRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 120, y: 98, width: 174, height: 18), xRadius: 4, yRadius: 4).fill()
    NSColor(srgbRed: 0.65, green: 0.70, blue: 0.78, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 120, y: 72, width: 132, height: 12), xRadius: 3, yRadius: 3).fill()
    // Progress scrubber
    NSColor(srgbRed: 0.22, green: 0.25, blue: 0.31, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 120, y: 34, width: 180, height: 10), xRadius: 5, yRadius: 5).fill()
    NSColor(srgbRed: 0.95, green: 0.36, blue: 0.10, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 120, y: 34, width: 112, height: 10), xRadius: 5, yRadius: 5).fill()
    img.unlockFocus()
    m.diffuse.contents = img
    m.emission.contents = img
    m.emission.intensity = 0.55
    m.roughness.contents = 0.14
    m.metalness.contents = 0.04
    return m
}()

let matPhoneScreen: SCNMaterial = {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = NSColor(srgbRed: 0.05, green: 0.06, blue: 0.08, alpha: 1.0)
    m.roughness.contents = 0.08
    m.metalness.contents = 0.10
    return m
}()

let matAirPodsWhite = pbrMat(0.95, 0.95, 0.94, roughness: 0.18, metalness: 0.02)
let matCardWhite    = pbrMat(0.94, 0.94, 0.92, roughness: 0.28, metalness: 0.04)
let matCardStripe   = pbrMat(0.14, 0.32, 0.62, roughness: 0.35, metalness: 0.10)
let matClearKeepout = pbrMat(0.95, 0.55, 0.15, 0.22, roughness: 0.5, metalness: 0.0)

// ----------------------------------------------------------------------------
// 3. Geometry Helpers (CAD coordinates X_right, Y_up, Z_front -> SceneKit)
// ----------------------------------------------------------------------------
enum CylAxis { case x, y, z }

@discardableResult
func addBox(_ parent: SCNNode, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double,
            radius: Double = 0.0, mat: SCNMaterial, name: String = "box") -> SCNNode {
    let w = max(0.05, abs(x1 - x0))
    let h = max(0.05, abs(y1 - y0))
    let d = max(0.05, abs(z1 - z0))
    let box = SCNBox(width: CGFloat(w), height: CGFloat(d), length: CGFloat(h), chamferRadius: CGFloat(radius))
    box.materials = [mat]
    let node = SCNNode(geometry: box)
    node.name = name
    node.position = SCNVector3((x0 + x1) * 0.5, (z0 + z1) * 0.5, -(y0 + y1) * 0.5)
    parent.addChildNode(node)
    return node
}

@discardableResult
func addCyl(_ parent: SCNNode, cx: Double, cy: Double, cz: Double, d: Double, h: Double,
            axis: CylAxis = .z, mat: SCNMaterial, name: String = "cyl") -> SCNNode {
    let cyl = SCNCylinder(radius: CGFloat(d * 0.5), height: CGFloat(h))
    cyl.radialSegmentCount = 36
    cyl.materials = [mat]
    let node = SCNNode(geometry: cyl)
    node.name = name
    node.position = SCNVector3(cx, cz, -cy)
    switch axis {
    case .z: break
    case .x: node.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
    case .y: node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
    }
    parent.addChildNode(node)
    return node
}

func cadPlace(_ node: SCNNode, ox: Double, oy: Double, oz: Double, rotZDeg: Int = 0) {
    node.position = SCNVector3(ox, oz, -oy)
    let rad = Float(rotZDeg) * Float.pi / 180.0
    node.eulerAngles = SCNVector3(0, rad, 0)
}

// ----------------------------------------------------------------------------
// 4. Verified 1:1 Internal Component Builders (with exact AABB records)
// ----------------------------------------------------------------------------
struct BuiltComponent {
    let node: SCNNode
    let aabbs: [(String, AABB)]
}

func buildPart01ESP32(ox: Double, oy: Double, oz: Double, rotZDeg: Int = 0, includeKeepout: Bool) -> BuiltComponent {
    let n = SCNNode(); n.name = "part01_esp32"
    addBox(n, 0, 63.7, 0, 31.5, 0, 1.6, radius: 0.4, mat: matPCBBlack, name: "esp_pcb")
    // Metal shield & antenna end on right
    addBox(n, 48.0, 61.5, 5.0, 26.5, 1.6, 3.8, radius: 0.3, mat: matSteel, name: "esp_shield")
    // USB-C on left edge
    addBox(n, -1.5, 6.0, 11.25, 20.25, 1.6, 4.9, radius: 0.8, mat: matSteel, name: "esp_usbc")
    // 1.9" IPS Display Glass + Active 42.72 x 22.70 mm screen
    addBox(n, 9.5, 59.22, 2.85, 28.65, 1.6, 3.08, radius: 0.3, mat: matBezelBlack, name: "lcd_glass")
    addBox(n, 13.0, 55.72, 4.4, 27.10, 3.05, 3.22, radius: 0.1, mat: matScreenActive, name: "lcd_active")
    // Dual 1x19 pins
    for i in 0..<19 {
        let px = 8.9 + Double(i) * 2.54
        addBox(n, px - 0.32, px + 0.32, 2.24, 2.88, -11.5, 0.0, mat: matGold, name: "pin_b")
        addBox(n, px - 0.32, px + 0.32, 28.62, 29.26, -11.5, 0.0, mat: matGold, name: "pin_t")
    }
    if includeKeepout {
        addBox(n, 7.72, 55.98, 1.5, 29.9, -22.5, -2.5, radius: 0.6, mat: matClearKeepout, name: "esp_keepout")
    }
    cadPlace(n, ox: ox, oy: oy, oz: oz, rotZDeg: rotZDeg)

    let o = (ox, oy, oz)
    let boxes: [(String, AABB)] = [
        ("esp32", makeAABB(origin: o, rotZDeg: rotZDeg, name: "pcb", 0, 63.7, 0, 31.5, 0, 1.6)),
        ("esp32", makeAABB(origin: o, rotZDeg: rotZDeg, name: "usbc", -1.5, 6.0, 11.25, 20.25, 1.6, 4.9)),
        ("esp32", makeAABB(origin: o, rotZDeg: rotZDeg, name: "lcd", 9.5, 59.22, 2.85, 28.65, 1.6, 3.22)),
        ("esp32", makeAABB(origin: o, rotZDeg: rotZDeg, name: "dupont_keepout", 7.72, 55.98, 1.5, 29.9, -22.5, 0.0))
    ]
    return BuiltComponent(node: n, aabbs: boxes)
}

func buildPart02WM8960(ox: Double, oy: Double, oz: Double, rotZDeg: Int = 0, matedJ1: Bool, includeKeepout: Bool) -> BuiltComponent {
    let n = SCNNode(); n.name = "part02_wm8960"
    addBox(n, 0, 65.0, 0, 30.0, 0, 1.6, radius: 0.4, mat: matPCBBlack, name: "wm_pcb")
    // 3.5mm TRS headphone jack overhanging top edge +2.0 mm
    addBox(n, 12.0, 20.5, 18.0, 32.0, 1.6, 6.6, radius: 0.4, mat: matDarkSlate, name: "trs_body")
    addCyl(n, cx: 16.25, cy: 31.5, cz: 4.1, d: 6.0, h: 1.5, axis: .y, mat: matSteel, name: "trs_ring")
    // Stereo MEMS Mics
    addBox(n, 4.5, 8.26, 4.5, 7.45, 1.6, 2.8, mat: matGold, name: "mic_l")
    addBox(n, 56.74, 60.5, 22.55, 25.5, 1.6, 2.8, mat: matGold, name: "mic_r")
    // WM8960 QFN Codec IC
    addBox(n, 29.0, 34.0, 12.5, 17.5, 1.6, 2.4, mat: matDarkSlate, name: "wm_ic")
    // J1 4-pin JST header (unmated <= 7.6; mated w/ speaker bend <= 15.6)
    addBox(n, 52.1, 62.0, 11.0, 15.5, 1.6, 7.6, radius: 0.3, mat: matJSTWhite, name: "j1_jst")
    if matedJ1 {
        addBox(n, 51.8, 62.3, 10.6, 15.9, 7.6, 15.6, radius: 0.8, mat: matCopperWire, name: "j1_mated_bend")
    }
    // 40-pin Pi socket & M-F DuPont keepout beneath PCB (-28.5..0.0)
    addBox(n, 7.1, 57.9, 0.8, 6.2, -8.5, 0.0, mat: matDarkSlate, name: "pi_40p_hdr")
    if includeKeepout {
        addBox(n, 7.1, 57.9, 0.8, 6.2, -28.5, -8.5, radius: 0.6, mat: matClearKeepout, name: "wm_keepout")
    }
    cadPlace(n, ox: ox, oy: oy, oz: oz, rotZDeg: rotZDeg)

    let o = (ox, oy, oz)
    let j1Top = matedJ1 ? 15.6 : 7.6
    let boxes: [(String, AABB)] = [
        ("wm8960", makeAABB(origin: o, rotZDeg: rotZDeg, name: "pcb", 0, 65.0, 0, 30.0, 0, 1.6)),
        ("wm8960", makeAABB(origin: o, rotZDeg: rotZDeg, name: "trs", 12.0, 20.5, 18.0, 32.0, 1.6, 6.6)),
        ("wm8960", makeAABB(origin: o, rotZDeg: rotZDeg, name: "j1", 51.8, 62.3, 10.6, 15.9, 1.6, j1Top)),
        ("wm8960", makeAABB(origin: o, rotZDeg: rotZDeg, name: "40p_keepout", 7.1, 57.9, 0.8, 6.2, -28.5, 0.0))
    ]
    return BuiltComponent(node: n, aabbs: boxes)
}

func buildPart02bSpeaker(ox: Double, oy: Double, oz: Double, rotZDeg: Int = 0) -> BuiltComponent {
    let n = SCNNode(); n.name = "part02b_speaker_3070"
    // 70 x 30 x 17 mm enclosed resonance chamber + 1.0 mm front EVA gasket = 18.0 mm total Z
    addBox(n, 0, 70.0, 0, 30.0, 0, 17.0, radius: 1.2, mat: matDarkSlate, name: "spk_box")
    addBox(n, 1.5, 68.5, 1.5, 28.5, 17.0, 18.0, radius: 0.8, mat: matFoamBlack, name: "spk_gasket")
    // Visible front cone & passive radiator accent
    addCyl(n, cx: 19.0, cy: 15.0, cz: 17.2, d: 21.0, h: 1.0, axis: .z, mat: matCharcoal, name: "spk_cone")
    addBox(n, 35.0, 63.0, 5.0, 25.0, 17.0, 17.6, radius: 2.0, mat: matMeshDark, name: "spk_rad")
    cadPlace(n, ox: ox, oy: oy, oz: oz, rotZDeg: rotZDeg)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("spk_mono", makeAABB(origin: o, rotZDeg: rotZDeg, name: "enclosure_gasket", 0, 70.0, 0, 30.0, 0, 18.0))
    ])
}

func buildPart03KY023(ox: Double, oy: Double, oz: Double, rotZDeg: Int = 0) -> BuiltComponent {
    let n = SCNNode(); n.name = "part03_ky023"
    addBox(n, 0, 34.0, 0, 26.0, 0, 1.6, radius: 0.4, mat: matPCBBlack, name: "ky_pcb")
    addBox(n, 3.0, 31.0, 2.0, 24.0, -2.0, 0.0, mat: matDarkSlate, name: "ky_tails")
    // Metal gimbal frame
    addBox(n, 7.0, 23.0, 5.0, 21.0, 1.6, 13.8, radius: 0.3, mat: matSteel, name: "ky_gimbal")
    // Dome + Shaft + Mushroom Cap (protrudes cleanly through Z=30..32 faceplate)
    addCyl(n, cx: 15.0, cy: 13.0, cz: 16.4, d: 16.0, h: 5.2, axis: .z, mat: matCharcoal, name: "ky_dome")
    addCyl(n, cx: 15.0, cy: 13.0, cz: 22.2, d: 4.5, h: 6.4, axis: .z, mat: matCharcoal, name: "ky_shaft")
    addCyl(n, cx: 15.0, cy: 13.0, cz: 27.6, d: 17.5, h: 4.8, axis: .z, mat: matDarkSlate, name: "ky_cap")
    // 90 deg 5-pin header + 5P F-F cable bundle (+X exit)
    addBox(n, 31.0, 34.0, 6.35, 19.65, 1.4, 7.4, mat: matDarkSlate, name: "ky_hdr")
    addBox(n, 34.0, 56.0, 6.35, 19.65, 1.4, 7.4, radius: 0.8, mat: matCopperWire, name: "ky_5p_cable")
    cadPlace(n, ox: ox, oy: oy, oz: oz, rotZDeg: rotZDeg)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("ky023", makeAABB(origin: o, rotZDeg: rotZDeg, name: "pcb_tails", 0, 34.0, 0, 26.0, -2.0, 1.6)),
        ("ky023", makeAABB(origin: o, rotZDeg: rotZDeg, name: "gimbal_dome", 7.0, 23.0, 5.0, 21.0, 1.6, 19.0)),
        ("ky023", makeAABB(origin: o, rotZDeg: rotZDeg, name: "5p_cable", 34.0, 56.0, 6.35, 19.65, 1.4, 7.4))
    ])
}

func buildPart04KeypadOpt2(ox: Double, oy: Double, oz: Double, rotZDeg: Int = 0) -> BuiltComponent {
    // Option-2 90-degree bent 1x5 header (12.5 mm total Z under roof!) + 4 tactile keycaps rising to Z_pcb+14.6
    let n = SCNNode(); n.name = "part04_keypad_opt2"
    addBox(n, 0, 37.0, 0, 15.0, 0, 1.6, radius: 0.3, mat: matPCBGreen, name: "pad_pcb")
    addBox(n, 3.0, 34.0, 2.0, 13.0, -1.5, 0.0, mat: matDarkSlate, name: "pad_tails")
    for i in 0..<4 {
        let bx = 6.5 + Double(i) * 8.0
        addBox(n, bx - 3.0, bx + 3.0, 2.0, 8.0, 1.6, 11.0, radius: 0.2, mat: matDarkSlate, name: "tact_\(i)")
        let capMat = (i == 3) ? matRecOrange : matCharcoal
        addBox(n, bx - 3.1, bx + 3.1, 2.2, 8.2, 11.0, 14.6, radius: 0.8, mat: capMat, name: "keycap_\(i)")
    }
    // 90 deg bent 1x5 header + 5P F-F ribbon exiting +Y edge
    addBox(n, 12.15, 24.85, 15.0, 35.0, 1.6, 7.2, radius: 0.6, mat: matCopperWire, name: "pad_5p_bent")
    cadPlace(n, ox: ox, oy: oy, oz: oz, rotZDeg: rotZDeg)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("keypad_opt2", makeAABB(origin: o, rotZDeg: rotZDeg, name: "pcb_switches", 0, 37.0, 0, 15.0, -1.5, 11.0)),
        ("keypad_opt2", makeAABB(origin: o, rotZDeg: rotZDeg, name: "5p_bent_cable", 12.15, 24.85, 15.0, 35.0, 1.6, 7.2))
    ])
}

func buildPart05MicroSD(ox: Double, oy: Double, oz: Double, rotZDeg: Int = 0) -> BuiltComponent {
    // 42.0 x 24.0 mm, -1.5..5.0 mm Z; push-pull TF cage on X = 0..-2 edge
    let n = SCNNode(); n.name = "part05_microsd"
    addBox(n, 0, 42.0, 0, 24.0, 0, 1.6, radius: 0.3, mat: matPCBBlue, name: "sd_pcb")
    addBox(n, -0.5, 15.5, 4.5, 19.5, 1.6, 5.0, radius: 0.2, mat: matSteel, name: "sd_cage")
    addBox(n, -2.5, 8.0, 6.5, 17.5, 2.1, 3.1, radius: 0.1, mat: matRecOrange, name: "sd_card")
    addBox(n, 36.0, 41.0, 4.0, 20.0, -1.5, 0.0, mat: matDarkSlate, name: "sd_hdr_pins")
    cadPlace(n, ox: ox, oy: oy, oz: oz, rotZDeg: rotZDeg)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("microsd", makeAABB(origin: o, rotZDeg: rotZDeg, name: "pcb_cage", 0, 42.0, 0, 24.0, -1.5, 5.0))
    ])
}

func buildPart07BatteryV3(ox: Double, oy: Double, oz: Double, rotZDeg: Int = 0) -> BuiltComponent {
    // 99.5 x 29.2 mm, -1.4..20.75 mm (22.15 mm total Z). USB-A at X=0..14, Micro-USB at X=93.5..99.5
    let n = SCNNode(); n.name = "part07_18650_v3"
    addBox(n, 0, 99.5, 0, 29.2, 0, 1.6, radius: 0.4, mat: matPCBBlack, name: "v3_pcb")
    addBox(n, 16.0, 92.0, 3.6, 25.6, -1.4, 0.0, mat: matDarkSlate, name: "v3_tails")
    // 18650 cradle & purple 3500 mAh cell
    addBox(n, 16.0, 92.5, 3.6, 25.6, 1.6, 4.5, mat: matCharcoal, name: "v3_cradle")
    addCyl(n, cx: 54.0, cy: 14.6, cz: 11.6, d: 18.3, h: 65.0, axis: .x, mat: matPurple18650, name: "cell_18650")
    // USB-A 5V out (X=0..14) + power rocker
    addBox(n, -1.0, 14.0, 7.6, 21.6, 1.6, 8.6, radius: 0.2, mat: matSteel, name: "v3_usba")
    addBox(n, 63.0, 70.0, 9.0, 14.0, 1.6, 5.2, mat: matRecOrange, name: "v3_sw")
    cadPlace(n, ox: ox, oy: oy, oz: oz, rotZDeg: rotZDeg)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("battery_v3", makeAABB(origin: o, rotZDeg: rotZDeg, name: "pcb_cell", 0, 99.5, 0, 29.2, -1.4, 20.75))
    ])
}

// ----------------------------------------------------------------------------
// 5. Verified Options A & B Complete Assemblies + Industrial Enclosures
// ----------------------------------------------------------------------------
func buildOptionAAssembly(xray: Bool = false) -> (SCNNode, Int) {
    // 106.0 x 132.0 mm. Lower grip Z=0..32.0 (Y=0..98.0), Upper Audio Ridge Z=0..40.5 (Y=98.0..132.0)
    let root = SCNNode(); root.name = "option_a_0spk"
    var boxes: [(String, AABB)] = []

    let v3 = buildPart07BatteryV3(ox: 3.5, oy: 2.5, oz: 3.8, rotZDeg: 0)
    let esp = buildPart01ESP32(ox: 3.5, oy: 65.7, oz: 27.3, rotZDeg: 0, includeKeepout: xray)
    let wm = buildPart02WM8960(ox: 20.5, oy: 99.5, oz: 30.5, rotZDeg: 0, matedJ1: false, includeKeepout: xray)
    let ky = buildPart03KY023(ox: 4.0, oy: 39.2, oz: 8.4, rotZDeg: 0)
    let pad = buildPart04KeypadOpt2(ox: 63.0, oy: 43.0, oz: 19.0, rotZDeg: 0)
    let sd = buildPart05MicroSD(ox: 104.0, oy: 92.0, oz: 5.0, rotZDeg: 180)

    for c in [v3, esp, wm, ky, pad, sd] {
        root.addChildNode(c.node)
        boxes.append(contentsOf: c.aabbs)
    }

    // Main wire trunk & trunk AABB
    addBox(root, 8.0, 98.0, 32.2, 38.7, 3.0, 17.0, radius: 1.5, mat: matCopperWire, name: "wire_trunk")
    boxes.append(("wire_trunk", AABB(name: "trunk", minX: 8.0, maxX: 98.0, minY: 32.2, maxY: 38.7, minZ: 3.0, maxZ: 17.0)))

    // Shell boundary cavity checks (outer back wall Z=0..2.0, left 0..2, right 104..106)
    boxes.append(("shell", AABB(name: "back_wall", minX: 0, maxX: 106.0, minY: 0, maxY: 132.0, minZ: 0.0, maxZ: 2.0)))
    boxes.append(("shell", AABB(name: "left_wall", minX: 0, maxX: 2.0, minY: 0, maxY: 132.0, minZ: 0.0, maxZ: 32.0)))
    boxes.append(("shell", AABB(name: "right_wall", minX: 104.0, maxX: 106.0, minY: 0, maxY: 132.0, minZ: 0.0, maxZ: 32.0)))
    // Check ridge front ceiling over WM8960 (Y=98..132, Z=38.5..40.5)
    boxes.append(("shell", AABB(name: "ridge_roof", minX: 0, maxX: 106.0, minY: 98.0, maxY: 132.0, minZ: 38.5, maxZ: 40.5)))

    let collisions = verifyAABBs(label: "Option A (0-Speaker 106x132x32/40.5)", boxes: boxes)

    // Exterior Sculpted Case Shell
    let lowerRear = xray ? matSmokedShell : matCharcoal
    let lowerFront = xray ? matSmokedTop : matStoneGray
    let topRidgeMat = xray ? matSmokedTop : matStoneStep

    // Lower Grip Body (0..106, 0..98, 0..32) — back dark charcoal, front warm stone-gray
    addBox(root, 0, 106.0, 0, 98.0, 0.0, 15.8, radius: 3.8, mat: lowerRear, name: "shell_a_back")
    addBox(root, 0, 106.0, 0, 98.0, 16.2, 32.0, radius: 3.6, mat: lowerFront, name: "shell_a_front")
    addBox(root, 0.5, 105.5, 0.5, 97.5, 15.6, 16.4, radius: 3.4, mat: matDarkSlate, name: "shell_a_seam")

    // Stepped Top Audio Camera-Bar Ridge (0..106, 98..132, 0..40.5) — smooth step ramp at Y=96..99
    addBox(root, 0, 106.0, 98.0, 132.0, 0.0, 15.8, radius: 3.8, mat: lowerRear, name: "ridge_a_back")
    addBox(root, 0, 106.0, 98.0, 132.0, 16.2, 40.5, radius: 3.6, mat: topRidgeMat, name: "ridge_a_front")

    // Front Surface Details on Option A (zero speaker grilles!)
    // Black flushed bezel & active 1.9" IPS lens slightly proud at Z=31.9..32.3
    addBox(root, 12.0, 68.5, 67.2, 94.8, 31.4, 32.15, radius: 1.4, mat: matBezelBlack, name: "screen_a_bezel")
    addBox(root, 16.5, 59.22, 70.1, 92.80, 31.9, 32.28, radius: 0.4, mat: matScreenActive, name: "screen_a_face")
    // KY-023 thumbstick recessed bezel ring + protruding mushroom cap
    addCyl(root, cx: 19.0, cy: 52.2, cz: 31.8, d: 21.0, h: 1.0, axis: .z, mat: matDarkSlate, name: "stick_well_a")
    addCyl(root, cx: 19.0, cy: 52.2, cz: 33.8, d: 4.8, h: 4.5, axis: .z, mat: matCharcoal, name: "stick_stem_a")
    addCyl(root, cx: 19.0, cy: 52.2, cz: 36.8, d: 18.0, h: 4.2, axis: .z, mat: matDarkSlate, name: "stick_cap_a")
    // 4x Tactile Keycaps on Lower-Right (X: 69.5 + i*8)
    for i in 0..<4 {
        let bx = 69.5 + Double(i) * 8.0
        let cMat = (i == 3) ? matRecOrange : matCharcoal
        addBox(root, bx - 3.2, bx + 3.2, 45.0, 51.4, 31.6, 33.8, radius: 0.9, mat: cMat, name: "btn_a_\(i)")
    }
    // Twin pill MEMS mic slots on Top Audio Ridge front face (Z = 40.4..40.7)
    addBox(root, 24.5, 31.5, 104.0, 107.0, 40.1, 40.7, radius: 1.2, mat: matMeshDark, name: "mic_slot_l_a")
    addBox(root, 75.5, 82.5, 121.5, 124.5, 40.1, 40.7, radius: 1.2, mat: matMeshDark, name: "mic_slot_r_a")
    // Top Edge 3.5mm Headphone TRS Jack Bezel (wm ox=20.5 + 16.25 = 36.75)
    addCyl(root, cx: 36.75, cy: 132.1, cz: 34.6, d: 7.4, h: 1.2, axis: .y, mat: matSteel, name: "trs_top_a")
    addCyl(root, cx: 36.75, cy: 132.3, cz: 34.6, d: 3.6, h: 1.4, axis: .y, mat: matBezelBlack, name: "trs_hole_a")
    // Side detail accents (USB-C left X=0, MicroSD slot right X=106, V3 switch)
    addBox(root, -0.3, 0.4, 76.5, 86.5, 28.0, 31.0, radius: 0.8, mat: matDarkSlate, name: "usbc_slot_a")
    addBox(root, 105.6, 106.3, 74.0, 86.5, 6.2, 8.6, radius: 0.4, mat: matDarkSlate, name: "sd_slot_a")

    return (root, collisions)
}

func buildOptionBAssembly(xray: Bool = false) -> (SCNNode, Int) {
    // 119.0 x 134.0 mm. Lower grip Z=0..32.0 (Y=0..100.0), Upper Audio Ridge Z=0..48.5 (Y=100.0..134.0)
    let root = SCNNode(); root.name = "option_b_1spk"
    var boxes: [(String, AABB)] = []

    // Right-Edge Vertical Spine 18650 Bay (-90 deg)
    let v3 = buildPart07BatteryV3(ox: 87.5, oy: 130.5, oz: 3.8, rotZDeg: -90)
    let sd = buildPart05MicroSD(ox: 2.0, oy: 6.0, oz: 4.0, rotZDeg: 0)
    let spk = buildPart02bSpeaker(ox: 5.0, oy: 4.0, oz: 11.5, rotZDeg: 0)
    let ky = buildPart03KY023(ox: 4.0, oy: 41.0, oz: 8.4, rotZDeg: 0)
    let pad = buildPart04KeypadOpt2(ox: 49.0, oy: 45.0, oz: 19.0, rotZDeg: 0)
    let esp = buildPart01ESP32(ox: 3.5, oy: 67.5, oz: 27.3, rotZDeg: 0, includeKeepout: xray)
    let wm = buildPart02WM8960(ox: 13.0, oy: 101.0, oz: 30.5, rotZDeg: 0, matedJ1: true, includeKeepout: xray)

    for c in [v3, sd, spk, ky, pad, esp, wm] {
        root.addChildNode(c.node)
        boxes.append(contentsOf: c.aabbs)
    }

    addBox(root, 8.0, 82.0, 34.5, 40.5, 4.0, 18.0, radius: 1.5, mat: matCopperWire, name: "wire_trunk_b")
    boxes.append(("wire_trunk", AABB(name: "trunk", minX: 8.0, maxX: 82.0, minY: 34.5, maxY: 40.5, minZ: 4.0, maxZ: 18.0)))

    // Outer shell boundary keepouts
    boxes.append(("shell", AABB(name: "back_wall", minX: 0, maxX: 119.0, minY: 0, maxY: 134.0, minZ: 0.0, maxZ: 2.0)))
    boxes.append(("shell", AABB(name: "left_wall", minX: 0, maxX: 2.0, minY: 0, maxY: 134.0, minZ: 0.0, maxZ: 32.0)))
    boxes.append(("shell", AABB(name: "right_wall", minX: 117.0, maxX: 119.0, minY: 0, maxY: 134.0, minZ: 0.0, maxZ: 32.0)))
    boxes.append(("shell", AABB(name: "ridge_roof", minX: 0, maxX: 119.0, minY: 100.0, maxY: 134.0, minZ: 46.5, maxZ: 48.5)))

    let collisions = verifyAABBs(label: "Option B (1-Speaker 119x134x32/48.5)", boxes: boxes)

    // Exterior Sculpted Case Shell
    let lowerRear = xray ? matSmokedShell : matCharcoal
    let lowerFront = xray ? matSmokedTop : matStoneGray
    let topRidgeMat = xray ? matSmokedTop : matStoneStep

    // Lower Grip Body (0..119, 0..100, 0..32)
    addBox(root, 0, 119.0, 0, 100.0, 0.0, 15.8, radius: 3.8, mat: lowerRear, name: "shell_b_back")
    addBox(root, 0, 119.0, 0, 100.0, 16.2, 32.0, radius: 3.6, mat: lowerFront, name: "shell_b_front")
    addBox(root, 0.5, 118.5, 0.5, 99.5, 15.6, 16.4, radius: 3.4, mat: matDarkSlate, name: "shell_b_seam")

    // Stepped Top Audio Camera-Bar Ridge (0..119, 100..134, 0..48.5)
    addBox(root, 0, 119.0, 100.0, 134.0, 0.0, 15.8, radius: 3.8, mat: lowerRear, name: "ridge_b_back")
    addBox(root, 0, 119.0, 100.0, 134.0, 16.2, 48.5, radius: 3.6, mat: topRidgeMat, name: "ridge_b_front")

    if !xray {
        // Active 1.9" IPS Display on Upper-Left Chest
        addBox(root, 12.0, 68.5, 69.0, 96.6, 31.4, 32.15, radius: 1.4, mat: matBezelBlack, name: "screen_b_bezel")
        addBox(root, 16.5, 59.22, 71.9, 94.60, 31.9, 32.28, radius: 0.4, mat: matScreenActive, name: "screen_b_face")
        // KY-023 Thumbstick
        addCyl(root, cx: 19.0, cy: 54.0, cz: 31.8, d: 21.0, h: 1.0, axis: .z, mat: matDarkSlate, name: "stick_well_b")
        addCyl(root, cx: 19.0, cy: 54.0, cz: 33.8, d: 4.8, h: 4.5, axis: .z, mat: matCharcoal, name: "stick_stem_b")
        addCyl(root, cx: 19.0, cy: 54.0, cz: 36.8, d: 18.0, h: 4.2, axis: .z, mat: matDarkSlate, name: "stick_cap_b")
        // 4x Tactile Keycaps right of thumbstick
        for i in 0..<4 {
            let bx = 55.5 + Double(i) * 8.0
            let cMat = (i == 3) ? matRecOrange : matCharcoal
            addBox(root, bx - 3.2, bx + 3.2, 47.0, 53.4, 31.6, 33.8, radius: 0.9, mat: cMat, name: "btn_b_\(i)")
        }
        // SINGLE Lower-Left 3070 Speaker Grille (slotted precision louver pattern)
        addBox(root, 9.5, 71.0, 7.0, 31.0, 31.5, 32.12, radius: 2.0, mat: matDarkSlate, name: "spk_grille_frame_b")
        for s in 0..<11 {
            let sx = 12.5 + Double(s) * 5.2
            addBox(root, sx, sx + 2.8, 9.5, 28.5, 31.8, 32.25, radius: 1.0, mat: matMeshDark, name: "spk_slot_\(s)")
        }
        // Right grip subtle textured tactile indicator rib over internal 18650 spine
        addBox(root, 92.0, 113.0, 10.0, 92.0, 31.8, 32.18, radius: 2.5, mat: matStoneStep, name: "right_grip_pad_b")
    } else {
        // Light X-Ray ghosted bezel + thumbstick + keycaps so alignment reads immediately
        addBox(root, 16.5, 59.22, 71.9, 94.60, 31.8, 32.25, radius: 0.4, mat: matScreenActive, name: "screen_bx")
        addCyl(root, cx: 19.0, cy: 54.0, cz: 36.8, d: 18.0, h: 4.2, axis: .z, mat: matDarkSlate, name: "stick_cap_bx")
        for i in 0..<4 {
            let bx = 55.5 + Double(i) * 8.0
            addBox(root, bx - 3.2, bx + 3.2, 47.0, 53.4, 31.6, 33.8, radius: 0.9, mat: (i == 3) ? matRecOrange : matCharcoal, name: "btn_bx_\(i)")
        }
    }

    // Twin MEMS mic slots on 48.5 mm Top Audio Bar + Top 3.5 mm TRS jack (ox=13 + 16.25 = 29.25)
    addBox(root, 17.5, 24.5, 106.0, 109.0, 48.1, 48.7, radius: 1.2, mat: matMeshDark, name: "mic_slot_l_b")
    addBox(root, 68.5, 75.5, 123.5, 126.5, 48.1, 48.7, radius: 1.2, mat: matMeshDark, name: "mic_slot_r_b")
    addCyl(root, cx: 29.25, cy: 134.1, cz: 34.6, d: 7.4, h: 1.2, axis: .y, mat: matSteel, name: "trs_top_b")
    addCyl(root, cx: 29.25, cy: 134.3, cz: 34.6, d: 3.6, h: 1.4, axis: .y, mat: matBezelBlack, name: "trs_hole_b")
    // Left Edge MicroSD Slot (X=0, Y=12..24) + USB-C (Y=78..88)
    addBox(root, -0.3, 0.4, 12.0, 24.5, 5.5, 7.8, radius: 0.4, mat: matDarkSlate, name: "sd_slot_b")
    addBox(root, -0.3, 0.4, 78.5, 88.5, 28.0, 31.0, radius: 0.8, mat: matDarkSlate, name: "usbc_slot_b")

    return (root, collisions)
}

func buildBaseline2SpkShell() -> SCNNode {
    // Verified Baseline 156.0 x 112.0 x 49.0 mm 2-speaker brick for comparison
    let n = SCNNode(); n.name = "baseline_2spk"
    addBox(n, 0, 156.0, 0, 112.0, 0.0, 24.0, radius: 4.5, mat: matCharcoal, name: "base_back")
    addBox(n, 0, 156.0, 0, 112.0, 24.5, 49.0, radius: 4.2, mat: matStoneGray, name: "base_front")
    addBox(n, 0.5, 155.5, 0.5, 111.5, 23.8, 24.7, radius: 4.0, mat: matDarkSlate, name: "base_seam")
    // Two 3070 bottom speaker grilles + centered upper 1.9" IPS + thumbstick & buttons
    for s in 0..<10 {
        let sxL = 10.0 + Double(s) * 5.6
        addBox(n, sxL, sxL + 3.0, 9.0, 30.0, 48.7, 49.25, radius: 1.0, mat: matMeshDark, name: "spk_l_\(s)")
        let sxR = 88.0 + Double(s) * 5.6
        addBox(n, sxR, sxR + 3.0, 9.0, 30.0, 48.7, 49.25, radius: 1.0, mat: matMeshDark, name: "spk_r_\(s)")
    }
    addBox(n, 45.0, 102.0, 68.0, 98.0, 48.4, 49.15, radius: 1.4, mat: matBezelBlack, name: "base_bezel")
    addBox(n, 50.0, 92.72, 71.5, 94.20, 48.9, 49.28, radius: 0.4, mat: matScreenActive, name: "base_lcd")
    addCyl(n, cx: 22.0, cy: 52.0, cz: 48.8, d: 21.0, h: 1.0, axis: .z, mat: matDarkSlate, name: "base_well")
    addCyl(n, cx: 22.0, cy: 52.0, cz: 53.0, d: 18.0, h: 4.2, axis: .z, mat: matDarkSlate, name: "base_cap")
    for i in 0..<4 {
        let bx = 112.0 + Double(i) * 9.0
        addBox(n, bx - 3.2, bx + 3.2, 46.0, 52.4, 48.6, 50.8, radius: 0.9, mat: (i == 3) ? matRecOrange : matCharcoal, name: "base_btn_\(i)")
    }
    return n
}

// ----------------------------------------------------------------------------
// 6. Calibrated 1:1 Everyday Scale Props
// ----------------------------------------------------------------------------
func buildIPhone61() -> SCNNode {
    // 71.5 x 146.7 x 7.8 mm
    let n = SCNNode(); n.name = "prop_iphone_61"
    addBox(n, 0, 71.5, 0, 146.7, 0.0, 7.8, radius: 3.9, mat: matDarkSlate, name: "phone_body")
    addBox(n, 1.5, 70.0, 1.5, 145.2, 7.5, 7.9, radius: 3.4, mat: matPhoneScreen, name: "phone_screen")
    addBox(n, 25.0, 46.5, 138.0, 142.0, 7.82, 7.95, radius: 1.8, mat: matBezelBlack, name: "phone_island")
    return n
}

func buildCreditCard() -> SCNNode {
    // ISO ID-1: 85.60 x 53.98 x 0.76 mm
    let n = SCNNode(); n.name = "prop_credit_card"
    addBox(n, 0, 85.60, 0, 53.98, 0, 0.76, radius: 3.0, mat: matCardWhite, name: "card_body")
    addBox(n, 0, 85.60, 34.0, 44.0, 0.72, 0.79, mat: matCardStripe, name: "card_band")
    addBox(n, 11.0, 23.0, 22.0, 31.0, 0.72, 0.82, radius: 1.0, mat: matGold, name: "card_chip")
    return n
}

func buildAirPodsProCase() -> SCNNode {
    // 60.6 x 45.2 x 21.7 mm
    let n = SCNNode(); n.name = "prop_airpods_pro"
    addBox(n, 0, 60.6, 0, 45.2, 0, 21.7, radius: 8.5, mat: matAirPodsWhite, name: "ap_case")
    addBox(n, 0.4, 60.2, 29.0, 29.8, 0.4, 21.3, mat: matCharcoal, name: "ap_lid_seam")
    return n
}

func buildLoose18650() -> SCNNode {
    // 18.3 mm dia x 65.0 mm
    let n = SCNNode(); n.name = "prop_loose_18650"
    addCyl(n, cx: 32.5, cy: 9.15, cz: 9.15, d: 18.3, h: 65.0, axis: .x, mat: matPurple18650, name: "cell")
    addCyl(n, cx: 0.4, cy: 9.15, cz: 9.15, d: 15.0, h: 0.8, axis: .x, mat: matSteel, name: "neg_cap")
    addCyl(n, cx: 64.6, cy: 9.15, cz: 9.15, d: 10.5, h: 1.0, axis: .x, mat: matSteel, name: "pos_cap")
    return n
}

func buildSteelRuler160() -> SCNNode {
    // 160 x 18 x 1.2 mm brushed steel architectural scale ruler
    let n = SCNNode(); n.name = "prop_ruler_160mm"
    addBox(n, 0, 160.0, 0, 18.0, 0, 1.2, radius: 0.2, mat: matBrushedAl, name: "ruler_bar")
    for mm in stride(from: 0, through: 150, by: 2) {
        let major = (mm % 10 == 0)
        let hTick = major ? 6.0 : 3.2
        addBox(n, Double(mm) + 4.8, Double(mm) + 5.15, 18.0 - hTick, 18.0, 1.18, 1.28, mat: matDarkSlate, name: "tick_\(mm)")
    }
    return n
}

func buildLooseMicroSD() -> SCNNode {
    let n = SCNNode(); n.name = "prop_loose_microsd"
    addBox(n, 0, 11.0, 0, 15.0, 0, 1.0, radius: 0.3, mat: matCharcoal, name: "sd_chip")
    addBox(n, 1.0, 10.0, 1.0, 5.5, 0.95, 1.05, mat: matRecOrange, name: "sd_stripe")
    return n
}

func buildQuarter() -> SCNNode {
    let n = SCNNode(); n.name = "prop_quarter"
    addCyl(n, cx: 12.13, cy: 12.13, cz: 0.88, d: 24.26, h: 1.75, axis: .z, mat: matSteel, name: "coin")
    return n
}

// ----------------------------------------------------------------------------
// 7. Metal SCNRenderer Helpers & Cutting Mat Floor
// ----------------------------------------------------------------------------
let metalDevice = MTLCreateSystemDefaultDevice()!
let renderer = SCNRenderer(device: metalDevice, options: nil)

func setupStudioLighting(_ scene: SCNScene, ortho: Bool = false) {
    let key = SCNNode(); key.light = SCNLight(); key.light!.type = .directional
    key.light!.intensity = ortho ? 950 : 1200
    key.light!.color = NSColor(srgbRed: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
    key.light!.castsShadow = !ortho
    key.light!.shadowRadius = 6.0; key.light!.shadowSampleCount = 16
    key.position = SCNVector3(240, 420, 260)
    key.look(at: SCNVector3(0, 0, 0))
    scene.rootNode.addChildNode(key)

    let fill = SCNNode(); fill.light = SCNLight(); fill.light!.type = .directional
    fill.light!.intensity = ortho ? 520 : 480
    fill.light!.color = NSColor(srgbRed: 0.88, green: 0.93, blue: 1.0, alpha: 1.0)
    fill.position = SCNVector3(-280, 220, -180)
    fill.look(at: SCNVector3(0, 0, 0))
    scene.rootNode.addChildNode(fill)

    let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient
    amb.light!.intensity = ortho ? 480 : 320
    scene.rootNode.addChildNode(amb)
}

func makeCuttingMatTexture(widthMM: Double, heightMM: Double, bg: NSColor, minorCol: NSColor, majorCol: NSColor) -> NSImage {
    let pxPerMM = 5.0
    let w = Int(widthMM * pxPerMM), h = Int(heightMM * pxPerMM)
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    bg.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: w, height: h)).fill()
    for mm in stride(from: 0, through: Int(widthMM), by: 10) {
        let isMajor = (mm % 50 == 0)
        (isMajor ? majorCol : minorCol).setStroke()
        let p = NSBezierPath()
        p.lineWidth = isMajor ? 1.8 : 0.8
        let x = CGFloat(Double(mm) * pxPerMM)
        p.move(to: NSPoint(x: x, y: 0)); p.line(to: NSPoint(x: x, y: CGFloat(h)))
        p.stroke()
    }
    for mm in stride(from: 0, through: Int(heightMM), by: 10) {
        let isMajor = (mm % 50 == 0)
        (isMajor ? majorCol : minorCol).setStroke()
        let p = NSBezierPath()
        p.lineWidth = isMajor ? 1.8 : 0.8
        let y = CGFloat(Double(mm) * pxPerMM)
        p.move(to: NSPoint(x: 0, y: y)); p.line(to: NSPoint(x: CGFloat(w), y: y))
        p.stroke()
    }
    img.unlockFocus()
    return img
}

func renderSceneToImage(_ scene: SCNScene, camNode: SCNNode, width: Int, height: Int, antialiasing: SCNAntialiasingMode = .multisampling4X) -> NSImage {
    renderer.scene = scene
    renderer.pointOfView = camNode
    return renderer.snapshot(atTime: 0, with: CGSize(width: width, height: height), antialiasingMode: antialiasing)
}

func savePNG(_ image: NSImage, fileName: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    let p1 = "\(renderDir)/\(fileName)"
    let p2 = "\(artifactDir)/\(fileName)"
    try? png.write(to: URL(fileURLWithPath: p1))
    try? png.write(to: URL(fileURLWithPath: p2))
    print("💾 Saved \(fileName) (\(Int(image.size.width))x\(Int(image.size.height))) -> renders/ + artifactDir/")
}

func exportUSDZ(_ root: SCNNode, fileName: String) {
    let wrapper = SCNNode()
    let clone = root.clone()
    clone.scale = SCNVector3(0.001, 0.001, 0.001)
    wrapper.addChildNode(clone)
    let scene = SCNScene()
    scene.rootNode.addChildNode(wrapper)
    let url = URL(fileURLWithPath: "\(usdzDir)/\(fileName)")
    scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
    print("📦 Exported \(fileName) -> \(url.path)")
}

// ----------------------------------------------------------------------------
// 8. Build Standalone Models, Run AABB Audits, and Export USDZ
// ----------------------------------------------------------------------------
let (optA, colA) = buildOptionAAssembly(xray: false)
let (optB, colB) = buildOptionBAssembly(xray: false)
let (optBXray, _) = buildOptionBAssembly(xray: true)
if colA > 0 || colB > 0 {
    print("❌ ABORTING: Detected mechanical AABB collision (colA=\(colA), colB=\(colB)).")
    exit(2)
}

exportUSDZ(optA, fileName: "10a_slim_0speaker_pocket_walkman.usdz")
exportUSDZ(optB, fileName: "10b_slim_1speaker_field_recorder.usdz")

// ----------------------------------------------------------------------------
// 9. Scene 1: Calibrated 1:1 Ortho Engineering Comparison Sheet (2200 x 1400)
// ----------------------------------------------------------------------------
func renderOrthoSheet() {
    let w = 2200, h = 1400
    let scene = SCNScene()
    scene.background.contents = NSColor(srgbRed: 0.965, green: 0.968, blue: 0.972, alpha: 1.0)
    setupStudioLighting(scene, ortho: true)

    // Sheet spans CAD X in [-320..+320] (640 mm wide), halfHeight = 640 / (2200/1400) / 2 = 203.64 mm
    let halfH = 320.0 * Double(h) / Double(w) // 203.636 mm -> Y spans [-203.6 .. +203.6]

    // Drafting sheet background plane behind models (at Z = -30)
    let sheetMat = SCNMaterial()
    sheetMat.lightingModel = .constant
    sheetMat.diffuse.contents = makeCuttingMatTexture(
        widthMM: 640, heightMM: halfH * 2.0,
        bg: NSColor(srgbRed: 0.975, green: 0.977, blue: 0.980, alpha: 1.0),
        minorCol: NSColor(srgbRed: 0.89, green: 0.91, blue: 0.93, alpha: 1.0),
        majorCol: NSColor(srgbRed: 0.78, green: 0.81, blue: 0.85, alpha: 1.0)
    )
    addBox(scene.rootNode, -320, 320, -halfH, halfH, -31.0, -30.0, mat: sheetMat, name: "draft_grid")

    // X column centers across [-320..+320] so all 5 widths (106, 119, 156, 71.5, 85.6) breathe
    let items: [(String, String, SCNNode, Double, Double)] = [
        ("OPTION A: 0-SPEAKER", "106 × 132 × 32 mm (40.5 bar)", optA.clone(), 106.0, -242.0),
        ("OPTION B: 1-SPEAKER", "119 × 134 × 32 mm (48.5 bar)", optB.clone(), 119.0, -108.0),
        ("BASELINE: 2-SPEAKER", "156 × 112 × 49 mm", buildBaseline2SpkShell(), 156.0, 50.0),
        ("6.1\" SMARTPHONE", "71.5 × 146.7 × 7.8 mm", buildIPhone61(), 71.5, 184.0),
        ("ISO CREDIT CARD", "85.6 × 53.98 × 0.76 mm", buildCreditCard(), 85.6, 276.0)
    ]

    for (_, _, node, width, cx) in items {
        // Row 1: Front View (model's +Z facing camera at +Y_scn, sitting on baseline Y = +16 mm)
        let f = node.clone()
        f.position = SCNVector3(cx - width * 0.5, 0, -16.0) // cadY=16..16+H
        scene.rootNode.addChildNode(f)

        // Row 2: Side Thickness Profile directly below (rotate +90° around cadY / SceneKit -Z?
        // In SceneKit, rotating around vertical axis cadY (scnZ) by -90° makes +Z_thickness point RIGHT (+X_scn)!
        // Let's map so back (Z=0) is at x_left, front (Z=T) extends RIGHT (+X): rotate around Z_scn = -pi/2? Wait:
        // Around Z_scn (= -cadY): right-hand rotation by -pi/2 maps +Y_scn (Thickness) -> +X_scn (Right)!
        let s = node.clone()
        s.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        // At eulerAngles.z = -pi/2: local (x_scn, y_scn, z_scn) -> (+y_scn, -x_scn, z_scn)
        // So local width X maps downward in Height? NO! Remember we want Height along -Z_scn (Up on top-down camera)
        // and Thickness (+Y_scn) along +X_scn (Right)! That's already untouched Z_scn!
        // Only issue is Height (-x_scn) would push depth downward (-Y_scn), keeping same screen plane if x in [0..W]!
        // Actually in top-down ortho camera looking down -Y_scn: screen X = scnX, screen Y = -scnZ (= cadY)!
        // So rotating around `scnZ` (screen Y!) spins Thickness (+Y_scn) directly onto Screen X (`+scnX`) cleanly!
        // At `eulerAngles.z = -pi/2`: world_Y = -local_X, so set `pos.y = 0` keeps everything in ortho clip, `world_X = local_Y (0..49)!`
        s.position = SCNVector3(cx - 20.0, 20.0, 178.0) // cadY = -178 .. -178+H! Wait: top half cadY=+16..+163, bottom half cadY=-176..-29!
        scene.rootNode.addChildNode(s)
    }

    // Ortho top-down camera looking along -Y_scn (looking directly at CAD X-Y plane, with +Z toward lens)
    let camNode = SCNNode()
    camNode.camera = SCNCamera()
    camNode.camera!.usesOrthographicProjection = true
    camNode.camera!.orthographicScale = halfH
    camNode.camera!.zNear = 1.0
    camNode.camera!.zFar = 1000.0
    camNode.position = SCNVector3(0, 420, 0)
    camNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0) // looks down -Y_scn, +X right, -Z_scn up (+cadY up!)
    scene.rootNode.addChildNode(camNode)

    let rawImg = renderSceneToImage(scene, camNode: camNode, width: w, height: h)

    // Overlay crisp non-overlapping engineering callouts in margin bands via Cocoa drawing
    let annotated = NSImage(size: NSSize(width: w, height: h))
    annotated.lockFocus()
    rawImg.draw(in: NSRect(x: 0, y: 0, width: w, height: h))

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .bold),
        .foregroundColor: NSColor(srgbRed: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
    ]
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .medium),
        .foregroundColor: NSColor(srgbRed: 0.32, green: 0.35, blue: 0.40, alpha: 1.0)
    ]
    let badgeAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 20, weight: .bold),
        .foregroundColor: NSColor(srgbRed: 0.90, green: 0.30, blue: 0.06, alpha: 1.0)
    ]

    NSString("1:1 ORTHOGRAPHIC ENCLOSURE COMPARISON — SLIM POCKETABLE VARIANTS vs BASELINE & REFERENCE PROPS")
        .draw(at: NSPoint(x: 42, y: CGFloat(h) - 48), withAttributes: titleAttrs)
    NSString("Uniform Scale (10 mm Grid)  •  Zero Internal Collisions Verified  •  Option-2 90° Bent Keypad (32.0 mm Grip)")
        .draw(at: NSPoint(x: 42, y: CGFloat(h) - 76), withAttributes: subAttrs)

    NSString("FRONT ELEVATION")
        .draw(at: NSPoint(x: 42, y: CGFloat(h) - 116), withAttributes: badgeAttrs)
    NSString("SIDE THICKNESS PROFILE (Z-DEPTH)")
        .draw(at: NSPoint(x: 42, y: 615), withAttributes: badgeAttrs)

    // Map CAD X [-320..+320] to pixel X [0..w]
    let pxPerMM = Double(w) / 640.0
    for (title, spec, _, _, cx) in items {
        let pxX = (cx + 320.0) * pxPerMM
        let tSize = NSString(string: title).size(withAttributes: badgeAttrs)
        let sSize = NSString(string: spec).size(withAttributes: subAttrs)
        // Label strictly in clean band between Front row (cadY=+16 -> py=755) and Side row
        NSString(string: title).draw(at: NSPoint(x: pxX - Double(tSize.width) * 0.5, y: 690), withAttributes: badgeAttrs)
        NSString(string: spec).draw(at: NSPoint(x: pxX - Double(sSize.width) * 0.5, y: 662), withAttributes: subAttrs)
        NSString(string: spec).draw(at: NSPoint(x: pxX - Double(sSize.width) * 0.5, y: 28), withAttributes: subAttrs)
    }

    annotated.unlockFocus()
    savePNG(annotated, fileName: "ref_10_slim_options_ortho_comparison.png")
}

// ----------------------------------------------------------------------------
// 10. Scenes 2 & 3: Studio Knolling Guide (10a) + Low-Angle Thickness Hero (10b)
// ----------------------------------------------------------------------------
func buildStudioScene() -> (SCNScene, SCNNode, SCNNode) {
    let scene = SCNScene()
    scene.background.contents = NSColor(srgbRed: 0.90, green: 0.905, blue: 0.91, alpha: 1.0)
    setupStudioLighting(scene, ortho: false)

    // Dark Slate Studio Cutting Mat (640 x 360 mm, 10 mm Teal-Gray Grid)
    let matTex = SCNMaterial()
    matTex.lightingModel = .physicallyBased
    matTex.roughness.contents = 0.85
    matTex.metalness.contents = 0.02
    matTex.diffuse.contents = makeCuttingMatTexture(
        widthMM: 640, heightMM: 360,
        bg: NSColor(srgbRed: 0.15, green: 0.17, blue: 0.19, alpha: 1.0),
        minorCol: NSColor(srgbRed: 0.22, green: 0.25, blue: 0.28, alpha: 1.0),
        majorCol: NSColor(srgbRed: 0.30, green: 0.35, blue: 0.40, alpha: 1.0)
    )
    addBox(scene.rootNode, -320, 320, -180, 180, -3.0, 0.0, mat: matTex, name: "cutting_mat")

    // Well-spaced top row (cadX cleanly separated: A=[-262..-156], B=[-126..-7], BX=[+24..+143], Phone=[+182..+253.5])
    let aNode = optA.clone()
    aNode.position = SCNVector3(-262, 0.0, -28.0) // cadY = -28..+104
    scene.rootNode.addChildNode(aNode)

    let bNode = optB.clone()
    bNode.position = SCNVector3(-126, 0.0, -29.0) // cadY = -29..+105
    scene.rootNode.addChildNode(bNode)

    // Smoked Charcoal X-Ray Option B elevated cleanly off mat (+18° pitched forward, -8° yawed left)
    let bxNode = optBXray.clone()
    bxNode.eulerAngles = SCNVector3(Float(-18.0 * .pi / 180.0), Float(-8.0 * .pi / 180.0), 0)
    bxNode.position = SCNVector3(24, 38.0, -20.0)
    scene.rootNode.addChildNode(bxNode)

    // Far Right: 6.1" iPhone (71.5 x 146.7 x 7.8 mm) — >= 38 mm clear of Smoked X-Ray!
    let phone = buildIPhone61()
    phone.position = SCNVector3(186, 0.0, -36.0)
    scene.rootNode.addChildNode(phone)

    // Centered Foreground 1:1 Props (tighter row gap cadY = -108..-54 so frame is cohesive)
    let ruler = buildSteelRuler160()
    ruler.position = SCNVector3(-232, 0.0, 96.0) // X=[-232..-72]
    scene.rootNode.addChildNode(ruler)

    let ap = buildAirPodsProCase()
    ap.position = SCNVector3(-42, 0.0, 100.0) // X=[-42..+18.6]
    scene.rootNode.addChildNode(ap)

    let card = buildCreditCard()
    card.position = SCNVector3(46, 0.0, 102.0) // X=[+46..+131.6]
    scene.rootNode.addChildNode(card)

    let cell = buildLoose18650()
    cell.position = SCNVector3(162, 0.0, 96.0) // X=[+162..+227]
    scene.rootNode.addChildNode(cell)

    let quarter = buildQuarter()
    quarter.position = SCNVector3(162, 0.0, 62.0)
    scene.rootNode.addChildNode(quarter)

    let sdChip = buildLooseMicroSD()
    sdChip.position = SCNVector3(204, 0.0, 66.0)
    scene.rootNode.addChildNode(sdChip)

    // Camera 10a: Elevated 3/4 Knolling Overview (52° down from top, tight cohesive framing)
    let camA = SCNNode(); camA.camera = SCNCamera()
    camA.camera!.fieldOfView = 35.0; camA.camera!.zNear = 1.0; camA.camera!.zFar = 2000.0
    camA.position = SCNVector3(-2, 540, 325)
    camA.look(at: SCNVector3(-2, 10, 14))
    scene.rootNode.addChildNode(camA)

    // Camera 10b: Low-Angle 18° Hero Thickness & Cutaway Shot (zero clipping on left ruler or right 18650!)
    let camB = SCNNode(); camB.camera = SCNCamera()
    camB.camera!.fieldOfView = 34.0; camB.camera!.zNear = 1.0; camB.camera!.zFar = 2000.0
    camB.position = SCNVector3(-4, 182, 545)
    camB.look(at: SCNVector3(-2, 22, 6))
    scene.rootNode.addChildNode(camB)

    // Also export complete comparative studio USDZ
    exportUSDZ(scene.rootNode, fileName: "10c_slim_comparison_studio_scene.usdz")
    return (scene, camA, camB)
}

renderOrthoSheet()
let (studioScene, cam10a, cam10b) = buildStudioScene()
savePNG(renderSceneToImage(studioScene, camNode: cam10a, width: 1920, height: 1080), fileName: "ref_10a_1to1_slim_knolling_guide.png")
savePNG(renderSceneToImage(studioScene, camNode: cam10b, width: 1920, height: 1080), fileName: "ref_10b_1to1_slim_thickness_guide.png")

print("🎉 DONE: Option A (0-Spk) & Option B (1-Spk) verified with 0 collisions, 3 USDZ + 3 PNG renders generated!")
