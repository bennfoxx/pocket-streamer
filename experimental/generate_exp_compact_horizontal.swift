import Foundation
import SceneKit
import AppKit
import Metal

// MARK: - Paths & Output Directories (Strictly inside experimental/)
let expDir = "/Users/benfox/Development/3D Design/Pocket Streamer Hardware CAD/experimental"
let usdzDir = "\(expDir)/usdz"
let renderDir = "\(expDir)/renders"
let stlDir = "\(expDir)/stl_p5_exp_compact_horizontal"

try FileManager.default.createDirectory(atPath: usdzDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: renderDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: stlDir, withIntermediateDirectories: true)

// MARK: - Collision AABB Helpers (CAD: +X Right 0..86, +Y Up/Top 0..70, +Z Front 0..19.5)
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

// MARK: - Binary STL Mesh Builder (1 mm units, watertight boxes, cylinders & rounded corner sectors)
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
             _ cx: Double, _ y0: Double, _ y1: Double, _ cz: Double, _ radius: Double,
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
                    _ mat: SCNMaterial, dz: Double = 0.0, renderOrder: Int = 0) -> SCNNode {
    var verts: [SCNVector3] = []
    var norms: [SCNVector3] = []
    var indices: [Int32] = []
    verts.reserveCapacity(mesh.tris.count * 3)
    norms.reserveCapacity(mesh.tris.count * 3)
    indices.reserveCapacity(mesh.tris.count * 3)
    let fdz = Float(dz)
    for (idx, t) in mesh.tris.enumerated() {
        let p1 = SCNVector3(t.v1.x, t.v1.z + fdz, -t.v1.y)
        let p2 = SCNVector3(t.v2.x, t.v2.z + fdz, -t.v2.y)
        let p3 = SCNVector3(t.v3.x, t.v3.z + fdz, -t.v3.y)
        let e1 = SIMD3<Float>(Float(p2.x - p1.x), Float(p2.y - p1.y), Float(p2.z - p1.z))
        let e2 = SIMD3<Float>(Float(p3.x - p1.x), Float(p3.y - p1.y), Float(p3.z - p1.z))
        var n = simd_normalize(simd_cross(e1, e2))
        if n.x.isNaN || n.y.isNaN || n.z.isNaN { n = SIMD3<Float>(0, 1, 0) }
        let sn = SCNVector3(n.x, n.y, n.z)
        verts.append(p1); verts.append(p2); verts.append(p3)
        norms.append(sn); norms.append(sn); norms.append(sn)
        let base = Int32(idx * 3)
        indices.append(base); indices.append(base + 1); indices.append(base + 2)
    }
    let vSrc = SCNGeometrySource(vertices: verts)
    let nSrc = SCNGeometrySource(normals: norms)
    let elem = SCNGeometryElement(indices: indices, primitiveType: .triangles)
    let geom = SCNGeometry(sources: [vSrc, nSrc], elements: [elem])
    geom.materials = [mat]
    let node = SCNNode(geometry: geom)
    node.name = name
    node.renderingOrder = renderOrder
    parent.addChildNode(node)
    return node
}

@discardableResult
func addCornerSectorNode(_ parent: SCNNode, _ name: String,
                         cx: Double, cy: Double, rCorner: Double, quadrant: Int,
                         holeX: Double, holeY: Double, rHole: Double,
                         z0: Double, z1: Double, _ mat: SCNMaterial, renderOrder: Int = 0) -> SCNNode {
    let m = STLMesh()
    m.addCornerSector(cx: cx, cy: cy, rCorner: rCorner, quadrant: quadrant,
                      holeX: holeX, holeY: holeY, rHole: rHole, z0: z0, z1: z1,
                      arcSegs: 28, edgeSegs: 8)
    return addSTLMeshNode(parent, name, m, mat, renderOrder: renderOrder)
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
let matPigtailCable = makeMat(0.14, 0.15, 0.18, 1.0, metal: 0.05, rough: 0.65)

// MARK: - Locked Compact Horizontal Architectural Constants (86.0 x 70.0 x 19.5 mm, R=5.4 mm)
let boxW = 86.0
let boxH = 70.0
let boxT = 19.5
let cornerR = 5.4

struct CornerSpec {
    let cx: Double
    let cy: Double
    let quadrant: Int
    let holeX: Double
    let holeY: Double
}
let corners: [CornerSpec] = [
    CornerSpec(cx: 5.4,          cy: 5.4,          quadrant: 0, holeX: 3.6,          holeY: 3.6),          // Bottom-Left
    CornerSpec(cx: boxW - 5.4,   cy: 5.4,          quadrant: 1, holeX: boxW - 3.6,   holeY: 3.6),          // Bottom-Right
    CornerSpec(cx: boxW - 5.4,   cy: boxH - 5.4,   quadrant: 2, holeX: boxW - 3.6,   holeY: boxH - 3.6),   // Top-Right
    CornerSpec(cx: 5.4,          cy: boxH - 5.4,   quadrant: 3, holeX: 3.6,          holeY: boxH - 3.6)    // Top-Left
]

let topCapXs = [25.5, 34.7, 43.9, 53.1]   // Top-Edge 1x4 Shoulder Keypad (X: 21.0..58.0, B1 at X=53.1 outermost right)
let frontCapXs = [35.5, 44.7, 53.9, 63.1] // Front 1x4 Keypad (X: 31.0..68.0, Y: 2.2..17.2)
let frontCapYCenter = 9.7
let halfCut = 4.3
let trsCX = 71.5                          // Top-Right 3.5mm TRS jack pointing UPWARD through Y=70.0
let trsCutX0 = trsCX - 3.25               // 68.25
let trsCutX1 = trsCX + 3.25               // 74.75
let micCX = 76.0
let micCY = 48.0
let stickCX = 18.0
let stickCY = 19.0

// MARK: - Build Complete Segmented Shell & Faceplate (86.0 x 70.0 x 19.5 mm, R=5.4 mm Corners)
func buildShellAndLid(shellMat: SCNMaterial, cradleMat: SCNMaterial, dzShellBot: Double, dzLid: Double, renderOrder: Int) -> (SCNNode, SCNNode) {
    let tray = SCNNode()
    tray.name = "p5_exp_compact_horizontal_bottom_tray"

    // 1. Back plate (Z: 0.0..1.8 mm)
    addBox(tray, "back_plate_center", 5.4, boxW - 5.4, 0.0, boxH, 0.0 + dzShellBot, 1.8 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "back_plate_left_wing", 0.0, 5.4, 5.4, boxH - 5.4, 0.0 + dzShellBot, 1.8 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "back_plate_right_wing", boxW - 5.4, boxW, 5.4, boxH - 5.4, 0.0 + dzShellBot, 1.8 + dzShellBot, shellMat, renderOrder: renderOrder)

    // 2. 4x Monolithic R = 5.4 mm Corner Pillars: solid base (Z: 0..4.2) + cored Ø2.0 mm M2 pilot bore (Z: 4.2..17.7)
    for (idx, c) in corners.enumerated() {
        addCornerSectorNode(tray, "pillar_\(idx)_base",
                            cx: c.cx, cy: c.cy, rCorner: 5.4, quadrant: c.quadrant,
                            holeX: c.holeX, holeY: c.holeY, rHole: 0.0,
                            z0: 0.0 + dzShellBot, z1: 4.2 + dzShellBot, shellMat, renderOrder: renderOrder)
        addCornerSectorNode(tray, "pillar_\(idx)_bore",
                            cx: c.cx, cy: c.cy, rCorner: 5.4, quadrant: c.quadrant,
                            holeX: c.holeX, holeY: c.holeY, rHole: 1.0,
                            z0: 4.2 + dzShellBot, z1: 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
        addCylZ(tray, "pillar_\(idx)_cavity", c.holeX, c.holeY, 4.2 + dzShellBot, 17.72 + dzShellBot, 0.96, matPortCavity)
    }

    // 3. Left Wall (X: 0..1.8, Y: 5.4..64.6, Z: 1.8..17.7) with SOLE external USB-C Pigtail Cutout (Y: 43.3..53.7, Z: 11.6..15.6)
    addBox(tray, "wall_left_bot", 0.0, 1.8, 5.4, 43.3, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_left_top", 0.0, 1.8, 53.7, boxH - 5.4, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_left_under_usbc", 0.0, 1.8, 43.3, 53.7, 1.8 + dzShellBot, 11.6 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_left_over_usbc", 0.0, 1.8, 43.3, 53.7, 15.6 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)

    // 4. Right Wall (X: 84.2..86.0, Y: 5.4..64.6, Z: 1.8..17.7) with MicroSD Slot (Y: 19.3..33.8, Z: 9.8..13.4)
    addBox(tray, "wall_right_bot", boxW - 1.8, boxW, 5.4, 19.3, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_under_sd", boxW - 1.8, boxW, 19.3, 33.8, 1.8 + dzShellBot, 9.8 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_over_sd", boxW - 1.8, boxW, 19.3, 33.8, 13.4 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_right_top", boxW - 1.8, boxW, 33.8, boxH - 5.4, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)

    // 5. Bottom Wall (solid, 100% port-free) & Top Wall (4x 8.6x8.6mm cutouts at topCapXs + Top-Right 3.5mm TRS cutout)
    addBox(tray, "wall_bot", 5.4, boxW - 5.4, 0.0, 1.8, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_left", 5.4, topCapXs.first! - halfCut, boxH - 1.8, boxH, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_bot_rail", topCapXs.first! - halfCut, topCapXs.last! + halfCut, boxH - 1.8, boxH, 1.8 + dzShellBot, 5.4 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_top_rail", topCapXs.first! - halfCut, topCapXs.last! + halfCut, boxH - 1.8, boxH, 14.0 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    for i in 1..<topCapXs.count {
        let divX0 = topCapXs[i - 1] + halfCut
        let divX1 = topCapXs[i] - halfCut
        addBox(tray, "wall_top_div_\(i)", divX0, divX1, boxH - 1.8, boxH, 5.4 + dzShellBot, 14.0 + dzShellBot, shellMat, renderOrder: renderOrder)
    }
    addBox(tray, "wall_top_mid", topCapXs.last! + halfCut, trsCutX0, boxH - 1.8, boxH, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_under_trs", trsCutX0, trsCutX1, boxH - 1.8, boxH, 1.8 + dzShellBot, 8.6 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_over_trs", trsCutX0, trsCutX1, boxH - 1.8, boxH, 14.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)
    addBox(tray, "wall_top_right", trsCutX1, boxW - 5.4, boxH - 1.8, boxH, 1.8 + dzShellBot, 17.7 + dzShellBot, shellMat, renderOrder: renderOrder)

    // 6. Internal Molded PCB Cradles, Support Rails & LiPo Retention
    // a. LiPo lateral rails (Z: 1.8..7.0) supporting shield_rib (Z: 7.0..7.8)
    addBox(tray, "cradle_lipo_l", 30.6, 31.2, 2.2, 61.2, 1.8 + dzShellBot, 7.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_lipo_r", 68.6, 69.2, 30.0, 61.2, 1.8 + dzShellBot, 7.0 + dzShellBot, cradleMat, renderOrder: renderOrder)

    // b. KY-023 4x Corner Standoffs (25.0 x 33.0 mm PCB, X: 5.5..30.5, Y: 2.5..35.5, Z: 1.8..2.4 mm)
    for (kx0, kx1, ky0, ky1) in [
        (5.5, 8.5, 2.5, 5.5), (27.5, 30.5, 2.5, 5.5),
        (5.5, 8.5, 32.5, 35.5), (27.5, 30.5, 32.5, 35.5)
    ] {
        addBox(tray, "cradle_ky_\(kx0)_\(ky0)", kx0, kx1, ky0, ky1, 1.8 + dzShellBot, 2.4 + dzShellBot, cradleMat, renderOrder: renderOrder)
    }

    // c. Front 1x4 Keypad Flanking Rails + Bridge Steps clear of shield_rib (Z <= 7.8)
    addBox(tray, "cradle_fpad_l", 30.6, 31.0, 2.2, 17.2, 8.0 + dzShellBot, 9.7 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_fpad_r", 68.0, 68.4, 2.2, 17.2, 8.0 + dzShellBot, 9.7 + dzShellBot, cradleMat, renderOrder: renderOrder)

    // d. Top-Edge 1x4 Keypad Vertical Guide Rails (X: 19.9..20.9 & 58.1..59.1, Y: 61.5..68.2, Z: 1.8..17.7)
    addBox(tray, "cradle_tpad_l", 19.9, 20.9, 61.5, 68.2, 1.8 + dzShellBot, 17.7 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_tpad_r", 58.1, 59.1, 61.5, 68.2, 1.8 + dzShellBot, 17.7 + dzShellBot, cradleMat, renderOrder: renderOrder)

    // e. Centered T-Display-S3 AMOLED Support Pillars (X: 13.0..73.0, Y: 35.8..61.3, Z: 1.8..13.5)
    addBox(tray, "cradle_amoled_l_bot", 13.0, 16.0, 35.8, 36.7, 1.8 + dzShellBot, 13.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_amoled_l_top", 16.0, 19.0, 60.4, 61.3, 1.8 + dzShellBot, 13.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_amoled_r_bot", 73.1, 76.0, 35.8, 36.1, 1.8 + dzShellBot, 13.5 + dzShellBot, cradleMat, renderOrder: renderOrder)

    // f. AOICRIE V713 5V 2A Boost Internal Floor Pads & Stop-Lips (X: 2.0..28.5, Y: 38.0..58.0, Z: 1.8..4.5)
    for (bx0, bx1, by0, by1) in [
        (2.5, 5.0, 38.5, 41.0), (25.5, 28.0, 38.5, 41.0),
        (2.5, 5.0, 55.0, 57.5), (25.5, 28.0, 55.0, 57.5)
    ] {
        addBox(tray, "cradle_boost_pad_\(bx0)_\(by0)", bx0, bx1, by0, by1, 1.8 + dzShellBot, 2.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    }
    addBox(tray, "cradle_boost_r", 28.7, 29.5, 40.0, 56.0, 1.8 + dzShellBot, 4.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_boost_bot", 5.0, 25.0, 37.1, 37.8, 1.8 + dzShellBot, 4.5 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_boost_top", 5.0, 25.0, 58.2, 58.9, 1.8 + dzShellBot, 4.5 + dzShellBot, cradleMat, renderOrder: renderOrder)

    // g. WWZMDiB Mini 3.3V MicroSD Open U-Cradle (X: 66.3..84.2, Y: 17.6..35.5, Z: 1.8..9.0)
    addBox(tray, "cradle_sd_top", 70.0, 84.2, 35.5, 36.1, 1.8 + dzShellBot, 9.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_sd_bot", 70.0, 84.2, 16.5, 17.5, 5.0 + dzShellBot, 9.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_sd_back", 65.5, 66.2, 20.0, 34.0, 8.0 + dzShellBot, 9.0 + dzShellBot, cradleMat, renderOrder: renderOrder)

    // h. GY-PCM5102 Support Pillars (X: 63.0..80.0, Y: 36.2..68.2, Z: 7.9..9.5) + Acxico BT TX Retention Pads (Z: 1.8..4.5)
    addBox(tray, "cradle_pcm_r_top", 80.2, 82.0, 54.0, 64.0, 1.8 + dzShellBot, 7.9 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_pcm_r_bot", 80.2, 82.0, 36.5, 42.0, 1.8 + dzShellBot, 7.9 + dzShellBot, cradleMat, renderOrder: renderOrder)
    addBox(tray, "cradle_pcm_l_top", 60.0, 62.8, 61.5, 64.5, 1.8 + dzShellBot, 7.9 + dzShellBot, cradleMat, renderOrder: renderOrder)
    for (ax0, ax1, ay0, ay1) in [
        (68.7, 71.2, 6.0, 8.5), (81.7, 84.2, 6.0, 8.5),
        (68.7, 71.2, 27.0, 29.5), (81.7, 84.2, 27.0, 29.5)
    ] {
        addBox(tray, "cradle_bt_pad_\(ax0)_\(ay0)", ax0, ax1, ay0, ay1, 1.8 + dzShellBot, 2.0 + dzShellBot, cradleMat, renderOrder: renderOrder)
    }

    // Complete Segmented Front Faceplate Lid (Z: 17.7..19.5 mm)
    let lid = SCNNode()
    lid.name = "p5_exp_compact_horizontal_top_faceplate"

    // 4x Rounded Corner Sectors (R = 5.4 mm) with Ø2.2 mm M2 clearance holes (rHole = 1.1)
    for (idx, c) in corners.enumerated() {
        addCornerSectorNode(lid, "lid_corner_\(idx)",
                            cx: c.cx, cy: c.cy, rCorner: 5.4, quadrant: c.quadrant,
                            holeX: c.holeX, holeY: c.holeY, rHole: 1.1,
                            z0: 17.7 + dzLid, z1: 19.5 + dzLid, shellMat, renderOrder: renderOrder)
        addCylZ(lid, "m2_screw_\(idx)", c.holeX, c.holeY, 17.8 + dzLid, 19.55 + dzLid, 1.7, matBlackCap)
        addCylZ(lid, "m2_hex_\(idx)", c.holeX, c.holeY, 17.85 + dzLid, 19.58 + dzLid, 0.8, matSilver)
    }

    // 1. Upper Dead-Centered AMOLED Window (X: 18.0..68.0, Y: 37.8..59.3) + Upper-Right Mic Grille (76.0, 48.0)
    addBox(lid, "lid_up_left_outer", 0.0, 5.4, 36.0, boxH - 5.4, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_left_main", 5.4, 18.0, 36.0, boxH, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_amoled_b", 18.0, 68.0, 36.0, 37.8, 17.7 + dzLid, 19.5 + dzLid, matOpaqueBezel, renderOrder: renderOrder)
    addBox(lid, "lid_amoled_t", 18.0, 68.0, 59.3, 60.8, 17.7 + dzLid, 19.5 + dzLid, matOpaqueBezel, renderOrder: renderOrder)
    addBox(lid, "lid_amoled_top_strip", 18.0, 68.0, 60.8, boxH, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)

    // Upper-Right INMP441 Mic Zone (centered at 76.0, 48.0, window 71.0..81.0, 43.0..53.0)
    addBox(lid, "lid_up_mid_strip", 68.0, 71.0, 36.0, boxH, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_mic_bot", 71.0, 81.0, 36.0, 43.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_mic_top", 71.0, 81.0, 53.0, boxH, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_right_strip", 81.0, boxW, 36.0, boxH - 5.4, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_up_far_right_top", 81.0, boxW - 5.4, boxH - 5.4, boxH, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)

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
    addTubeZ(lid, "lid_inmp441_ring", micCX, micCY, 16.5 + dzLid, 17.7 + dzLid, 4.6, 6.2, cradleMat)

    // 2. Lower-Left Thumbstick Deck (X: 0..31.0, Y: 0..36.0) with Ø25.0 mm recessed well at (18.0, 19.0)
    addTubeZ(lid, "lid_stick_collar", stickCX, stickCY, 16.3 + dzLid, 19.5 + dzLid, 12.5, 13.5, shellMat)
    addBox(lid, "lid_stick_l_outer", 0.0, 5.4, 5.4, 36.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_l_edge", 5.4, 5.5, 0.0, 36.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_r", 30.5, 31.0, 0.0, 36.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_b", 5.5, 30.5, 0.0, 6.5, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_stick_t", 5.5, 30.5, 31.5, 36.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    for sx in [-1.0, 1.0] {
        for sy in [-1.0, 1.0] {
            let ax0 = stickCX + sx * 8.9, ax1 = stickCX + sx * 12.6
            let ay0 = stickCY + sy * 8.9, ay1 = stickCY + sy * 12.6
            addBox(lid, "lid_stick_spA_\(sx)_\(sy)", min(ax0, ax1), max(ax0, ax1), min(ay0, ay1), max(ay0, ay1), 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
            let bx0 = stickCX + sx * 6.4, bx1 = stickCX + sx * 9.0
            let by0 = stickCY + sy * 10.8, by1 = stickCY + sy * 12.6
            addBox(lid, "lid_stick_spB_\(sx)_\(sy)", min(bx0, bx1), max(bx0, bx1), min(by0, by1), max(by0, by1), 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
            let cx0 = stickCX + sx * 10.8, cx1 = stickCX + sx * 12.6
            let cy0 = stickCY + sy * 6.4, cy1 = stickCY + sy * 9.0
            addBox(lid, "lid_stick_spC_\(sx)_\(sy)", min(cx0, cx1), max(cx0, cx1), min(cy0, cy1), max(cy0, cy1), 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
        }
    }
    addCylZ(lid, "lid_stick_well", stickCX, stickCY, 16.1 + dzLid, 16.4 + dzLid, 12.6, matPortCavity)
    addTubeZ(lid, "lid_stick_wall", stickCX, stickCY, 16.3 + dzLid, 19.45 + dzLid, 12.35, 12.55, matOpaqueBezel)

    // 3. Single Front 1x4 Keypad + Right Grip Deck (X: 31.0..86.0, Y: 0..36.0) with 4x 8.6x8.6mm cutouts
    addBox(lid, "lid_fpad_bot_main", 31.0, boxW - 5.4, 0.0, frontCapYCenter - halfCut, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_fpad_bot_r", boxW - 5.4, boxW, 5.4, frontCapYCenter - halfCut, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_fpad_top_strip", 31.0, boxW, frontCapYCenter + halfCut, 36.0, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    addBox(lid, "lid_fpad_l_border", 31.0, frontCapXs.first! - halfCut, frontCapYCenter - halfCut, frontCapYCenter + halfCut, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    for i in 1..<frontCapXs.count {
        let divX0 = frontCapXs[i - 1] + halfCut
        let divX1 = frontCapXs[i] - halfCut
        addBox(lid, "lid_fpad_div_\(i)", divX0, divX1, frontCapYCenter - halfCut, frontCapYCenter + halfCut, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)
    }
    addBox(lid, "lid_fpad_r_border", frontCapXs.last! + halfCut, boxW, frontCapYCenter - halfCut, frontCapYCenter + halfCut, 17.7 + dzLid, 19.5 + dzLid, shellMat, renderOrder: renderOrder)

    return (tray, lid)
}

// MARK: - Build Option P5-Exp-Compact-Horizontal (86.0 x 70.0 x 19.5 mm, R=5.4 mm) + Verify Collisions
func buildP5ExpCompactHorizontal(exploded: Bool = false, opaque: Bool = false) -> (SCNNode, Int) {
    let root = SCNNode()
    var boxes: [(String, AABB)] = []
    let dzShellBot = exploded ? -19.0 : 0.0
    let dzLiPo = exploded ? -8.0 : 0.0
    let dzShield = exploded ? -1.0 : 0.0
    let dzControls = exploded ? 7.5 : 0.0
    let dzTopBay = exploded ? 10.5 : 0.0
    let dzAMOLED = exploded ? 19.0 : 0.0
    let dzLid = exploded ? 30.0 : 0.0

    let shellMat = opaque ? matOpaqueCharcoal : matSmokeShell
    let ro = opaque ? 0 : 20
    let (tray, lid) = buildShellAndLid(shellMat: shellMat, cradleMat: shellMat, dzShellBot: dzShellBot, dzLid: dzLid, renderOrder: ro)
    root.addChildNode(tray)

    // Register 4x Monolithic Rounded Corner Pillars & Walls for Collision Verification
    boxes.append(("boss_bl", makeAABB("boss_bl", 0.0, 5.4, 0.0, 5.4, 1.8, 17.7)))
    boxes.append(("boss_br", makeAABB("boss_br", boxW - 5.4, boxW, 0.0, 5.4, 1.8, 17.7)))
    boxes.append(("boss_tr", makeAABB("boss_tr", boxW - 5.4, boxW, boxH - 5.4, boxH, 1.8, 17.7)))
    boxes.append(("boss_tl", makeAABB("boss_tl", 0.0, 5.4, boxH - 5.4, boxH, 1.8, 17.7)))

    boxes.append(("walls", makeAABB("wall_left_bot", 0.0, 1.8, 5.4, 43.3, 1.8, 17.7)))
    boxes.append(("walls", makeAABB("wall_left_top", 0.0, 1.8, 53.7, boxH - 5.4, 1.8, 17.7)))
    boxes.append(("walls", makeAABB("wall_left_under_usbc", 0.0, 1.8, 43.3, 53.7, 1.8, 11.6)))
    boxes.append(("walls", makeAABB("wall_left_over_usbc", 0.0, 1.8, 43.3, 53.7, 15.6, 17.7)))
    boxes.append(("walls", makeAABB("wall_right_bot", boxW - 1.8, boxW, 5.4, 19.3, 1.8, 17.7)))
    boxes.append(("walls", makeAABB("wall_right_under_sd", boxW - 1.8, boxW, 19.3, 33.8, 1.8, 9.8)))
    boxes.append(("walls", makeAABB("wall_right_over_sd", boxW - 1.8, boxW, 19.3, 33.8, 13.4, 17.7)))
    boxes.append(("walls", makeAABB("wall_right_top", boxW - 1.8, boxW, 33.8, boxH - 5.4, 1.8, 17.7)))
    boxes.append(("walls", makeAABB("wall_bot", 5.4, boxW - 5.4, 0.0, 1.8, 1.8, 17.7)))
    boxes.append(("walls", makeAABB("wall_top_left", 5.4, topCapXs.first! - halfCut, boxH - 1.8, boxH, 1.8, 17.7)))
    boxes.append(("walls", makeAABB("wall_top_bot_rail", topCapXs.first! - halfCut, topCapXs.last! + halfCut, boxH - 1.8, boxH, 1.8, 5.4)))
    boxes.append(("walls", makeAABB("wall_top_top_rail", topCapXs.first! - halfCut, topCapXs.last! + halfCut, boxH - 1.8, boxH, 14.0, 17.7)))
    boxes.append(("walls", makeAABB("wall_top_mid", topCapXs.last! + halfCut, trsCutX0, boxH - 1.8, boxH, 1.8, 17.7)))
    boxes.append(("walls", makeAABB("wall_top_under_trs", trsCutX0, trsCutX1, boxH - 1.8, boxH, 1.8, 8.6)))
    boxes.append(("walls", makeAABB("wall_top_over_trs", trsCutX0, trsCutX1, boxH - 1.8, boxH, 14.8, 17.7)))
    boxes.append(("walls", makeAABB("wall_top_right", trsCutX1, boxW - 5.4, boxH - 1.8, boxH, 1.8, 17.7)))

    // Register Internal Molded Cradles
    boxes.append(("cradles", makeAABB("cradle_lipo_l", 30.6, 31.2, 2.2, 61.2, 1.8, 7.0)))
    boxes.append(("cradles", makeAABB("cradle_lipo_r", 68.6, 69.2, 30.0, 61.2, 1.8, 7.0)))
    for (kx0, kx1, ky0, ky1) in [
        (5.5, 8.5, 2.5, 5.5), (27.5, 30.5, 2.5, 5.5),
        (5.5, 8.5, 32.5, 35.5), (27.5, 30.5, 32.5, 35.5)
    ] {
        boxes.append(("cradles", makeAABB("cradle_ky_\(kx0)_\(ky0)", kx0, kx1, ky0, ky1, 1.8, 2.4)))
    }
    boxes.append(("cradles", makeAABB("cradle_fpad_l", 30.6, 31.0, 2.2, 17.2, 8.0, 9.7)))
    boxes.append(("cradles", makeAABB("cradle_fpad_r", 68.0, 68.4, 2.2, 17.2, 8.0, 9.7)))
    boxes.append(("cradles", makeAABB("cradle_tpad_l", 19.9, 20.9, 61.5, 68.2, 1.8, 17.7)))
    boxes.append(("cradles", makeAABB("cradle_tpad_r", 58.1, 59.1, 61.5, 68.2, 1.8, 17.7)))
    boxes.append(("cradles", makeAABB("cradle_amoled_l_bot", 13.0, 16.0, 35.8, 36.7, 1.8, 13.5)))
    boxes.append(("cradles", makeAABB("cradle_amoled_l_top", 16.0, 19.0, 60.4, 61.3, 1.8, 13.5)))
    boxes.append(("cradles", makeAABB("cradle_amoled_r_bot", 73.1, 76.0, 35.8, 36.1, 1.8, 13.5)))
    for (bx0, bx1, by0, by1) in [
        (2.5, 5.0, 38.5, 41.0), (25.5, 28.0, 38.5, 41.0),
        (2.5, 5.0, 55.0, 57.5), (25.5, 28.0, 55.0, 57.5)
    ] {
        boxes.append(("cradles", makeAABB("cradle_boost_pad_\(bx0)_\(by0)", bx0, bx1, by0, by1, 1.8, 2.0)))
    }
    boxes.append(("cradles", makeAABB("cradle_boost_r", 28.7, 29.5, 40.0, 56.0, 1.8, 4.5)))
    boxes.append(("cradles", makeAABB("cradle_boost_bot", 5.0, 25.0, 37.1, 37.8, 1.8, 4.5)))
    boxes.append(("cradles", makeAABB("cradle_boost_top", 5.0, 25.0, 58.2, 58.9, 1.8, 4.5)))
    boxes.append(("cradles", makeAABB("cradle_sd_top", 70.0, 84.2, 35.5, 36.1, 1.8, 9.0)))
    boxes.append(("cradles", makeAABB("cradle_sd_bot", 70.0, 84.2, 16.5, 17.5, 5.0, 9.0)))
    boxes.append(("cradles", makeAABB("cradle_sd_back", 65.5, 66.2, 20.0, 34.0, 8.0, 9.0)))
    boxes.append(("cradles", makeAABB("cradle_pcm_r_top", 80.2, 82.0, 54.0, 64.0, 1.8, 7.9)))
    boxes.append(("cradles", makeAABB("cradle_pcm_r_bot", 80.2, 82.0, 36.5, 42.0, 1.8, 7.9)))
    boxes.append(("cradles", makeAABB("cradle_pcm_l_top", 60.0, 62.8, 61.5, 64.5, 1.8, 7.9)))
    for (ax0, ax1, ay0, ay1) in [
        (68.7, 71.2, 6.0, 8.5), (81.7, 84.2, 6.0, 8.5),
        (68.7, 71.2, 27.0, 29.5), (81.7, 84.2, 27.0, 29.5)
    ] {
        boxes.append(("cradles", makeAABB("cradle_bt_pad_\(ax0)_\(ay0)", ax0, ax1, ay0, ay1, 1.8, 2.0)))
    }

    // 1. Liter 503759 1300 mAh LiPo (37.0 x 59.0 x 5.0 mm) + 0.8 mm Shield Rib
    let lipoNode = SCNNode()
    addBox(lipoNode, "lipo_503759", 31.4, 68.4, 2.2, 61.2, 1.8 + dzLiPo, 6.8 + dzLiPo, matLiPo, chamfer: 0.4)
    addBox(lipoNode, "lipo_tape", 31.4, 68.4, 56.7, 61.2, 1.9 + dzLiPo, 6.9 + dzLiPo, matAmberCap)
    addBox(lipoNode, "shield_rib", 31.1, 68.7, 2.0, 61.4, 7.0 + dzShield, 7.8 + dzShield, shellMat, renderOrder: ro)
    boxes.append(("lipo", makeAABB("lipo_503759", 31.4, 68.4, 2.2, 61.2, 1.8, 6.8)))
    boxes.append(("shield_rib", makeAABB("shield_rib", 31.1, 68.7, 2.0, 61.4, 7.0, 7.8)))
    root.addChildNode(lipoNode)

    // 2. KY-023 Low-Profile Gimbal (25.0 x 33.0 mm on Z=2.4mm standoffs) + Ø16.0mm Coral Concave Thumb-Disc at (18.0, 19.0)
    let kyNode = SCNNode()
    addBox(kyNode, "ky_pcb", 5.5, 30.5, 2.5, 35.5, 2.4 + dzControls, 4.0 + dzControls, matDarkPCB)
    addBox(kyNode, "ky_gimbal", 10.0, 26.0, 11.0, 27.0, 4.0 + dzControls, 14.4 + dzControls, matSilver)
    addCylZ(kyNode, "ky_shaft", stickCX, stickCY, 14.4 + dzControls, 18.1 + dzControls, 2.0, matBlackCap)
    addTubeZ(kyNode, "ky_disc_stem", stickCX, stickCY, 16.3 + dzControls, 17.9 + dzControls, 2.0, 3.6, matCoralCap)
    addCylZ(kyNode, "ky_concave_disc", stickCX, stickCY, 17.9 + dzControls, 18.9 + dzControls, 8.0, matCoralCap)
    addTubeZ(kyNode, "ky_disc_rim", stickCX, stickCY, 18.9 + dzControls, 20.1 + dzControls, 5.8, 8.0, matCoralCap)
    let matCoralInner = makeMat(0.82, 0.33, 0.26, 1.0, metal: 0.04, rough: 0.48)
    addTubeZ(kyNode, "ky_disc_dish_shade", stickCX, stickCY, 18.85 + dzControls, 19.05 + dzControls, 5.4, 5.8, matCoralInner)
    boxes.append(("ky023", makeAABB("ky_body", 5.5, 30.5, 2.5, 35.5, 2.4, 14.4)))
    root.addChildNode(kyNode)

    // 3. 1x Front 1x4 Keypad (X: 31.0..68.0, Y: 2.2..17.2, Z: 9.7..17.5 mm, captive color-coded keycaps 16.9..20.5 mm)
    let padNode = SCNNode()
    addBox(padNode, "pad_front_pcb", 31.0, 68.0, 2.2, 17.2, 9.7 + dzControls, 11.3 + dzControls, matGreenPCB)
    let frontMats = [matAmberCap, matTealCap, matAmberCap, matCoralCap]
    for (i, cx) in frontCapXs.enumerated() {
        addBox(padNode, "sw_front_\(i)", cx - 3.0, cx + 3.0, frontCapYCenter - 3.0, frontCapYCenter + 3.0, 11.3 + dzControls, 16.9 + dzControls, matBlackCap)
        addBox(padNode, "cap_front_flange_\(i)", cx - 4.55, cx + 4.55, frontCapYCenter - 4.55, frontCapYCenter + 4.55, 16.9 + dzControls, 17.7 + dzControls, frontMats[i])
        addBox(padNode, "cap_front_\(i)", cx - 4.0, cx + 4.0, frontCapYCenter - 4.0, frontCapYCenter + 4.0, 17.7 + dzControls, 20.5 + dzControls, frontMats[i], chamfer: 0.6)
    }
    boxes.append(("pad_front", makeAABB("pad_front", 31.0, 68.0, 2.2, 17.2, 9.7, 17.5)))
    root.addChildNode(padNode)

    // 4. 1x Top-Edge 1x4 Keypad (37.0 x 15.0 mm standing vertically along Y=70.0, X: 21.0..58.0, Z: 2.2..17.2 mm)
    let topPadNode = SCNNode()
    let dyTopPad = exploded ? 14.0 : 0.0
    addBox(topPadNode, "pad_top_pcb", 21.0, 58.0, 61.5 + dyTopPad, 63.1 + dyTopPad, 2.2, 17.2, matGreenPCB)
    for (i, cx) in topCapXs.enumerated() {
        addBox(topPadNode, "sw_top_\(i)", cx - 3.0, cx + 3.0, 63.1 + dyTopPad, 67.4 + dyTopPad, 6.7, 12.7, matBlackCap)
        addBox(topPadNode, "cap_top_flange_\(i)", cx - 4.55, cx + 4.55, 67.4 + dyTopPad, 68.2 + dyTopPad, 5.15, 14.25, matBlackCap)
        addBox(topPadNode, "cap_top_\(i)", cx - 4.0, cx + 4.0, 68.2 + dyTopPad, 70.8 + dyTopPad, 5.7, 13.7, matBlackCap, chamfer: 0.6)
    }
    boxes.append(("pad_top", makeAABB("pad_top_vertical", 21.0, 58.0, 61.5, 68.2, 2.2, 17.2)))
    root.addChildNode(topPadNode)

    // 5. Dead-Centered LILYGO T-Display-S3 AMOLED (X: 13.0..73.0, Y: 35.8..61.3, Z: 13.5..17.7, active X: 20.9..65.1 centered at 43.0)
    let espNode = SCNNode()
    addBox(espNode, "amoled_pcb", 13.0, 73.0, 35.8, 61.3, 13.5 + dzAMOLED, 15.1 + dzAMOLED, matDarkPCB)
    addBox(espNode, "amoled_rear_jst", 13.2, 22.5, 36.8, 60.3, 9.7 + dzAMOLED, 13.5 + dzAMOLED, matSilver)
    addBox(espNode, "amoled_rear_ant", 63.0, 72.8, 40.0, 55.5, 10.0 + dzAMOLED, 13.5 + dzAMOLED, matSilver)
    addBox(espNode, "amoled_glass", 18.0, 68.0, 37.8, 59.3, 15.1 + dzAMOLED, 17.7 + dzAMOLED, matAMOLEDGlass)
    addBox(espNode, "amoled_active", 20.9, 65.1, 38.6, 58.4, 17.55 + dzAMOLED, 17.80 + dzAMOLED, matAMOLEDActive)
    // Short internal USB-C panel-mount pigtail (X: 0.0..13.0, Y: 44.0..53.0, Z: 12.0..15.2) routing to Left Wall X=0.0
    addBox(espNode, "amoled_usbc_shell", 0.0, 6.8, 44.0, 53.0, 12.0 + dzAMOLED, 15.2 + dzAMOLED, matSilver, chamfer: 0.5)
    addBox(espNode, "amoled_usbc_bore", -0.05, 1.5, 44.8, 52.2, 12.5 + dzAMOLED, 14.7 + dzAMOLED, matPortCavity, chamfer: 0.3)
    addBox(espNode, "amoled_usbc_pigtail", 6.8, 13.0, 45.5, 51.5, 12.6 + dzAMOLED, 14.6 + dzAMOLED, matPigtailCable, chamfer: 0.4)
    boxes.append(("amoled", makeAABB("t_display_s3_amoled_pcb", 13.0, 73.0, 35.8, 61.3, 13.5, 15.1)))
    boxes.append(("amoled", makeAABB("t_display_s3_amoled_glass", 18.0, 68.0, 37.8, 59.3, 15.1, 17.7)))
    boxes.append(("amoled", makeAABB("amoled_rear_jst", 13.2, 22.5, 36.8, 60.3, 9.7, 13.5)))
    boxes.append(("amoled", makeAABB("amoled_rear_ant", 63.0, 72.8, 40.0, 55.5, 10.0, 13.5)))
    boxes.append(("amoled", makeAABB("amoled_usbc_pigtail", 0.2, 13.0, 44.0, 53.0, 12.0, 15.2)))
    root.addChildNode(espNode)

    // 6. Internal AOICRIE V713 5V 2A Boost (26.5 x 20.0 x 4.8 mm) under left AMOLED (Z: 2.0..6.8)
    let bayNode = SCNNode()
    addBox(bayNode, "boost_5v2a_pcb", 2.0, 28.5, 38.0, 58.0, 2.0 + dzTopBay, 3.6 + dzTopBay, matDarkPCB)
    addBox(bayNode, "boost_inductor", 8.0, 15.0, 44.5, 51.5, 3.6 + dzTopBay, 6.8 + dzTopBay, matBlackCap)
    addBox(bayNode, "boost_usbc_shell", 17.5, 26.5, 49.5, 56.5, 3.6 + dzTopBay, 6.8 + dzTopBay, matSilver, chamfer: 0.5)
    boxes.append(("boost_5v2a", makeAABB("boost_5v2a", 2.0, 28.5, 38.0, 58.0, 2.0, 6.8)))

    // 7. EGSCST INMP441 MEMS Mic (Ø14.0 mm) Upper-Right at (76.0, 48.0, Z: 15.2..17.6) cleanly above amoled_pcb (Z <= 15.1) & beside amoled_glass (X <= 68.0)
    addCylZ(bayNode, "inmp441_pcb", micCX, micCY, 15.2 + dzTopBay, 16.7 + dzTopBay, 7.0, matDarkPCB)
    addCylZ(bayNode, "inmp441_gasket", micCX, micCY, 16.7 + dzTopBay, 17.6 + dzTopBay, 4.5, matBlackCap)
    boxes.append(("inmp441", makeAABB("inmp441", micCX - 7.0, micCX + 7.0, micCY - 7.0, micCY + 7.0, 15.2, 17.6)))

    // 8. WWZMDiB Mini 3.3V MicroSD (17.9 x 17.9 x 4.0 mm) Middle-Right, push-push slot flush Right Wall X=86.0 (Z: 9.0..13.0)
    addBox(bayNode, "microsd_pcb", 66.3, 84.2, 17.6, 35.5, 9.0 + dzTopBay, 10.6 + dzTopBay, matBluePCB)
    addBox(bayNode, "microsd_cage", 69.7, 84.2, 19.6, 33.4, 10.6 + dzTopBay, 13.0 + dzTopBay, matSilver)
    addBox(bayNode, "microsd_card_edge", 82.0, 85.9, 20.8, 31.8, 11.0 + dzTopBay, 12.2 + dzTopBay, matGold)
    boxes.append(("microsd", makeAABB("mini_3v3_microsd", 66.3, 84.2, 17.6, 35.5, 9.0, 13.0)))

    // 9. Lower-Right Bay: Acxico KCX_BT_EMITTER (15.5 x 23.5 x 2.5 mm, Z: 2.0..4.5)
    addBox(bayNode, "bt_emitter_pcb", 68.7, 84.2, 6.0, 29.5, 2.0 + dzTopBay, 3.4 + dzTopBay, matBluePCB)
    addBox(bayNode, "bt_emitter_ic", 72.7, 79.7, 13.0, 22.0, 3.4 + dzTopBay, 4.5 + dzTopBay, matBlackCap)
    boxes.append(("bt_emitter", makeAABB("kcx_bt_emitter", 68.7, 84.2, 6.0, 29.5, 2.0, 4.5)))

    // 10. Top-Right GY-PCM5102 (17.0 x 32.0 x 5.5 mm, X: 63.0..80.0, Y: 36.2..68.2, Z: 7.9..13.4) with 3.5mm TRS jack pointing UPWARD (+Y) through Top Edge Y=70.0
    addBox(bayNode, "pcm5102_pcb", 63.0, 80.0, 36.2, 68.2, 7.9 + dzTopBay, 9.5 + dzTopBay, matPurplePCB)
    addBox(bayNode, "pcm5102_trs", trsCX - 4.25, trsCX + 4.25, 56.0, 68.2, 9.5 + dzTopBay, 13.4 + dzTopBay, matBlackCap)
    addCylY(bayNode, "pcm5102_trs_ring", trsCX, 67.8, 70.35, 11.45 + dzTopBay, 3.0, matGold)
    addCylY(bayNode, "pcm5102_trs_bore", trsCX, 68.0, 70.42, 11.45 + dzTopBay, 1.75, matPortCavity)
    boxes.append(("pcm5102", makeAABB("gy_pcm5102_pcb", 63.0, 80.0, 36.2, 68.2, 7.9, 9.5)))
    boxes.append(("pcm5102", makeAABB("gy_pcm5102_trs", trsCX - 4.25, trsCX + 4.25, 56.0, 68.2, 9.5, 13.4)))
    root.addChildNode(bayNode)

    root.addChildNode(lid)

    let cols = exploded ? 0 : verifyAABBs(label: opaque ? "Option_P5_Exp_Compact_Horizontal_Opaque" : "Option_P5_Exp_Compact_Horizontal_Smoke", boxes: boxes)
    return (root, cols)
}

// MARK: - Build 1:1 Standard Poker Playing Card Deck (88.9 x 63.5 x 17.5 mm, Horizontal)
func buildPlayingCardDeckHorizontal() -> SCNNode {
    let deck = SCNNode()
    addBox(deck, "deck_tuck_box", 0, 88.9, 0, 63.5, 0, 17.5, matCardWhite, chamfer: 0.6)
    addBox(deck, "deck_red_panel", 6.0, 82.9, 4.5, 59.0, 17.4, 17.6, matCardRed)
    addBox(deck, "deck_inner_white", 18.0, 70.0, 8.5, 55.0, 17.5, 17.65, matCardWhite)
    return deck
}

// MARK: - Build Printable Binary STL Parts (1 mm units for Bambu P2S)
func exportPrintableSTLs() throws {
    // 1. Bottom Tray (86.0 x 70.0 x 17.7 mm, R = 5.4 mm rounded corners)
    let tray = STLMesh()
    tray.addBox(5.4, boxW - 5.4, 0.0, boxH, 0.0, 1.8)
    tray.addBox(0.0, 5.4, 5.4, boxH - 5.4, 0.0, 1.8)
    tray.addBox(boxW - 5.4, boxW, 5.4, boxH - 5.4, 0.0, 1.8)
    for c in corners {
        tray.addCornerSector(cx: c.cx, cy: c.cy, rCorner: 5.4, quadrant: c.quadrant,
                             holeX: c.holeX, holeY: c.holeY, rHole: 0.0, z0: 0.0, z1: 4.2)
        tray.addCornerSector(cx: c.cx, cy: c.cy, rCorner: 5.4, quadrant: c.quadrant,
                             holeX: c.holeX, holeY: c.holeY, rHole: 1.0, z0: 4.2, z1: 17.7)
    }
    // Left Wall (USB-C pigtail cutout Y: 43.3..53.7, Z: 11.6..15.6)
    tray.addBox(0.0, 1.8, 5.4, 43.3, 1.8, 17.7)
    tray.addBox(0.0, 1.8, 53.7, boxH - 5.4, 1.8, 17.7)
    tray.addBox(0.0, 1.8, 43.3, 53.7, 1.8, 11.6)
    tray.addBox(0.0, 1.8, 43.3, 53.7, 15.6, 17.7)
    // Right Wall (MicroSD Y: 19.3..33.8, Z: 9.8..13.4)
    tray.addBox(boxW - 1.8, boxW, 5.4, 19.3, 1.8, 17.7)
    tray.addBox(boxW - 1.8, boxW, 19.3, 33.8, 1.8, 9.8)
    tray.addBox(boxW - 1.8, boxW, 19.3, 33.8, 13.4, 17.7)
    tray.addBox(boxW - 1.8, boxW, 33.8, boxH - 5.4, 1.8, 17.7)
    // Bottom Wall (solid) & Top Wall (4x 8.6x8.6mm keycap cutouts + Top-Right 3.5mm TRS cutout)
    tray.addBox(5.4, boxW - 5.4, 0.0, 1.8, 1.8, 17.7)
    tray.addBox(5.4, topCapXs.first! - halfCut, boxH - 1.8, boxH, 1.8, 17.7)
    tray.addBox(topCapXs.first! - halfCut, topCapXs.last! + halfCut, boxH - 1.8, boxH, 1.8, 5.4)
    tray.addBox(topCapXs.first! - halfCut, topCapXs.last! + halfCut, boxH - 1.8, boxH, 14.0, 17.7)
    for i in 1..<topCapXs.count {
        tray.addBox(topCapXs[i - 1] + halfCut, topCapXs[i] - halfCut, boxH - 1.8, boxH, 5.4, 14.0)
    }
    tray.addBox(topCapXs.last! + halfCut, trsCutX0, boxH - 1.8, boxH, 1.8, 17.7)
    tray.addBox(trsCutX0, trsCutX1, boxH - 1.8, boxH, 1.8, 8.6)
    tray.addBox(trsCutX0, trsCutX1, boxH - 1.8, boxH, 14.8, 17.7)
    tray.addBox(trsCutX1, boxW - 5.4, boxH - 1.8, boxH, 1.8, 17.7)
    // Internal Cradles
    tray.addBox(30.6, 31.2, 2.2, 61.2, 1.8, 7.0)
    tray.addBox(68.6, 69.2, 30.0, 61.2, 1.8, 7.0)
    for (kx0, kx1, ky0, ky1) in [
        (5.5, 8.5, 2.5, 5.5), (27.5, 30.5, 2.5, 5.5),
        (5.5, 8.5, 32.5, 35.5), (27.5, 30.5, 32.5, 35.5)
    ] {
        tray.addBox(kx0, kx1, ky0, ky1, 1.8, 2.4)
    }
    tray.addBox(30.6, 31.0, 2.2, 17.2, 8.0, 9.7)
    tray.addBox(68.0, 68.4, 2.2, 17.2, 8.0, 9.7)
    tray.addBox(19.9, 20.9, 61.5, 68.2, 1.8, 17.7)
    tray.addBox(58.1, 59.1, 61.5, 68.2, 1.8, 17.7)
    tray.addBox(13.0, 16.0, 35.8, 36.7, 1.8, 13.5)
    tray.addBox(16.0, 19.0, 60.4, 61.3, 1.8, 13.5)
    tray.addBox(73.1, 76.0, 35.8, 36.1, 1.8, 13.5)
    for (bx0, bx1, by0, by1) in [
        (2.5, 5.0, 38.5, 41.0), (25.5, 28.0, 38.5, 41.0),
        (2.5, 5.0, 55.0, 57.5), (25.5, 28.0, 55.0, 57.5)
    ] {
        tray.addBox(bx0, bx1, by0, by1, 1.8, 2.0)
    }
    tray.addBox(28.7, 29.5, 40.0, 56.0, 1.8, 4.5)
    tray.addBox(5.0, 25.0, 37.1, 37.8, 1.8, 4.5)
    tray.addBox(5.0, 25.0, 58.2, 58.9, 1.8, 4.5)
    tray.addBox(70.0, 84.2, 35.5, 36.1, 1.8, 9.0)
    tray.addBox(70.0, 84.2, 16.5, 17.5, 5.0, 9.0)
    tray.addBox(65.5, 66.2, 20.0, 34.0, 8.0, 9.0)
    tray.addBox(80.2, 82.0, 54.0, 64.0, 1.8, 7.9)
    tray.addBox(80.2, 82.0, 36.5, 42.0, 1.8, 7.9)
    tray.addBox(60.0, 62.8, 61.5, 64.5, 1.8, 7.9)
    for (ax0, ax1, ay0, ay1) in [
        (68.7, 71.2, 6.0, 8.5), (81.7, 84.2, 6.0, 8.5),
        (68.7, 71.2, 27.0, 29.5), (81.7, 84.2, 27.0, 29.5)
    ] {
        tray.addBox(ax0, ax1, ay0, ay1, 1.8, 2.0)
    }
    try tray.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_horizontal_bottom_tray.stl", header: "P5-Exp-Compact-Horizontal Bottom Tray 86x70x17.7mm R5.4")

    // 2. Top Faceplate printed exterior-down (Z: 0..1.8 faceplate, Z: 1.8..3.4 INMP441 collar & stick well skirt)
    let lid = STLMesh()
    for c in corners {
        lid.addCornerSector(cx: c.cx, cy: c.cy, rCorner: 5.4, quadrant: c.quadrant,
                            holeX: c.holeX, holeY: c.holeY, rHole: 1.1, z0: 0.0, z1: 1.8)
    }
    // Upper Centered AMOLED Window + Upper-Right Mic Zone
    lid.addBox(0.0, 5.4, 36.0, boxH - 5.4, 0.0, 1.8)
    lid.addBox(5.4, 18.0, 36.0, boxH, 0.0, 1.8)
    lid.addBox(18.0, 68.0, 36.0, 37.8, 0.0, 1.8)
    lid.addBox(18.0, 68.0, 59.3, boxH, 0.0, 1.8)
    lid.addBox(68.0, 71.0, 36.0, boxH, 0.0, 1.8)
    lid.addBox(71.0, 81.0, 36.0, 43.0, 0.0, 1.8)
    lid.addBox(71.0, 81.0, 53.0, boxH, 0.0, 1.8)
    lid.addBox(81.0, boxW, 36.0, boxH - 5.4, 0.0, 1.8)
    lid.addBox(81.0, boxW - 5.4, boxH - 5.4, boxH, 0.0, 1.8)
    // Circular 21-hole recessed mic grille centered at (76.0, 48.0)
    lid.addAnnulusZ(cx: micCX, cy: micCY, rIn: 4.8, rOut: 6.2, z0: 0.0, z1: 1.8)
    for (mx, my) in [(micCX - 4.3, micCY - 4.3), (micCX + 4.3, micCY - 4.3), (micCX - 4.3, micCY + 4.3), (micCX + 4.3, micCY + 4.3)] {
        lid.addBox(mx - 0.75, mx + 0.75, my - 0.75, my + 0.75, 0.0, 1.8)
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
    lid.addAnnulusZ(cx: micCX, cy: micCY, rIn: 4.6, rOut: 6.2, z0: 1.8, z1: 3.0)
    // Recessed Ø25.0mm thumbstick well skirt (Z: 0..3.2mm) at (18.0, 19.0)
    lid.addAnnulusZ(cx: stickCX, cy: stickCY, rIn: 12.5, rOut: 13.5, z0: 0.0, z1: 3.2)
    lid.addBox(0.0, 5.4, 5.4, 36.0, 0.0, 1.8)
    lid.addBox(5.4, 5.5, 0.0, 36.0, 0.0, 1.8)
    lid.addBox(30.5, 31.0, 0.0, 36.0, 0.0, 1.8)
    lid.addBox(5.5, 30.5, 0.0, 6.5, 0.0, 1.8)
    lid.addBox(5.5, 30.5, 31.5, 36.0, 0.0, 1.8)
    for sx in [-1.0, 1.0] {
        for sy in [-1.0, 1.0] {
            lid.addBox(min(stickCX + sx * 8.9, stickCX + sx * 12.6), max(stickCX + sx * 8.9, stickCX + sx * 12.6),
                       min(stickCY + sy * 8.9, stickCY + sy * 12.6), max(stickCY + sy * 8.9, stickCY + sy * 12.6), 0.0, 1.8)
            lid.addBox(min(stickCX + sx * 6.4, stickCX + sx * 9.0), max(stickCX + sx * 6.4, stickCX + sx * 9.0),
                       min(stickCY + sy * 10.8, stickCY + sy * 12.6), max(stickCY + sy * 10.8, stickCY + sy * 12.6), 0.0, 1.8)
            lid.addBox(min(stickCX + sx * 10.8, stickCX + sx * 12.6), max(stickCX + sx * 10.8, stickCX + sx * 12.6),
                       min(stickCY + sy * 6.4, stickCY + sy * 9.0), max(stickCY + sy * 6.4, stickCY + sy * 9.0), 0.0, 1.8)
        }
    }
    // Front 1x4 Keypad & Right Grip Deck (X: 31.0..86.0, Y: 0..36.0)
    lid.addBox(31.0, boxW - 5.4, 0.0, frontCapYCenter - halfCut, 0.0, 1.8)
    lid.addBox(boxW - 5.4, boxW, 5.4, frontCapYCenter - halfCut, 0.0, 1.8)
    lid.addBox(31.0, boxW, frontCapYCenter + halfCut, 36.0, 0.0, 1.8)
    lid.addBox(31.0, frontCapXs.first! - halfCut, frontCapYCenter - halfCut, frontCapYCenter + halfCut, 0.0, 1.8)
    for i in 1..<frontCapXs.count {
        lid.addBox(frontCapXs[i - 1] + halfCut, frontCapXs[i] - halfCut, frontCapYCenter - halfCut, frontCapYCenter + halfCut, 0.0, 1.8)
    }
    lid.addBox(frontCapXs.last! + halfCut, boxW, frontCapYCenter - halfCut, frontCapYCenter + halfCut, 0.0, 1.8)
    lid.mirrorYInPlace(yMax: boxH)
    try lid.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_horizontal_top_faceplate.stl", header: "P5-Exp-Compact-Horizontal Top Faceplate 86x70x3.2mm R5.4")

    // 3. Coral Concave Thumb-Disc (Ø16.0 x 3.8 mm)
    let disc = STLMesh()
    disc.addAnnulusZ(cx: 8.0, cy: 8.0, rIn: 2.0, rOut: 3.6, z0: 0.0, z1: 1.6)
    disc.addCylinderZ(cx: 8.0, cy: 8.0, r: 8.0, z0: 1.6, z1: 3.2)
    disc.addAnnulusZ(cx: 8.0, cy: 8.0, rIn: 5.8, rOut: 8.0, z0: 3.2, z1: 3.8)
    try disc.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_horizontal_concave_thumb_disc.stl", header: "P5-Exp-Compact-Horizontal Concave Thumb-Disc 16x3.8mm")

    // 4. Keycap Helpers
    func addKeycap(to mesh: STLMesh, x0: Double, y0: Double, bodyHeight: Double = 2.8) {
        mesh.addBox(x0 - 0.55, x0 + 8.55, y0 - 0.55, y0 + 8.55, 0.0, 0.8)
        mesh.addBox(x0, x0 + 8.0, y0, y0 + 8.0, 0.8, 0.8 + bodyHeight)
    }

    let frontCaps = STLMesh()
    for c in 0..<4 {
        addKeycap(to: frontCaps, x0: Double(c) * 12.0 + 0.55, y0: 0.55, bodyHeight: 2.8)
    }
    try frontCaps.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_horizontal_keycaps_front_4x.stl", header: "P5-Exp-Compact-Horizontal Front 4x Captive Keycaps")

    let topCaps = STLMesh()
    for c in 0..<4 {
        addKeycap(to: topCaps, x0: Double(c) * 12.0 + 0.55, y0: 0.55, bodyHeight: 2.6)
    }
    try topCaps.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_horizontal_keycaps_top_4x.stl", header: "P5-Exp-Compact-Horizontal Top-Edge 4x Captive Keycaps")

    // 5. Single-Plate All-in-One STL arranged in 4 AMS color zones inside Bambu Lab P2S 256 x 256 mm build plate
    let shield = STLMesh()
    shield.addBox(0.0, 37.6, 0.0, 59.4, 0.0, 0.8)

    let singlePlate = STLMesh()
    // Zone 1: Matte Black (Tray + Faceplate + Shield Rib + Top-Edge 4x Keycaps)
    singlePlate.appendOffset(from: tray, dx: 0.0, dy: 96.0)
    singlePlate.appendOffset(from: lid, dx: 96.0, dy: 96.0)
    singlePlate.appendOffset(from: shield, dx: 0.0, dy: 24.0)
    for c in 0..<4 {
        addKeycap(to: singlePlate, x0: 96.0 + Double(c) * 12.0, y0: 70.0, bodyHeight: 2.6)
    }
    // Zone 2: Matte Coral (Concave Thumb-Disc + Front Key 4)
    singlePlate.appendOffset(from: disc, dx: 204.0, dy: 44.0)
    addKeycap(to: singlePlate, x0: 206.0, y0: 16.0, bodyHeight: 2.8)
    // Zone 3: Matte Warm Amber (Front Keys 1 & 3)
    for c in 0..<2 {
        addKeycap(to: singlePlate, x0: 96.0 + Double(c) * 12.0, y0: 6.0, bodyHeight: 2.8)
    }
    // Zone 4: Matte Retro Teal (Front Key 2)
    addKeycap(to: singlePlate, x0: 56.0, y0: 6.0, bodyHeight: 2.8)
    try singlePlate.writeBinarySTL(to: "\(stlDir)/p5_exp_compact_horizontal_single_plate_all_parts.stl", header: "P5-Exp-Compact-Horizontal Single-Plate All Parts (220x166x17.7mm)")
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
    keyNode.position = SCNVector3(120, 165, 95)
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
let (p5Smoke, cols1) = buildP5ExpCompactHorizontal(exploded: false, opaque: false)
let (p5Opaque, cols2) = buildP5ExpCompactHorizontal(exploded: false, opaque: true)
guard cols1 == 0 && cols2 == 0 else {
    fatalError("P5-Exp-Compact-Horizontal collision check failed!")
}

let (p5Exploded, _) = buildP5ExpCompactHorizontal(exploded: true, opaque: false)
try exportUSDZ(p5Smoke.clone(), to: "\(usdzDir)/p5_exp_compact_horizontal_smoke.usdz")
try exportUSDZ(p5Exploded.clone(), to: "\(usdzDir)/p5_exp_compact_horizontal_exploded.usdz")
try exportUSDZ(p5Opaque.clone(), to: "\(usdzDir)/p5_exp_compact_horizontal_opaque.usdz")
try exportPrintableSTLs()

// 1. Orthographic 90-deg Top-Down Scene: Opaque P5-Exp-Compact-Horizontal (86x70x19.5mm) + Bicycle Deck (88.9x63.5mm)
let topDownScene = SCNNode()
let opaqueCopy = p5Opaque.clone()
opaqueCopy.position = SCNVector3(0, 0, 0)
topDownScene.addChildNode(opaqueCopy)

let deckNode = buildPlayingCardDeckHorizontal()
deckNode.position = SCNVector3(98.0, 0, -3.25)
topDownScene.addChildNode(deckNode)

let imgTopDown = renderSnapshot(topDownScene,
                                camPos: SCNVector3(94, 240, -35),
                                lookAt: SCNVector3(94, 9.75, -35),
                                up: SCNVector3(0, 0, -1),
                                orthoScale: 74.0,
                                size: CGSize(width: 1400, height: 1050))
savePNG(imgTopDown, to: "\(renderDir)/exp_ch_ortho_topdown.png")

// 2. 4-Panel Port & Top-Edge Shoulder Keypad Sheet (Left USB-C, Right MicroSD, Top-Edge 1x4 + Top-Right 3.5mm TRS)
let sheetSize = CGSize(width: 1600, height: 1200)
let sheetImg = NSImage(size: sheetSize)
sheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: sheetSize))

let pTL = renderSnapshot(p5Opaque.clone(),
                         camPos: SCNVector3(-78, 96, -132),
                         lookAt: SCNVector3(41, 9.75, -36),
                         fov: 30, size: CGSize(width: 780, height: 560))
pTL.draw(in: NSRect(x: 10, y: 610, width: 780, height: 560))

let pTR = renderSnapshot(p5Opaque.clone(),
                         camPos: SCNVector3(166, 96, -132),
                         lookAt: SCNVector3(45, 9.75, -36),
                         fov: 30, size: CGSize(width: 780, height: 560))
pTR.draw(in: NSRect(x: 810, y: 610, width: 780, height: 560))

let pBL = renderSnapshot(p5Opaque.clone(),
                         camPos: SCNVector3(230, 9.75, -35),
                         lookAt: SCNVector3(43, 9.75, -35),
                         up: SCNVector3(0, 1, 0),
                         orthoScale: 28.0, size: CGSize(width: 780, height: 560))
pBL.draw(in: NSRect(x: 10, y: 20, width: 780, height: 560))

let sidePair = SCNNode()
let leftViewNode = p5Opaque.clone()
leftViewNode.position = SCNVector3(0, 14, 0)
sidePair.addChildNode(leftViewNode)
let topEdgeNode = p5Opaque.clone()
topEdgeNode.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
topEdgeNode.position = SCNVector3(70, -14, 8)
sidePair.addChildNode(topEdgeNode)

let pBR = renderSnapshot(sidePair,
                         camPos: SCNVector3(-200, 9.75, -35),
                         lookAt: SCNVector3(43, 9.75, -35),
                         up: SCNVector3(0, 1, 0),
                         orthoScale: 42.0, size: CGSize(width: 780, height: 560))
pBR.draw(in: NSRect(x: 810, y: 20, width: 780, height: 560))

sheetImg.unlockFocus()
savePNG(sheetImg, to: "\(renderDir)/exp_ch_ports_and_top_keys.png")

// 3. 2-Panel Internal Cradles & Bambu P2S Single-Plate Print Sheet (1600x900)
let plateSheetSize = CGSize(width: 1600, height: 900)
let plateSheetImg = NSImage(size: plateSheetSize)
plateSheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: plateSheetSize))

let (emptyTrayCradles, _) = buildShellAndLid(shellMat: matOpaqueCharcoal, cradleMat: matCradle, dzShellBot: 0, dzLid: 0, renderOrder: 0)
let pCradles = renderSnapshot(emptyTrayCradles,
                              camPos: SCNVector3(-52, 152, 54),
                              lookAt: SCNVector3(43, 8.5, -35),
                              fov: 34, size: CGSize(width: 780, height: 820))
pCradles.draw(in: NSRect(x: 10, y: 20, width: 780, height: 820))

let plateScene = SCNNode()
addBox(plateScene, "bambu_p2s_bed", 0, 256, 0, 256, -2.0, 0.0, matBuildPlate)
for g in stride(from: 0.0, through: 256.0, by: 32.0) {
    addBox(plateScene, "grid_x_\(Int(g))", g - 0.35, g + 0.35, 0, 256, -0.02, 0.05, matGridLine)
    addBox(plateScene, "grid_y_\(Int(g))", 0, 256, g - 0.35, g + 0.35, -0.02, 0.05, matGridLine)
}
let (plateTray, _) = buildShellAndLid(shellMat: matOpaqueCharcoal, cradleMat: matCradle, dzShellBot: 0, dzLid: 0, renderOrder: 0)
plateTray.position = SCNVector3(0.0, 0.0, -96.0)
plateScene.addChildNode(plateTray)

let (_, plateLid) = buildShellAndLid(shellMat: matOpaqueCharcoal, cradleMat: matCradle, dzShellBot: 0, dzLid: 0, renderOrder: 0)
let plateLidWrap = SCNNode()
plateLidWrap.eulerAngles = SCNVector3(Float.pi, 0, 0)
plateLidWrap.position = SCNVector3(96.0, 19.5, -166.0)
plateLidWrap.addChildNode(plateLid)
plateScene.addChildNode(plateLidWrap)

addBox(plateScene, "plate_shield_rib", 0.0, 37.6, 24.0, 83.4, 0.0, 0.8, matOpaqueCharcoal)

func addPlateCap(_ id: String, _ kx: Double, _ ky: Double, _ mat: SCNMaterial, bodyH: Double = 2.8) {
    addBox(plateScene, "plate_cap_f_\(id)", kx - 0.55, kx + 8.55, ky - 0.55, ky + 8.55, 0.0, 0.8, mat)
    addBox(plateScene, "plate_cap_b_\(id)", kx, kx + 8.0, ky, ky + 8.0, 0.8, 0.8 + bodyH, mat, chamfer: 0.4)
}
for c in 0..<4 {
    addPlateCap("blk_\(c)", 96.0 + Double(c) * 12.0, 70.0, matBlackCap, bodyH: 2.6)
}
addTubeZ(plateScene, "plate_disc_stem", 212.0, 52.0, 0.0, 1.6, 2.0, 3.6, matCoralCap)
addCylZ(plateScene, "plate_disc_body", 212.0, 52.0, 1.6, 3.2, 8.0, matCoralCap)
addTubeZ(plateScene, "plate_disc_rim", 212.0, 52.0, 3.2, 3.8, 5.8, 8.0, matCoralCap)
addPlateCap("coral_b4", 206.0, 16.0, matCoralCap)
for c in 0..<2 {
    addPlateCap("amber_\(c)", 96.0 + Double(c) * 12.0, 6.0, matAmberCap)
}
addPlateCap("teal_b2", 56.0, 6.0, matTealCap)

let pPlate = renderSnapshot(plateScene,
                            camPos: SCNVector3(128, 380, -128),
                            lookAt: SCNVector3(128, 0, -128),
                            up: SCNVector3(0, 0, -1),
                            orthoScale: 138.0,
                            size: CGSize(width: 780, height: 820))
pPlate.draw(in: NSRect(x: 810, y: 20, width: 780, height: 820))

let headerAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 21),
    .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.20, alpha: 1.0)
]
("EXP-CH INTERNAL CRADLES & TOP-EDGE KEYPAD + 3.5MM TRS (Z: 0..17.7 mm)" as NSString).draw(at: NSPoint(x: 24, y: 854), withAttributes: headerAttrs)
("BAMBU LAB P2S (256 x 256 mm) — 4 COLOR ZONES, 1 PLATE" as NSString).draw(at: NSPoint(x: 836, y: 854), withAttributes: headerAttrs)

plateSheetImg.unlockFocus()
savePNG(plateSheetImg, to: "\(renderDir)/exp_ch_cradles_and_plate.png")

// 4. 2-Panel Side-by-Side Smoke-Translucent Assembled & Vertically Exploded Sheet (1600x900)
let txSheetSize = CGSize(width: 1600, height: 900)
let txSheetImg = NSImage(size: txSheetSize)
txSheetImg.lockFocus()
NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: txSheetSize))

let pTransAssembled = renderSnapshot(p5Smoke.clone(),
                                     camPos: SCNVector3(-64, 130, 54),
                                     lookAt: SCNVector3(43, 9.75, -35),
                                     fov: 31,
                                     size: CGSize(width: 780, height: 820))
pTransAssembled.draw(in: NSRect(x: 10, y: 20, width: 780, height: 820))

let pTransExploded = renderSnapshot(p5Exploded.clone(),
                                    camPos: SCNVector3(-76, 136, 76),
                                    lookAt: SCNVector3(43, 12.5, -35),
                                    fov: 35,
                                    size: CGSize(width: 780, height: 820))
pTransExploded.draw(in: NSRect(x: 810, y: 20, width: 780, height: 820))

("EXP-CH SMOKE ASSEMBLED (86 x 70 x 19.5 mm · R5.4)" as NSString).draw(at: NSPoint(x: 28, y: 854), withAttributes: headerAttrs)
("VERTICALLY EXPLODED Z-STACK + TOP-EDGE 1x4 & 3.5MM TRS" as NSString).draw(at: NSPoint(x: 836, y: 854), withAttributes: headerAttrs)

txSheetImg.unlockFocus()
savePNG(txSheetImg, to: "\(renderDir)/exp_ch_smoke_and_exploded.png")

print("DONE Option P5-Exp-Compact-Horizontal CAD, STLs, USDZs & 4 Render Sheets.")
