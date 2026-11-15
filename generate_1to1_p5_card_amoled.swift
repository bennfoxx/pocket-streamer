import Foundation
import SceneKit
import AppKit
import Metal

// MARK: - Paths & Output Directories
let rootDir = "/Users/benfox/Development/3D Design/Pocket Streamer Hardware CAD"
let usdzDir = "\(rootDir)/parts_1to1_3d/usdz"
let renderDir = "\(rootDir)/parts_1to1_3d/renders"
let stlDir = "\(rootDir)/stl_p5_card"
let artifactDir = "/Users/benfox/.gemini/antigravity/brain/d773b1b3-4405-4408-8ad7-b59f103e4218"

try FileManager.default.createDirectory(atPath: usdzDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: renderDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: stlDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: artifactDir, withIntermediateDirectories: true)

// MARK: - Collision AABB Helpers (CAD: +X Right, +Y Up/Top, +Z Front)
struct AABB {
    let name: String
    let minX, maxX: Double
    let minY, maxY: Double
    let minZ, maxZ: Double

    func overlaps(_ o: AABB, eps: Double = 0.05) -> (Bool, Double, String) {
        let ox = min(maxX, o.maxX) - max(minX, o.minX)
        let oy = min(maxY, o.maxY) - max(minY, o.minY)
        let oz = min(maxZ, o.maxZ) - max(minZ, o.minZ)
        let hit = (ox > eps) && (oy > eps) && (oz > eps)
        let detail = String(format: "dx=%.2f dy=%.2f dz=%.2f", ox, oy, oz)
        return (hit, min(ox, min(oy, oz)), detail)
    }
}

func makeAABB(_ name: String, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double) -> AABB {
    return AABB(name: name, minX: min(x0, x1), maxX: max(x0, x1),
                minY: min(y0, y1), maxY: max(y0, y1),
                minZ: min(z0, z1), maxZ: max(z0, z1))
}

func verifyAABBs(label: String, boxes: [(String, AABB)]) -> Int {
    var collisions = 0
    for i in 0..<boxes.count {
        for j in (i + 1)..<boxes.count {
            let (g1, a) = boxes[i]
            let (g2, b) = boxes[j]
            if g1 == g2 { continue }
            let (hit, _, detail) = a.overlaps(b)
            if hit {
                collisions += 1
                print("COLLISION [\(label)] \(g1):\(a.name) <-> \(g2):\(b.name) [\(detail)]")
            }
        }
    }
    print("CHECK [\(label)] boxes=\(boxes.count) Collisions=\(collisions)")
    return collisions
}

// MARK: - Binary STL Mesh Builder (1 mm units, watertight boxes & cylinders)
struct Tri {
    let v1, v2, v3: SIMD3<Float>
}

class STLMesh {
    var tris: [Tri] = []

    func addQuad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
        tris.append(Tri(v1: a, v2: b, v3: c))
        tris.append(Tri(v1: a, v2: c, v3: d))
    }

    func addBox(_ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double) {
        let fx0 = Float(min(x0, x1)), fx1 = Float(max(x0, x1))
        let fy0 = Float(min(y0, y1)), fy1 = Float(max(y0, y1))
        let fz0 = Float(min(z0, z1)), fz1 = Float(max(z0, z1))
        let p000 = SIMD3<Float>(fx0, fy0, fz0), p100 = SIMD3<Float>(fx1, fy0, fz0)
        let p110 = SIMD3<Float>(fx1, fy1, fz0), p010 = SIMD3<Float>(fx0, fy1, fz0)
        let p001 = SIMD3<Float>(fx0, fy0, fz1), p101 = SIMD3<Float>(fx1, fy0, fz1)
        let p111 = SIMD3<Float>(fx1, fy1, fz1), p011 = SIMD3<Float>(fx0, fy1, fz1)
        addQuad(p000, p010, p110, p100)
        addQuad(p001, p101, p111, p011)
        addQuad(p000, p100, p101, p001)
        addQuad(p110, p010, p011, p111)
        addQuad(p010, p000, p001, p011)
        addQuad(p100, p110, p111, p101)
    }

    func addCylinderZ(cx: Double, cy: Double, r: Double, z0: Double, z1: Double, segs: Int = 40) {
        let fz0 = Float(z0), fz1 = Float(z1)
        let c0 = SIMD3<Float>(Float(cx), Float(cy), fz0)
        let c1 = SIMD3<Float>(Float(cx), Float(cy), fz1)
        for i in 0..<segs {
            let a0 = Double(i) * 2.0 * .pi / Double(segs)
            let a1 = Double(i + 1) * 2.0 * .pi / Double(segs)
            let x0 = Float(cx + r * cos(a0)), y0 = Float(cy + r * sin(a0))
            let x1 = Float(cx + r * cos(a1)), y1 = Float(cy + r * sin(a1))
            let b0 = SIMD3<Float>(x0, y0, fz0), b1 = SIMD3<Float>(x1, y1, fz0)
            let t0 = SIMD3<Float>(x0, y0, fz1), t1 = SIMD3<Float>(x1, y1, fz1)
            tris.append(Tri(v1: c0, v2: b1, v3: b0))
            tris.append(Tri(v1: c1, v2: t0, v3: t1))
            addQuad(b0, b1, t1, t0)
        }
    }

    func addAnnulusZ(cx: Double, cy: Double, rIn: Double, rOut: Double, z0: Double, z1: Double, segs: Int = 48) {
        let fz0 = Float(z0), fz1 = Float(z1)
        for i in 0..<segs {
            let a0 = Double(i) * 2.0 * .pi / Double(segs)
            let a1 = Double(i + 1) * 2.0 * .pi / Double(segs)
            let ix0 = Float(cx + rIn * cos(a0)), iy0 = Float(cy + rIn * sin(a0))
            let ix1 = Float(cx + rIn * cos(a1)), iy1 = Float(cy + rIn * sin(a1))
            let ox0 = Float(cx + rOut * cos(a0)), oy0 = Float(cy + rOut * sin(a0))
            let ox1 = Float(cx + rOut * cos(a1)), oy1 = Float(cy + rOut * sin(a1))
            let bi0 = SIMD3<Float>(ix0, iy0, fz0), bi1 = SIMD3<Float>(ix1, iy1, fz0)
            let bo0 = SIMD3<Float>(ox0, oy0, fz0), bo1 = SIMD3<Float>(ox1, oy1, fz0)
            let ti0 = SIMD3<Float>(ix0, iy0, fz1), ti1 = SIMD3<Float>(ix1, iy1, fz1)
            let to0 = SIMD3<Float>(ox0, oy0, fz1), to1 = SIMD3<Float>(ox1, oy1, fz1)
            addQuad(bi0, bi1, bo1, bo0)
            addQuad(ti0, to0, to1, ti1)
            addQuad(bo0, bo1, to1, to0)
            addQuad(bi1, bi0, ti0, ti1)
        }
    }

    func mirrorYInPlace(yMax: Double) {
        let fy = Float(yMax)
        tris = tris.map { t in
            let p1 = SIMD3<Float>(t.v1.x, fy - t.v1.y, t.v1.z)
            let p2 = SIMD3<Float>(t.v2.x, fy - t.v2.y, t.v2.z)
            let p3 = SIMD3<Float>(t.v3.x, fy - t.v3.y, t.v3.z)
            // Reflection flips winding order; swap v2/v3 to preserve outward normals.
            return Tri(v1: p1, v2: p3, v3: p2)
        }
    }

    func appendOffset(from other: STLMesh, dx: Double, dy: Double, dz: Double = 0.0) {
        let delta = SIMD3<Float>(Float(dx), Float(dy), Float(dz))
        for t in other.tris {
            tris.append(Tri(v1: t.v1 + delta, v2: t.v2 + delta, v3: t.v3 + delta))
        }
    }

    func writeBinarySTL(to path: String, header: String) throws {
        var data = Data(count: 80)
        let hdrBytes = Array(header.utf8.prefix(79))
        data.replaceSubrange(0..<hdrBytes.count, with: hdrBytes)
        var count = UInt32(tris.count).littleEndian
        data.append(Data(bytes: &count, count: 4))

        for t in tris {
            let e1 = t.v2 - t.v1
            let e2 = t.v3 - t.v1
            let nrm = simd_normalize(simd_cross(e1, e2))
            let vals: [Float] = [
                nrm.x.isNaN ? 0 : nrm.x, nrm.y.isNaN ? 0 : nrm.y, nrm.z.isNaN ? 1 : nrm.z,
                t.v1.x, t.v1.y, t.v1.z,
                t.v2.x, t.v2.y, t.v2.z,
                t.v3.x, t.v3.y, t.v3.z
            ]
            for i in 0..<vals.count {
                var bits = vals[i].bitPattern.littleEndian
                data.append(Data(bytes: &bits, count: 4))
            }
            var attr: UInt16 = 0
            data.append(Data(bytes: &attr, count: 2))
        }
        try data.write(to: URL(fileURLWithPath: path))
    }
}

// MARK: - SceneKit CAD Mapping: scnX = cadX, scnY = cadZ, scnZ = -cadY
@discardableResult
func addBox(_ parent: SCNNode, _ name: String,
            _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double,
            _ mat: SCNMaterial, chamfer: CGFloat = 0.0, renderOrder: Int = 0) -> SCNNode {
    let w = max(0.05, abs(x1 - x0))
    let h = max(0.05, abs(y1 - y0))
    let d = max(0.05, abs(z1 - z0))
    let box = SCNBox(width: CGFloat(w), height: CGFloat(d), length: CGFloat(h), chamferRadius: chamfer)
    box.materials = [mat]
    let node = SCNNode(geometry: box)
    node.name = name
    node.renderingOrder = renderOrder
    node.position = SCNVector3((x0 + x1) * 0.5, (z0 + z1) * 0.5, -(y0 + y1) * 0.5)
    parent.addChildNode(node)
    return node
}

@discardableResult
func addCylZ(_ parent: SCNNode, _ name: String,
             _ cx: Double, _ cy: Double, _ z0: Double, _ z1: Double, _ radius: Double,
             _ mat: SCNMaterial, radialSegs: Int = 36) -> SCNNode {
    let cyl = SCNCylinder(radius: CGFloat(radius), height: CGFloat(max(0.05, abs(z1 - z0))))
    cyl.radialSegmentCount = radialSegs
    cyl.materials = [mat]
    let node = SCNNode(geometry: cyl)
    node.name = name
    node.position = SCNVector3(cx, (z0 + z1) * 0.5, -cy)
    parent.addChildNode(node)
    return node
}

@discardableResult
func addTubeZ(_ parent: SCNNode, _ name: String,
              _ cx: Double, _ cy: Double, _ z0: Double, _ z1: Double, _ rIn: Double, _ rOut: Double,
              _ mat: SCNMaterial, radialSegs: Int = 48) -> SCNNode {
    let tube = SCNTube(innerRadius: CGFloat(rIn), outerRadius: CGFloat(rOut), height: CGFloat(max(0.05, abs(z1 - z0))))
    tube.radialSegmentCount = radialSegs
    tube.materials = [mat]
    let node = SCNNode(geometry: tube)
    node.name = name
    node.position = SCNVector3(cx, (z0 + z1) * 0.5, -cy)
    parent.addChildNode(node)
    return node
}

@discardableResult
func addCylY(_ parent: SCNNode, _ name: String,
             _ cx: Double, _ cz: Double, _ y0: Double, _ y1: Double, _ radius: Double,
             _ mat: SCNMaterial) -> SCNNode {
    let cyl = SCNCylinder(radius: CGFloat(radius), height: CGFloat(max(0.05, abs(y1 - y0))))
    cyl.radialSegmentCount = 28
    cyl.materials = [mat]
    let node = SCNNode(geometry: cyl)
    node.name = name
    node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
    node.position = SCNVector3(cx, cz, -(y0 + y1) * 0.5)
    parent.addChildNode(node)
    return node
}

// MARK: - Materials
func makeMat(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0, metal: CGFloat = 0.1, rough: CGFloat = 0.45) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    m.metalness.contents = metal
    m.roughness.contents = rough
    if a < 0.99 { m.transparencyMode = .aOne; m.isDoubleSided = true }
    return m
}

let matSmokeShell = makeMat(0.18, 0.20, 0.24, 0.34, metal: 0.05, rough: 0.25)
let matOpaqueCharcoal = makeMat(0.16, 0.17, 0.19, 1.0, metal: 0.06, rough: 0.65)
let matOpaqueBezel = makeMat(0.12, 0.13, 0.15, 1.0, metal: 0.08, rough: 0.55)
let matDarkPCB = makeMat(0.08, 0.09, 0.11, 1.0, metal: 0.15, rough: 0.55)
let matPurplePCB = makeMat(0.32, 0.14, 0.42, 1.0, metal: 0.15, rough: 0.50)
let matBluePCB = makeMat(0.07, 0.24, 0.55, 1.0, metal: 0.15, rough: 0.50)
let matGreenPCB = makeMat(0.08, 0.42, 0.22, 1.0, metal: 0.15, rough: 0.55)
let matBlackCap = makeMat(0.10, 0.10, 0.12, 1.0, metal: 0.05, rough: 0.50)
let matCoralCap = makeMat(0.95, 0.42, 0.34, 1.0, metal: 0.05, rough: 0.42)
let matTealCap = makeMat(0.16, 0.68, 0.66, 1.0, metal: 0.05, rough: 0.42)
let matAmberCap = makeMat(0.94, 0.66, 0.20, 1.0, metal: 0.05, rough: 0.42)
let matSilver = makeMat(0.76, 0.78, 0.81, 1.0, metal: 0.88, rough: 0.22)
let matPortCavity = makeMat(0.03, 0.03, 0.04, 1.0, metal: 0.10, rough: 0.80)
let matLiPo = makeMat(0.82, 0.84, 0.86, 1.0, metal: 0.65, rough: 0.32)
let matGold = makeMat(0.86, 0.68, 0.24, 1.0, metal: 0.90, rough: 0.22)
let matAMOLEDGlass = makeMat(0.03, 0.03, 0.05, 1.0, metal: 0.10, rough: 0.10)
let matAMOLEDActive: SCNMaterial = {
    let m = makeMat(0.04, 0.14, 0.20, 1.0, metal: 0.0, rough: 0.15)
    m.emission.contents = NSColor(calibratedRed: 0.12, green: 0.72, blue: 0.48, alpha: 1.0)
    return m
}()
let matCardWhite = makeMat(0.95, 0.95, 0.94, 1.0, metal: 0.02, rough: 0.55)
let matCardRed = makeMat(0.78, 0.14, 0.16, 1.0, metal: 0.04, rough: 0.50)
let matCradle = makeMat(0.24, 0.48, 0.72, 1.0, metal: 0.08, rough: 0.45)
let matBuildPlate = makeMat(0.14, 0.16, 0.19, 1.0, metal: 0.15, rough: 0.70)
let matGridLine = makeMat(0.32, 0.36, 0.42, 1.0, metal: 0.05, rough: 0.60)

// MARK: - Build Complete Segmented Shell & Faceplate (With All Port Cutouts + Internal Cradles)
func buildShellAndLid(shellMat: SCNMaterial, cradleMat: SCNMaterial, dzShellBot: Double, dzLid: Double, renderOrder: Int) -> (SCNNode, SCNNode) {
    let tray = SCNNode()
    tray.name = "p5_bottom_tray"
    // Back plate (72.0 x 98.0 x 1.8 mm)
    addBox(tray, "back_plate", 0, 72.0, 0, 98.0, 0 + dzShellBot, 1.8 + dzShellBot, shellMat, chamfer: 0.4, renderOrder: renderOrder)

    // Left Wall (X: 0..1.8) with AMOLED USB-C Cutout (Y: 54.0..64.4, Z: 11.6..15.6)
    addBox(tray, "wall_left_bot", 0, 1.8, 0, 54.0, 1.8 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_left_top", 0, 1.8, 64.4, 98.0, 1.8 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_left_under_usbc", 0, 1.8, 54.0, 64.4, 1.8 + dzShellBot, 11.6 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_left_over_usbc", 0, 1.8, 54.0, 64.4, 15.6 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)

    // Right Wall (X: 70.2..72.0) with MicroSD Push-Push Slot Cutout (Y: 75.5..90.0, Z: 10.6..14.2)
    addBox(tray, "wall_right_bot", 70.2, 72.0, 0, 75.5, 1.8 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_top", 70.2, 72.0, 90.0, 98.0, 1.8 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_under_sd", 70.2, 72.0, 75.5, 90.0, 1.8 + dzShellBot, 10.6 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_over_sd", 70.2, 72.0, 75.5, 90.0, 14.2 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)

    // Bottom Wall (Y: 0..1.8)
    addBox(tray, "wall_bot", 1.8, 70.2, 0, 1.8, 1.8 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)

    // Top Wall (Y: 96.2..98.0) with:
    //  - 3.5mm TRS Jack Opening (X: 11.0..17.5, Z: 10.0..16.2)
    //  - Boost USB-C Charge Port Opening (X: 35.1..45.5, Z: 3.2..7.2)
    addBox(tray, "wall_top_left", 1.8, 11.0, 96.2, 98.0, 1.8 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_under_trs", 11.0, 17.5, 96.2, 98.0, 1.8 + dzShellBot, 10.0 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_mid", 17.5, 35.1, 96.2, 98.0, 1.8 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_under_boost", 35.1, 45.5, 96.2, 98.0, 1.8 + dzShellBot, 3.2 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_over_boost", 35.1, 45.5, 96.2, 98.0, 7.2 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_right", 45.5, 70.2, 96.2, 98.0, 1.8 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)

    // 4x Hollow M2 Corner Screw Bosses (3.6 x 3.6 mm with 2.0 x 2.0 mm pilot bore above Z=4.2)
    for (idx, (bx0, by0)) in [(1.8, 1.8), (66.6, 1.8), (1.8, 92.6), (66.6, 92.6)].enumerated() {
        let bx1 = bx0 + 3.6, by1 = by0 + 3.6
        addBox(tray, "boss_\(idx)_base", bx0, bx1, by0, by1, 1.8 + dzShellBot, 4.2 + dzShellBot, shellMat, renderOrder: renderOrder)
        addBox(tray, "boss_\(idx)_wl", bx0, bx0 + 0.8, by0, by1, 4.2 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
        addBox(tray, "boss_\(idx)_wr", bx1 - 0.8, bx1, by0, by1, 4.2 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
        addBox(tray, "boss_\(idx)_wb", bx0 + 0.8, bx1 - 0.8, by0, by0 + 0.8, 4.2 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
        addBox(tray, "boss_\(idx)_wt", bx0 + 0.8, bx1 - 0.8, by1 - 0.8, by1, 4.2 + dzShellBot, 16.2 + dzShellBot, shellMat, renderOrder: renderOrder)
        addBox(tray, "boss_\(idx)_hole", bx0 + 0.85, bx1 - 0.85, by0 + 0.85, by1 - 0.85, 4.2 + dzShellBot, 16.22 + dzShellBot, matPortCavity, renderOrder: renderOrder)
    }

    // Internal Molded PCB Cradles, Support Rails & LiPo Retention
    // a. LiPo lateral rails (Z: 1.8..7.0) flush under shield_rib (Z: 7.0..7.8)
    addBox(tray, "cradle_lipo_l", 5.5, 6.4, 41.0, 78.0, 1.8 + dzShellBot, 7.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_lipo_r", 65.6, 66.5, 41.0, 78.0, 1.8 + dzShellBot, 7.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // b. KY-023 4x Corner Standoffs (Z: 1.8..2.4 mm)
    for (kx0, kx1, ky0, ky1) in [
        (4.5, 7.5, 5.8, 8.8), (27.5, 30.5, 5.8, 8.8),
        (4.5, 7.5, 36.8, 39.8), (27.5, 30.5, 36.8, 39.8)
    ] {
        addBox(tray, "cradle_ky_\(kx0)_\(ky0)", kx0, kx1, ky0, ky1, 1.8 + dzShellBot, 2.4 + dzShellBot, cradleMat, renderOrder: renderOrder)
    }
    // c. Keypad Matrix Support Rails (Z: 1.8..6.4 mm, open wire channels between)
    addBox(tray, "cradle_pad_l", 32.0, 34.5, 6.0, 37.5, 1.8 + dzShellBot, 6.4 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_pad_c", 49.0, 51.5, 6.0, 37.5, 1.8 + dzShellBot, 6.4 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_pad_r", 66.5, 69.0, 6.0, 37.5, 1.8 + dzShellBot, 6.4 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // d. T-Display-S3 AMOLED Support Ledges (Left Z: 1.8..12.0 straddling USB-C; Right floor L-bracket clear of shield Z<=7.8)
    addBox(tray, "cradle_amoled_l1", 3.2, 5.8, 46.5, 53.5, 1.8 + dzShellBot, 12.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_amoled_l2", 3.2, 5.8, 64.5, 72.0, 1.8 + dzShellBot, 12.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_amoled_r_stem", 66.5, 70.2, 46.5, 72.0, 1.8 + dzShellBot, 12.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_amoled_r_shelf", 59.5, 66.5, 46.5, 72.0, 8.0 + dzShellBot, 12.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // e. GY-PCM5102 Support Pillars (Left L-bracket clear of boss_tl + Right pillar between BT & Boost)
    addBox(tray, "cradle_pcm_l_stem", 3.5, 5.3, 79.0, 92.4, 1.8 + dzShellBot, 9.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_pcm_l_shelf", 5.3, 7.8, 79.0, 92.4, 7.5 + dzShellBot, 9.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_pcm_r", 29.1, 29.7, 79.0, 95.5, 1.8 + dzShellBot, 9.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // f. Mini 3.3V MicroSD U-Pedestal (front-left contiguous top step at Y=78.8 clear of shield Z<=7.8)
    addBox(tray, "cradle_sd_rear_l", 52.2, 55.0, 78.8, 92.0, 1.8 + dzShellBot, 9.8 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_sd_rear_top", 55.0, 69.5, 89.8, 92.0, 1.8 + dzShellBot, 9.8 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_sd_front_r", 66.2, 70.2, 73.5, 78.8, 1.8 + dzShellBot, 9.8 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_sd_front_l", 52.2, 55.0, 76.5, 78.8, 8.0 + dzShellBot, 9.8 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // g. 5V 2A Boost Retention Stop-Lip (Z: 1.8..4.5 mm)
    addBox(tray, "cradle_boost_stop", 31.0, 49.0, 78.2, 78.9, 1.8 + dzShellBot, 4.5 + dzShellBot, cradleMat, renderOrder: renderOrder)

    // Complete Segmented Front Faceplate Lid (Z: 16.2..18.0 mm)
    let lid = SCNNode()
    lid.name = "p5_top_faceplate"
    // 1. Upper section (Y: 71.0..98.0) with Ø9.6mm 21-dot + bisected circular mic grille at (45.0, 86.5) + INMP441 collar
    addBox(lid, "lid_up_left", 0, 40.0, 71.0, 98.0, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_right", 50.0, 72.0, 71.0, 98.0, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_mic_bot", 40.0, 50.0, 71.0, 81.5, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_mic_top", 40.0, 50.0, 91.5, 98.0, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addTubeZ(lid, "lid_mic_collar", 45.0, 86.5, 16.2 + dzLid, 18.0 + dzLid, 4.8, 6.2, shellMat)
    for (mx, my) in [(40.7, 82.2), (49.3, 82.2), (40.7, 90.8), (49.3, 90.8)] {
        addBox(lid, "lid_mic_corner_\(mx)_\(my)", mx - 0.75, mx + 0.75, my - 0.75, my + 0.75, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    }
    addTubeZ(lid, "lid_mic_trim", 45.0, 86.5, 16.2 + dzLid, 17.95 + dzLid, 4.55, 4.8, matPortCavity)
    addCylZ(lid, "lid_mic_disc_floor", 45.0, 86.5, 16.2 + dzLid, 17.55 + dzLid, 4.55, shellMat)
    addBox(lid, "lid_mic_cross_x", 41.1, 48.9, 86.38, 86.62, 17.52 + dzLid, 17.59 + dzLid, matPortCavity)
    addBox(lid, "lid_mic_cross_y", 44.88, 45.12, 82.6, 90.4, 17.52 + dzLid, 17.59 + dzLid, matPortCavity)
    for dx in [-3.2, -1.6, 0.0, 1.6, 3.2] {
        for dy in [-3.2, -1.6, 0.0, 1.6, 3.2] {
            if abs(dx) + abs(dy) < 6.0 {
                addCylZ(lid, "mic_dot_\(dx)_\(dy)", 45.0 + dx, 86.5 + dy, 17.50 + dzLid, 17.62 + dzLid, 0.475, matPortCavity, radialSegs: 20)
            }
        }
    }
    addTubeZ(lid, "lid_inmp441_ring", 45.0, 86.5, 14.6 + dzLid, 16.2 + dzLid, 4.6, 6.2, cradleMat)

    // 2. AMOLED window bezel (Y: 46.5..71.0, active glass cutout X: 8.5..58.5, Y: 48.0..69.5)
    addBox(lid, "lid_amoled_l", 0, 8.5, 46.5, 71.0, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_amoled_r", 58.5, 72.0, 46.5, 71.0, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_amoled_t", 8.5, 58.5, 69.5, 71.0, 16.2 + dzLid, 18.0 + dzLid, matOpaqueBezel, renderOrder: renderOrder)
    addBox(lid, "lid_amoled_b", 8.5, 58.5, 46.5, 48.0, 16.2 + dzLid, 18.0 + dzLid, matOpaqueBezel, renderOrder: renderOrder)

    // 3. Mid bridge bar (Y: 37.5..46.5)
    addBox(lid, "lid_mid_bar", 0, 72.0, 37.5, 46.5, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)

    // 4. Lower-left thumbstick deck (X: 0..31.5, Y: 0..37.5) with recessed Ø25.0mm well at (17.5, 21.8)
    addTubeZ(lid, "lid_stick_collar", 17.5, 21.8, 14.8 + dzLid, 18.0 + dzLid, 12.5, 14.15, shellMat)
    addBox(lid, "lid_stick_l", 0, 5.0, 0, 37.5, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_r", 30.0, 31.5, 0, 37.5, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_b", 5.0, 30.0, 0, 9.3, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_t", 5.0, 30.0, 34.3, 37.5, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    for sx in [-1.0, 1.0] {
        for sy in [-1.0, 1.0] {
            let ax0 = 17.5 + sx * 8.9, ax1 = 17.5 + sx * 12.6
            let ay0 = 21.8 + sy * 8.9, ay1 = 21.8 + sy * 12.6
            addBox(lid, "lid_stick_spA_\(sx)_\(sy)", min(ax0, ax1), max(ax0, ax1), min(ay0, ay1), max(ay0, ay1), 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
            let bx0 = 17.5 + sx * 6.4, bx1 = 17.5 + sx * 9.0
            let by0 = 21.8 + sy * 10.8, by1 = 21.8 + sy * 12.6
            addBox(lid, "lid_stick_spB_\(sx)_\(sy)", min(bx0, bx1), max(bx0, bx1), min(by0, by1), max(by0, by1), 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
            let cx0 = 17.5 + sx * 10.8, cx1 = 17.5 + sx * 12.6
            let cy0 = 21.8 + sy * 6.4, cy1 = 21.8 + sy * 9.0
            addBox(lid, "lid_stick_spC_\(sx)_\(sy)", min(cx0, cx1), max(cx0, cx1), min(cy0, cy1), max(cy0, cy1), 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
        }
    }
    addCylZ(lid, "lid_stick_well", 17.5, 21.8, 14.6 + dzLid, 14.9 + dzLid, 12.6, matPortCavity)
    addTubeZ(lid, "lid_stick_wall", 17.5, 21.8, 14.8 + dzLid, 17.95 + dzLid, 12.35, 12.55, matOpaqueBezel)

    // 5. Lower-right keypad grid (X: 31.5..72.0, Y: 0..37.5) with 8 individual square key cutouts
    addBox(lid, "lid_pad_bot_strip", 31.5, 72.0, 0, 9.1, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_pad_mid_strip", 31.5, 72.0, 17.9, 25.6, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_pad_top_strip", 31.5, 72.0, 34.4, 37.5, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    let capXs = [36.5, 45.7, 54.9, 64.1]
    for (i, cx) in capXs.enumerated() {
        let prevX = i == 0 ? 31.5 : capXs[i - 1] + 4.4
        addBox(lid, "lid_pad_b_div_\(i)", prevX, cx - 4.4, 9.1, 17.9, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
        addBox(lid, "lid_pad_t_div_\(i)", prevX, cx - 4.4, 25.6, 34.4, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    }
    addBox(lid, "lid_pad_b_right", 68.5, 72.0, 9.1, 17.9, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_pad_t_right", 68.5, 72.0, 25.6, 34.4, 16.2 + dzLid, 18.0 + dzLid, shellMat, renderOrder: renderOrder)

    // 6. 4x Countersunk M2 Corner Screw Heads on Faceplate
    for (sx, sy) in [(3.6, 3.6), (68.4, 3.6), (3.6, 94.4), (68.4, 94.4)] {
        addCylZ(lid, "m2_screw_\(sx)_\(sy)", sx, sy, 16.3 + dzLid, 18.05 + dzLid, 1.7, matBlackCap)
        addCylZ(lid, "m2_hex_\(sx)_\(sy)", sx, sy, 16.35 + dzLid, 18.08 + dzLid, 0.8, matSilver)
    }

    return (tray, lid)
}

// MARK: - Build Option P5-Card (72.0 x 98.0 x 18.0 mm) + Verify + Export STL/USDZ
func buildP5Card(exploded: Bool = false, opaque: Bool = false) -> (SCNNode, Int) {
    let root = SCNNode()
    var boxes: [(String, AABB)] = []
    let dzShellBot = exploded ? -18.0 : 0.0
    let dzLiPo = exploded ? -8.0 : 0.0
    let dzShield = exploded ? 0.0 : 0.0
    let dzControls = exploded ? 8.0 : 0.0
    let dzTopBay = exploded ? 10.0 : 0.0
    let dzAMOLED = exploded ? 18.0 : 0.0
    let dzLid = exploded ? 28.0 : 0.0

    let shellMat = opaque ? matOpaqueCharcoal : matSmokeShell
    let ro = opaque ? 0 : 20
    let (tray, lid) = buildShellAndLid(shellMat: shellMat, cradleMat: shellMat, dzShellBot: dzShellBot, dzLid: dzLid, renderOrder: ro)
    root.addChildNode(tray)

    boxes.append(("boss_bl", makeAABB("boss_bl", 1.8, 5.4, 1.8, 5.4, 1.8, 16.2)))
    boxes.append(("boss_br", makeAABB("boss_br", 66.6, 70.2, 1.8, 5.4, 1.8, 16.2)))
    boxes.append(("boss_tl", makeAABB("boss_tl", 1.8, 5.4, 92.6, 96.2, 1.8, 16.2)))
    boxes.append(("boss_tr", makeAABB("boss_tr", 66.6, 70.2, 92.6, 96.2, 1.8, 16.2)))

    // Register Internal Printed Support Cradles for Collision Verification
    boxes.append(("cradles", makeAABB("cradle_lipo_l", 5.5, 6.4, 41.0, 78.0, 1.8, 7.0)))
    boxes.append(("cradles", makeAABB("cradle_lipo_r", 65.6, 66.5, 41.0, 78.0, 1.8, 7.0)))
    for (kx0, kx1, ky0, ky1) in [
        (4.5, 7.5, 5.8, 8.8), (27.5, 30.5, 5.8, 8.8),
        (4.5, 7.5, 36.8, 39.8), (27.5, 30.5, 36.8, 39.8)
    ] {
        boxes.append(("cradles", makeAABB("cradle_ky_\(kx0)_\(ky0)", kx0, kx1, ky0, ky1, 1.8, 2.4)))
    }
    boxes.append(("cradles", makeAABB("cradle_pad_l", 32.0, 34.5, 6.0, 37.5, 1.8, 6.4)))
    boxes.append(("cradles", makeAABB("cradle_pad_c", 49.0, 51.5, 6.0, 37.5, 1.8, 6.4)))
    boxes.append(("cradles", makeAABB("cradle_pad_r", 66.5, 69.0, 6.0, 37.5, 1.8, 6.4)))
    boxes.append(("cradles", makeAABB("cradle_amoled_l1", 3.2, 5.8, 46.5, 53.5, 1.8, 12.0)))
    boxes.append(("cradles", makeAABB("cradle_amoled_l2", 3.2, 5.8, 64.5, 72.0, 1.8, 12.0)))
    boxes.append(("cradles", makeAABB("cradle_amoled_r_stem", 66.5, 70.2, 46.5, 72.0, 1.8, 12.0)))
    boxes.append(("cradles", makeAABB("cradle_amoled_r_shelf", 59.5, 66.5, 46.5, 72.0, 8.0, 12.0)))
    boxes.append(("cradles", makeAABB("cradle_pcm_l_stem", 3.5, 5.3, 79.0, 92.4, 1.8, 9.5)))
    boxes.append(("cradles", makeAABB("cradle_pcm_l_shelf", 5.3, 7.8, 79.0, 92.4, 7.5, 9.5)))
    boxes.append(("cradles", makeAABB("cradle_pcm_r", 29.1, 29.7, 79.0, 95.5, 1.8, 9.5)))
    boxes.append(("cradles", makeAABB("cradle_sd_rear_l", 52.2, 55.0, 78.8, 92.0, 1.8, 9.8)))
    boxes.append(("cradles", makeAABB("cradle_sd_rear_top", 55.0, 69.5, 89.8, 92.0, 1.8, 9.8)))
    boxes.append(("cradles", makeAABB("cradle_sd_front_r", 66.2, 70.2, 73.5, 78.8, 1.8, 9.8)))
    boxes.append(("cradles", makeAABB("cradle_sd_front_l", 52.2, 55.0, 76.5, 78.8, 8.0, 9.8)))
    boxes.append(("cradles", makeAABB("cradle_boost_stop", 31.0, 49.0, 78.2, 78.9, 1.8, 4.5)))

    // 1. 503759 1300 mAh LiPo (59.0 x 37.0 x 5.0 mm) + 0.8 mm Shield Rib
    let lipoNode = SCNNode()
    addBox(lipoNode, "lipo_503759", 6.5, 65.5, 41.0, 78.0, 1.8 + dzLiPo, 6.8 + dzLiPo, matLiPo, chamfer: 0.4)
    addBox(lipoNode, "lipo_tape", 6.5, 11.0, 41.0, 78.0, 1.9 + dzLiPo, 6.9 + dzLiPo, matAmberCap)
    addBox(lipoNode, "shield_rib", 6.0, 66.0, 40.5, 78.5, 7.0 + dzShield, 7.8 + dzShield, shellMat, renderOrder: ro)
    boxes.append(("lipo", makeAABB("lipo_503759", 6.5, 65.5, 41.0, 78.0, 1.8, 6.8)))
    boxes.append(("shield_rib", makeAABB("shield_rib", 6.0, 66.0, 40.5, 78.5, 7.0, 7.8)))
    root.addChildNode(lipoNode)

    // 2. KY-023 Low-Profile Gimbal (26.0 x 34.0 mm on Z=2.4mm standoffs) + Ø16.0mm Concave Cap Recessed in Ø25.0mm Well
    let kyNode = SCNNode()
    addBox(kyNode, "ky_pcb", 4.5, 30.5, 5.8, 39.8, 2.4 + dzControls, 4.0 + dzControls, matDarkPCB)
    addBox(kyNode, "ky_gimbal", 9.5, 25.5, 13.8, 29.8, 4.0 + dzControls, 14.4 + dzControls, matSilver)
    addCylZ(kyNode, "ky_shaft", 17.5, 21.8, 14.4 + dzControls, 16.6 + dzControls, 2.0, matBlackCap)
    addTubeZ(kyNode, "ky_disc_stem", 17.5, 21.8, 14.8 + dzControls, 16.4 + dzControls, 2.0, 3.6, matCoralCap)
    addCylZ(kyNode, "ky_concave_disc", 17.5, 21.8, 16.4 + dzControls, 17.4 + dzControls, 8.0, matCoralCap)
    addTubeZ(kyNode, "ky_disc_rim", 17.5, 21.8, 17.4 + dzControls, 18.6 + dzControls, 5.8, 8.0, matCoralCap)
    let matCoralInner = makeMat(0.82, 0.33, 0.26, 1.0, metal: 0.04, rough: 0.48)
    addTubeZ(kyNode, "ky_disc_dish_shade", 17.5, 21.8, 17.35 + dzControls, 17.55 + dzControls, 5.4, 5.8, matCoralInner)
    boxes.append(("ky023", makeAABB("ky_body", 4.5, 30.5, 5.8, 39.8, 2.4, 14.4)))
    root.addChildNode(kyNode)

    // 3. 2x GODIYMODULES 1x4 Keypads (37.0 x 15.0 mm resting on Z=6.4mm rails, captive flange Z: 15.4..16.2)
    let padNode = SCNNode()
    addBox(padNode, "pad_bot_pcb", 32.0, 69.0, 6.0, 21.0, 6.4 + dzControls, 8.0 + dzControls, matGreenPCB)
    addBox(padNode, "pad_top_pcb", 32.0, 69.0, 22.5, 37.5, 6.4 + dzControls, 8.0 + dzControls, matGreenPCB)
    let capXs = [36.5, 45.7, 54.9, 64.1]
    let botMats = [matAmberCap, matTealCap, matAmberCap, matCoralCap]
    for (i, cx) in capXs.enumerated() {
        addBox(padNode, "sw_bot_\(i)", cx - 3.0, cx + 3.0, 10.5, 16.5, 8.0 + dzControls, 15.4 + dzControls, matBlackCap)
        addBox(padNode, "cap_bot_flange_\(i)", cx - 4.7, cx + 4.7, 8.8, 18.2, 15.4 + dzControls, 16.2 + dzControls, botMats[i])
        addBox(padNode, "cap_bot_\(i)", cx - 4.1, cx + 4.1, 9.4, 17.6, 16.2 + dzControls, 19.0 + dzControls, botMats[i], chamfer: 0.6)
        addBox(padNode, "sw_top_\(i)", cx - 3.0, cx + 3.0, 27.0, 33.0, 8.0 + dzControls, 15.4 + dzControls, matBlackCap)
        addBox(padNode, "cap_top_flange_\(i)", cx - 4.7, cx + 4.7, 25.3, 34.7, 15.4 + dzControls, 16.2 + dzControls, matBlackCap)
        addBox(padNode, "cap_top_\(i)", cx - 4.1, cx + 4.1, 25.9, 34.1, 16.2 + dzControls, 19.0 + dzControls, matBlackCap, chamfer: 0.6)
    }
    boxes.append(("pad_bot", makeAABB("pad_bot", 32.0, 69.0, 6.0, 21.0, 6.4, 16.0)))
    boxes.append(("pad_top", makeAABB("pad_top", 32.0, 69.0, 22.5, 37.5, 6.4, 16.0)))
    root.addChildNode(padNode)

    // 4. LILYGO T-Display-S3 AMOLED (58.8 x 25.5 x 4.2 mm, Landscape; USB-C flush at Left Wall X=0.0..1.8!)
    let espNode = SCNNode()
    addBox(espNode, "amoled_pcb", 3.2, 62.0, 46.5, 72.0, 12.0 + dzAMOLED, 13.6 + dzAMOLED, matDarkPCB)
    addBox(espNode, "amoled_glass", 8.5, 58.5, 48.0, 69.5, 13.6 + dzAMOLED, 16.2 + dzAMOLED, matAMOLEDGlass)
    addBox(espNode, "amoled_active", 11.4, 55.6, 48.8, 68.6, 16.05 + dzAMOLED, 16.30 + dzAMOLED, matAMOLEDActive)
    // USB-C receptacle (X: 0.0..6.8, Y: 54.7..63.7, Z: 12.0..15.2) visible right at Left Wall X=0!
    addBox(espNode, "amoled_usbc_shell", 0.0, 6.8, 54.7, 63.7, 12.0 + dzAMOLED, 15.2 + dzAMOLED, matSilver, chamfer: 0.5)
    addBox(espNode, "amoled_usbc_bore", -0.05, 1.5, 55.5, 62.9, 12.5 + dzAMOLED, 14.7 + dzAMOLED, matPortCavity, chamfer: 0.3)
    boxes.append(("amoled", makeAABB("t_display_s3_amoled", 3.2, 62.0, 46.5, 72.0, 12.0, 16.2)))
    boxes.append(("amoled", makeAABB("amoled_usbc", 0.2, 6.8, 54.7, 63.7, 12.0, 15.2)))
    root.addChildNode(espNode)

    // 5. Top Bay:
    // 5a. Acxico KCX_BT_EMITTER (23.5 x 15.5 x 2.5 mm) Rear-Left under GY-PCM5102 (Z: 2.0..4.5)
    let topBay = SCNNode()
    addBox(topBay, "bt_emitter_pcb", 5.5, 29.0, 79.0, 94.5, 2.0 + dzTopBay, 3.4 + dzTopBay, matBluePCB)
    addBox(topBay, "bt_emitter_ic", 12.0, 21.0, 82.5, 89.5, 3.4 + dzTopBay, 4.5 + dzTopBay, matBlackCap)
    boxes.append(("bt_emitter", makeAABB("kcx_bt_emitter", 5.5, 29.0, 79.0, 94.5, 2.0, 4.5)))

    // 5a2. 5V 2A Type-C Boost (21.0 x 17.2 x 4.2 mm) in Rear-Center (Z: 2.0..6.8), USB-C flush at Top Wall Y=98.0!
    addBox(topBay, "boost_5v2a_pcb", 29.8, 50.8, 79.0, 96.2, 2.0 + dzTopBay, 3.6 + dzTopBay, matDarkPCB)
    addBox(topBay, "boost_inductor", 32.3, 39.3, 83.2, 90.2, 3.6 + dzTopBay, 6.2 + dzTopBay, matBlackCap)
    addBox(topBay, "boost_usbc_shell", 35.8, 44.8, 91.5, 98.0, 3.6 + dzTopBay, 6.8 + dzTopBay, matSilver, chamfer: 0.5)
    addBox(topBay, "boost_usbc_bore", 36.6, 44.0, 96.5, 98.05, 4.1 + dzTopBay, 6.3 + dzTopBay, matPortCavity, chamfer: 0.3)
    boxes.append(("boost_5v2a", makeAABB("boost_5v2a", 29.8, 50.8, 79.0, 96.2, 2.0, 6.8)))

    // 5b. GY-PCM5102 (32.0 x 17.0 x 5.5 mm) Top-Left (Z: 9.5..15.0), 3.5mm TRS Jack flush at Top Wall Y=98.0!
    addBox(topBay, "pcm5102_pcb", 6.0, 38.0, 79.0, 96.0, 9.5 + dzTopBay, 11.1 + dzTopBay, matPurplePCB)
    addBox(topBay, "pcm5102_trs", 10.0, 18.5, 84.0, 96.2, 11.1 + dzTopBay, 15.0 + dzTopBay, matBlackCap)
    addCylY(topBay, "pcm5102_trs_ring", 14.25, 13.05 + dzTopBay, 95.8, 98.35, 3.0, matGold)
    addCylY(topBay, "pcm5102_trs_bore", 14.25, 13.05 + dzTopBay, 96.0, 98.42, 1.75, matPortCavity)
    boxes.append(("pcm5102", makeAABB("gy_pcm5102", 6.0, 38.0, 79.0, 96.0, 9.5, 15.0)))

    // 5c. INMP441 MEMS Mic (Ø14.0 mm) Top-Center (Z: 13.0..16.2)
    addCylZ(topBay, "inmp441_pcb", 45.0, 86.5, 13.0 + dzTopBay, 14.6 + dzTopBay, 7.0, matDarkPCB)
    addCylZ(topBay, "inmp441_gasket", 45.0, 86.5, 14.6 + dzTopBay, 16.0 + dzTopBay, 4.5, matBlackCap)
    boxes.append(("inmp441", makeAABB("inmp441", 38.5, 51.5, 80.0, 93.0, 13.0, 16.0)))

    // 5d. WWZMDiB Mini 3.3V MicroSD (18.0 x 18.5 x 4.0 mm) Top-Right, card slot flush at Right Wall X=72.0!
    addBox(topBay, "microsd_pcb", 52.2, 70.2, 73.5, 92.0, 9.8 + dzTopBay, 11.4 + dzTopBay, matBluePCB)
    addBox(topBay, "microsd_cage", 55.7, 70.2, 75.8, 89.8, 11.4 + dzTopBay, 13.8 + dzTopBay, matSilver)
    addBox(topBay, "microsd_card_edge", 68.0, 71.9, 77.2, 88.2, 11.8 + dzTopBay, 13.0 + dzTopBay, matGold)
    boxes.append(("microsd", makeAABB("mini_3v3_microsd", 52.2, 70.2, 73.5, 92.0, 9.8, 13.8)))
    root.addChildNode(topBay)

    root.addChildNode(lid)

    let cols = exploded ? 0 : verifyAABBs(label: opaque ? "Option_P5_Card_Opaque" : "Option_P5_Card_Smoke", boxes: boxes)
    return (root, cols)
}

// MARK: - Build 1:1 Standard Poker Playing Card Deck (63.5 x 88.9 x 17.5 mm)
func buildPlayingCardDeck() -> SCNNode {
    let deck = SCNNode()
    addBox(deck, "deck_tuck_box", 0, 63.5, 0, 88.9, 0, 17.5, matCardWhite, chamfer: 0.6)
    addBox(deck, "deck_red_panel", 4.5, 59.0, 6.0, 82.9, 17.4, 17.6, matCardRed)
    addBox(deck, "deck_inner_white", 8.5, 55.0, 18.0, 70.0, 17.5, 17.65, matCardWhite)
    return deck
}

// MARK: - Build Printable Binary STL Parts (1 mm units for Bambu P2S)
func exportPrintableSTLs() throws {
    let tray = STLMesh()
    tray.addBox(0, 72.0, 0, 98.0, 0, 1.8)
    tray.addBox(0, 1.8, 0, 54.0, 1.8, 16.2)
    tray.addBox(0, 1.8, 64.4, 98.0, 1.8, 16.2)
    tray.addBox(0, 1.8, 54.0, 64.4, 1.8, 11.6)
    tray.addBox(0, 1.8, 54.0, 64.4, 15.6, 16.2)
    tray.addBox(70.2, 72.0, 0, 75.5, 1.8, 16.2)
    tray.addBox(70.2, 72.0, 90.0, 98.0, 1.8, 16.2)
    tray.addBox(70.2, 72.0, 75.5, 90.0, 1.8, 10.6)
    tray.addBox(70.2, 72.0, 75.5, 90.0, 14.2, 16.2)
    tray.addBox(1.8, 70.2, 0, 1.8, 1.8, 16.2)
    tray.addBox(1.8, 11.0, 96.2, 98.0, 1.8, 16.2)
    tray.addBox(11.0, 17.5, 96.2, 98.0, 1.8, 10.0)
    tray.addBox(17.5, 35.1, 96.2, 98.0, 1.8, 16.2)
    tray.addBox(35.1, 45.5, 96.2, 98.0, 1.8, 3.2)
    tray.addBox(35.1, 45.5, 96.2, 98.0, 7.2, 16.2)
    tray.addBox(45.5, 70.2, 96.2, 98.0, 1.8, 16.2)
    // 4x Hollow M2 Corner Screw Bosses (2.0 x 2.0 mm pilot bore above Z=4.2 mm)
    for (bx0, by0) in [(1.8, 1.8), (66.6, 1.8), (1.8, 92.6), (66.6, 92.6)] {
        let bx1 = bx0 + 3.6, by1 = by0 + 3.6
        tray.addBox(bx0, bx1, by0, by1, 1.8, 4.2)
        tray.addBox(bx0, bx0 + 0.8, by0, by1, 4.2, 16.2)
        tray.addBox(bx1 - 0.8, bx1, by0, by1, 4.2, 16.2)
        tray.addBox(bx0 + 0.8, bx1 - 0.8, by0, by0 + 0.8, 4.2, 16.2)
        tray.addBox(bx0 + 0.8, bx1 - 0.8, by1 - 0.8, by1, 4.2, 16.2)
    }
    // Internal PCB Cradles & Support Rails
    tray.addBox(5.5, 6.4, 41.0, 78.0, 1.8, 7.0)
    tray.addBox(65.6, 66.5, 41.0, 78.0, 1.8, 7.0)
    for (kx0, kx1, ky0, ky1) in [
        (4.5, 7.5, 5.8, 8.8), (27.5, 30.5, 5.8, 8.8),
        (4.5, 7.5, 36.8, 39.8), (27.5, 30.5, 36.8, 39.8)
    ] {
        tray.addBox(kx0, kx1, ky0, ky1, 1.8, 2.4)
    }
    tray.addBox(32.0, 34.5, 6.0, 37.5, 1.8, 6.4)
    tray.addBox(49.0, 51.5, 6.0, 37.5, 1.8, 6.4)
    tray.addBox(66.5, 69.0, 6.0, 37.5, 1.8, 6.4)
    tray.addBox(3.2, 5.8, 46.5, 53.5, 1.8, 12.0)
    tray.addBox(3.2, 5.8, 64.5, 72.0, 1.8, 12.0)
    tray.addBox(66.5, 70.2, 46.5, 72.0, 1.8, 12.0)
    tray.addBox(59.5, 66.5, 46.5, 72.0, 8.0, 12.0)
    tray.addBox(3.5, 5.3, 79.0, 92.4, 1.8, 9.5)
    tray.addBox(5.3, 7.8, 79.0, 92.4, 7.5, 9.5)
    tray.addBox(29.1, 29.7, 79.0, 95.5, 1.8, 9.5)
    tray.addBox(52.2, 55.0, 78.8, 92.0, 1.8, 9.8)
    tray.addBox(55.0, 69.5, 89.8, 92.0, 1.8, 9.8)
    tray.addBox(66.2, 70.2, 73.5, 78.8, 1.8, 9.8)
    tray.addBox(52.2, 55.0, 76.5, 78.8, 8.0, 9.8)
    tray.addBox(31.0, 49.0, 78.2, 78.9, 1.8, 4.5)
    try tray.writeBinarySTL(to: "\(stlDir)/p5_card_bottom_tray.stl", header: "P5-Card Bottom Tray 72x98x16.2mm")

    // Top Faceplate printed exterior-down (Z: 0..1.8 faceplate, Z: 1.8..3.4 INMP441 collar & stick well skirt)
    let lid = STLMesh()
    // Upper-left (X: 0..40.0, Y: 71.0..98.0) with 2.2x2.2 M2 hole (X: 2.5..4.7, Y: 93.3..95.5)
    lid.addBox(0, 2.5, 71.0, 98.0, 0, 1.8)
    lid.addBox(4.7, 40.0, 71.0, 98.0, 0, 1.8)
    lid.addBox(2.5, 4.7, 71.0, 93.3, 0, 1.8)
    lid.addBox(2.5, 4.7, 95.5, 98.0, 0, 1.8)
    // Upper-right (X: 50.0..72.0, Y: 71.0..98.0) with 2.2x2.2 M2 hole (X: 67.3..69.5, Y: 93.3..95.5)
    lid.addBox(50.0, 67.3, 71.0, 98.0, 0, 1.8)
    lid.addBox(69.5, 72.0, 71.0, 98.0, 0, 1.8)
    lid.addBox(67.3, 69.5, 71.0, 93.3, 0, 1.8)
    lid.addBox(67.3, 69.5, 95.5, 98.0, 0, 1.8)
    // Circular 21-hole recessed mic grille window (X: 40.0..50.0, Y: 81.5..91.5)
    lid.addBox(40.0, 50.0, 71.0, 81.5, 0, 1.8)
    lid.addBox(40.0, 50.0, 91.5, 98.0, 0, 1.8)
    lid.addAnnulusZ(cx: 45.0, cy: 86.5, rIn: 4.8, rOut: 6.2, z0: 0, z1: 1.8)
    for (mx, my) in [(40.7, 82.2), (49.3, 82.2), (40.7, 90.8), (49.3, 90.8)] {
        lid.addBox(mx - 0.75, mx + 0.75, my - 0.75, my + 0.75, 0, 1.8)
    }
    // 21 real 0.9x0.9mm through-holes recessed at Z: 0.45..1.80mm (5x5 minus 4 corners at 1.6mm pitch)
    let ribSpans: [(Double, Double)] = [
        (-5.00, -3.65), (-2.75, -2.05), (-1.15, -0.45),
        (0.45, 1.15), (2.05, 2.75), (3.65, 5.00)
    ]
    for (ry0, ry1) in ribSpans {
        lid.addBox(40.0, 50.0, 86.5 + ry0, 86.5 + ry1, 0.45, 1.8)
    }
    let holeCenters = [-3.2, -1.6, 0.0, 1.6, 3.2]
    for hc in holeCenters {
        for (rx0, rx1) in ribSpans {
            lid.addBox(45.0 + rx0, 45.0 + rx1, 86.5 + hc - 0.45, 86.5 + hc + 0.45, 0.45, 1.8)
        }
        if abs(hc) == 3.2 {
            for vc in [-3.2, 3.2] {
                lid.addBox(45.0 + vc - 0.45, 45.0 + vc + 0.45, 86.5 + hc - 0.45, 86.5 + hc + 0.45, 0.45, 1.8)
            }
        }
    }
    lid.addAnnulusZ(cx: 45.0, cy: 86.5, rIn: 4.6, rOut: 6.2, z0: 1.8, z1: 3.4)
    // AMOLED window bezel + mid bridge bar
    lid.addBox(0, 8.5, 46.5, 71.0, 0, 1.8)
    lid.addBox(58.5, 72.0, 46.5, 71.0, 0, 1.8)
    lid.addBox(8.5, 58.5, 69.5, 71.0, 0, 1.8)
    lid.addBox(8.5, 58.5, 46.5, 48.0, 0, 1.8)
    lid.addBox(0, 72.0, 37.5, 46.5, 0, 1.8)
    // Recessed Ø25.0mm thumbstick well skirt (Z: 0..3.2mm) with 2.2x2.2 M2 hole (X: 2.5..4.7, Y: 2.5..4.7) + corner spandrels
    lid.addAnnulusZ(cx: 17.5, cy: 21.8, rIn: 12.5, rOut: 14.15, z0: 0, z1: 3.2)
    lid.addBox(0, 2.5, 0, 37.5, 0, 1.8)
    lid.addBox(4.7, 5.0, 0, 37.5, 0, 1.8)
    lid.addBox(2.5, 4.7, 0, 2.5, 0, 1.8)
    lid.addBox(2.5, 4.7, 4.7, 37.5, 0, 1.8)
    lid.addBox(30.0, 31.5, 0, 37.5, 0, 1.8)
    lid.addBox(5.0, 30.0, 0, 9.3, 0, 1.8)
    lid.addBox(5.0, 30.0, 34.3, 37.5, 0, 1.8)
    for sx in [-1.0, 1.0] {
        for sy in [-1.0, 1.0] {
            lid.addBox(min(17.5 + sx * 8.9, 17.5 + sx * 12.6), max(17.5 + sx * 8.9, 17.5 + sx * 12.6),
                       min(21.8 + sy * 8.9, 21.8 + sy * 12.6), max(21.8 + sy * 8.9, 21.8 + sy * 12.6), 0, 1.8)
            lid.addBox(min(17.5 + sx * 6.4, 17.5 + sx * 9.0), max(17.5 + sx * 6.4, 17.5 + sx * 9.0),
                       min(21.8 + sy * 10.8, 21.8 + sy * 12.6), max(21.8 + sy * 10.8, 21.8 + sy * 12.6), 0, 1.8)
            lid.addBox(min(17.5 + sx * 10.8, 17.5 + sx * 12.6), max(17.5 + sx * 10.8, 17.5 + sx * 12.6),
                       min(21.8 + sy * 6.4, 21.8 + sy * 9.0), max(21.8 + sy * 6.4, 21.8 + sy * 9.0), 0, 1.8)
        }
    }
    // Keypad grid bottom strip (X: 31.5..72.0, Y: 0..9.1) with 2.2x2.2 M2 hole (X: 67.3..69.5, Y: 2.5..4.7)
    lid.addBox(31.5, 67.3, 0, 9.1, 0, 1.8)
    lid.addBox(69.5, 72.0, 0, 9.1, 0, 1.8)
    lid.addBox(67.3, 69.5, 0, 2.5, 0, 1.8)
    lid.addBox(67.3, 69.5, 4.7, 9.1, 0, 1.8)
    lid.addBox(31.5, 72.0, 17.9, 25.6, 0, 1.8)
    lid.addBox(31.5, 72.0, 34.4, 37.5, 0, 1.8)
    let capXs = [36.5, 45.7, 54.9, 64.1]
    for (i, cx) in capXs.enumerated() {
        let prevX = i == 0 ? 31.5 : capXs[i - 1] + 4.4
        lid.addBox(prevX, cx - 4.4, 9.1, 17.9, 0, 1.8)
        lid.addBox(prevX, cx - 4.4, 25.6, 34.4, 0, 1.8)
    }
    lid.addBox(68.5, 72.0, 9.1, 17.9, 0, 1.8)
    lid.addBox(68.5, 72.0, 25.6, 34.4, 0, 1.8)
    // Apply rigid 180-deg X-flip Y -> 98 - Y so exterior-down print snaps directly onto tray without mirroring.
    lid.mirrorYInPlace(yMax: 98.0)
    try lid.writeBinarySTL(to: "\(stlDir)/p5_card_top_faceplate.stl", header: "P5-Card Top Faceplate 72x98x3.4mm")

    let disc = STLMesh()
    disc.addAnnulusZ(cx: 0, cy: 0, rIn: 2.0, rOut: 3.6, z0: 0.0, z1: 1.6)
    disc.addCylinderZ(cx: 0, cy: 0, r: 8.0, z0: 1.6, z1: 3.2)
    disc.addAnnulusZ(cx: 0, cy: 0, rIn: 5.8, rOut: 8.0, z0: 3.2, z1: 3.8)
    try disc.writeBinarySTL(to: "\(stlDir)/p5_card_concave_thumb_disc.stl", header: "P5-Card Concave Pocket Thumb-Disc 16x3.8mm")

    func addKeycap(to mesh: STLMesh, x0: Double, y0: Double) {
        mesh.addBox(x0 - 0.6, x0 + 8.8, y0 - 0.6, y0 + 8.8, 0, 0.8)
        mesh.addBox(x0, x0 + 8.2, y0, y0 + 8.2, 0.8, 3.6)
    }

    let caps = STLMesh()
    for r in 0..<2 {
        for c in 0..<4 {
            addKeycap(to: caps, x0: Double(c) * 12.0, y0: Double(r) * 12.0)
        }
    }
    try caps.writeBinarySTL(to: "\(stlDir)/p5_card_keycaps_8x.stl", header: "P5-Card 8x Captive Keycaps")

    // Single-Plate All-in-One STL arranged in 4 AMS color zones inside Bambu Lab P2S 256 x 256 mm build plate
    let singlePlate = STLMesh()
    // Zone 1: Matte Black (Tray + Faceplate + B1..B4 Keycaps)
    singlePlate.appendOffset(from: tray, dx: 0.0, dy: 85.0)
    singlePlate.appendOffset(from: lid, dx: 84.0, dy: 85.0)
    for c in 0..<4 {
        addKeycap(to: singlePlate, x0: 96.0 + Double(c) * 12.0, y0: 62.0)
    }
    // Zone 2: Matte Coral (Concave Thumb-Disc + B8 Keycap)
    singlePlate.appendOffset(from: disc, dx: 192.0, dy: 24.0)
    addKeycap(to: singlePlate, x0: 202.0, y0: 19.9)
    // Zone 3: Matte Warm Amber (B5, B7 Keycaps)
    for c in 0..<2 {
        addKeycap(to: singlePlate, x0: 104.0 + Double(c) * 12.0, y0: 0.6)
    }
    // Zone 4: Matte Sage Teal (B6 Keycap)
    addKeycap(to: singlePlate, x0: 24.0, y0: 0.6)
    try singlePlate.writeBinarySTL(to: "\(stlDir)/p5_card_single_plate_all_parts.stl", header: "P5-Card Single-Plate All 11 Parts (210.8x183x16.2mm)")
    print("STL_EXPORTED_OK dir=\(stlDir)")
}

// MARK: - Export USDZ & Render Metal PNG Guides
func exportUSDZ(_ node: SCNNode, to path: String) throws {
    let scene = SCNScene()
    scene.rootNode.addChildNode(node)
    scene.rootNode.scale = SCNVector3(0.001, 0.001, 0.001)
    let ok = scene.write(to: URL(fileURLWithPath: path), options: nil, delegate: nil, progressHandler: nil)
    if !ok { throw NSError(domain: "USDZ", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed \(path)"]) }
}

func renderSnapshot(_ node: SCNNode, camPos: SCNVector3, lookAt: SCNVector3, up: SCNVector3 = SCNVector3(0, 1, 0),
                    orthoScale: Double? = nil, fov: CGFloat = 32, size: CGSize = CGSize(width: 1400, height: 1050)) -> NSImage {
    let scene = SCNScene()
    scene.background.contents = NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
    scene.rootNode.addChildNode(node)

    let key = SCNLight(); key.type = .directional; key.intensity = 1350; key.castsShadow = true
    let keyNode = SCNNode(); keyNode.light = key
    keyNode.position = SCNVector3(110, 160, 90)
    keyNode.look(at: lookAt)
    scene.rootNode.addChildNode(keyNode)

    let fill = SCNLight(); fill.type = .directional; fill.intensity = 550
    let fillNode = SCNNode(); fillNode.light = fill
    fillNode.position = SCNVector3(-90, 90, -110)
    fillNode.look(at: lookAt)
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

// MARK: - Main Run
let (p5Smoke, cols1) = buildP5Card(exploded: false, opaque: false)
let (p5Opaque, cols2) = buildP5Card(exploded: false, opaque: true)
guard cols1 == 0 && cols2 == 0 else {
    fatalError("P5-Card collision check failed!")
}

let (p5Exploded, _) = buildP5Card(exploded: true, opaque: false)
try exportUSDZ(p5Smoke.clone(), to: "\(usdzDir)/15a_p5_card_amoled_18mm.usdz")
try exportUSDZ(p5Exploded.clone(), to: "\(usdzDir)/15b_p5_card_amoled_exploded.usdz")
try exportUSDZ(p5Opaque.clone(), to: "\(usdzDir)/15c_p5_card_amoled_opaque.usdz")
try exportPrintableSTLs()

// 1. Orthographic 90-deg Top-Down Scene: Opaque P5-Card (72x98mm) + Bicycle Deck (63.5x88.9mm)
let topDownScene = SCNNode()
let opaqueCopy = p5Opaque.clone()
opaqueCopy.position = SCNVector3(0, 0, 0)
topDownScene.addChildNode(opaqueCopy)

let deckNode = buildPlayingCardDeck()
deckNode.position = SCNVector3(86.0, 0, 0) // 14 mm gap to the right, bottom-aligned at Y=0!
topDownScene.addChildNode(deckNode)

let imgTopDown = renderSnapshot(topDownScene,
                                camPos: SCNVector3(75, 220, -49),
                                lookAt: SCNVector3(75, 9, -49),
                                up: SCNVector3(0, 0, -1),
                                orthoScale: 62.0,
                                size: CGSize(width: 1400, height: 1050))
savePNG(imgTopDown, to: "\(renderDir)/ref_15c_ortho_topdown_with_deck.png")

// 2. 4-Panel Port & Side Elevation Sheet (Top Ports, Left USB-C, Right MicroSD, 3/4 Views)
let sheetSize = CGSize(width: 1600, height: 1200)
let sheetImg = NSImage(size: sheetSize)
sheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: sheetSize))

// Panel TL: 3/4 Front-Top-Left Opaque (shows Left Wall AMOLED USB-C + Top Wall 3.5mm TRS & Boost USB-C)
let pTL = renderSnapshot(p5Opaque.clone(),
                         camPos: SCNVector3(-75, 95, -145),
                         lookAt: SCNVector3(34, 9, -52),
                         fov: 30, size: CGSize(width: 780, height: 560))
pTL.draw(in: NSRect(x: 10, y: 610, width: 780, height: 560))

// Panel TR: 3/4 Front-Top-Right Opaque (shows Right Wall MicroSD + Top Wall Boost USB-C & 3.5mm TRS)
let pTR = renderSnapshot(p5Opaque.clone(),
                         camPos: SCNVector3(145, 95, -145),
                         lookAt: SCNVector3(38, 9, -52),
                         fov: 30, size: CGSize(width: 780, height: 560))
pTR.draw(in: NSRect(x: 810, y: 610, width: 780, height: 560))

// Panel BL: Direct Close-Up TOP PORT EDGE View (looking at Y=98mm: 3.5mm TRS + Boost USB-C)
let pBL = renderSnapshot(p5Opaque.clone(),
                         camPos: SCNVector3(36, 16, -210),
                         lookAt: SCNVector3(36, 9, -85),
                         up: SCNVector3(0, 1, 0),
                         fov: 22, size: CGSize(width: 780, height: 560))
pBL.draw(in: NSRect(x: 10, y: 20, width: 780, height: 560))

// Panel BR: Direct Orthographic LEFT & RIGHT SIDE PORT Views (stacked: Left AMOLED USB-C & Right MicroSD)
let sidePair = SCNNode()
let leftViewNode = p5Opaque.clone()
leftViewNode.position = SCNVector3(0, 14, 0)
sidePair.addChildNode(leftViewNode)
let rightViewNode = p5Opaque.clone()
// Rotate 180 around Y so Right Wall faces -X toward the same camera!
rightViewNode.eulerAngles = SCNVector3(0, Float.pi, 0)
rightViewNode.position = SCNVector3(72, -14, -98)
sidePair.addChildNode(rightViewNode)

let pBR = renderSnapshot(sidePair,
                         camPos: SCNVector3(-180, 9, -49),
                         lookAt: SCNVector3(36, 9, -49),
                         up: SCNVector3(0, 1, 0),
                         orthoScale: 38.0, size: CGSize(width: 780, height: 560))
pBR.draw(in: NSRect(x: 810, y: 20, width: 780, height: 560))

sheetImg.unlockFocus()
savePNG(sheetImg, to: "\(renderDir)/ref_15d_ports_top_left_right_views.png")

// 3. 2-Panel Internal Cradles & Bambu P2S Single-Plate Print Sheet (1600x900)
let plateSheetSize = CGSize(width: 1600, height: 900)
let plateSheetImg = NSImage(size: plateSheetSize)
plateSheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: plateSheetSize))

// Left Panel: 3/4 view of empty bottom tray showing blue-gray molded PCB cradles & hollow M2 bosses
let (emptyTrayCradles, _) = buildShellAndLid(shellMat: matOpaqueCharcoal, cradleMat: matCradle, dzShellBot: 0, dzLid: 0, renderOrder: 0)
let pCradles = renderSnapshot(emptyTrayCradles,
                              camPos: SCNVector3(-56, 158, 48),
                              lookAt: SCNVector3(36, 8, -49),
                              fov: 36, size: CGSize(width: 780, height: 820))
pCradles.draw(in: NSRect(x: 10, y: 20, width: 780, height: 820))

// Right Panel: Orthographic 1:1 Bambu P2S 256 x 256 mm build plate with all 11 parts grouped in 4 AMS color zones
let plateScene = SCNNode()
addBox(plateScene, "bambu_p2s_bed", 0, 256, 0, 256, -2.0, 0.0, matBuildPlate)
for g in stride(from: 0.0, through: 256.0, by: 32.0) {
    addBox(plateScene, "grid_x_\(Int(g))", g - 0.35, g + 0.35, 0, 256, -0.02, 0.05, matGridLine)
    addBox(plateScene, "grid_y_\(Int(g))", 0, 256, g - 0.35, g + 0.35, -0.02, 0.05, matGridLine)
}
let (plateTray, _) = buildShellAndLid(shellMat: matOpaqueCharcoal, cradleMat: matCradle, dzShellBot: 0, dzLid: 0, renderOrder: 0)
plateTray.position = SCNVector3(0.0, 0.0, -85.0)
plateScene.addChildNode(plateTray)

let (_, plateLid) = buildShellAndLid(shellMat: matOpaqueCharcoal, cradleMat: matCradle, dzShellBot: 0, dzLid: 0, renderOrder: 0)
let plateLidWrap = SCNNode()
plateLidWrap.eulerAngles = SCNVector3(Float.pi, 0, 0)
plateLidWrap.position = SCNVector3(84.0, 18.0, -183.0)
plateLidWrap.addChildNode(plateLid)
plateScene.addChildNode(plateLidWrap)

func addPlateCap(_ id: String, _ kx: Double, _ ky: Double, _ mat: SCNMaterial) {
    addBox(plateScene, "plate_cap_f_\(id)", kx - 0.6, kx + 8.8, ky - 0.6, ky + 8.8, 0.0, 0.8, mat)
    addBox(plateScene, "plate_cap_b_\(id)", kx, kx + 8.2, ky, ky + 8.2, 0.8, 3.6, mat, chamfer: 0.4)
}

// Zone 1: B1..B4 Black keycaps
for c in 0..<4 {
    addPlateCap("blk_\(c)", 96.0 + Double(c) * 12.0, 62.0, matBlackCap)
}
// Zone 2: Coral concave thumb-disc + B8 Coral keycap
addTubeZ(plateScene, "plate_disc_stem", 192.0, 24.0, 0.0, 1.6, 2.0, 3.6, matCoralCap)
addCylZ(plateScene, "plate_disc_body", 192.0, 24.0, 1.6, 3.2, 8.0, matCoralCap)
addTubeZ(plateScene, "plate_disc_rim", 192.0, 24.0, 3.2, 3.8, 5.8, 8.0, matCoralCap)
addPlateCap("coral_b8", 202.0, 19.9, matCoralCap)
// Zone 3: B5 & B7 Amber keycaps
for c in 0..<2 {
    addPlateCap("amber_\(c)", 104.0 + Double(c) * 12.0, 0.6, matAmberCap)
}
// Zone 4: B6 Teal keycap
addPlateCap("teal_b6", 24.0, 0.6, matTealCap)

let pPlate = renderSnapshot(plateScene,
                            camPos: SCNVector3(128, 380, -128),
                            lookAt: SCNVector3(128, 0, -128),
                            up: SCNVector3(0, 0, -1),
                            orthoScale: 138.0,
                            size: CGSize(width: 780, height: 820))
pPlate.draw(in: NSRect(x: 810, y: 20, width: 780, height: 820))

let headerAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 22),
    .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.20, alpha: 1.0)
]
("INTERNAL PCB CRADLES & HOLLOW M2 BOSSES (TRAY Z: 0..16.2 mm)" as NSString).draw(at: NSPoint(x: 34, y: 854), withAttributes: headerAttrs)
("BAMBU LAB P2S (256 x 256 mm) — 4 COLOR ZONES, 1 PLATE" as NSString).draw(at: NSPoint(x: 836, y: 854), withAttributes: headerAttrs)

plateSheetImg.unlockFocus()
savePNG(plateSheetImg, to: "\(renderDir)/ref_15g_p5_card_internal_cradles_and_print_plate.png")

// 4. 2-Panel Top-Down & Side Elevation / Recessed Joystick Profile Sheet (1600x900)
let profileSheetSize = CGSize(width: 1600, height: 900)
let profileSheetImg = NSImage(size: profileSheetSize)
profileSheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: profileSheetSize))

let pTopOrtho = renderSnapshot(p5Opaque.clone(),
                               camPos: SCNVector3(36, 200, -49),
                               lookAt: SCNVector3(36, 9, -49),
                               up: SCNVector3(0, 0, -1),
                               orthoScale: 52.0,
                               size: CGSize(width: 780, height: 820))
pTopOrtho.draw(in: NSRect(x: 10, y: 20, width: 780, height: 820))

let pSideOrtho = renderSnapshot(p5Opaque.clone(),
                                camPos: SCNVector3(-180, 10, -49),
                                lookAt: SCNVector3(36, 10, -49),
                                up: SCNVector3(0, 1, 0),
                                orthoScale: 24.0,
                                size: CGSize(width: 780, height: 390))
pSideOrtho.draw(in: NSRect(x: 810, y: 450, width: 780, height: 390))

let pSideOblique = renderSnapshot(p5Opaque.clone(),
                                  camPos: SCNVector3(-38, 42, 18),
                                  lookAt: SCNVector3(28, 15, -36),
                                  fov: 25,
                                  size: CGSize(width: 780, height: 390))
pSideOblique.draw(in: NSRect(x: 810, y: 20, width: 780, height: 390))

("TOP-DOWN 1:1 — 21-DOT MIC GRILLE & Ø16mm CAP IN Ø25mm WELL" as NSString).draw(at: NSPoint(x: 28, y: 854), withAttributes: headerAttrs)
("LEFT SIDE ELEVATION (18.0mm PROFILE) & LOW-ANGLE STICK DEPTH" as NSString).draw(at: NSPoint(x: 828, y: 854), withAttributes: headerAttrs)

profileSheetImg.unlockFocus()
savePNG(profileSheetImg, to: "\(renderDir)/ref_15h_topdown_and_side_profile_closeup.png")

// 5. 2-Panel Side-by-Side Transparent Assembled & Vertically Exploded Sheet (1600x900)
let txSheetSize = CGSize(width: 1600, height: 900)
let txSheetImg = NSImage(size: txSheetSize)
txSheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: txSheetSize))

let pTransAssembled = renderSnapshot(p5Smoke.clone(),
                                     camPos: SCNVector3(-62, 128, 52),
                                     lookAt: SCNVector3(36, 9, -49),
                                     fov: 31,
                                     size: CGSize(width: 780, height: 820))
pTransAssembled.draw(in: NSRect(x: 10, y: 20, width: 780, height: 820))

let pTransExploded = renderSnapshot(p5Exploded.clone(),
                                    camPos: SCNVector3(-78, 138, 72),
                                    lookAt: SCNVector3(36, 12, -49),
                                    fov: 35,
                                    size: CGSize(width: 780, height: 820))
pTransExploded.draw(in: NSRect(x: 810, y: 20, width: 780, height: 820))

("FULLY TRANSPARENT ASSEMBLED (72 x 98 x 18 mm)" as NSString).draw(at: NSPoint(x: 34, y: 854), withAttributes: headerAttrs)
("VERTICALLY EXPLODED Z-STACK (ALL 9 MODULES + CRADLES)" as NSString).draw(at: NSPoint(x: 836, y: 854), withAttributes: headerAttrs)

txSheetImg.unlockFocus()
savePNG(txSheetImg, to: "\(renderDir)/ref_15j_transparent_and_exploded_side_by_side.png")

for fn in ["ref_15c_ortho_topdown_with_deck.png", "ref_15d_ports_top_left_right_views.png", "ref_15g_p5_card_internal_cradles_and_print_plate.png", "ref_15h_topdown_and_side_profile_closeup.png", "ref_15j_transparent_and_exploded_side_by_side.png"] {
    let src = URL(fileURLWithPath: "\(renderDir)/\(fn)")
    let dst = URL(fileURLWithPath: "\(artifactDir)/\(fn)")
    try? FileManager.default.removeItem(at: dst)
    try? FileManager.default.copyItem(at: src, to: dst)
}

print("DONE Opaque P5-Card CAD, Top-Down Ortho, Port Sheet, Cradle/Bed Sheet & Profile Sheet.")
