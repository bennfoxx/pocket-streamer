#!/usr/bin/env swift
// ============================================================================
// generate_1to1_pocket_slim.swift
// Pocket Streamer Hardware CAD — True Jeans-Pocket Light-Mod + Flat LiPo Editions:
//   - Option P1: 8-Button Walkman Edition     (76.0 x 118.0 x 17.5 mm grip / 22.2 bar, 169.8 cm^3)
//   - Option P2: Low-Pro Thumbstick + 4-Btn   (76.0 x 118.0 x 19.0 mm grip / 22.2 bar, 178.7 cm^3)
//   - Reference: Previous 0-Spk Zero-Solder   (106.0 x 132.0 x 32.0 / 40.5 mm, 478.4 cm^3)
// Swaps 18650 V3 shield -> 604060 Flat Protected LiPo (60x40x6.0 mm) + USB-C Boost (27x22x5.5 mm),
// uses zero-desolder Light Modding (90-deg bent headers + bare heat-shrunk female crimps,
// WM8960 90-deg pins behind 2x20 socket, hand-pulled KY-023 dome + 3D-printed concave Pocket Disc).
// ============================================================================

import Foundation
import SceneKit
import SceneKit.ModelIO
import Metal
import AppKit
import CoreGraphics

let baseDir = "/Users/benfox/Development/3D Design/Pocket Streamer Hardware CAD"
let usdzDir = "\(baseDir)/parts_1to1_3d/usdz"
let renderDir = "\(baseDir)/parts_1to1_3d/renders"
let artifactDir = "/Users/benfox/.gemini/antigravity/brain/d773b1b3-4405-4408-8ad7-b59f103e4218"

try? FileManager.default.createDirectory(atPath: usdzDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: renderDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: artifactDir, withIntermediateDirectories: true)

// ----------------------------------------------------------------------------
// 1. Coordinate & Pairwise AABB Verification (CAD X right, Y up, Z front)
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
// 2. Material Palette
// ----------------------------------------------------------------------------
func pbrMat(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0,
            roughness: CGFloat = 0.65, metalness: CGFloat = 0.05) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    m.roughness.contents = roughness
    m.metalness.contents = metalness
    if a < 0.99 {
        m.isDoubleSided = true
        m.transparencyMode = .aOne
    }
    return m
}

let matStoneGray   = pbrMat(0.84, 0.83, 0.80, roughness: 0.70, metalness: 0.03)
let matStoneStep   = pbrMat(0.79, 0.78, 0.75, roughness: 0.66, metalness: 0.05)
let matCharcoal    = pbrMat(0.18, 0.19, 0.21, roughness: 0.66, metalness: 0.08)
let matDarkSlate   = pbrMat(0.11, 0.12, 0.14, roughness: 0.56, metalness: 0.12)
let matRecOrange   = pbrMat(0.95, 0.34, 0.08, roughness: 0.44, metalness: 0.05)
let matBezelBlack  = pbrMat(0.05, 0.05, 0.06, roughness: 0.16, metalness: 0.08)
let matSmokedShell = pbrMat(0.14, 0.15, 0.17, 0.30, roughness: 0.34, metalness: 0.06)
let matSmokedTop   = pbrMat(0.45, 0.45, 0.43, 0.34, roughness: 0.36, metalness: 0.04)

let matPCBBlack    = pbrMat(0.08, 0.09, 0.10, roughness: 0.55, metalness: 0.10)
let matPCBBlue     = pbrMat(0.08, 0.24, 0.52, roughness: 0.50, metalness: 0.08)
let matPCBGreen    = pbrMat(0.09, 0.38, 0.18, roughness: 0.52, metalness: 0.08)
let matSteel       = pbrMat(0.76, 0.78, 0.80, roughness: 0.28, metalness: 0.90)
let matBrushedAl   = pbrMat(0.78, 0.80, 0.83, roughness: 0.36, metalness: 0.85)
let matGold        = pbrMat(0.88, 0.70, 0.22, roughness: 0.24, metalness: 0.92)
let matLiPoSilver  = pbrMat(0.74, 0.77, 0.81, roughness: 0.30, metalness: 0.75)
let matKaptonTape  = pbrMat(0.82, 0.52, 0.08, roughness: 0.32, metalness: 0.12)
let matCopperWire  = pbrMat(0.80, 0.36, 0.16, roughness: 0.42, metalness: 0.72)
let matJSTWhite    = pbrMat(0.92, 0.91, 0.88, roughness: 0.45, metalness: 0.02)
let matMeshDark    = pbrMat(0.07, 0.07, 0.08, roughness: 0.85, metalness: 0.18)
let matShieldRib   = pbrMat(0.28, 0.30, 0.33, 0.75, roughness: 0.65, metalness: 0.05)

let matScreenActive: SCNMaterial = {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    let w = 320, h = 170
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    NSColor(srgbRed: 0.06, green: 0.08, blue: 0.11, alpha: 1.0).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: w, height: h)).fill()
    NSColor(srgbRed: 0.92, green: 0.36, blue: 0.10, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 16, y: 24, width: 88, height: 112), xRadius: 8, yRadius: 8).fill()
    NSColor(srgbRed: 0.98, green: 0.86, blue: 0.65, alpha: 1.0).setFill()
    NSBezierPath(ovalIn: NSRect(x: 42, y: 78, width: 36, height: 36)).fill()
    NSColor(srgbRed: 0.14, green: 0.78, blue: 0.58, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 120, y: 132, width: 64, height: 14), xRadius: 4, yRadius: 4).fill()
    NSColor(srgbRed: 0.55, green: 0.62, blue: 0.72, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 248, y: 132, width: 54, height: 14), xRadius: 4, yRadius: 4).fill()
    NSColor(srgbRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 120, y: 98, width: 174, height: 18), xRadius: 4, yRadius: 4).fill()
    NSColor(srgbRed: 0.65, green: 0.70, blue: 0.78, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 120, y: 72, width: 132, height: 12), xRadius: 3, yRadius: 3).fill()
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

let matPhoneScreen  = pbrMat(0.05, 0.06, 0.08, roughness: 0.08, metalness: 0.10)
let matAirPodsWhite = pbrMat(0.95, 0.95, 0.94, roughness: 0.18, metalness: 0.02)
let matCardWhite    = pbrMat(0.94, 0.94, 0.92, roughness: 0.28, metalness: 0.04)
let matCardEdgeDark = pbrMat(0.20, 0.22, 0.25, roughness: 0.45, metalness: 0.08)
let matCardStripe   = pbrMat(0.14, 0.32, 0.62, roughness: 0.35, metalness: 0.10)

// ----------------------------------------------------------------------------
// 3. Geometry Helpers
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
    node.eulerAngles = SCNVector3(0, Float(rotZDeg) * Float.pi / 180.0, 0)
}

// ----------------------------------------------------------------------------
// 4. Light-Modded Component Builders
// ----------------------------------------------------------------------------
struct BuiltComponent {
    let node: SCNNode
    let aabbs: [(String, AABB)]
}

func buildESP32LightMod(ox: Double, oy: Double, oz: Double) -> BuiltComponent {
    // 21 unused pins flush-cut; 17 active pins bent 90° inward w/ bare heat-shrunk female crimps (-5.2..0.0 mm!)
    let n = SCNNode(); n.name = "esp32_lightmod"
    addBox(n, 0, 63.7, 0, 31.5, 0, 1.6, radius: 0.4, mat: matPCBBlack, name: "esp_pcb")
    addBox(n, 48.0, 61.5, 5.0, 26.5, 1.6, 3.8, radius: 0.3, mat: matSteel, name: "esp_shield")
    addBox(n, -1.5, 6.0, 11.25, 20.25, 1.6, 4.9, radius: 0.8, mat: matSteel, name: "esp_usbc")
    addBox(n, 9.5, 59.22, 2.85, 28.65, 1.6, 3.08, radius: 0.3, mat: matBezelBlack, name: "lcd_glass")
    addBox(n, 13.0, 55.72, 4.4, 27.10, 3.05, 3.22, radius: 0.1, mat: matScreenActive, name: "lcd_active")
    addBox(n, 7.72, 55.98, 1.5, 29.9, -5.2, 0.0, radius: 0.5, mat: matCopperWire, name: "bent_crimps")
    cadPlace(n, ox: ox, oy: oy, oz: oz)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("esp32", makeAABB(origin: o, name: "pcb", 0, 63.7, 0, 31.5, 0, 1.6)),
        ("esp32", makeAABB(origin: o, name: "lcd", 9.5, 59.22, 2.85, 28.65, 1.6, 3.22)),
        ("esp32", makeAABB(origin: o, name: "bent_crimps", 7.72, 55.98, 1.5, 29.9, -5.2, 0.0))
    ])
}

func buildWM8960LightMod(ox: Double, oy: Double, oz: Double) -> BuiltComponent {
    // 2x20 female socket intact (-8.5..0.0) + 90-deg male header elbow (-11.0..-8.5) leaving Y_local >= 6.8 open!
    let n = SCNNode(); n.name = "wm8960_lightmod"
    addBox(n, 0, 65.0, 0, 30.0, 0, 1.6, radius: 0.4, mat: matPCBBlack, name: "wm_pcb")
    addBox(n, 12.0, 20.5, 18.0, 32.0, 1.6, 6.6, radius: 0.4, mat: matDarkSlate, name: "trs_body")
    addCyl(n, cx: 16.25, cy: 31.5, cz: 4.1, d: 6.0, h: 1.5, axis: .y, mat: matSteel, name: "trs_ring")
    addBox(n, 4.5, 8.26, 4.5, 7.45, 1.6, 2.8, mat: matGold, name: "mic_l")
    addBox(n, 56.74, 60.5, 22.55, 25.5, 1.6, 2.8, mat: matGold, name: "mic_r")
    addBox(n, 51.8, 62.3, 10.6, 15.9, 1.6, 7.6, radius: 0.3, mat: matJSTWhite, name: "j1_unmated")
    addBox(n, 7.1, 57.9, 0.8, 6.2, -11.0, 0.0, radius: 0.3, mat: matDarkSlate, name: "pi40_90deg")
    cadPlace(n, ox: ox, oy: oy, oz: oz)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("wm8960", makeAABB(origin: o, name: "pcb", 0, 65.0, 0, 30.0, 0, 1.6)),
        ("wm8960", makeAABB(origin: o, name: "trs", 12.0, 20.5, 18.0, 32.0, 1.6, 6.6)),
        ("wm8960", makeAABB(origin: o, name: "j1_unmated", 51.8, 62.3, 10.6, 15.9, 1.6, 7.6)),
        ("wm8960", makeAABB(origin: o, name: "pi40_90deg", 7.1, 57.9, 0.8, 6.2, -11.0, 0.0))
    ])
}

func buildKeypadLightMod(id: String, ox: Double, oy: Double, oz: Double, isActionRow: Bool) -> BuiltComponent {
    // 37 x 15 mm PCB, tails clipped to -1.0 mm, switches up to +11.0 mm, 90-deg 5P bare crimps exit +Y (15..20.2)
    let n = SCNNode(); n.name = id
    addBox(n, 0, 37.0, 0, 15.0, 0, 1.6, radius: 0.3, mat: matPCBGreen, name: "pad_pcb")
    addBox(n, 3.0, 34.0, 2.0, 13.0, -1.0, 0.0, mat: matDarkSlate, name: "pad_tails")
    for i in 0..<4 {
        let bx = 6.5 + Double(i) * 8.0
        addBox(n, bx - 3.0, bx + 3.0, 2.0, 8.0, 1.6, 11.0, radius: 0.2, mat: matDarkSlate, name: "tact_\(i)")
        let cMat = (isActionRow && i == 3) ? matRecOrange : matCharcoal
        addBox(n, bx - 3.1, bx + 3.1, 2.2, 8.2, 11.0, 14.0, radius: 0.7, mat: cMat, name: "keycap_\(i)")
    }
    addBox(n, 12.15, 24.85, 15.0, 20.2, 1.6, 5.8, radius: 0.5, mat: matCopperWire, name: "pad_5p_crimps")
    cadPlace(n, ox: ox, oy: oy, oz: oz)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        (id, makeAABB(origin: o, name: "pcb_switches", 0, 37.0, 0, 15.0, -1.0, 11.0)),
        (id, makeAABB(origin: o, name: "5p_bare_crimps", 12.15, 24.85, 15.0, 20.2, 1.6, 5.8))
    ])
}

func buildKY023LowProfile(ox: Double, oy: Double, oz: Double, rotZDeg: Int = 90) -> BuiltComponent {
    // Snap-on mushroom dome pulled off by hand; 13.0 mm gimbal ends at Z=14.5; tails clipped to -1.0 mm;
    // bare 5P crimps extend X_local 34.0..40.5
    let n = SCNNode(); n.name = "ky023_lowprofile"
    addBox(n, 0, 34.0, 0, 26.0, 0, 1.6, radius: 0.4, mat: matPCBBlack, name: "ky_pcb")
    addBox(n, 3.0, 31.0, 2.0, 24.0, -1.0, 0.0, mat: matDarkSlate, name: "ky_tails")
    addBox(n, 7.0, 23.0, 5.0, 21.0, 1.6, 14.5, radius: 0.3, mat: matSteel, name: "ky_gimbal")
    addCyl(n, cx: 15.0, cy: 13.0, cz: 15.6, d: 3.8, h: 3.4, axis: .z, mat: matDarkSlate, name: "ky_stub_post")
    // Printed Concave Pocket Disc snaps onto post outside grip (local cz = 17.8 -> world Z ~20.6)
    addCyl(n, cx: 15.0, cy: 13.0, cz: 17.8, d: 15.5, h: 2.6, axis: .z, mat: matDarkSlate, name: "pocket_disc")
    addBox(n, 34.0, 40.5, 6.35, 19.65, 1.4, 6.4, radius: 0.5, mat: matCopperWire, name: "5p_bare_crimps")
    cadPlace(n, ox: ox, oy: oy, oz: oz, rotZDeg: rotZDeg)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("ky023", makeAABB(origin: o, rotZDeg: rotZDeg, name: "pcb_tails", 0, 34.0, 0, 26.0, -1.0, 1.6)),
        ("ky023", makeAABB(origin: o, rotZDeg: rotZDeg, name: "gimbal_box", 7.0, 23.0, 5.0, 21.0, 1.6, 14.5)),
        ("ky023", makeAABB(origin: o, rotZDeg: rotZDeg, name: "5p_bare_crimps", 34.0, 40.5, 6.35, 19.65, 1.4, 6.4))
    ])
}

func buildMicroSDLightMod(ox: Double, oy: Double, oz: Double) -> BuiltComponent {
    // 42.0 x 24.0 mm, tails clipped -1.0..0, card cage +5.0 mm; bare 6P crimps exit +X (42.0..44.7)
    let n = SCNNode(); n.name = "microsd_lightmod"
    addBox(n, 0, 42.0, 0, 24.0, 0, 1.6, radius: 0.3, mat: matPCBBlue, name: "sd_pcb")
    addBox(n, -0.5, 15.5, 4.5, 19.5, 1.6, 5.0, radius: 0.2, mat: matSteel, name: "sd_cage")
    addBox(n, -2.0, 8.0, 6.5, 17.5, 2.1, 3.1, radius: 0.1, mat: matRecOrange, name: "sd_card")
    addBox(n, 37.0, 44.7, 4.0, 20.0, -1.0, 4.5, radius: 0.4, mat: matCopperWire, name: "sd_6p_crimps")
    cadPlace(n, ox: ox, oy: oy, oz: oz)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("microsd", makeAABB(origin: o, name: "pcb_cage", 0, 42.0, 0, 24.0, -1.0, 5.0)),
        ("microsd", makeAABB(origin: o, name: "6p_crimps", 42.0, 44.7, 4.0, 20.0, 0.7, 4.7))
    ])
}

func buildLiPo604060(ox: Double, oy: Double, oz: Double) -> BuiltComponent {
    let n = SCNNode(); n.name = "lipo_604060"
    addBox(n, 0, 60.0, 0, 40.0, 0, 6.0, radius: 1.5, mat: matLiPoSilver, name: "lipo_pouch")
    addBox(n, 5.0, 55.0, 35.5, 40.0, 0.2, 5.8, radius: 0.5, mat: matKaptonTape, name: "lipo_bms_tape")
    cadPlace(n, ox: ox, oy: oy, oz: oz)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("lipo", makeAABB(origin: o, name: "604060_pouch", 0, 60.0, 0, 40.0, 0, 6.0))
    ])
}

func buildUSBCBoostBoard(ox: Double, oy: Double, oz: Double) -> BuiltComponent {
    // 27.0 x 22.0 x 5.5 mm USB-C 5V Charger/Boost UPS module (USB-C exits +X right edge)
    let n = SCNNode(); n.name = "usbc_boost"
    addBox(n, 0, 27.0, 0, 22.0, 0, 1.6, radius: 0.3, mat: matPCBBlue, name: "boost_pcb")
    addBox(n, 20.0, 28.0, 6.5, 15.5, 1.6, 5.0, radius: 0.6, mat: matSteel, name: "boost_usbc")
    addBox(n, 6.0, 16.0, 6.0, 16.0, 1.6, 5.5, radius: 0.3, mat: matDarkSlate, name: "boost_inductor")
    cadPlace(n, ox: ox, oy: oy, oz: oz)

    let o = (ox, oy, oz)
    return BuiltComponent(node: n, aabbs: [
        ("usbc_boost", makeAABB(origin: o, name: "pcb_inductor", 0, 27.0, 0, 22.0, 0, 5.5))
    ])
}

// ----------------------------------------------------------------------------
// 5. Build Option P1 (17.5 mm 8-Button) & Option P2 (19.0 mm Low-Pro Stick)
// ----------------------------------------------------------------------------
func addSharedUpperDeck(to root: SCNNode, boxes: inout [(String, AABB)]) {
    let lipo = buildLiPo604060(ox: 8.0, oy: 45.0, oz: 1.8)
    let wm = buildWM8960LightMod(ox: 5.5, oy: 85.5, oz: 12.8)
    let sd = buildMicroSDLightMod(ox: 1.8, oy: 92.2, oz: 3.8)
    let boost = buildUSBCBoostBoard(ox: 47.2, oy: 93.0, oz: 2.5)

    for c in [lipo, wm, sd, boost] {
        root.addChildNode(c.node)
        boxes.append(contentsOf: c.aabbs)
    }

    // Mandatory 0.7 mm solid printed protective puncture wall above LiPo (Z: 7.8..8.5)
    addBox(root, 6.0, 70.0, 44.6, 85.2, 7.8, 8.5, mat: matShieldRib, name: "lipo_shield_rib")
    boxes.append(("shield_rib", AABB(name: "rib", minX: 6.0, maxX: 70.0, minY: 44.6, maxY: 85.2, minZ: 7.8, maxZ: 8.5)))

    // Outer 1.6 mm enclosure wall keepouts
    boxes.append(("shell", AABB(name: "back_wall", minX: 0, maxX: 76.0, minY: 0, maxY: 118.0, minZ: 0.0, maxZ: 1.6)))
    boxes.append(("shell", AABB(name: "left_wall", minX: 0, maxX: 1.6, minY: 0, maxY: 118.0, minZ: 0.0, maxZ: 22.2)))
    boxes.append(("shell", AABB(name: "right_wall", minX: 74.4, maxX: 76.0, minY: 0, maxY: 118.0, minZ: 0.0, maxZ: 22.2)))
    boxes.append(("shell", AABB(name: "bar_roof", minX: 0, maxX: 76.0, minY: 85.0, maxY: 118.0, minZ: 20.6, maxZ: 22.2)))
}

func buildOptionP1Assembly(xray: Bool = false) -> (SCNNode, Int) {
    let root = SCNNode(); root.name = "option_p1_17p5mm"
    var boxes: [(String, AABB)] = []
    addSharedUpperDeck(to: root, boxes: &boxes)

    let esp = buildESP32LightMod(ox: 6.0, oy: 52.0, oz: 13.8)
    let padBot = buildKeypadLightMod(id: "pad_bot", ox: 19.5, oy: 2.5, oz: 4.8, isActionRow: true)
    let padTop = buildKeypadLightMod(id: "pad_top", ox: 19.5, oy: 24.2, oz: 4.8, isActionRow: false)

    for c in [esp, padBot, padTop] {
        root.addChildNode(c.node)
        boxes.append(contentsOf: c.aabbs)
    }

    let collisions = verifyAABBs(label: "Option P1 (8-Btn 76x118x17.5/22.2)", boxes: boxes)

    // Exterior Sculpted Pocket Walkman Shell (17.5 mm grip, 22.2 mm Pixel-style top audio camera bar)
    let rearMat = xray ? matSmokedShell : matCharcoal
    let frontMat = xray ? matSmokedTop : matStoneGray
    let barMat = xray ? matSmokedTop : matStoneStep

    addBox(root, 0, 76.0, 0, 85.0, 0.0, 8.6, radius: 3.2, mat: rearMat, name: "p1_back")
    addBox(root, 0, 76.0, 0, 85.0, 8.9, 17.5, radius: 3.0, mat: frontMat, name: "p1_front")
    addBox(root, 0.4, 75.6, 0.4, 84.6, 8.4, 9.1, radius: 2.8, mat: matDarkSlate, name: "p1_seam")

    addBox(root, 0, 76.0, 85.0, 118.0, 0.0, 8.6, radius: 3.2, mat: rearMat, name: "p1_bar_back")
    addBox(root, 0, 76.0, 85.0, 118.0, 8.9, 22.2, radius: 3.0, mat: barMat, name: "p1_bar_front")

    // Active 1.9" IPS screen + extended asymmetrical instrument bezel concealing ESP32 USB-C flashing slot
    addBox(root, 5.5, 66.0, 54.0, 81.5, 17.0, 17.85, radius: 1.2, mat: matBezelBlack, name: "p1_lcd_bezel")
    addBox(root, 19.0, 61.72, 56.4, 79.10, 17.55, 17.95, radius: 0.3, mat: matScreenActive, name: "p1_lcd_face")

    // 2x4 Tactile Keycaps protruding gently to Z=18.8 mm (pad_top nav row + pad_bot action/REC row)
    for row in 0..<2 {
        let cy0 = (row == 0) ? 4.7 : 26.4
        for i in 0..<4 {
            let bx = 26.0 + Double(i) * 8.0
            let kMat = (row == 0 && i == 3) ? matRecOrange : matCharcoal
            addBox(root, bx - 3.1, bx + 3.1, cy0, cy0 + 6.0, 17.0, 18.8, radius: 0.7, mat: kMat, name: "p1_key_\(row)_\(i)")
        }
    }
    // Subtle iPod-inspired tactile guide frame around the 2x4 pad
    addBox(root, 20.5, 55.5, 2.5, 35.0, 17.35, 17.6, radius: 2.0, mat: matStoneStep, name: "p1_pad_well")

    // Top Audio Bar Stereo MEMS Mic Slots & Top 3.5mm Jack (ox=5.5+16.25=21.75)
    addBox(root, 9.0, 15.0, 89.5, 92.5, 21.9, 22.35, radius: 1.0, mat: matMeshDark, name: "p1_mic_l")
    addBox(root, 61.0, 67.0, 107.5, 110.5, 21.9, 22.35, radius: 1.0, mat: matMeshDark, name: "p1_mic_r")
    addCyl(root, cx: 21.75, cy: 118.1, cz: 16.9, d: 6.4, h: 1.0, axis: .y, mat: matSteel, name: "p1_trs_ring")
    addCyl(root, cx: 21.75, cy: 118.3, cz: 16.9, d: 3.5, h: 1.2, axis: .y, mat: matBezelBlack, name: "p1_trs_hole")

    // Left microSD slot + Right USB-C charge port accent
    addBox(root, -0.3, 0.3, 99.0, 110.0, 5.5, 7.6, radius: 0.3, mat: matDarkSlate, name: "p1_sd_slot")
    addBox(root, 75.7, 76.3, 100.0, 108.5, 4.2, 6.8, radius: 0.5, mat: matSteel, name: "p1_usbc_chg")

    return (root, collisions)
}

func buildOptionP2Assembly(xray: Bool = false) -> (SCNNode, Int) {
    let root = SCNNode(); root.name = "option_p2_19mm"
    var boxes: [(String, AABB)] = []
    addSharedUpperDeck(to: root, boxes: &boxes)

    let esp = buildESP32LightMod(ox: 6.0, oy: 52.0, oz: 15.3)
    let ky = buildKY023LowProfile(ox: 29.5, oy: 3.5, oz: 2.8, rotZDeg: 90)
    let pad = buildKeypadLightMod(id: "pad_right", ox: 34.5, oy: 13.0, oz: 6.3, isActionRow: true)

    for c in [esp, ky, pad] {
        root.addChildNode(c.node)
        boxes.append(contentsOf: c.aabbs)
    }

    let collisions = verifyAABBs(label: "Option P2 (Low-Pro Stick 76x118x19.0/22.2)", boxes: boxes)

    let rearMat = xray ? matSmokedShell : matCharcoal
    let frontMat = xray ? matSmokedTop : matStoneGray
    let barMat = xray ? matSmokedTop : matStoneStep

    addBox(root, 0, 76.0, 0, 85.0, 0.0, 9.4, radius: 3.2, mat: rearMat, name: "p2_back")
    addBox(root, 0, 76.0, 0, 85.0, 9.7, 19.0, radius: 3.0, mat: frontMat, name: "p2_front")
    addBox(root, 0.4, 75.6, 0.4, 84.6, 9.2, 9.9, radius: 2.8, mat: matDarkSlate, name: "p2_seam")

    addBox(root, 0, 76.0, 85.0, 118.0, 0.0, 9.4, radius: 3.2, mat: rearMat, name: "p2_bar_back")
    addBox(root, 0, 76.0, 85.0, 118.0, 9.7, 22.2, radius: 3.0, mat: barMat, name: "p2_bar_front")

    if !xray {
        addBox(root, 5.5, 66.0, 54.0, 81.5, 18.5, 19.35, radius: 1.2, mat: matBezelBlack, name: "p2_lcd_bezel")
        addBox(root, 19.0, 61.72, 56.4, 79.10, 19.05, 19.45, radius: 0.3, mat: matScreenActive, name: "p2_lcd_face")
    } else {
        addBox(root, 19.0, 61.72, 56.4, 79.10, 18.85, 19.22, radius: 0.3, mat: matScreenActive, name: "p2_lcd_face_x")
    }

    // Concave Low-Profile Pocket Thumb Disc (Z: 19.3..21.9 < 22.2 top ridge!) in sculpted bezel well
    addCyl(root, cx: 16.5, cy: 18.5, cz: 18.9, d: 19.5, h: 0.6, axis: .z, mat: matStoneStep, name: "p2_disc_well")
    addCyl(root, cx: 16.5, cy: 18.5, cz: 20.6, d: 15.5, h: 2.6, axis: .z, mat: matDarkSlate, name: "p2_pocket_disc")
    addCyl(root, cx: 16.5, cy: 18.5, cz: 21.8, d: 11.5, h: 0.4, axis: .z, mat: matCharcoal, name: "p2_disc_ring")

    // Right 1x4 Tactile Keys
    for i in 0..<4 {
        let bx = 41.0 + Double(i) * 8.0
        let kMat = (i == 3) ? matRecOrange : matCharcoal
        addBox(root, bx - 3.1, bx + 3.1, 15.2, 21.2, 18.5, 20.3, radius: 0.7, mat: kMat, name: "p2_key_\(i)")
    }

    // Top Bar Audio Details & Side Ports
    addBox(root, 9.0, 15.0, 89.5, 92.5, 21.9, 22.35, radius: 1.0, mat: matMeshDark, name: "p2_mic_l")
    addBox(root, 61.0, 67.0, 107.5, 110.5, 21.9, 22.35, radius: 1.0, mat: matMeshDark, name: "p2_mic_r")
    addCyl(root, cx: 21.75, cy: 118.1, cz: 16.9, d: 6.4, h: 1.0, axis: .y, mat: matSteel, name: "p2_trs_ring")
    addCyl(root, cx: 21.75, cy: 118.3, cz: 16.9, d: 3.5, h: 1.2, axis: .y, mat: matBezelBlack, name: "p2_trs_hole")
    addBox(root, -0.3, 0.3, 99.0, 110.0, 5.5, 7.6, radius: 0.3, mat: matDarkSlate, name: "p2_sd_slot")
    addBox(root, 75.7, 76.3, 100.0, 108.5, 4.2, 6.8, radius: 0.5, mat: matSteel, name: "p2_usbc_chg")

    return (root, collisions)
}

func buildPrevOptionAShell() -> SCNNode {
    // 106 x 132 x 32 / 40.5 mm Zero-Solder 18650 Option A for size comparison
    let n = SCNNode(); n.name = "prev_opt_a_32mm"
    addBox(n, 0, 106.0, 0, 98.0, 0.0, 15.8, radius: 3.8, mat: matCharcoal, name: "a_back")
    addBox(n, 0, 106.0, 0, 98.0, 16.2, 32.0, radius: 3.6, mat: matStoneGray, name: "a_front")
    addBox(n, 0, 106.0, 98.0, 132.0, 0.0, 15.8, radius: 3.8, mat: matCharcoal, name: "a_bar_b")
    addBox(n, 0, 106.0, 98.0, 132.0, 16.2, 40.5, radius: 3.6, mat: matStoneStep, name: "a_bar_f")
    addBox(n, 12.0, 68.5, 67.2, 94.8, 31.4, 32.15, radius: 1.4, mat: matBezelBlack, name: "a_bezel")
    addBox(n, 16.5, 59.22, 70.1, 92.80, 31.9, 32.28, radius: 0.4, mat: matScreenActive, name: "a_lcd")
    addCyl(n, cx: 19.0, cy: 52.2, cz: 36.8, d: 18.0, h: 4.2, axis: .z, mat: matDarkSlate, name: "a_stick")
    for i in 0..<4 {
        let bx = 69.5 + Double(i) * 8.0
        addBox(n, bx - 3.2, bx + 3.2, 45.0, 51.4, 31.6, 33.8, radius: 0.9, mat: (i == 3) ? matRecOrange : matCharcoal, name: "a_btn_\(i)")
    }
    return n
}

// ----------------------------------------------------------------------------
// 6. Calibrated 1:1 Everyday Scale Props
// ----------------------------------------------------------------------------
func buildIPhone61() -> SCNNode {
    let n = SCNNode(); n.name = "prop_iphone_61"
    addBox(n, 0, 71.5, 0, 146.7, 0.0, 7.8, radius: 3.9, mat: matDarkSlate, name: "phone_body")
    addBox(n, 1.5, 70.0, 1.5, 145.2, 7.5, 7.9, radius: 3.4, mat: matPhoneScreen, name: "phone_screen")
    addBox(n, 25.0, 46.5, 138.0, 142.0, 7.82, 7.95, radius: 1.8, mat: matBezelBlack, name: "phone_island")
    return n
}

func buildAirPodsProCase() -> SCNNode {
    let n = SCNNode(); n.name = "prop_airpods_pro"
    addBox(n, 0, 60.6, 0, 45.2, 0, 21.7, radius: 8.5, mat: matAirPodsWhite, name: "ap_case")
    addBox(n, 0.4, 60.2, 29.0, 29.8, 0.4, 21.3, mat: matCharcoal, name: "ap_lid_seam")
    return n
}

func buildCreditCard(darkEdge: Bool = false) -> SCNNode {
    let n = SCNNode(); n.name = "prop_credit_card"
    addBox(n, 0, 85.60, 0, 53.98, 0, 0.76, radius: 3.0, mat: darkEdge ? matCardEdgeDark : matCardWhite, name: "card_body")
    addBox(n, 0.2, 85.4, 0.2, 53.78, 0.05, 0.76, radius: 2.8, mat: matCardWhite, name: "card_face")
    addBox(n, 0, 85.60, 34.0, 44.0, 0.72, 0.79, mat: matCardStripe, name: "card_band")
    addBox(n, 11.0, 23.0, 22.0, 31.0, 0.72, 0.82, radius: 1.0, mat: matGold, name: "card_chip")
    return n
}

func buildSteelRuler160() -> SCNNode {
    let n = SCNNode(); n.name = "prop_ruler_160mm"
    addBox(n, 0, 160.0, 0, 18.0, 0, 1.2, radius: 0.2, mat: matBrushedAl, name: "ruler_bar")
    for mm in stride(from: 0, through: 150, by: 2) {
        let major = (mm % 10 == 0)
        addBox(n, Double(mm) + 4.8, Double(mm) + 5.15, 18.0 - (major ? 6.0 : 3.2), 18.0, 1.18, 1.28, mat: matDarkSlate, name: "tick_\(mm)")
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
// 7. Metal Rendering & Exports
// ----------------------------------------------------------------------------
let metalDevice = MTLCreateSystemDefaultDevice()!
let renderer = SCNRenderer(device: metalDevice, options: nil)

func setupStudioLighting(_ scene: SCNScene, ortho: Bool = false) {
    let key = SCNNode(); key.light = SCNLight(); key.light!.type = .directional
    key.light!.intensity = ortho ? 950 : 1220
    key.light!.color = NSColor(srgbRed: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
    key.light!.castsShadow = !ortho
    key.light!.shadowRadius = 5.0; key.light!.shadowSampleCount = 16
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
        let p = NSBezierPath(); p.lineWidth = isMajor ? 1.8 : 0.8
        let x = CGFloat(Double(mm) * pxPerMM)
        p.move(to: NSPoint(x: x, y: 0)); p.line(to: NSPoint(x: x, y: CGFloat(h)))
        p.stroke()
    }
    for mm in stride(from: 0, through: Int(heightMM), by: 10) {
        let isMajor = (mm % 50 == 0)
        (isMajor ? majorCol : minorCol).setStroke()
        let p = NSBezierPath(); p.lineWidth = isMajor ? 1.8 : 0.8
        let y = CGFloat(Double(mm) * pxPerMM)
        p.move(to: NSPoint(x: 0, y: y)); p.line(to: NSPoint(x: CGFloat(w), y: y))
        p.stroke()
    }
    img.unlockFocus()
    return img
}

func renderSceneToImage(_ scene: SCNScene, camNode: SCNNode, width: Int, height: Int) -> NSImage {
    renderer.scene = scene
    renderer.pointOfView = camNode
    return renderer.snapshot(atTime: 0, with: CGSize(width: width, height: height), antialiasingMode: .multisampling4X)
}

func savePNG(_ image: NSImage, fileName: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: "\(renderDir)/\(fileName)"))
    try? png.write(to: URL(fileURLWithPath: "\(artifactDir)/\(fileName)"))
    print("💾 Saved \(fileName) (\(Int(image.size.width))x\(Int(image.size.height)))")
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
    print("📦 Exported \(fileName)")
}

// ----------------------------------------------------------------------------
// 8. Execute Build, Audit & USDZ Exports
// ----------------------------------------------------------------------------
let (optP1, colP1) = buildOptionP1Assembly(xray: false)
let (optP2, colP2) = buildOptionP2Assembly(xray: false)
let (optP2Xray, _) = buildOptionP2Assembly(xray: true)
if colP1 > 0 || colP2 > 0 {
    print("❌ ABORTING: Detected collision (colP1=\(colP1), colP2=\(colP2)).")
    exit(2)
}

exportUSDZ(optP1, fileName: "11a_pocket_slim_8btn_17p5mm.usdz")
exportUSDZ(optP2, fileName: "11b_pocket_slim_thumbstick_19mm.usdz")

// ----------------------------------------------------------------------------
// 9. Orthographic Comparison Sheet: Evolution (2400 x 1400)
// ----------------------------------------------------------------------------
func renderOrthoEvolutionSheet() {
    let w = 2400, h = 1400
    let scene = SCNScene()
    scene.background.contents = NSColor(srgbRed: 0.965, green: 0.968, blue: 0.972, alpha: 1.0)
    setupStudioLighting(scene, ortho: true)

    // Sheet spans X [-340..+340] (680 mm wide) -> halfH = 340 * (1400/2400) = 198.33 mm
    let halfH = 340.0 * Double(h) / Double(w)
    let sheetMat = SCNMaterial()
    sheetMat.lightingModel = .constant
    sheetMat.diffuse.contents = makeCuttingMatTexture(
        widthMM: 680, heightMM: halfH * 2.0,
        bg: NSColor(srgbRed: 0.975, green: 0.977, blue: 0.980, alpha: 1.0),
        minorCol: NSColor(srgbRed: 0.89, green: 0.91, blue: 0.93, alpha: 1.0),
        majorCol: NSColor(srgbRed: 0.78, green: 0.81, blue: 0.85, alpha: 1.0)
    )
    addBox(scene.rootNode, -340, 340, -halfH, halfH, -55.0, -54.0, mat: sheetMat, name: "draft_grid")

    // 6-item evolution lineup across [-340..+340]
    let items: [(String, String, SCNNode, Double, Double, Double)] = [
        ("OPTION P1: 8-BTN", "76 × 118 × 17.5 mm (22.2 bar)", optP1.clone(), 76.0, 22.2, -280.0),
        ("OPTION P2: POCKET STICK", "76 × 118 × 19.0 mm (22.2 bar)", optP2.clone(), 76.0, 22.2, -182.0),
        ("PREV ZERO-SOLDER", "106 × 132 × 32 mm (40.5 bar)", buildPrevOptionAShell(), 106.0, 40.5, -62.0),
        ("6.1\" SMARTPHONE", "71.5 × 146.7 × 7.8 mm", buildIPhone61(), 71.5, 7.8, 60.0),
        ("AIRPODS PRO CASE", "60.6 × 45.2 × 21.7 mm", buildAirPodsProCase(), 60.6, 21.7, 166.0),
        ("ISO CREDIT CARD", "85.6 × 53.98 × 0.76 mm", buildCreditCard(darkEdge: true), 85.6, 1.2, 274.0)
    ]

    for (_, _, node, width, depth, cx) in items {
        let f = node.clone()
        f.position = SCNVector3(cx - width * 0.5, 0, -18.0) // cadY = +18 .. +165
        scene.rootNode.addChildNode(f)

        let s = node.clone()
        s.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        s.position = SCNVector3(cx - depth * 0.5, 0, 174.0) // cadY = -174 .. -27
        scene.rootNode.addChildNode(s)
    }

    let camNode = SCNNode(); camNode.camera = SCNCamera()
    camNode.camera!.usesOrthographicProjection = true
    camNode.camera!.orthographicScale = halfH
    camNode.camera!.zNear = 1.0; camNode.camera!.zFar = 1200.0
    camNode.position = SCNVector3(0, 460, 0)
    camNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
    scene.rootNode.addChildNode(camNode)

    let rawImg = renderSceneToImage(scene, camNode: camNode, width: w, height: h)
    let annotated = NSImage(size: NSSize(width: w, height: h))
    annotated.lockFocus()
    rawImg.draw(in: NSRect(x: 0, y: 0, width: w, height: h))

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .bold),
        .foregroundColor: NSColor(srgbRed: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
    ]
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .medium),
        .foregroundColor: NSColor(srgbRed: 0.30, green: 0.33, blue: 0.38, alpha: 1.0)
    ]
    let badgeAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .bold),
        .foregroundColor: NSColor(srgbRed: 0.90, green: 0.30, blue: 0.06, alpha: 1.0)
    ]

    NSString("1:1 ORTHOGRAPHIC POCKET EVOLUTION — SUB-AIRPODS FLAT-LiPo VARIANTS (17.5 & 19.0 mm) vs ZERO-SOLDER & PROPS")
        .draw(at: NSPoint(x: 42, y: CGFloat(h) - 46), withAttributes: titleAttrs)
    NSString("Uniform 10 mm Scale  •  Light-Mod Bent Headers + Flat 604060 LiPo  •  Option P1 (168.7 cm³) = -64.7% vs Option A, -80.3% vs Baseline")
        .draw(at: NSPoint(x: 42, y: CGFloat(h) - 72), withAttributes: subAttrs)
    NSString("FRONT ELEVATION")
        .draw(at: NSPoint(x: 42, y: CGFloat(h) - 108), withAttributes: badgeAttrs)
    NSString("SIDE THICKNESS PROFILE (Z-DEPTH)")
        .draw(at: NSPoint(x: 42, y: 635), withAttributes: badgeAttrs)

    let pxPerMM = Double(w) / 680.0
    for (title, spec, _, _, _, cx) in items {
        let pxX = (cx + 340.0) * pxPerMM
        let tSize = NSString(string: title).size(withAttributes: badgeAttrs)
        let sSize = NSString(string: spec).size(withAttributes: subAttrs)
        NSString(string: title).draw(at: NSPoint(x: pxX - Double(tSize.width) * 0.5, y: 706), withAttributes: badgeAttrs)
        NSString(string: spec).draw(at: NSPoint(x: pxX - Double(sSize.width) * 0.5, y: 680), withAttributes: subAttrs)
        NSString(string: spec).draw(at: NSPoint(x: pxX - Double(sSize.width) * 0.5, y: 24), withAttributes: subAttrs)
    }

    annotated.unlockFocus()
    savePNG(annotated, fileName: "ref_11_pocket_evolution_ortho_comparison.png")
}

// ----------------------------------------------------------------------------
// 10. Calibrated Studio Knolling (11a) + Low-Angle Profile (11b)
// ----------------------------------------------------------------------------
func buildPocketStudioScene() -> (SCNScene, SCNNode, SCNNode) {
    let scene = SCNScene()
    scene.background.contents = NSColor(srgbRed: 0.90, green: 0.905, blue: 0.91, alpha: 1.0)
    setupStudioLighting(scene, ortho: false)

    // Compact 500 x 300 mm Cutting Mat (fits our genuinely pocketable 76x118 mm devices cleanly!)
    let matTex = SCNMaterial()
    matTex.lightingModel = .physicallyBased
    matTex.roughness.contents = 0.85; matTex.metalness.contents = 0.02
    matTex.diffuse.contents = makeCuttingMatTexture(
        widthMM: 500, heightMM: 300,
        bg: NSColor(srgbRed: 0.15, green: 0.17, blue: 0.19, alpha: 1.0),
        minorCol: NSColor(srgbRed: 0.22, green: 0.25, blue: 0.28, alpha: 1.0),
        majorCol: NSColor(srgbRed: 0.30, green: 0.35, blue: 0.40, alpha: 1.0)
    )
    addBox(scene.rootNode, -250, 250, -150, 150, -3.0, 0.0, mat: matTex, name: "cutting_mat")

    // Top Row (well-spaced across X=-210..+200): P1 (76), P2 (76), P2 X-Ray (76), 6.1" Smartphone (71.5)
    let p1Node = optP1.clone()
    p1Node.position = SCNVector3(-206, 0.0, -20.0) // X [-206..-130]
    scene.rootNode.addChildNode(p1Node)

    let p2Node = optP2.clone()
    p2Node.position = SCNVector3(-100, 0.0, -20.0) // X [-100..-24]
    scene.rootNode.addChildNode(p2Node)

    let p2xNode = optP2Xray.clone()
    p2xNode.eulerAngles = SCNVector3(Float(-20.0 * .pi / 180.0), Float(-8.0 * .pi / 180.0), 0)
    p2xNode.position = SCNVector3(6, 26.0, -16.0) // X [+6..+82], clean 30mm clear from P2 and 34mm clear from Phone!
    scene.rootNode.addChildNode(p2xNode)

    let phone = buildIPhone61()
    phone.position = SCNVector3(122, 0.0, -10.0) // X [+122..+193.5]
    scene.rootNode.addChildNode(phone)

    // Foreground Row (Z_scn = +80, right in front so airpods 21.7 mm aligns visually with P1 17.5 & P2 19.0!)
    let ruler = buildSteelRuler160()
    ruler.position = SCNVector3(-206, 0.0, 74.0) // X [-206..-46]
    scene.rootNode.addChildNode(ruler)

    let ap = buildAirPodsProCase()
    ap.position = SCNVector3(-22, 0.0, 82.0) // X [-22..+38.6]
    scene.rootNode.addChildNode(ap)

    let card = buildCreditCard()
    card.position = SCNVector3(58, 0.0, 84.0) // X [+58..+143.6]
    scene.rootNode.addChildNode(card)

    let quarter = buildQuarter()
    quarter.position = SCNVector3(160, 0.0, 72.0)
    scene.rootNode.addChildNode(quarter)

    let sdChip = buildLooseMicroSD()
    sdChip.position = SCNVector3(166, 0.0, 96.0) // neatly inside right margin, unobstructed in 11a and 11b!
    scene.rootNode.addChildNode(sdChip)

    // Camera 11a: Elevated 3/4 Knolling Overview (52°)
    let camA = SCNNode(); camA.camera = SCNCamera()
    camA.camera!.fieldOfView = 33.0; camA.camera!.zNear = 1.0; camA.camera!.zFar = 2000.0
    camA.position = SCNVector3(-6, 445, 275)
    camA.look(at: SCNVector3(-6, 8, 12))
    scene.rootNode.addChildNode(camA)

    // Camera 11b: Low-Angle ~16° Profile Shot showing 17.5 mm & 19.0 mm sitting LOWER than 21.7 mm AirPods Pro Case
    let camB = SCNNode(); camB.camera = SCNCamera()
    camB.camera!.fieldOfView = 33.0; camB.camera!.zNear = 1.0; camB.camera!.zFar = 2000.0
    camB.position = SCNVector3(-6, 136, 480)
    camB.look(at: SCNVector3(-6, 14, 8))
    scene.rootNode.addChildNode(camB)

    exportUSDZ(scene.rootNode, fileName: "11c_pocket_evolution_comparison_scene.usdz")
    return (scene, camA, camB)
}

renderOrthoEvolutionSheet()
let (pocketScene, cam11a, cam11b) = buildPocketStudioScene()
savePNG(renderSceneToImage(pocketScene, camNode: cam11a, width: 1920, height: 1080), fileName: "ref_11a_1to1_pocket_slim_knolling_guide.png")
savePNG(renderSceneToImage(pocketScene, camNode: cam11b, width: 1920, height: 1080), fileName: "ref_11b_1to1_pocket_slim_profile_guide.png")

print("🎉 DONE: Option P1 (17.5 mm) & Option P2 (19.0 mm) verified with 0 collisions, 3 USDZ + 3 PNG renders generated!")
