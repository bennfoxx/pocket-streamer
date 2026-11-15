import Foundation
import SceneKit
import AppKit
import Metal

// MARK: - Paths & Output Directories (Strictly inside experimental/)
let expDir = "/Users/benfox/Development/3D Design/Pocket Streamer Hardware CAD/experimental"
let usdzDir = "\(expDir)/usdz"
let renderDir = "\(expDir)/renders"
let stlDir = "\(expDir)/stl_p5_exp_compact_portrait"

try FileManager.default.createDirectory(atPath: usdzDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: renderDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: stlDir, withIntermediateDirectories: true)

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

    func addCornerSector(cx: Double, cy: Double, rCorner: Double, quadrant: Int,
                         holeX: Double, holeY: Double, rHole: Double,
                         z0: Double, z1: Double, arcSegs: Int = 24, edgeSegs: Int = 8) {
        let fz0 = Float(min(z0, z1)), fz1 = Float(max(z0, z1))
        let a0 = (1.0 + Double(quadrant) * 0.5) * .pi
        let a1 = a0 + 0.5 * .pi
        let ptEnd = SIMD2<Double>(cx + rCorner * cos(a0), cy + rCorner * sin(a0))
        let ptStart = SIMD2<Double>(cx + rCorner * cos(a1), cy + rCorner * sin(a1))
        let cornerPt = SIMD2<Double>(cx, cy)

        var outerPts: [SIMD2<Double>] = []
        for k in 0..<edgeSegs {
            let t = Double(k) / Double(edgeSegs)
            outerPts.append(ptStart * (1.0 - t) + cornerPt * t)
        }
        for k in 0..<edgeSegs {
            let t = Double(k) / Double(edgeSegs)
            outerPts.append(cornerPt * (1.0 - t) + ptEnd * t)
        }
        for k in 0..<arcSegs {
            let a = a0 + (a1 - a0) * Double(k) / Double(arcSegs)
            outerPts.append(SIMD2<Double>(cx + rCorner * cos(a), cy + rCorner * sin(a)))
        }

        let n = outerPts.count
        if rHole <= 0.001 {
            let cBot = SIMD3<Float>(Float(holeX), Float(holeY), fz0)
            let cTop = SIMD3<Float>(Float(holeX), Float(holeY), fz1)
            for i in 0..<n {
                let p0 = outerPts[i]
                let p1 = outerPts[(i + 1) % n]
                let b0 = SIMD3<Float>(Float(p0.x), Float(p0.y), fz0)
                let b1 = SIMD3<Float>(Float(p1.x), Float(p1.y), fz0)
                let t0 = SIMD3<Float>(Float(p0.x), Float(p0.y), fz1)
                let t1 = SIMD3<Float>(Float(p1.x), Float(p1.y), fz1)
                tris.append(Tri(v1: cBot, v2: b1, v3: b0))
                tris.append(Tri(v1: cTop, v2: t0, v3: t1))
                addQuad(b0, b1, t1, t0)
            }
        } else {
            let innerPts: [SIMD2<Double>] = outerPts.map { p in
                let ang = atan2(p.y - holeY, p.x - holeX)
                return SIMD2<Double>(holeX + rHole * cos(ang), holeY + rHole * sin(ang))
            }
            for i in 0..<n {
                let j = (i + 1) % n
                let pi0 = innerPts[i], pi1 = innerPts[j]
                let po0 = outerPts[i], po1 = outerPts[j]
                let bi0 = SIMD3<Float>(Float(pi0.x), Float(pi0.y), fz0)
                let bi1 = SIMD3<Float>(Float(pi1.x), Float(pi1.y), fz0)
                let bo0 = SIMD3<Float>(Float(po0.x), Float(po0.y), fz0)
                let bo1 = SIMD3<Float>(Float(po1.x), Float(po1.y), fz0)
                let ti0 = SIMD3<Float>(Float(pi0.x), Float(pi0.y), fz1)
                let ti1 = SIMD3<Float>(Float(pi1.x), Float(pi1.y), fz1)
                let to0 = SIMD3<Float>(Float(po0.x), Float(po0.y), fz1)
                let to1 = SIMD3<Float>(Float(po1.x), Float(po1.y), fz1)
                addQuad(bi0, bi1, bo1, bo0)
                addQuad(ti0, to0, to1, ti1)
                addQuad(bo0, bo1, to1, to0)
                addQuad(bi1, bi0, ti0, ti1)
            }
        }
    }

    func mirrorYInPlace(yMax: Double) {
        let fy = Float(yMax)
        tris = tris.map { t in
            let p1 = SIMD3<Float>(t.v1.x, fy - t.v1.y, t.v1.z)
            let p2 = SIMD3<Float>(t.v2.x, fy - t.v2.y, t.v2.z)
            let p3 = SIMD3<Float>(t.v3.x, fy - t.v3.y, t.v3.z)
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

@discardableResult
func addSTLMeshNode(_ parent: SCNNode, _ name: String, _ mesh: STLMesh,
                    _ mat: SCNMaterial, renderOrder: Int = 0) -> SCNNode {
    var vertices: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var indices: [Int32] = []
    vertices.reserveCapacity(mesh.tris.count * 3)
    normals.reserveCapacity(mesh.tris.count * 3)
    indices.reserveCapacity(mesh.tris.count * 3)
    for t in mesh.tris {
        let base = Int32(vertices.count)
        let e1 = t.v2 - t.v1
        let e2 = t.v3 - t.v1
        let nrm = simd_normalize(simd_cross(e1, e2))
        let sn = SCNVector3(CGFloat(nrm.x.isNaN ? 0 : nrm.x),
                            CGFloat(nrm.z.isNaN ? 1 : nrm.z),
                            CGFloat(nrm.y.isNaN ? 0 : -nrm.y))
        for v in [t.v1, t.v2, t.v3] {
            vertices.append(SCNVector3(CGFloat(v.x), CGFloat(v.z), CGFloat(-v.y)))
            normals.append(sn)
        }
        indices.append(contentsOf: [base, base + 1, base + 2])
    }
    let vSrc = SCNGeometrySource(vertices: vertices)
    let nSrc = SCNGeometrySource(normals: normals)
    let elem = SCNGeometryElement(indices: indices, primitiveType: .triangles)
    let geom = SCNGeometry(sources: [vSrc, nSrc], elements: [elem])
    geom.materials = [mat]
    let node = SCNNode(geometry: geom)
    node.name = name
    node.renderingOrder = renderOrder
    parent.addChildNode(node)
    return node
}

// MARK: - Locked Geometry Constants (72.0 x 84.0 x 19.5 mm, R=5.4mm)
let boxW = 72.0
let boxH = 84.0
let boxD = 19.5
let p5CornerRadius = 5.4
let p5CornerSpecs: [(q: Int, cx: Double, cy: Double, hx: Double, hy: Double)] = [
    (0, 5.4,  5.4,  3.6,  3.6),   // Bottom-Left
    (1, 66.6, 5.4,  68.4, 3.6),   // Bottom-Right
    (2, 66.6, 78.6, 68.4, 80.4),  // Top-Right
    (3, 5.4,  78.6, 3.6,  80.4)   // Top-Left
]

let frontCapXs = [36.0, 45.2, 54.4, 63.6]
let sideCapYs  = [54.3, 45.1, 35.9, 26.7] // B1 (V713 5V Audio Power) at topmost Y=54.3!
let micCX = 45.2
let micCY = 73.5

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

// MARK: - Build Complete Segmented Shell & Faceplate (72.0 x 84.0 x 19.5 mm)
func buildShellAndLid(shellMat: SCNMaterial, cradleMat: SCNMaterial, dzShellBot: Double, dzLid: Double, renderOrder: Int) -> (SCNNode, SCNNode) {
    let tray = SCNNode()
    tray.name = "p5_exp_compact_portrait_bottom_tray"
    // Back plate (Z: 0..1.8)
    addBox(tray, "back_center", 5.4, 66.6, 0.0, boxH, 0 + dzShellBot, 1.8 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "back_left", 0.0, 5.4, 5.4, 78.6, 0 + dzShellBot, 1.8 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "back_right", 66.6, boxW, 5.4, 78.6, 0 + dzShellBot, 1.8 + dzShellBot, shellMat, renderOrder: renderOrder)

    // Left Wall (X: 0..1.8, Y: 5.4..78.6, Z: 1.8..17.7) with 4.5mm Recessed Chamfered USB-C Plug Funnel (Y: 45.0..55.4, Z: 13.5..16.7)
    addBox(tray, "wall_left_bot", 0, 1.8, 5.4, 45.0, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_left_top", 0, 1.8, 55.4, 78.6, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_left_under_usbc", 0, 1.8, 45.0, 55.4, 1.8 + dzShellBot, 13.5 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_left_over_usbc", 0, 1.8, 45.0, 55.4, 16.7 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    // Internal USB-C funnel guide cheeks (X: 1.8..4.5) framing Y: 45.0..55.4, Z: 13.5..16.7
    addBox(tray, "usbc_funnel_bot_y", 1.8, 4.5, 44.0, 45.0, 12.5 + dzShellBot, 17.7 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "usbc_funnel_top_y", 1.8, 4.5, 55.4, 56.4, 12.5 + dzShellBot, 17.7 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "usbc_funnel_under_z", 1.8, 4.5, 45.0, 55.4, 12.5 + dzShellBot, 13.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "usbc_funnel_over_z", 1.8, 4.5, 45.0, 55.4, 16.7 + dzShellBot, 17.7 + dzShellBot, cradleMat, renderOrder: renderOrder)

    // Right Wall (X: 70.2..72.0, Y: 5.4..78.6, Z: 1.8..17.7) with Side 1x4 Keypad Cutouts (Y: 22.3..58.7) & MicroSD Cutout (Y: 60.5..78.4, Z: 9.8..13.4)
    addBox(tray, "wall_right_bot", 70.2, 72.0, 5.4, 22.3, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_side_under", 70.2, 72.0, 22.3, 58.7, 1.8 + dzShellBot, 5.3 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_side_over", 70.2, 72.0, 22.3, 58.7, 14.1 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    let sortedSideYs = sideCapYs.sorted() // [26.7, 35.9, 45.1, 54.3]
    for (i, cy) in sortedSideYs.enumerated() {
        let prevY = i == 0 ? 22.3 : sortedSideYs[i - 1] + 4.4
        if cy - 4.4 > prevY + 0.01 {
            addBox(tray, "wall_right_side_div_\(i)", 70.2, 72.0, prevY, cy - 4.4, 5.3 + dzShellBot, 14.1 + dzShellBot, shellMat, renderOrder: renderOrder)
        }
    }
    addBox(tray, "wall_right_mid", 70.2, 72.0, 58.7, 60.5, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    // MicroSD cutout (Y: 60.5..78.4, Z: 9.8..13.4)
    addBox(tray, "wall_right_under_sd", 70.2, 72.0, 60.5, 78.4, 1.8 + dzShellBot, 9.8 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_over_sd", 70.2, 72.0, 60.5, 78.4, 13.4 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_top", 70.2, 72.0, 78.4, 78.6, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)

    // Bottom Wall (X: 5.4..66.6, Y: 0..1.8)
    addBox(tray, "wall_bot", 5.4, 66.6, 0, 1.8, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)

    // Top Wall (X: 5.4..66.6, Y: 82.2..84.0) with 3.5mm TRS Jack Opening (X: 11.0..17.5, Z: 11.5..17.7)
    addBox(tray, "wall_top_left", 5.4, 11.0, 82.2, 84.0, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_under_trs", 11.0, 17.5, 82.2, 84.0, 1.8 + dzShellBot, 11.5 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_right", 17.5, 66.6, 82.2, 84.0, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)

    // 4x Monolithic R=5.4mm Rounded Corner Pillars w/ Ø2.0mm M2 Pilot Bores above Z=4.2
    let trayCornerMesh = STLMesh()
    for c in p5CornerSpecs {
        trayCornerMesh.addCornerSector(cx: c.cx, cy: c.cy, rCorner: p5CornerRadius, quadrant: c.q,
                                       holeX: c.hx, holeY: c.hy, rHole: 0.0, z0: 0.0 + dzShellBot, z1: 4.2 + dzShellBot)
        trayCornerMesh.addCornerSector(cx: c.cx, cy: c.cy, rCorner: p5CornerRadius, quadrant: c.q,
                                       holeX: c.hx, holeY: c.hy, rHole: 1.0, z0: 4.2 + dzShellBot, z1: 17.7 + dzShellBot)
        addCylZ(tray, "boss_hole_\(c.q)", c.hx, c.hy, 4.2 + dzShellBot, 17.71 + dzShellBot, 0.98, matPortCavity, radialSegs: 24)
    }
    addSTLMeshNode(tray, "tray_rounded_corners", trayCornerMesh, shellMat, renderOrder: renderOrder)

    // Internal Molded PCB Cradles, Support Rails & LiPo Retention
    // a. LiPo lateral rails (X: 4.5..5.4 left, X: 64.6..65.5 right above Y=60.0)
    addBox(tray, "cradle_lipo_l", 4.5, 5.4, 37.5, 74.5, 1.8 + dzShellBot, 7.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_lipo_r", 64.6, 65.5, 60.0, 74.5, 1.8 + dzShellBot, 7.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // b. KY-023 4x Corner Standoffs (25.0 x 33.0 mm PCB, Y: 3.5..36.5, Z: 1.8..2.4 mm)
    for (kx0, kx1, ky0, ky1) in [
        (5.5, 8.5, 3.5, 6.5), (27.5, 30.5, 3.5, 6.5),
        (5.5, 8.5, 33.5, 36.5), (27.5, 30.5, 33.5, 36.5)
    ] {
        addBox(tray, "cradle_ky_\(kx0)_\(ky0)", kx0, kx1, ky0, ky1, 1.8 + dzShellBot, 2.4 + dzShellBot, cradleMat, renderOrder: renderOrder)
    }
    // c. Front 1x4 Keypad Support Rails (X: 31.5..68.5, Y: 5.5..20.5, Z: 1.8..7.9 mm; L/C stop at Y=15.5 to clear V713)
    addBox(tray, "cradle_front_pad_l", 31.5, 34.0, 5.5, 15.5, 1.8 + dzShellBot, 7.9 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_front_pad_c", 48.8, 51.2, 5.5, 15.5, 1.8 + dzShellBot, 7.9 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_front_pad_r", 66.0, 68.5, 5.5, 20.5, 1.8 + dzShellBot, 7.9 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // d. Right-Side Vertical 1x4 Keypad Mounting Rails (Y: 20.8..21.8 bot, Y: 59.2..60.2 top, X: 64.6..70.2)
    addBox(tray, "cradle_side_pad_bot", 64.6, 70.2, 20.8, 21.8, 1.8 + dzShellBot, 17.2 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_side_pad_top", 64.6, 70.2, 59.2, 60.2, 1.8 + dzShellBot, 17.2 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_side_pad_floor", 64.6, 66.6, 22.0, 59.0, 1.8 + dzShellBot, 2.2 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // e. T-Display-S3 AMOLED Support Ledges (Centered Display: PCB X: 4.5..64.5, Y: 37.5..63.0, Z: 13.5..15.1)
    addBox(tray, "cradle_amoled_l1", 4.5, 6.2, 37.5, 38.4, 8.0 + dzShellBot, 13.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_amoled_l2", 4.5, 6.2, 62.3, 63.0, 8.0 + dzShellBot, 13.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_amoled_r_shelf", 60.0, 64.6, 59.2, 60.2, 8.0 + dzShellBot, 13.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // f. GY-PCM5102 Support Pillars (Z: 1.8..11.0)
    addBox(tray, "cradle_pcm_l_stem", 3.5, 5.3, 65.0, 78.4, 1.8 + dzShellBot, 11.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_pcm_l_shelf", 5.3, 7.8, 65.0, 78.4, 9.0 + dzShellBot, 11.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_pcm_r", 29.1, 29.7, 75.5, 81.5, 1.8 + dzShellBot, 11.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // g. Mini 3.3V MicroSD U-Pedestal (Y: 60.5..78.4, Z: 9.0)
    addBox(tray, "cradle_sd_rear_top", 56.8, 66.4, 79.5, 81.6, 1.8 + dzShellBot, 9.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_sd_front_r", 66.6, 70.2, 60.5, 65.0, 1.8 + dzShellBot, 9.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_sd_shelf_l", 52.3, 56.8, 60.5, 78.4, 8.0 + dzShellBot, 9.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    // h. V713 5V 2A Boost Retention Stop-Lip + KCX_BT_EMITTER Elevated Shelf (Z: 9.0 above V713)
    addBox(tray, "cradle_boost_stop", 32.0, 57.0, 15.8, 16.2, 1.8 + dzShellBot, 4.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_kcx_stem", 59.0, 61.0, 22.0, 36.0, 1.8 + dzShellBot, 9.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_kcx_shelf", 53.0, 59.0, 22.0, 36.0, 7.5 + dzShellBot, 9.0 + dzShellBot, cradleMat, renderOrder: renderOrder)

    // Complete Segmented Front Faceplate Lid (Z: 17.7..19.5 mm) w/ R=5.4mm Rounded Corners
    let lid = SCNNode()
    lid.name = "p5_exp_compact_portrait_top_faceplate"
    let lidCornerMesh = STLMesh()
    for c in p5CornerSpecs {
        lidCornerMesh.addCornerSector(cx: c.cx, cy: c.cy, rCorner: p5CornerRadius, quadrant: c.q,
                                      holeX: c.hx, holeY: c.hy, rHole: 1.1, z0: 17.7 + dzLid, z1: 19.5 + dzLid)
    }
    addSTLMeshNode(lid, "lid_rounded_corners", lidCornerMesh, shellMat, renderOrder: renderOrder)

    // 1. Upper section (Y: 62.0..84.0) + Ø9.6mm 21-dot mic grille at (45.2, 73.5)
    addBox(lid, "lid_up_left_l", 0.0, 5.4, 62.0, 78.6, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_left_main", 5.4, micCX - 5.0, 62.0, 84.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_right_main", micCX + 5.0, 66.6, 62.0, 84.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_right_r", 66.6, 72.0, 62.0, 78.6, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_mic_bot", micCX - 5.0, micCX + 5.0, 62.0, micCY - 5.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_mic_top", micCX - 5.0, micCX + 5.0, micCY + 5.0, 84.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addTubeZ(lid, "lid_mic_collar", micCX, micCY, 17.7 + dzLid, 19.5 + dzLid, 4.8, 6.2, shellMat)
    for (mx, my) in [(micCX - 4.3, micCY - 4.3), (micCX + 4.3, micCY - 4.3), (micCX - 4.3, micCY + 4.3), (micCX + 4.3, micCY + 4.3)] {
        addBox(lid, "lid_mic_corner_\(mx)_\(my)", mx - 0.75, mx + 0.75, my - 0.75, my + 0.75, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    }
    addTubeZ(lid, "lid_mic_trim", micCX, micCY, 17.7 + dzLid, 19.45 + dzLid, 4.55, 4.8, matPortCavity)
    addCylZ(lid, "lid_mic_disc_floor", micCX, micCY, 17.7 + dzLid, 19.05 + dzLid, 4.55, shellMat)
    addBox(lid, "lid_mic_cross_x", micCX - 3.9, micCX + 3.9, micCY - 0.12, micCY + 0.12, 19.02 + dzLid, 19.09 + dzLid, matPortCavity)
    addBox(lid, "lid_mic_cross_y", micCX - 0.12, micCX + 0.12, micCY - 3.9, micCY + 3.9, 19.02 + dzLid, 19.09 + dzLid, matPortCavity)
    for dx in [-3.2, -1.6, 0.0, 1.6, 3.2] {
        for dy in [-3.2, -1.6, 0.0, 1.6, 3.2] {
            if abs(dx) + abs(dy) < 6.0 {
                addCylZ(lid, "mic_dot_\(dx)_\(dy)", micCX + dx, micCY + dy, 19.00 + dzLid, 19.12 + dzLid, 0.475, matPortCavity, radialSegs: 20)
            }
        }
    }
    addTubeZ(lid, "lid_inmp441_ring", micCX, micCY, 16.1 + dzLid, 17.7 + dzLid, 4.6, 6.2, cradleMat)

    // 2. Dead-Centered AMOLED window bezel (Y: 37.5..62.0, active glass cutout X: 11.0..61.0, Y: 39.0..60.5)
    addBox(lid, "lid_amoled_l", 0, 11.0, 37.5, 62.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_amoled_r", 61.0, 72.0, 37.5, 62.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_amoled_t", 11.0, 61.0, 60.5, 62.0, 17.7 + dzLid, 19.5 + dzLid, matOpaqueBezel, renderOrder: renderOrder)
    addBox(lid, "lid_amoled_b", 11.0, 61.0, 37.5, 39.0, 17.7 + dzLid, 19.5 + dzLid, matOpaqueBezel, renderOrder: renderOrder)

    // 3. Upper-Right solid deck over Front Keypad (X: 31.5..72.0, Y: 22.0..37.5)
    addBox(lid, "lid_upper_right_solid", 31.5, 72.0, 22.0, 37.5, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)

    // 4. Lower-left thumbstick deck (X: 0..31.5, Y: 0..37.5) centered at (17.5, 20.8)
    addTubeZ(lid, "lid_stick_collar", 17.5, 20.8, 16.3 + dzLid, 19.5 + dzLid, 12.5, 14.15, shellMat)
    addBox(lid, "lid_stick_l", 0, 5.0, 5.4, 37.5, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_bl_fill", 5.0, 5.4, 5.4, 8.3, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_r", 30.0, 31.5, 0, 37.5, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_b", 5.4, 30.0, 0, 8.3, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_t", 5.0, 30.0, 33.3, 37.5, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    for sx in [-1.0, 1.0] {
        for sy in [-1.0, 1.0] {
            let ax0 = 17.5 + sx * 8.9, ax1 = 17.5 + sx * 12.6
            let ay0 = 20.8 + sy * 8.9, ay1 = 20.8 + sy * 12.6
            addBox(lid, "lid_stick_spA_\(sx)_\(sy)", min(ax0, ax1), max(ax0, ax1), min(ay0, ay1), max(ay0, ay1), 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
            let bx0 = 17.5 + sx * 6.4, bx1 = 17.5 + sx * 9.0
            let by0 = 20.8 + sy * 10.8, by1 = 20.8 + sy * 12.6
            addBox(lid, "lid_stick_spB_\(sx)_\(sy)", min(bx0, bx1), max(bx0, bx1), min(by0, by1), max(by0, by1), 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
            let cx0 = 17.5 + sx * 10.8, cx1 = 17.5 + sx * 12.6
            let cy0 = 20.8 + sy * 6.4, cy1 = 20.8 + sy * 9.0
            addBox(lid, "lid_stick_spC_\(sx)_\(sy)", min(cx0, cx1), max(cx0, cx1), min(cy0, cy1), max(cy0, cy1), 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
        }
    }
    addCylZ(lid, "lid_stick_well", 17.5, 20.8, 16.1 + dzLid, 16.4 + dzLid, 12.6, matPortCavity)
    addTubeZ(lid, "lid_stick_wall", 17.5, 20.8, 16.3 + dzLid, 19.45 + dzLid, 12.35, 12.55, matOpaqueBezel)

    // 5. Lower-right 1x4 Front Keypad Grid (X: 31.5..72.0, Y: 0..22.0, cap Y center = 13.0)
    addBox(lid, "lid_pad_bot_strip", 31.5, 66.6, 0, 8.6, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_pad_bot_rcap", 66.6, 72.0, 5.4, 8.6, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_pad_top_strip", 31.5, 72.0, 17.4, 22.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    for (i, cx) in frontCapXs.enumerated() {
        let prevX = i == 0 ? 31.5 : frontCapXs[i - 1] + 4.4
        addBox(lid, "lid_pad_b_div_\(i)", prevX, cx - 4.4, 8.6, 17.4, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    }
    addBox(lid, "lid_pad_b_right", 68.0, 72.0, 8.6, 17.4, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)

    // 6. 4x Countersunk M2 Corner Screw Heads on Faceplate
    for (sx, sy) in [(3.6, 3.6), (68.4, 3.6), (3.6, 80.4), (68.4, 80.4)] {
        addCylZ(lid, "m2_screw_\(sx)_\(sy)", sx, sy, 17.8 + dzLid, 19.55 + dzLid, 1.7, matBlackCap)
        addCylZ(lid, "m2_hex_\(sx)_\(sy)", sx, sy, 17.85 + dzLid, 19.58 + dzLid, 0.8, matSilver)
    }

    return (tray, lid)
}

// MARK: - Build Option P5-Exp-Compact-Portrait (72.0 x 84.0 x 19.5 mm) + Verify
func buildP5ExpCompactPortrait(exploded: Bool = false, opaque: Bool = false) -> (SCNNode, Int) {
    let root = SCNNode()
    var boxes: [(String, AABB)] = []
    let dzShellBot = exploded ? -19.0 : 0.0
    let dzLiPo = exploded ? -8.5 : 0.0
    let dzShield = exploded ? 0.0 : 0.0
    let dzControls = exploded ? 8.5 : 0.0
    let dzTopBay = exploded ? 10.5 : 0.0
    let dzAMOLED = exploded ? 19.0 : 0.0
    let dzLid = exploded ? 30.0 : 0.0

    let shellMat = opaque ? matOpaqueCharcoal : matSmokeShell
    let ro = opaque ? 0 : 20
    let (tray, lid) = buildShellAndLid(shellMat: shellMat, cradleMat: shellMat, dzShellBot: dzShellBot, dzLid: dzLid, renderOrder: ro)
    root.addChildNode(tray)

    boxes.append(("boss_bl", makeAABB("boss_bl", 0.0, 5.4, 0.0, 5.4, 1.8, 17.7)))
    boxes.append(("boss_br", makeAABB("boss_br", 66.6, 72.0, 0.0, 5.4, 1.8, 17.7)))
    boxes.append(("boss_tl", makeAABB("boss_tl", 0.0, 5.4, 78.6, 84.0, 1.8, 17.7)))
    boxes.append(("boss_tr", makeAABB("boss_tr", 66.6, 72.0, 78.6, 84.0, 1.8, 17.7)))

    // Register Internal Printed Support Cradles for Collision Verification
    boxes.append(("cradles", makeAABB("cradle_lipo_l", 4.5, 5.4, 37.5, 74.5, 1.8, 7.0)))
    boxes.append(("cradles", makeAABB("cradle_lipo_r", 64.6, 65.5, 60.0, 74.5, 1.8, 7.0)))
    for (kx0, kx1, ky0, ky1) in [
        (5.5, 8.5, 3.5, 6.5), (27.5, 30.5, 3.5, 6.5),
        (5.5, 8.5, 33.5, 36.5), (27.5, 30.5, 33.5, 36.5)
    ] {
        boxes.append(("cradles", makeAABB("cradle_ky_\(kx0)_\(ky0)", kx0, kx1, ky0, ky1, 1.8, 2.4)))
    }
    boxes.append(("cradles", makeAABB("cradle_front_pad_l", 31.5, 34.0, 5.5, 15.5, 1.8, 7.9)))
    boxes.append(("cradles", makeAABB("cradle_front_pad_c", 48.8, 51.2, 5.5, 15.5, 1.8, 7.9)))
    boxes.append(("cradles", makeAABB("cradle_front_pad_r", 66.0, 68.5, 5.5, 20.5, 1.8, 7.9)))
    boxes.append(("cradles", makeAABB("cradle_side_pad_bot", 64.6, 70.2, 20.8, 21.8, 1.8, 17.2)))
    boxes.append(("cradles", makeAABB("cradle_side_pad_top", 64.6, 70.2, 59.2, 60.2, 1.8, 17.2)))
    boxes.append(("cradles", makeAABB("cradle_side_pad_floor", 64.6, 66.6, 22.0, 59.0, 1.8, 2.2)))
    boxes.append(("cradles", makeAABB("cradle_amoled_l1", 4.5, 6.2, 37.5, 38.4, 8.0, 13.5)))
    boxes.append(("cradles", makeAABB("cradle_amoled_l2", 4.5, 6.2, 62.3, 63.0, 8.0, 13.5)))
    boxes.append(("cradles", makeAABB("cradle_amoled_r_shelf", 60.0, 64.6, 59.2, 60.2, 8.0, 13.5)))
    boxes.append(("cradles", makeAABB("cradle_pcm_l_stem", 3.5, 5.3, 65.0, 78.4, 1.8, 11.0)))
    boxes.append(("cradles", makeAABB("cradle_pcm_l_shelf", 5.3, 7.8, 65.0, 78.4, 9.0, 11.0)))
    boxes.append(("cradles", makeAABB("cradle_pcm_r", 29.1, 29.7, 75.5, 81.5, 1.8, 11.0)))
    boxes.append(("cradles", makeAABB("cradle_sd_rear_top", 56.8, 66.4, 79.5, 81.6, 1.8, 9.0)))
    boxes.append(("cradles", makeAABB("cradle_sd_front_r", 66.6, 70.2, 60.5, 65.0, 1.8, 9.0)))
    boxes.append(("cradles", makeAABB("cradle_sd_shelf_l", 52.3, 56.8, 60.5, 78.4, 8.0, 9.0)))
    boxes.append(("cradles", makeAABB("cradle_boost_stop", 32.0, 57.0, 15.8, 16.2, 1.8, 4.5)))
    boxes.append(("cradles", makeAABB("cradle_kcx_stem", 59.0, 61.0, 22.0, 36.0, 1.8, 9.0)))
    boxes.append(("cradles", makeAABB("cradle_kcx_shelf", 53.0, 59.0, 22.0, 36.0, 7.5, 9.0)))
    boxes.append(("cradles", makeAABB("usbc_funnel_bot_y", 1.8, 4.5, 44.0, 45.0, 12.5, 17.7)))
    boxes.append(("cradles", makeAABB("usbc_funnel_top_y", 1.8, 4.5, 55.4, 56.4, 12.5, 17.7)))
    boxes.append(("cradles", makeAABB("usbc_funnel_under_z", 1.8, 4.5, 45.0, 55.4, 12.5, 13.5)))
    boxes.append(("cradles", makeAABB("usbc_funnel_over_z", 1.8, 4.5, 45.0, 55.4, 16.7, 17.7)))

    // 1. 503759 1300 mAh LiPo (59.0 x 37.0 x 5.0 mm, X: 5.5..64.5, Y: 37.5..74.5) + 0.8 mm Shield Rib
    let lipoNode = SCNNode()
    addBox(lipoNode, "lipo_503759", 5.5, 64.5, 37.5, 74.5, 1.8 + dzLiPo, 6.8 + dzLiPo, matLiPo, chamfer: 0.4)
    addBox(lipoNode, "lipo_tape", 5.5, 10.0, 37.5, 74.5, 1.9 + dzLiPo, 6.9 + dzLiPo, matAmberCap)
    addBox(lipoNode, "shield_rib", 5.5, 64.5, 37.2, 74.7, 7.0 + dzShield, 7.8 + dzShield, shellMat, renderOrder: ro)
    boxes.append(("lipo", makeAABB("lipo_503759", 5.5, 64.5, 37.5, 74.5, 1.8, 6.8)))
    boxes.append(("shield_rib", makeAABB("shield_rib", 5.5, 64.5, 37.2, 74.7, 7.0, 7.8)))
    root.addChildNode(lipoNode)

    // 2. KY-023 Low-Profile Gimbal (25.0 x 33.0 mm on Z=2.4mm standoffs) + Ø16.0mm Concave Cap Recessed in Ø25.0mm Well
    let kyNode = SCNNode()
    addBox(kyNode, "ky_pcb", 5.5, 30.5, 3.5, 36.5, 2.4 + dzControls, 4.0 + dzControls, matDarkPCB)
    addBox(kyNode, "ky_gimbal", 9.5, 25.5, 12.8, 28.8, 4.0 + dzControls, 14.4 + dzControls, matSilver)
    addCylZ(kyNode, "ky_shaft", 17.5, 20.8, 14.4 + dzControls, 18.1 + dzControls, 2.0, matBlackCap)
    addTubeZ(kyNode, "ky_disc_stem", 17.5, 20.8, 16.3 + dzControls, 17.9 + dzControls, 2.0, 3.6, matCoralCap)
    addCylZ(kyNode, "ky_concave_disc", 17.5, 20.8, 17.9 + dzControls, 18.9 + dzControls, 8.0, matCoralCap)
    addTubeZ(kyNode, "ky_disc_rim", 17.5, 20.8, 18.9 + dzControls, 20.1 + dzControls, 5.8, 8.0, matCoralCap)
    let matCoralInner = makeMat(0.82, 0.33, 0.26, 1.0, metal: 0.04, rough: 0.48)
    addTubeZ(kyNode, "ky_disc_dish_shade", 17.5, 20.8, 18.85 + dzControls, 19.05 + dzControls, 5.4, 5.8, matCoralInner)
    boxes.append(("ky023", makeAABB("ky_body", 5.5, 30.5, 3.5, 36.5, 2.4, 14.4)))
    root.addChildNode(kyNode)

    // 3a. 1x Front 1x4 Keypad (37.0 x 15.0 mm at X: 31.5..68.5, Y: 5.5..20.5, Z: 7.9..17.5; Color: Amber, Teal, Amber, Coral)
    let padNode = SCNNode()
    addBox(padNode, "pad_front_pcb", 31.5, 68.5, 5.5, 20.5, 7.9 + dzControls, 9.5 + dzControls, matGreenPCB)
    let frontMats = [matAmberCap, matTealCap, matAmberCap, matCoralCap]
    for (i, cx) in frontCapXs.enumerated() {
        addBox(padNode, "sw_front_\(i)", cx - 3.0, cx + 3.0, 10.0, 16.0, 9.5 + dzControls, 16.9 + dzControls, matBlackCap)
        addBox(padNode, "cap_front_flange_\(i)", cx - 4.7, cx + 4.7, 8.3, 17.7, 16.9 + dzControls, 17.7 + dzControls, frontMats[i])
        addBox(padNode, "cap_front_\(i)", cx - 4.1, cx + 4.1, 8.9, 17.1, 17.7 + dzControls, 20.5 + dzControls, frontMats[i], chamfer: 0.6)
    }
    boxes.append(("pad_front", makeAABB("pad_front", 31.5, 68.5, 5.5, 20.5, 7.9, 17.5)))

    // 3b. 1x Right-Side 1x4 Keypad (37.0 x 15.0 mm vertical along X=72.0, Y: 22.0..59.0, Z: 2.2..17.2; 4x Matte Black caps)
    let dxSide = exploded ? 8.0 : 0.0
    addBox(padNode, "pad_side_pcb", 64.6 + dxSide, 66.2 + dxSide, 22.0, 59.0, 2.2 + dzControls, 17.2 + dzControls, matGreenPCB)
    for (i, cy) in sideCapYs.enumerated() {
        addBox(padNode, "sw_side_\(i)", 66.2 + dxSide, 70.2 + dxSide, cy - 3.0, cy + 3.0, 6.7 + dzControls, 12.7 + dzControls, matBlackCap)
        addBox(padNode, "cap_side_flange_\(i)", 69.4 + dxSide, 70.2 + dxSide, cy - 4.7, cy + 4.7, 5.0 + dzControls, 14.4 + dzControls, matBlackCap)
        addBox(padNode, "cap_side_\(i)", 70.2 + dxSide, 72.8 + dxSide, cy - 4.1, cy + 4.1, 5.6 + dzControls, 13.8 + dzControls, matBlackCap, chamfer: 0.5)
    }
    boxes.append(("pad_side", makeAABB("pad_side", 64.6, 70.2, 22.0, 59.0, 2.2, 17.2)))
    root.addChildNode(padNode)

    // 4. Dead-Centered LILYGO T-Display-S3 AMOLED (60.0 x 25.5 x 4.2 mm, Active Window centered at X=36.0 mm!)
    let espNode = SCNNode()
    addBox(espNode, "amoled_pcb", 4.5, 64.5, 37.5, 63.0, 13.5 + dzAMOLED, 15.1 + dzAMOLED, matDarkPCB)
    addBox(espNode, "amoled_rear_jst", 4.7, 14.0, 38.5, 62.2, 9.7 + dzAMOLED, 13.5 + dzAMOLED, matSilver)
    addBox(espNode, "amoled_rear_ant", 54.5, 64.3, 42.0, 58.5, 10.0 + dzAMOLED, 13.5 + dzAMOLED, matSilver)
    addBox(espNode, "amoled_glass", 11.0, 61.0, 39.0, 60.5, 15.1 + dzAMOLED, 17.7 + dzAMOLED, matAMOLEDGlass)
    addBox(espNode, "amoled_active", 13.9, 58.1, 39.8, 59.6, 17.55 + dzAMOLED, 17.80 + dzAMOLED, matAMOLEDActive)
    // USB-C receptacle (X: 2.5..9.3, Y: 45.7..54.7, Z: 13.5..16.7) behind 4.5mm Left-Wall Funnel
    addBox(espNode, "amoled_usbc_shell", 2.5, 9.3, 45.7, 54.7, 13.5 + dzAMOLED, 16.7 + dzAMOLED, matSilver, chamfer: 0.5)
    addBox(espNode, "amoled_usbc_bore", 2.45, 4.0, 46.5, 53.9, 14.0 + dzAMOLED, 16.2 + dzAMOLED, matPortCavity, chamfer: 0.3)
    boxes.append(("amoled", makeAABB("t_display_s3_amoled", 4.5, 64.5, 37.5, 63.0, 13.5, 17.7)))
    boxes.append(("amoled", makeAABB("amoled_rear_jst", 4.7, 14.0, 38.5, 62.2, 9.7, 13.5)))
    boxes.append(("amoled", makeAABB("amoled_rear_ant", 54.5, 64.3, 42.0, 58.5, 10.0, 13.5)))
    boxes.append(("amoled", makeAABB("amoled_usbc", 2.5, 9.3, 45.7, 54.7, 13.5, 16.7)))
    root.addChildNode(espNode)

    // 5. Mid-Right & Upper Deck:
    let topBay = SCNNode()
    // 5a1. AOICRIE V713 5V 2A Boost (26.5 x 20.0 x 4.8 mm) in Mid-Right Lower Bay (X: 32.0..58.5, Y: 16.5..36.5, Z: 2.0..6.8)
    addBox(topBay, "boost_5v2a_pcb", 32.0, 57.0, 16.5, 36.5, 2.0 + dzTopBay, 3.6 + dzTopBay, matDarkPCB)
    addBox(topBay, "boost_inductor", 35.5, 42.5, 23.0, 30.0, 3.6 + dzTopBay, 6.8 + dzTopBay, matBlackCap)
    addBox(topBay, "boost_usbc_shell", 51.7, 58.5, 22.0, 31.0, 3.6 + dzTopBay, 6.8 + dzTopBay, matSilver, chamfer: 0.5)
    boxes.append(("boost_5v2a", makeAABB("boost_5v2a", 32.0, 58.5, 16.5, 36.5, 2.0, 6.8)))

    // 5a2. Acxico KCX_BT_EMITTER (23.5 x 15.5 x 2.5 mm) Elevated above V713 (X: 32.0..55.5, Y: 21.5..37.0, Z: 9.0..11.5)
    addBox(topBay, "bt_emitter_pcb", 32.0, 55.5, 21.5, 37.0, 9.0 + dzTopBay, 10.4 + dzTopBay, matBluePCB)
    addBox(topBay, "bt_emitter_ic", 38.5, 47.5, 25.0, 32.0, 10.4 + dzTopBay, 11.5 + dzTopBay, matBlackCap)
    boxes.append(("bt_emitter", makeAABB("kcx_bt_emitter", 32.0, 55.5, 21.5, 37.0, 9.0, 11.5)))

    // 5b. GY-PCM5102 (32.0 x 17.0 x 5.5 mm) Top-Left (Z: 11.0..16.5), 3.5mm TRS Jack flush at Top Wall Y=84.0!
    addBox(topBay, "pcm5102_pcb", 6.0, 38.0, 65.0, 82.0, 11.0 + dzTopBay, 12.6 + dzTopBay, matPurplePCB)
    addBox(topBay, "pcm5102_trs", 10.0, 18.5, 70.0, 82.2, 12.6 + dzTopBay, 16.5 + dzTopBay, matBlackCap)
    addCylY(topBay, "pcm5102_trs_ring", 14.25, 14.55 + dzTopBay, 81.8, 84.35, 3.0, matGold)
    addCylY(topBay, "pcm5102_trs_bore", 14.25, 14.55 + dzTopBay, 82.0, 84.42, 1.75, matPortCavity)
    boxes.append(("pcm5102", makeAABB("gy_pcm5102", 6.0, 38.0, 65.0, 82.0, 11.0, 16.5)))

    // 5c. INMP441 MEMS Mic (Ø14.0 mm) Top-Middle-Right at (45.2, 73.5), Z: 14.5..17.5
    addCylZ(topBay, "inmp441_pcb", micCX, micCY, 14.5 + dzTopBay, 16.1 + dzTopBay, 7.0, matDarkPCB)
    addCylZ(topBay, "inmp441_gasket", micCX, micCY, 16.1 + dzTopBay, 17.5 + dzTopBay, 4.5, matBlackCap)
    boxes.append(("inmp441", makeAABB("inmp441", micCX - 7.0, micCX + 7.0, micCY - 7.0, micCY + 7.0, 14.5, 17.5)))

    // 5d. WWZMDiB Mini 3.3V MicroSD (17.9 x 17.9 x 4.0 mm) Upper-Right, card slot flush at Right Wall X=72.0!
    addBox(topBay, "microsd_pcb", 52.3, 70.2, 60.5, 78.4, 9.0 + dzTopBay, 10.6 + dzTopBay, matBluePCB)
    addBox(topBay, "microsd_cage", 55.7, 70.2, 62.5, 76.3, 10.6 + dzTopBay, 13.0 + dzTopBay, matSilver)
    addBox(topBay, "microsd_card_edge", 68.0, 71.9, 63.7, 74.7, 11.0 + dzTopBay, 12.2 + dzTopBay, matGold)
    boxes.append(("microsd", makeAABB("mini_3v3_microsd", 52.3, 70.2, 60.5, 78.4, 9.0, 13.0)))
    root.addChildNode(topBay)

    root.addChildNode(lid)

    let cols = exploded ? 0 : verifyAABBs(label: opaque ? "Option_P5_Exp_Compact_Portrait_Opaque" : "Option_P5_Exp_Compact_Portrait_Smoke", boxes: boxes)
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

// MARK: - Build Printable Binary STL Parts (1 mm units for Bambu P2S, R=5.4mm Rounded Corners)
func exportPrintableSTLs() throws {
    let tray = STLMesh()
    // Back plate partitioned flush inside R=5.4mm corners
    tray.addBox(5.4, 66.6, 0.0, boxH, 0.0, 1.8)
    tray.addBox(0.0, 5.4, 5.4, 78.6, 0.0, 1.8)
    tray.addBox(66.6, boxW, 5.4, 78.6, 0.0, 1.8)
    // Left Wall (X: 0..1.8, Z: 1.8..17.7) + 4.5mm Recessed USB-C Funnel
    tray.addBox(0, 1.8, 5.4, 45.0, 1.8, 17.7)
    tray.addBox(0, 1.8, 55.4, 78.6, 1.8, 17.7)
    tray.addBox(0, 1.8, 45.0, 55.4, 1.8, 13.5)
    tray.addBox(0, 1.8, 45.0, 55.4, 16.7, 17.7)
    tray.addBox(1.8, 4.5, 44.0, 45.0, 12.5, 17.7)
    tray.addBox(1.8, 4.5, 55.4, 56.4, 12.5, 17.7)
    tray.addBox(1.8, 4.5, 45.0, 55.4, 12.5, 13.5)
    tray.addBox(1.8, 4.5, 45.0, 55.4, 16.7, 17.7)
    // Right Wall (X: 70.2..72.0) w/ Side 1x4 Keypad Cutouts (Y: 22.3..58.7) & MicroSD Cutout (Y: 60.5..78.4)
    tray.addBox(70.2, 72.0, 5.4, 22.3, 1.8, 17.7)
    tray.addBox(70.2, 72.0, 22.3, 58.7, 1.8, 5.3)
    tray.addBox(70.2, 72.0, 22.3, 58.7, 14.1, 17.7)
    let sortedSideYs = sideCapYs.sorted()
    for (i, cy) in sortedSideYs.enumerated() {
        let prevY = i == 0 ? 22.3 : sortedSideYs[i - 1] + 4.4
        if cy - 4.4 > prevY + 0.01 {
            tray.addBox(70.2, 72.0, prevY, cy - 4.4, 5.3, 14.1)
        }
    }
    tray.addBox(70.2, 72.0, 58.7, 60.5, 1.8, 17.7)
    tray.addBox(70.2, 72.0, 60.5, 78.4, 1.8, 9.8)
    tray.addBox(70.2, 72.0, 60.5, 78.4, 13.4, 17.7)
    tray.addBox(70.2, 72.0, 78.4, 78.6, 1.8, 17.7)
    // Bottom & Top Walls
    tray.addBox(5.4, 66.6, 0, 1.8, 1.8, 17.7)
    tray.addBox(5.4, 11.0, 82.2, 84.0, 1.8, 17.7)
    tray.addBox(11.0, 17.5, 82.2, 84.0, 1.8, 11.5)
    tray.addBox(17.5, 66.6, 82.2, 84.0, 1.8, 17.7)
    // 4x Monolithic R=5.4mm Rounded Corner Pillars w/ Ø2.0mm M2 pilot bore above Z=4.2 mm
    for c in p5CornerSpecs {
        tray.addCornerSector(cx: c.cx, cy: c.cy, rCorner: p5CornerRadius, quadrant: c.q,
                             holeX: c.hx, holeY: c.hy, rHole: 0.0, z0: 0.0, z1: 4.2)
        tray.addCornerSector(cx: c.cx, cy: c.cy, rCorner: p5CornerRadius, quadrant: c.q,
                             holeX: c.hx, holeY: c.hy, rHole: 1.0, z0: 4.2, z1: 17.7)
    }
    // Internal PCB Cradles & Support Rails
    tray.addBox(4.5, 5.4, 37.5, 74.5, 1.8, 7.0)
    tray.addBox(64.6, 65.5, 60.0, 74.5, 1.8, 7.0)
    for (kx0, kx1, ky0, ky1) in [
        (5.5, 8.5, 3.5, 6.5), (27.5, 30.5, 3.5, 6.5),
        (5.5, 8.5, 33.5, 36.5), (27.5, 30.5, 33.5, 36.5)
    ] {
        tray.addBox(kx0, kx1, ky0, ky1, 1.8, 2.4)
    }
    tray.addBox(31.5, 34.0, 5.5, 15.5, 1.8, 7.9)
    tray.addBox(48.8, 51.2, 5.5, 15.5, 1.8, 7.9)
    tray.addBox(66.0, 68.5, 5.5, 20.5, 1.8, 7.9)
    tray.addBox(64.6, 70.2, 20.8, 21.8, 1.8, 17.2)
    tray.addBox(64.6, 70.2, 59.2, 60.2, 1.8, 17.2)
    tray.addBox(64.6, 66.6, 22.0, 59.0, 1.8, 2.2)
    tray.addBox(4.5, 6.2, 37.5, 38.4, 8.0, 13.5)
    tray.addBox(4.5, 6.2, 62.3, 63.0, 8.0, 13.5)
    tray.addBox(60.0, 64.6, 59.2, 60.2, 8.0, 13.5)
    tray.addBox(3.5, 5.3, 65.0, 78.4, 1.8, 11.0)
    tray.addBox(5.3, 7.8, 65.0, 78.4, 9.0, 11.0)
    tray.addBox(29.1, 29.7, 75.5, 81.5, 1.8, 11.0)
    tray.addBox(56.8, 66.4, 79.5, 81.6, 1.8, 9.0)
    tray.addBox(66.6, 70.2, 60.5, 65.0, 1.8, 9.0)
    tray.addBox(52.3, 56.8, 60.5, 78.4, 8.0, 9.0)
    tray.addBox(32.0, 57.0, 15.8, 16.2, 1.8, 4.5)
    tray.addBox(59.0, 61.0, 22.0, 36.0, 1.8, 9.0)
    tray.addBox(53.0, 59.0, 22.0, 36.0, 7.5, 9.0)
    try tray.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_portrait_bottom_tray.stl", header: "P5-Exp-Compact-Portrait Bottom Tray 72x84x17.7mm R5.4mm")

    // Top Faceplate printed exterior-down (Z: 0..1.8 faceplate w/ R=5.4mm corners & Ø2.2mm M2 holes, Z: 1.8..3.4 collars)
    let lid = STLMesh()
    for c in p5CornerSpecs {
        lid.addCornerSector(cx: c.cx, cy: c.cy, rCorner: p5CornerRadius, quadrant: c.q,
                            holeX: c.hx, holeY: c.hy, rHole: 1.1, z0: 0.0, z1: 1.8)
    }
    lid.addBox(0.0, 5.4, 62.0, 78.6, 0, 1.8)
    lid.addBox(5.4, micCX - 5.0, 62.0, 84.0, 0, 1.8)
    lid.addBox(micCX + 5.0, 66.6, 62.0, 84.0, 0, 1.8)
    lid.addBox(66.6, 72.0, 62.0, 78.6, 0, 1.8)
    lid.addBox(micCX - 5.0, micCX + 5.0, 62.0, micCY - 5.0, 0, 1.8)
    lid.addBox(micCX - 5.0, micCX + 5.0, micCY + 5.0, 84.0, 0, 1.8)
    lid.addAnnulusZ(cx: micCX, cy: micCY, rIn: 4.8, rOut: 6.2, z0: 0, z1: 1.8)
    for (mx, my) in [(micCX - 4.3, micCY - 4.3), (micCX + 4.3, micCY - 4.3), (micCX - 4.3, micCY + 4.3), (micCX + 4.3, micCY + 4.3)] {
        lid.addBox(mx - 0.75, mx + 0.75, my - 0.75, my + 0.75, 0, 1.8)
    }
    let ribSpans: [(Double, Double)] = [
        (-5.00, -3.65), (-2.75, -2.05), (-1.15, -0.45),
        (0.45, 1.15), (2.05, 2.75), (3.65, 5.00)
    ]
    for (ry0, ry1) in ribSpans {
        lid.addBox(micCX - 5.0, micCX + 5.0, micCY + ry0, micCY + ry1, 0.45, 1.8)
    }
    let holeCenters = [-3.2, -1.6, 0.0, 1.6, 3.2]
    for hc in holeCenters {
        for (rx0, rx1) in ribSpans {
            lid.addBox(micCX + rx0, micCX + rx1, micCY + hc - 0.45, micCY + hc + 0.45, 0.45, 1.8)
        }
        if abs(hc) == 3.2 {
            for vc in [-3.2, 3.2] {
                lid.addBox(micCX + vc - 0.45, micCX + vc + 0.45, micCY + hc - 0.45, micCY + hc + 0.45, 0.45, 1.8)
            }
        }
    }
    lid.addAnnulusZ(cx: micCX, cy: micCY, rIn: 4.6, rOut: 6.2, z0: 1.8, z1: 3.4)
    // Dead-centered AMOLED bezel + solid right deck
    lid.addBox(0, 11.0, 37.5, 62.0, 0, 1.8)
    lid.addBox(61.0, 72.0, 37.5, 62.0, 0, 1.8)
    lid.addBox(11.0, 61.0, 60.5, 62.0, 0, 1.8)
    lid.addBox(11.0, 61.0, 37.5, 39.0, 0, 1.8)
    lid.addBox(31.5, 72.0, 22.0, 37.5, 0, 1.8)
    // Recessed Ø25.0mm thumbstick well skirt (Z: 0..3.2mm)
    lid.addAnnulusZ(cx: 17.5, cy: 20.8, rIn: 12.5, rOut: 14.15, z0: 0, z1: 3.2)
    lid.addBox(0, 5.0, 5.4, 37.5, 0, 1.8)
    lid.addBox(5.0, 5.4, 5.4, 8.3, 0, 1.8)
    lid.addBox(30.0, 31.5, 0, 37.5, 0, 1.8)
    lid.addBox(5.4, 30.0, 0, 8.3, 0, 1.8)
    lid.addBox(5.0, 30.0, 33.3, 37.5, 0, 1.8)
    for sx in [-1.0, 1.0] {
        for sy in [-1.0, 1.0] {
            lid.addBox(min(17.5 + sx * 8.9, 17.5 + sx * 12.6), max(17.5 + sx * 8.9, 17.5 + sx * 12.6),
                       min(20.8 + sy * 8.9, 20.8 + sy * 12.6), max(20.8 + sy * 8.9, 20.8 + sy * 12.6), 0, 1.8)
            lid.addBox(min(17.5 + sx * 6.4, 17.5 + sx * 9.0), max(17.5 + sx * 6.4, 17.5 + sx * 9.0),
                       min(20.8 + sy * 10.8, 20.8 + sy * 12.6), max(20.8 + sy * 10.8, 20.8 + sy * 12.6), 0, 1.8)
            lid.addBox(min(17.5 + sx * 10.8, 17.5 + sx * 12.6), max(17.5 + sx * 10.8, 17.5 + sx * 12.6),
                       min(20.8 + sy * 6.4, 20.8 + sy * 9.0), max(20.8 + sy * 6.4, 20.8 + sy * 9.0), 0, 1.8)
        }
    }
    // Lower-right 1x4 front keypad grid (Y: 0..22.0)
    lid.addBox(31.5, 66.6, 0, 8.6, 0, 1.8)
    lid.addBox(66.6, 72.0, 5.4, 8.6, 0, 1.8)
    lid.addBox(31.5, 72.0, 17.4, 22.0, 0, 1.8)
    for (i, cx) in frontCapXs.enumerated() {
        let prevX = i == 0 ? 31.5 : frontCapXs[i - 1] + 4.4
        lid.addBox(prevX, cx - 4.4, 8.6, 17.4, 0, 1.8)
    }
    lid.addBox(68.0, 72.0, 8.6, 17.4, 0, 1.8)
    lid.mirrorYInPlace(yMax: boxH)
    try lid.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_portrait_top_faceplate.stl", header: "P5-Exp-Compact-Portrait Top Faceplate 72x84x3.4mm")

    let disc = STLMesh()
    disc.addAnnulusZ(cx: 0, cy: 0, rIn: 2.0, rOut: 3.6, z0: 0.0, z1: 1.6)
    disc.addCylinderZ(cx: 0, cy: 0, r: 8.0, z0: 1.6, z1: 3.2)
    disc.addAnnulusZ(cx: 0, cy: 0, rIn: 5.8, rOut: 8.0, z0: 3.2, z1: 3.8)
    try disc.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_portrait_concave_thumb_disc.stl", header: "P5-Exp-Compact-Portrait Concave Thumb-Disc 16x3.8mm")

    func addKeycap(to mesh: STLMesh, x0: Double, y0: Double, capH: Double = 3.6) {
        mesh.addBox(x0 - 0.6, x0 + 8.8, y0 - 0.6, y0 + 8.8, 0, 0.8)
        mesh.addBox(x0, x0 + 8.2, y0, y0 + 8.2, 0.8, capH)
    }

    let frontCaps = STLMesh()
    for c in 0..<4 {
        addKeycap(to: frontCaps, x0: Double(c) * 12.0, y0: 0.0, capH: 3.6)
    }
    try frontCaps.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_portrait_keycaps_front_4x.stl", header: "P5-Exp-Compact-Portrait 4x Front Keycaps")

    let sideCaps = STLMesh()
    for c in 0..<4 {
        addKeycap(to: sideCaps, x0: Double(c) * 12.0, y0: 0.0, capH: 3.4)
    }
    try sideCaps.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_portrait_keycaps_side_4x.stl", header: "P5-Exp-Compact-Portrait 4x Right-Side Keycaps")

    // Single-Plate All-in-One STL arranged in 4 AMS color zones inside Bambu Lab P2S 256 x 256 mm build plate
    let singlePlate = STLMesh()
    // Zone 1: Matte Black (Tray + Faceplate + 4x Side Keycaps)
    singlePlate.appendOffset(from: tray, dx: 0.0, dy: 85.0)
    singlePlate.appendOffset(from: lid, dx: 84.0, dy: 85.0)
    for c in 0..<4 {
        addKeycap(to: singlePlate, x0: 96.0 + Double(c) * 12.0, y0: 62.0, capH: 3.4)
    }
    // Zone 2: Matte Coral (Concave Thumb-Disc + Front B4 Coral Keycap)
    singlePlate.appendOffset(from: disc, dx: 192.0, dy: 24.0)
    addKeycap(to: singlePlate, x0: 202.0, y0: 19.9, capH: 3.6)
    // Zone 3: Matte Warm Amber (Front B1, B3 Keycaps)
    for c in 0..<2 {
        addKeycap(to: singlePlate, x0: 104.0 + Double(c) * 12.0, y0: 0.6, capH: 3.6)
    }
    // Zone 4: Matte Retro Teal (Front B2 Keycap)
    addKeycap(to: singlePlate, x0: 24.0, y0: 0.6, capH: 3.6)
    try singlePlate.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_portrait_single_plate_all_parts.stl", header: "P5-Exp-Compact-Portrait Single-Plate All Parts")
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
let (p5Smoke, cols1) = buildP5ExpCompactPortrait(exploded: false, opaque: false)
let (p5Opaque, cols2) = buildP5ExpCompactPortrait(exploded: false, opaque: true)
guard cols1 == 0 && cols2 == 0 else {
    fatalError("P5-Exp-Compact-Portrait collision check failed!")
}

let (p5Exploded, _) = buildP5ExpCompactPortrait(exploded: true, opaque: false)
try exportUSDZ(p5Smoke.clone(), to: "\(usdzDir)/p5_exp_compact_portrait_smoke.usdz")
try exportUSDZ(p5Exploded.clone(), to: "\(usdzDir)/p5_exp_compact_portrait_exploded.usdz")
try exportUSDZ(p5Opaque.clone(), to: "\(usdzDir)/p5_exp_compact_portrait_opaque.usdz")
try exportPrintableSTLs()

// 1. Orthographic 90-deg Top-Down Scene: Opaque P5-Exp-Compact-Portrait (72x84mm) + Bicycle Deck (63.5x88.9mm)
let topDownScene = SCNNode()
topDownScene.addChildNode(p5Opaque.clone())
let deckNode = buildPlayingCardDeck()
deckNode.position = SCNVector3(86.0, 0, 0)
topDownScene.addChildNode(deckNode)

let imgTopDown = renderSnapshot(topDownScene,
                                camPos: SCNVector3(75, 220, -44),
                                lookAt: SCNVector3(75, 9.75, -44),
                                up: SCNVector3(0, 0, -1),
                                orthoScale: 58.0,
                                size: CGSize(width: 1400, height: 1050))
savePNG(imgTopDown, to: "\(renderDir)/exp_cp_ortho_topdown.png")

// 2. 4-Panel Port & Side-Button Elevation Sheet
let sheetSize = CGSize(width: 1600, height: 1200)
let sheetImg = NSImage(size: sheetSize)
sheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: sheetSize))

let pTL = renderSnapshot(p5Opaque.clone(),
                         camPos: SCNVector3(-75, 95, -135),
                         lookAt: SCNVector3(34, 9.75, -44),
                         fov: 30, size: CGSize(width: 780, height: 560))
pTL.draw(in: NSRect(x: 10, y: 610, width: 780, height: 560))

let pTR = renderSnapshot(p5Opaque.clone(),
                         camPos: SCNVector3(145, 95, -135),
                         lookAt: SCNVector3(38, 9.75, -44),
                         fov: 30, size: CGSize(width: 780, height: 560))
pTR.draw(in: NSRect(x: 810, y: 610, width: 780, height: 560))

let pBL = renderSnapshot(p5Opaque.clone(),
                         camPos: SCNVector3(36, 16, -195),
                         lookAt: SCNVector3(36, 9.75, -75),
                         up: SCNVector3(0, 1, 0),
                         fov: 22, size: CGSize(width: 780, height: 560))
pBL.draw(in: NSRect(x: 10, y: 20, width: 780, height: 560))

let sidePair = SCNNode()
let leftViewNode = p5Opaque.clone()
leftViewNode.position = SCNVector3(0, 14, 0)
sidePair.addChildNode(leftViewNode)
let rightViewNode = p5Opaque.clone()
rightViewNode.eulerAngles = SCNVector3(0, Float.pi, 0)
rightViewNode.position = SCNVector3(72, -14, -84)
sidePair.addChildNode(rightViewNode)

let pBR = renderSnapshot(sidePair,
                         camPos: SCNVector3(-180, 9.75, -42),
                         lookAt: SCNVector3(36, 9.75, -42),
                         up: SCNVector3(0, 1, 0),
                         orthoScale: 36.0, size: CGSize(width: 780, height: 560))
pBR.draw(in: NSRect(x: 810, y: 20, width: 780, height: 560))

sheetImg.unlockFocus()
savePNG(sheetImg, to: "\(renderDir)/exp_cp_ports_and_side_keys.png")

// 3. 2-Panel Side-by-Side Smoke Assembled & Vertically Exploded Sheet
let txSheetSize = CGSize(width: 1600, height: 900)
let txSheetImg = NSImage(size: txSheetSize)
txSheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: txSheetSize))

let pTransAssembled = renderSnapshot(p5Smoke.clone(),
                                     camPos: SCNVector3(-62, 118, 46),
                                     lookAt: SCNVector3(36, 9.75, -42),
                                     fov: 31,
                                     size: CGSize(width: 780, height: 820))
pTransAssembled.draw(in: NSRect(x: 10, y: 20, width: 780, height: 820))

let pTransExploded = renderSnapshot(p5Exploded.clone(),
                                    camPos: SCNVector3(-76, 130, 66),
                                    lookAt: SCNVector3(36, 12, -42),
                                    fov: 35,
                                    size: CGSize(width: 780, height: 820))
pTransExploded.draw(in: NSRect(x: 810, y: 20, width: 780, height: 820))

let headerAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 22),
    .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.20, alpha: 1.0)
]
("SMOKE ASSEMBLED (72 x 84 x 19.5 mm · COMPACT PORTRAIT)" as NSString).draw(at: NSPoint(x: 34, y: 854), withAttributes: headerAttrs)
("VERTICALLY EXPLODED Z-STACK + RIGHT-SIDE 1x4" as NSString).draw(at: NSPoint(x: 836, y: 854), withAttributes: headerAttrs)

txSheetImg.unlockFocus()
savePNG(txSheetImg, to: "\(renderDir)/exp_cp_smoke_and_exploded.png")

// 4. 2-Panel Internal Cradles & Bambu P2S Single-Plate Print Sheet (1600x900)
let plateSheetSize = CGSize(width: 1600, height: 900)
let plateSheetImg = NSImage(size: plateSheetSize)
plateSheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: plateSheetSize))

let (emptyTrayCradles, _) = buildShellAndLid(shellMat: matOpaqueCharcoal, cradleMat: matCradle, dzShellBot: 0, dzLid: 0, renderOrder: 0)
let pCradles = renderSnapshot(emptyTrayCradles,
                              camPos: SCNVector3(-56, 148, 42),
                              lookAt: SCNVector3(36, 9, -42),
                              fov: 36, size: CGSize(width: 780, height: 820))
pCradles.draw(in: NSRect(x: 10, y: 20, width: 780, height: 820))

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
plateLidWrap.position = SCNVector3(84.0, 19.5, -169.0)
plateLidWrap.addChildNode(plateLid)
plateScene.addChildNode(plateLidWrap)

func addPlateCap(_ id: String, _ kx: Double, _ ky: Double, _ mat: SCNMaterial) {
    addBox(plateScene, "plate_cap_f_\(id)", kx - 0.6, kx + 8.8, ky - 0.6, ky + 8.8, 0.0, 0.8, mat)
    addBox(plateScene, "plate_cap_b_\(id)", kx, kx + 8.2, ky, ky + 8.2, 0.8, 3.6, mat, chamfer: 0.4)
}

for c in 0..<4 {
    addPlateCap("blk_\(c)", 96.0 + Double(c) * 12.0, 62.0, matBlackCap)
}
addTubeZ(plateScene, "plate_disc_stem", 192.0, 24.0, 0.0, 1.6, 2.0, 3.6, matCoralCap)
addCylZ(plateScene, "plate_disc_body", 192.0, 24.0, 1.6, 3.2, 8.0, matCoralCap)
addTubeZ(plateScene, "plate_disc_rim", 192.0, 24.0, 3.2, 3.8, 5.8, 8.0, matCoralCap)
addPlateCap("coral_b4", 202.0, 19.9, matCoralCap)
for c in 0..<2 {
    addPlateCap("amber_\(c)", 104.0 + Double(c) * 12.0, 0.6, matAmberCap)
}
addPlateCap("teal_b2", 24.0, 0.6, matTealCap)

let pPlate = renderSnapshot(plateScene,
                            camPos: SCNVector3(128, 380, -128),
                            lookAt: SCNVector3(128, 0, -128),
                            up: SCNVector3(0, 0, -1),
                            orthoScale: 138.0,
                            size: CGSize(width: 780, height: 820))
pPlate.draw(in: NSRect(x: 810, y: 20, width: 780, height: 820))

("INTERNAL PCB CRADLES & USB-C FUNNEL (TRAY Z: 0..17.7 mm)" as NSString).draw(at: NSPoint(x: 34, y: 854), withAttributes: headerAttrs)
("BAMBU LAB P2S (256 x 256 mm) — 4 COLOR ZONES, 1 PLATE" as NSString).draw(at: NSPoint(x: 836, y: 854), withAttributes: headerAttrs)

plateSheetImg.unlockFocus()
savePNG(plateSheetImg, to: "\(renderDir)/exp_cp_cradles_and_plate.png")

print("DONE P5-Exp-Compact-Portrait CAD, STLs, USDZs & 4 Render Sheets.")
