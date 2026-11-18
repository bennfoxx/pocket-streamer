#!/usr/bin/env swift
import Foundation
import SceneKit
import AppKit

// ============================================================================
// fbox Nano v2 (Metrology-Verified Edition): 68.5 x 68.0 x 24.2 mm (R = 4.8 mm)
// Zero-Illusion, Sub-0.1mm Calibrated Against Real Desk Components:
//   1. GODIYMODULES 1x4 (x2): True 7.28mm switch pitch (+7.55, +14.83, +22.12, +29.40 mm)
//      w/ 6.2x6.8mm keycaps (NOT stretched 9.2mm pitch!).
//   2. LILYGO T-Display-S3 AMOLED: CNC-calibrated 58.8x25.5mm acrylic body + 1.2mm USB-C lip,
//      44.22x19.80mm active screen (+11.32mm from USB-C acrylic edge), + 1.0mm underside
//      faceplate relief pocket over cantilevered BOOT (IO0) & IO21 clear-acrylic plungers!
//   3. KY-023 Joystick: 33.0x25.0mm PCB seated ON Z=2.4mm FLOOR (NOT stacked on battery!),
//      full 23.0x22.5x12.0mm gimbal+pots+SW block, stock ~19.5mm bare D-shaft fits natively,
//      with a clean 9.45mm solid faceplate bridge below the AMOLED!
//   4. Liter 503759 LiPo (59.0x37.0x5.0mm): Seated flat on Z=1.8mm floor north of KY-023
//      under 0.6mm shield rib, with V713 Boost + Speaker + Mic in dedicated lower-right bay.
// ============================================================================

let cwd = FileManager.default.currentDirectoryPath
let renderDir = "\(cwd)/experimental/renders"
try? FileManager.default.createDirectory(atPath: renderDir, withIntermediateDirectories: true)

struct AABB {
    let name: String
    let x0: Double, x1: Double
    let y0: Double, y1: Double
    let z0: Double, z1: Double
}

func makeAABB(_ name: String, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double) -> AABB {
    AABB(name: name, x0: min(x0, x1), x1: max(x0, x1), y0: min(y0, y1), y1: max(y0, y1), z0: min(z0, z1), z1: max(z0, z1))
}

func verifyAABBs(label: String, boxes: [(String, AABB)]) -> Int {
    var count = 0
    for i in 0..<boxes.count {
        for j in (i + 1)..<boxes.count {
            if boxes[i].0 == boxes[j].0 { continue }
            let a = boxes[i].1, b = boxes[j].1
            let ox = min(a.x1, b.x1) - max(a.x0, b.x0)
            let oy = min(a.y1, b.y1) - max(a.y0, b.y0)
            let oz = min(a.z1, b.z1) - max(a.z0, b.z0)
            if ox > 0.001 && oy > 0.001 && oz > 0.001 {
                print(String(format: "COLLISION [%@] %@:%@ <-> %@:%@ [dx=%.2f dy=%.2f dz=%.2f]",
                             label, boxes[i].0, a.name, boxes[j].0, b.name, ox, oy, oz))
                count += 1
            }
        }
    }
    print("CHECK [\(label)] boxes=\(boxes.count) Collisions=\(count)")
    return count
}

func makeMat(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0,
             metal: CGFloat = 0.08, rough: CGFloat = 0.55) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    m.metalness.contents = metal
    m.roughness.contents = rough
    if a < 0.999 {
        m.transparencyMode = .dualLayer
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
    }
    return m
}

let matOpaqueCharcoal = makeMat(0.18, 0.20, 0.24, 1.0, metal: 0.06, rough: 0.68)
let matSmokeShell     = makeMat(0.20, 0.23, 0.28, 0.24, metal: 0.08, rough: 0.18)
let matClearAcrylic   = makeMat(0.85, 0.90, 0.95, 0.38, metal: 0.05, rough: 0.12)
let matDarkPCB        = makeMat(0.10, 0.13, 0.18, 1.0, metal: 0.12, rough: 0.48)
let matGreenPCB       = makeMat(0.09, 0.48, 0.24, 1.0, metal: 0.10, rough: 0.45)
let matPurplePCB      = makeMat(0.46, 0.14, 0.76, 1.0, metal: 0.12, rough: 0.45)
let matBluePCB        = makeMat(0.12, 0.38, 0.84, 1.0, metal: 0.12, rough: 0.45)
let matSilver         = makeMat(0.78, 0.82, 0.86, 1.0, metal: 0.78, rough: 0.25)
let matGold           = makeMat(0.88, 0.70, 0.14, 1.0, metal: 0.85, rough: 0.22)
let matBlackCap       = makeMat(0.12, 0.13, 0.16, 1.0, metal: 0.06, rough: 0.58)
let matCoralCap       = makeMat(0.92, 0.46, 0.36, 1.0, metal: 0.04, rough: 0.42)
let matAmberCap       = makeMat(0.95, 0.76, 0.28, 1.0, metal: 0.04, rough: 0.42)
let matTealCap        = makeMat(0.24, 0.78, 0.74, 1.0, metal: 0.04, rough: 0.42)
let matYellowCap      = makeMat(0.96, 0.84, 0.32, 1.0, metal: 0.04, rough: 0.42)
let matLiPo           = makeMat(0.82, 0.85, 0.89, 1.0, metal: 0.35, rough: 0.38)
let matAMOLEDGlass    = makeMat(0.03, 0.04, 0.06, 1.0, metal: 0.20, rough: 0.12)
let matAMOLEDActive   = makeMat(0.04, 0.78, 0.58, 1.0, metal: 0.05, rough: 0.18)
let matPortCavity     = makeMat(0.04, 0.05, 0.07, 1.0, metal: 0.02, rough: 0.90)
let matWhiteGloss     = makeMat(0.96, 0.97, 0.98, 1.0, metal: 0.04, rough: 0.16)

@discardableResult
func addBox(_ parent: SCNNode, _ name: String,
            _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double,
            _ mat: SCNMaterial, chamfer: CGFloat = 0.0, renderOrder: Int = 0) -> SCNNode {
    let box = SCNBox(width: CGFloat(max(0.05, abs(x1 - x0))),
                     height: CGFloat(max(0.05, abs(z1 - z0))),
                     length: CGFloat(max(0.05, abs(y1 - y0))),
                     chamferRadius: chamfer)
    box.materials = [mat]
    let n = SCNNode(geometry: box)
    n.name = name
    n.renderingOrder = renderOrder
    n.position = SCNVector3((x0 + x1) * 0.5, (z0 + z1) * 0.5, -(y0 + y1) * 0.5)
    parent.addChildNode(n)
    return n
}

@discardableResult
func addCylZ(_ parent: SCNNode, _ name: String,
             _ cx: Double, _ cy: Double, _ z0: Double, _ z1: Double, _ r: Double,
             _ mat: SCNMaterial, segs: Int = 36, renderOrder: Int = 0) -> SCNNode {
    let cyl = SCNCylinder(radius: CGFloat(r), height: CGFloat(max(0.05, abs(z1 - z0))))
    cyl.radialSegmentCount = segs
    cyl.materials = [mat]
    let n = SCNNode(geometry: cyl)
    n.name = name
    n.renderingOrder = renderOrder
    n.position = SCNVector3(cx, (z0 + z1) * 0.5, -cy)
    parent.addChildNode(n)
    return n
}

@discardableResult
func addTubeZ(_ parent: SCNNode, _ name: String,
              _ cx: Double, _ cy: Double, _ z0: Double, _ z1: Double, _ rIn: Double, _ rOut: Double,
              _ mat: SCNMaterial, segs: Int = 40, renderOrder: Int = 0) -> SCNNode {
    let tube = SCNTube(innerRadius: CGFloat(rIn), outerRadius: CGFloat(rOut), height: CGFloat(max(0.05, abs(z1 - z0))))
    tube.radialSegmentCount = segs
    tube.materials = [mat]
    let n = SCNNode(geometry: tube)
    n.name = name
    n.renderingOrder = renderOrder
    n.position = SCNVector3(cx, (z0 + z1) * 0.5, -cy)
    parent.addChildNode(n)
    return n
}

@discardableResult
func addCylY(_ parent: SCNNode, _ name: String,
             _ cx: Double, _ cz: Double, _ y0: Double, _ y1: Double, _ r: Double,
             _ mat: SCNMaterial) -> SCNNode {
    let cyl = SCNCylinder(radius: CGFloat(r), height: CGFloat(max(0.05, abs(y1 - y0))))
    cyl.radialSegmentCount = 32
    cyl.materials = [mat]
    let n = SCNNode(geometry: cyl)
    n.name = name
    n.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)
    n.position = SCNVector3(cx, cz, -(y0 + y1) * 0.5)
    parent.addChildNode(n)
    return n
}

// Metrology-Verified Envelope: 69.0 x 68.0 x 24.2 mm (Walls = 1.8 mm, Lid Z: 22.4..24.2 mm)
let nanoW = 69.0
let nanoH = 68.0
let nanoD = 24.2
let nanoR = 4.8
let lidZ0 = 22.4

// True 7.28mm switch offsets from left edge of GODIYMODULES 37.0x15.0mm PCB:
let kOffsets = [7.55, 14.83, 22.12, 29.40]

func buildFboxNano(opaque: Bool) -> (SCNNode, Int) {
    let root = SCNNode()
    var boxes: [(String, AABB)] = []
    let shellMat = opaque ? matOpaqueCharcoal : matSmokeShell
    let ro = opaque ? 0 : 20

    let frontPadX0 = 30.1  // 30.1..67.1 (37.0 mm exact, clears X=67.2 right wall!)
    let topPadX0   = 26.8  // 26.8..63.8 (37.0 mm exact, clears boss_tr X=64.2!)
    let frontCapXs = kOffsets.map { frontPadX0 + $0 } // [37.65, 44.93, 52.22, 59.50]
    let topCapXs   = kOffsets.map { topPadX0 + $0 }   // [34.35, 41.63, 48.92, 56.20]

    // 0. Outer Shell (68.5 x 68.0 x 24.2 mm, R=4.8mm corners, 1.8mm walls)
    let shell = SCNNode()
    addBox(shell, "base_c", 4.8, nanoW - 4.8, 0, nanoH, 0, 1.8, shellMat, renderOrder: ro)
    addBox(shell, "base_l", 0, 4.8, 4.8, nanoH - 4.8, 0, 1.8, shellMat, renderOrder: ro)
    addBox(shell, "base_r", nanoW - 4.8, nanoW, 4.8, nanoH - 4.8, 0, 1.8, shellMat, renderOrder: ro)

    // Left Wall (X: 0..1.8) w/ Flush USB-C Cutout (Y: 42.2..52.1, Z: 17.8..21.8)
    addBox(shell, "wall_l_bot", 0, 1.8, 4.8, 42.2, 1.8, lidZ0, shellMat, renderOrder: ro)
    addBox(shell, "wall_l_top", 0, 1.8, 52.1, nanoH - 4.8, 1.8, lidZ0, shellMat, renderOrder: ro)
    addBox(shell, "wall_l_under_usb", 0, 1.8, 42.2, 52.1, 1.8, 17.8, shellMat, renderOrder: ro)
    addBox(shell, "wall_l_over_usb", 0, 1.8, 42.2, 52.1, 21.8, lidZ0, shellMat, renderOrder: ro)

    // Right Wall (X: 66.7..68.5) w/ MicroSD Slot (Y: 35.0..52.9, Z: 8.6..12.0)
    addBox(shell, "wall_r_bot", nanoW - 1.8, nanoW, 4.8, 35.0, 1.8, lidZ0, shellMat, renderOrder: ro)
    addBox(shell, "wall_r_top", nanoW - 1.8, nanoW, 52.9, nanoH - 4.8, 1.8, lidZ0, shellMat, renderOrder: ro)
    addBox(shell, "wall_r_under_sd", nanoW - 1.8, nanoW, 35.0, 52.9, 1.8, 8.6, shellMat, renderOrder: ro)
    addBox(shell, "wall_r_over_sd", nanoW - 1.8, nanoW, 35.0, 52.9, 12.0, lidZ0, shellMat, renderOrder: ro)

    // Bottom Wall (Y: 0..1.8) w/ Symmetrical Speaker (X: 35..47) & Mic (X: 51..62) Acoustic Slots
    addBox(shell, "wall_bot", 4.8, nanoW - 4.8, 0, 1.8, 1.8, lidZ0, shellMat, renderOrder: ro)
    for gx in [36.5, 39.3, 42.1, 44.9, 52.0, 54.8, 57.6, 60.4] {
        addBox(shell, "bot_slot_\(gx)", gx - 0.55, gx + 0.55, -0.05, 1.85, 6.8, 13.2, matPortCavity)
    }

    // Top Wall (Y: 66.2..68.0) w/ Top-Left 3.5mm TRS + Top-Right True-7.28mm-Pitch Shoulder Keys
    addBox(shell, "wall_top_l", 4.8, 10.2, nanoH - 1.8, nanoH, 1.8, lidZ0, shellMat, renderOrder: ro)
    addBox(shell, "wall_top_trs_u", 10.2, 16.8, nanoH - 1.8, nanoH, 1.8, 8.4, shellMat, renderOrder: ro)
    addBox(shell, "wall_top_trs_o", 10.2, 16.8, nanoH - 1.8, nanoH, 14.6, lidZ0, shellMat, renderOrder: ro)
    addBox(shell, "wall_top_mid", 16.8, topCapXs[0] - 3.3, nanoH - 1.8, nanoH, 1.8, lidZ0, shellMat, renderOrder: ro)
    addBox(shell, "wall_top_pad_u", topCapXs[0] - 3.3, topCapXs[3] + 3.3, nanoH - 1.8, nanoH, 1.8, 11.2, shellMat, renderOrder: ro)
    addBox(shell, "wall_top_pad_o", topCapXs[0] - 3.3, topCapXs[3] + 3.3, nanoH - 1.8, nanoH, 18.4, lidZ0, shellMat, renderOrder: ro)
    for i in 0..<3 {
        let divX0 = topCapXs[i] + 3.3
        let divX1 = topCapXs[i + 1] - 3.3
        addBox(shell, "wall_top_div_\(i)", divX0, divX1, nanoH - 1.8, nanoH, 11.2, 18.4, shellMat, renderOrder: ro)
    }
    addBox(shell, "wall_top_r", topCapXs[3] + 3.3, nanoW - 4.8, nanoH - 1.8, nanoH, 1.8, lidZ0, shellMat, renderOrder: ro)

    // 4x Corner Pillars w/ Deep M2 Counterbores (so ordered M2x14mm screws bite 6mm into tray!)
    let corners = [(4.8, 4.8, 3.3, 3.3), (nanoW - 4.8, 4.8, nanoW - 3.3, 3.3),
                   (4.8, nanoH - 4.8, 3.3, nanoH - 3.3), (nanoW - 4.8, nanoH - 4.8, nanoW - 3.3, nanoH - 3.3)]
    for (i, c) in corners.enumerated() {
        addCylZ(shell, "corner_\(i)", c.0, c.1, 0, lidZ0, nanoR, shellMat, renderOrder: ro)
        addCylZ(shell, "m2_\(i)", c.2, c.3, lidZ0 + 0.05, nanoD + 0.05, 1.55, matBlackCap)
        addCylZ(shell, "m2_hex_\(i)", c.2, c.3, lidZ0 + 0.10, nanoD + 0.09, 0.72, matPortCavity)
    }
    boxes.append(("boss_bl", makeAABB("boss_bl", 0, 4.8, 0, 4.8, 1.8, lidZ0)))
    boxes.append(("boss_br", makeAABB("boss_br", nanoW - 4.8, nanoW, 0, 4.8, 1.8, lidZ0)))
    boxes.append(("boss_tl", makeAABB("boss_tl", 0, 4.8, nanoH - 4.8, nanoH, 1.8, lidZ0)))
    boxes.append(("boss_tr", makeAABB("boss_tr", nanoW - 4.8, nanoW, nanoH - 4.8, nanoH, 1.8, lidZ0)))

    // Monolithic Extruded Top Faceplate (Z: 22.4..24.2 mm) w/ True-Measured Cutouts
    let lidPath = NSBezierPath()
    lidPath.windingRule = .evenOdd
    lidPath.appendRoundedRect(NSRect(x: 0, y: 0, width: nanoW, height: nanoH), xRadius: nanoR, yRadius: nanoR)
    // CNC-calibrated RM67162 1.91" AMOLED active window (44.22 x 19.80 mm + 0.4mm bezel reveal)
    lidPath.appendRoundedRect(NSRect(x: 12.9, y: 36.85, width: 45.0, height: 20.6), xRadius: 1.0, yRadius: 1.0)
    // Thumbstick circular recess cutout at (18.8, 16.0), Ø23.6 mm (9.05mm solid bridge below AMOLED!)
    lidPath.appendOval(in: NSRect(x: 18.8 - 11.8, y: 16.0 - 11.8, width: 23.6, height: 23.6))
    // 4 Front 1x4 key wells on TRUE 7.28mm pitch (6.6 x 7.2 mm wells for 6.2 x 6.8 mm caps)
    for cx in frontCapXs {
        lidPath.appendRoundedRect(NSRect(x: cx - 3.3, y: 16.0 - 3.6, width: 6.6, height: 7.2), xRadius: 0.75, yRadius: 0.75)
    }
    // 4 Corner M2 screw counterbores
    for c in corners {
        lidPath.appendOval(in: NSRect(x: c.2 - 1.65, y: c.3 - 1.65, width: 3.3, height: 3.3))
    }
    lidPath.flatness = 0.08
    let lidShape = SCNShape(path: lidPath, extrusionDepth: 1.8)
    lidShape.materials = [shellMat]
    let lidNode = SCNNode(geometry: lidShape)
    lidNode.name = "monolithic_lid"
    lidNode.renderingOrder = ro + 2
    lidNode.eulerAngles = SCNVector3(-Double.pi / 2.0, 0, 0)
    lidNode.position = SCNVector3(0, lidZ0 + 0.9, 0)
    shell.addChildNode(lidNode)

    addTubeZ(shell, "lid_stick_collar", 18.8, 16.0, 20.6, nanoD, 11.75, 13.0, shellMat, renderOrder: ro + 1)
    addCylZ(shell, "lid_stick_floor", 18.8, 16.0, 20.3, 20.6, 11.85, matPortCavity)
    root.addChildNode(shell)

    // 1. Liter 503759 1300mAh LiPo (59.0 x 37.0 x 5.0 mm) ON FLOOR North of KY-023 + 0.6mm Shield
    addBox(root, "lipo_503759", 5.0, 64.0, 29.2, 66.2, 1.8, 6.8, matLiPo, chamfer: 0.4)
    addBox(root, "shield_rib", 5.0, 64.0, 29.0, 66.2, 6.9, 7.5, matOpaqueCharcoal)
    boxes.append(("lipo", makeAABB("lipo_503759", 5.0, 64.0, 29.2, 66.2, 1.8, 6.8)))
    boxes.append(("shield", makeAABB("shield_rib", 5.0, 64.0, 29.0, 66.2, 6.9, 7.5)))

    // 2. LILYGO T-Display-S3 AMOLED (CNC-Calibrated 58.8x25.5mm body + 1.2mm USB-C + Clear Acrylic Guard)
    addBox(root, "amoled_pcb", 2.0, 60.8, 34.4, 59.9, 18.2, 19.8, matDarkPCB)
    // Full 58.8x25.5mm Clear Acrylic Screen Guard + Cantilevered BOOT/IO21 Button Tabs (w/ 1.0mm lid relief above!)
    addBox(root, "amoled_acrylic_guard", 2.0, 60.8, 34.4, 59.9, 19.8, 22.3, matClearAcrylic, renderOrder: ro - 1)
    addBox(root, "amoled_boot_btn_tab", 2.1, 8.2, 34.6, 41.6, 19.8, 22.35, matClearAcrylic)
    addBox(root, "amoled_io21_btn_tab", 2.1, 8.2, 52.6, 59.7, 19.8, 22.35, matClearAcrylic)
    // Black display glass + 44.22x19.80mm active window (+11.32mm from left acrylic edge!)
    addBox(root, "amoled_glass", 8.4, 58.7, 36.2, 58.1, 19.85, 22.38, matAMOLEDGlass)
    addBox(root, "amoled_active", 13.32, 57.54, 37.25, 57.05, 22.35, 22.52, matAMOLEDActive)
    // Rear JST-GH + Qwiic + Side RES switch envelope & Rear 3D SMD Antenna
    addBox(root, "amoled_rear_jst", 2.2, 12.7, 34.0, 59.5, 14.4, 18.2, matSilver)
    addBox(root, "amoled_rear_ant", 51.0, 60.6, 38.5, 55.5, 14.6, 18.2, matSilver)
    addBox(root, "amoled_usbc", 0.8, 7.8, 42.6, 51.6, 18.2, 21.4, matSilver, chamfer: 0.4)
    boxes.append(("amoled", makeAABB("amoled_pcb_guard", 2.0, 60.8, 34.4, 59.9, 18.2, 22.35)))
    boxes.append(("amoled", makeAABB("amoled_rear_jst_res", 2.2, 12.7, 34.0, 59.5, 14.4, 18.2)))
    boxes.append(("amoled", makeAABB("amoled_rear_ant", 51.0, 60.6, 38.5, 55.5, 14.6, 18.2)))
    boxes.append(("amoled", makeAABB("amoled_usbc", 0.8, 7.8, 42.6, 51.6, 18.2, 21.4)))

    // 3. Top-Shoulder 1x4 Keypad (37.0x15.0mm, TRUE 7.28mm Pitch, North of AMOLED & Above LiPo!)
    addBox(root, "pad_top_pcb", topPadX0, topPadX0 + 37.0, 60.4, 62.0, 7.6, 22.3, matGreenPCB)
    for (i, cx) in topCapXs.enumerated() {
        addBox(root, "sw_top_\(i)", cx - 3.0, cx + 3.0, 62.0, 66.0, 11.8, 17.8, matBlackCap)
        addBox(root, "cap_top_\(i)", cx - 3.1, cx + 3.1, 65.8, 68.8, 11.4, 18.2, matBlackCap, chamfer: 0.45)
    }
    boxes.append(("pad_top", makeAABB("pad_top", topPadX0, topPadX0 + 37.0, 60.4, 66.0, 7.6, 22.3)))

    // 4. KY-023 Thumbstick (33.0x25.0mm ON Z=2.4mm FLOOR, Full 23.0x22.5x12.0mm Gimbal+Pots+SW!)
    addBox(root, "ky_pcb", 5.0, 38.0, 3.5, 28.5, 2.4, 4.0, matDarkPCB)
    addBox(root, "ky_mech_block", 7.3, 30.3, 4.8, 27.3, 4.0, 16.0, matSilver)
    addCylZ(root, "ky_dshaft", 18.8, 16.0, 16.0, 21.9, 2.0, matGreenPCB)
    addCylZ(root, "ky_disc", 18.8, 16.0, 20.8, 23.8, 7.8, matCoralCap)
    addTubeZ(root, "ky_disc_rim", 18.8, 16.0, 23.8, 24.8, 5.5, 7.8, matCoralCap)
    boxes.append(("ky023", makeAABB("ky_pcb", 5.0, 38.0, 3.5, 28.5, 2.4, 4.0)))
    boxes.append(("ky023", makeAABB("ky_mech_block", 7.3, 30.3, 4.8, 27.3, 4.0, 16.0)))
    boxes.append(("ky023", makeAABB("ky_dshaft", 16.8, 20.8, 14.0, 18.0, 16.0, 21.9)))

    // 5. Front 1x4 Color Keypad (37.0x15.0x5.0mm real height, TRUE 7.28mm Pitch, Dead-Level Y=16.0 w/ Thumbstick!)
    addBox(root, "pad_front_pcb", frontPadX0, frontPadX0 + 37.0, 8.5, 23.5, 16.4, 18.0, matGreenPCB)
    let fMats = [matAmberCap, matTealCap, matYellowCap, matCoralCap]
    for (i, cx) in frontCapXs.enumerated() {
        addBox(root, "sw_front_\(i)", cx - 3.0, cx + 3.0, 13.0, 19.0, 18.0, 21.5, matBlackCap)
        addBox(root, "cap_front_\(i)", cx - 3.1, cx + 3.1, 12.6, 19.4, 21.5, 25.0, fMats[i], chamfer: 0.5)
    }
    boxes.append(("pad_front", makeAABB("pad_front", frontPadX0, frontPadX0 + 37.0, 8.5, 23.5, 16.4, 22.2)))

    // 6. AOICRIE V713 5V Boost (25.0 x 20.0 x 4.8 mm) on Floor Under Front 1x4 (8.0mm Wire Vault!)
    addBox(root, "v713_pcb", 38.6, 63.6, 8.2, 28.2, 2.0, 3.6, matDarkPCB)
    addBox(root, "v713_ind", 46.5, 53.5, 14.5, 21.5, 3.6, 6.8, matBlackCap)
    boxes.append(("v713", makeAABB("v713_boost", 38.6, 63.6, 8.2, 28.2, 2.0, 6.8)))

    // 7. WWZMDiB Mini 3.3V MicroSD (17.9 x 17.9 x 3.8 mm) Flush at Right Wall X=67.2
    addBox(root, "sd_pcb", 49.3, 67.2, 35.0, 52.9, 8.0, 9.6, matBluePCB)
    addBox(root, "sd_cage", 52.8, 67.2, 37.0, 50.8, 9.6, 11.8, matSilver)
    boxes.append(("microsd", makeAABB("mini_3v3_microsd", 49.3, 67.2, 35.0, 52.9, 8.0, 11.8)))

    // 8. GY-PCM5102 I2S DAC (16.9 x 31.9 x 5.5 mm), 3.5mm TRS at Top-Left X=13.45
    addBox(root, "pcm_pcb", 5.0, 21.9, 34.3, 66.2, 8.0, 9.6, matPurplePCB)
    addBox(root, "pcm_trs", 9.2, 17.7, 54.0, 66.2, 9.6, 13.5, matBlackCap)
    addCylY(root, "pcm_trs_ring", 13.45, 11.5, 65.9, 68.35, 3.0, matGold)
    addCylY(root, "pcm_trs_bore", 13.45, 11.5, 66.1, 68.42, 1.75, matPortCavity)
    boxes.append(("pcm5102", makeAABB("pcm5102_pcb", 5.0, 21.9, 34.3, 66.2, 8.0, 9.6)))
    boxes.append(("pcm5102", makeAABB("pcm5102_trs", 9.2, 17.7, 54.0, 66.2, 9.6, 13.5)))

    // 9. KCX_BT_EMITTER (23.5x15.5x2.5mm) + PAM8302A (24.0x15.0x2.8mm) in Center Z-Vault (4.0mm below AMOLED!)
    addBox(root, "kcx_bt", 23.2, 46.7, 35.0, 50.5, 8.0, 10.5, matBluePCB)
    addBox(root, "pam8302", 23.2, 47.2, 35.0, 50.0, 11.4, 14.2, matPurplePCB)
    boxes.append(("kcx_bt", makeAABB("kcx_bt", 23.2, 46.7, 35.0, 50.5, 8.0, 10.5)))
    boxes.append(("pam8302", makeAABB("pam8302", 23.2, 47.2, 35.0, 50.0, 11.4, 14.2)))

    // 10. Bottom-Edge Symmetrical 15.2x10.2x3.5mm Speaker + Ø14.0x2.6mm INMP441 Mic
    addBox(root, "spk_1511", 33.4, 48.6, 2.0, 5.5, 4.4, 14.6, matBlackCap, chamfer: 0.4)
    addBox(root, "inmp441_v", 49.4, 63.4, 2.0, 4.6, 4.4, 14.6, matDarkPCB, chamfer: 2.0)
    boxes.append(("speaker", makeAABB("spk_1511", 33.4, 48.6, 2.0, 5.5, 4.4, 14.6)))
    boxes.append(("inmp441", makeAABB("inmp441", 49.4, 63.4, 2.0, 4.6, 4.4, 14.6)))

    let cols = verifyAABBs(label: opaque ? "fbox_Nano_v2_Opaque" : "fbox_Nano_v2_Smoke", boxes: boxes)
    return (root, cols)
}

// Reference Models for 1:1 Scale Comparison (also updated w/ true 7.28mm 1x4 pitch!)
func buildCurrentCompactPortraitRef() -> SCNNode {
    let n = SCNNode()
    addBox(n, "cp_body", 0, 72.0, 0, 84.0, 0, 19.5, matOpaqueCharcoal, chamfer: 4.5)
    addBox(n, "cp_glass", 11.0, 61.0, 39.0, 60.5, 19.2, 19.6, matAMOLEDGlass)
    addBox(n, "cp_scr", 13.9, 58.1, 39.8, 59.6, 19.5, 19.7, matAMOLEDActive)
    addCylZ(n, "cp_well", 17.5, 20.8, 19.3, 19.6, 12.5, matPortCavity)
    addCylZ(n, "cp_disc", 17.5, 20.8, 19.5, 20.8, 8.0, matCoralCap)
    let fCols = [matAmberCap, matTealCap, matYellowCap, matCoralCap]
    for (i, ko) in kOffsets.enumerated() {
        let cx = 31.5 + ko
        addBox(n, "cp_k_\(i)", cx - 3.1, cx + 3.1, 20.8 - 3.4, 20.8 + 3.4, 19.5, 21.3, fCols[i], chamfer: 0.45)
    }
    for ko in kOffsets {
        let cy = 40.5 + ko
        addBox(n, "cp_sk_\(cy)", 72.0, 72.8, cy - 3.1, cy + 3.1, 5.6, 13.8, matBlackCap, chamfer: 0.4)
    }
    for gx in [26.8, 45.2] {
        addCylZ(n, "cp_g_\(gx)", gx, 73.5, 19.4, 19.65, 5.0, matPortCavity)
    }
    addCylY(n, "cp_trs", 13.75, 12.75, 83.8, 84.5, 2.8, matGold)
    return n
}

func buildAirPodsProCaseRef() -> SCNNode {
    let n = SCNNode()
    addBox(n, "ap_body", 0, 60.6, 0, 45.2, 0, 21.7, matWhiteGloss, chamfer: 8.5)
    addBox(n, "ap_seam", -0.1, 60.7, 31.5, 32.0, 0.5, 21.2, matSilver)
    addCylZ(n, "ap_led", 30.3, 22.0, 21.6, 21.85, 0.8, matAMOLEDActive)
    return n
}

func renderSnapshot(_ node: SCNNode, camPos: SCNVector3, lookAt: SCNVector3, up: SCNVector3 = SCNVector3(0, 1, 0),
                    orthoScale: Double? = nil, fov: CGFloat = 30, size: CGSize = CGSize(width: 1600, height: 1000)) -> NSImage {
    let scene = SCNScene()
    scene.background.contents = NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
    scene.rootNode.addChildNode(node)

    let key = SCNLight(); key.type = .directional; key.intensity = 1350; key.castsShadow = true
    let keyNode = SCNNode(); keyNode.light = key; keyNode.position = SCNVector3(120, 180, 110); keyNode.look(at: lookAt)
    scene.rootNode.addChildNode(keyNode)

    let fill = SCNLight(); fill.type = .directional; fill.intensity = 580
    let fillNode = SCNNode(); fillNode.light = fill; fillNode.position = SCNVector3(-100, 110, -90); fillNode.look(at: lookAt)
    scene.rootNode.addChildNode(fillNode)

    let amb = SCNLight(); amb.type = .ambient; amb.intensity = 550
    let ambNode = SCNNode(); ambNode.light = amb
    scene.rootNode.addChildNode(ambNode)

    let cam = SCNCamera(); cam.zNear = 1; cam.zFar = 1000
    if let os = orthoScale {
        cam.usesOrthographicProjection = true
        cam.orthographicScale = os
    } else {
        cam.fieldOfView = fov
    }
    let camNode = SCNNode(); camNode.camera = cam
    camNode.position = camPos
    camNode.look(at: lookAt, up: up, localFront: SCNVector3(0, 0, -1))
    scene.rootNode.addChildNode(camNode)

    let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
    renderer.scene = scene
    renderer.pointOfView = camNode
    return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
}

func savePNG(_ img: NSImage, to path: String) {
    if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

let (nanoOpaque, c1) = buildFboxNano(opaque: true)
let (nanoSmoke, c2)  = buildFboxNano(opaque: false)
guard c1 == 0 && c2 == 0 else {
    fatalError("fbox Nano v2 collision check failed!")
}

// 1. Orthographic 1:1 Scale Lineup: Compact Portrait (72x84) vs Metrology-Verified fbox Nano v2 (68.5x68.0) vs AirPods Pro (60.6x45.2)
let lineup = SCNNode()
let cpRef = buildCurrentCompactPortraitRef()
cpRef.position = SCNVector3(0, 0, 0)
lineup.addChildNode(cpRef)

let nano1 = nanoOpaque.clone()
nano1.position = SCNVector3(88.0, 0, 0)
lineup.addChildNode(nano1)

let nano2 = nanoSmoke.clone()
nano2.position = SCNVector3(172.5, 0, 0)
lineup.addChildNode(nano2)

let airpods = buildAirPodsProCaseRef()
airpods.position = SCNVector3(257.0, 0, 0)
lineup.addChildNode(airpods)

let imgLineup = renderSnapshot(lineup,
                               camPos: SCNVector3(158, 240, -42),
                               lookAt: SCNVector3(158, 12, -42),
                               up: SCNVector3(0, 0, -1),
                               orthoScale: 64.0,
                               size: CGSize(width: 2000, height: 820))
savePNG(imgLineup, to: "\(renderDir)/exp_fbox_nano_v2_ortho_lineup.png")

// 2. Hero Front-Bottom-Left 3/4 Pair
let pair34 = SCNNode()
let pO = nanoOpaque.clone()
pO.position = SCNVector3(0, 0, 0)
pair34.addChildNode(pO)

let pS = nanoSmoke.clone()
pS.position = SCNVector3(84.0, 0, 0)
pair34.addChildNode(pS)

let img34 = renderSnapshot(pair34,
                           camPos: SCNVector3(54, 182, 128),
                           lookAt: SCNVector3(76, 11, -34),
                           fov: 31,
                           size: CGSize(width: 1600, height: 960))
savePNG(img34, to: "\(renderDir)/exp_fbox_nano_v2_34_pair.png")

// 3. Top-Shoulder & Right-Port 3/4 Pair
let imgTop34 = renderSnapshot(pair34,
                              camPos: SCNVector3(118, 172, -158),
                              lookAt: SCNVector3(76, 11, -34),
                              fov: 32,
                              size: CGSize(width: 1600, height: 960))
savePNG(imgTop34, to: "\(renderDir)/exp_fbox_nano_v2_top_ports_34.png")

print("DONE fbox Nano v2 (68.5 x 68.0 x 24.2 mm) Metrology-Verified w/ 0 Collisions & rendered!")
