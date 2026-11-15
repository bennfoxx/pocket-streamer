import Foundation
import SceneKit
import AppKit
import Metal

// MARK: - Paths & Output Directories
let rootDir = "/Users/benfox/Development/3D Design/Pocket Streamer Hardware CAD"
let usdzDir = "\(rootDir)/parts_1to1_3d/usdz"
let renderDir = "\(rootDir)/parts_1to1_3d/renders"
let artifactDir = "/Users/benfox/.gemini/antigravity/brain/d773b1b3-4405-4408-8ad7-b59f103e4218"

try FileManager.default.createDirectory(atPath: usdzDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: renderDir, withIntermediateDirectories: true)
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

func makeAABB(origin: (Double, Double, Double), rotZDeg: Int = 0, name: String,
              _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double) -> AABB {
    let corners = [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]
    var xs: [Double] = []
    var ys: [Double] = []
    for (x, y) in corners {
        let rx, ry: Double
        switch ((rotZDeg % 360) + 360) % 360 {
        case 90:  rx = -y; ry = x
        case 180: rx = -x; ry = -y
        case 270: rx = y;  ry = -x
        default:  rx = x;  ry = y
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
func addCyl(_ parent: SCNNode, _ name: String, r: Double, h: Double,
            cx: Double, cy: Double, cz: Double, axis: String,
            _ mat: SCNMaterial, renderOrder: Int = 0) -> SCNNode {
    let cyl = SCNCylinder(radius: CGFloat(r), height: CGFloat(h))
    cyl.radialSegmentCount = 40
    cyl.materials = [mat]
    let node = SCNNode(geometry: cyl)
    node.name = name
    node.renderingOrder = renderOrder
    node.position = SCNVector3(cx, cz, -cy)
    if axis == "x" {
        node.eulerAngles = SCNVector3(0, 0, Double.pi / 2)
    } else if axis == "y" {
        node.eulerAngles = SCNVector3(Double.pi / 2, 0, 0)
    }
    parent.addChildNode(node)
    return node
}

@discardableResult
func addTorusRing(_ parent: SCNNode, _ name: String, ringR: Double, pipeR: Double,
                  cx: Double, cy: Double, cz: Double, _ mat: SCNMaterial, renderOrder: Int = 0) -> SCNNode {
    let torus = SCNTorus(ringRadius: CGFloat(ringR), pipeRadius: CGFloat(pipeR))
    torus.ringSegmentCount = 48
    torus.pipeSegmentCount = 16
    torus.materials = [mat]
    let node = SCNNode(geometry: torus)
    node.name = name
    node.renderingOrder = renderOrder
    node.position = SCNVector3(cx, cz, -cy)
    parent.addChildNode(node)
    return node
}

func cadPlace(_ node: SCNNode, ox: Double, oy: Double, oz: Double, rotZDeg: Int = 0) {
    node.position = SCNVector3(ox, oz, -oy)
    node.eulerAngles = SCNVector3(0, Double(rotZDeg) * Double.pi / 180.0, 0)
}

func pbrMat(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0,
            roughness: CGFloat = 0.55, metalness: CGFloat = 0.05,
            depthWrite: Bool? = nil) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    m.roughness.contents = NSNumber(value: Double(roughness))
    m.metalness.contents = NSNumber(value: Double(metalness))
    m.isDoubleSided = true
    if a < 0.99 {
        m.transparencyMode = .aOne
        m.writesToDepthBuffer = depthWrite ?? false
    } else if let dw = depthWrite {
        m.writesToDepthBuffer = dw
    }
    return m
}

func texMat(_ image: NSImage, roughness: CGFloat = 0.35, metalness: CGFloat = 0.02, a: CGFloat = 1.0) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = image
    m.roughness.contents = NSNumber(value: Double(roughness))
    m.metalness.contents = NSNumber(value: Double(metalness))
    m.isDoubleSided = true
    if a < 0.99 {
        m.transparencyMode = .aOne
        m.writesToDepthBuffer = false
    }
    return m
}

// MARK: - Procedural Textures
func drawImage(width: Int, height: Int, _ block: (CGContext) -> Void) -> NSImage {
    let img = NSImage(size: NSSize(width: width, height: height))
    img.lockFocus()
    if let ctx = NSGraphicsContext.current?.cgContext {
        block(ctx)
    }
    img.unlockFocus()
    return img
}

func makeScreenUITexture() -> NSImage {
    return drawImage(width: 640, height: 340) { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 640, height: 340))
        ctx.setFillColor(NSColor(calibratedRed: 0.11, green: 0.14, blue: 0.19, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 294, width: 640, height: 46))

        ctx.setFillColor(NSColor(calibratedRed: 0.93, green: 0.42, blue: 0.12, alpha: 1).cgColor)
        let cover = CGPath(roundedRect: CGRect(x: 24, y: 54, width: 170, height: 210), cornerWidth: 16, cornerHeight: 16, transform: nil)
        ctx.addPath(cover)
        ctx.fillPath()
        ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.72, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: 68, y: 122, width: 82, height: 82))

        ctx.setFillColor(NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.28, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 224, y: 84, width: 386, height: 14))
        ctx.setFillColor(NSColor(calibratedRed: 0.95, green: 0.47, blue: 0.14, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 224, y: 84, width: 248, height: 14))

        let titleAttr: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 30), .foregroundColor: NSColor.white]
        let subAttr: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 20, weight: .semibold), .foregroundColor: NSColor(calibratedRed: 0.62, green: 0.85, blue: 0.96, alpha: 1)]
        let statusAttr: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 18, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.42, green: 0.94, blue: 0.68, alpha: 1)]
        NSAttributedString(string: "Audiobookshelf • Ch 14", attributes: statusAttr).draw(at: NSPoint(x: 20, y: 304))
        NSAttributedString(string: "PROJECT HAIL MARY", attributes: titleAttr).draw(at: NSPoint(x: 224, y: 216))
        NSAttributedString(string: "Andy Weir  •  Scrub: +1.8×", attributes: subAttr).draw(at: NSPoint(x: 224, y: 174))
        NSAttributedString(string: "14:22 / 10:53:10    Wi-Fi Cached", attributes: subAttr).draw(at: NSPoint(x: 224, y: 112))
    }
}

func makeLiPoLabelTexture() -> NSImage {
    return drawImage(width: 600, height: 400) { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.87, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 400))
        ctx.setStrokeColor(NSColor(calibratedRed: 0.66, green: 0.69, blue: 0.73, alpha: 1).cgColor)
        ctx.setLineWidth(4)
        ctx.stroke(CGRect(x: 10, y: 10, width: 580, height: 380))
        let bigAttr: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 34, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.19, alpha: 1)]
        let medAttr: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 22, weight: .semibold), .foregroundColor: NSColor(calibratedRed: 0.22, green: 0.25, blue: 0.30, alpha: 1)]
        NSAttributedString(string: "3.7V  1500mAh  Li-Po", attributes: bigAttr).draw(at: NSPoint(x: 34, y: 66))
        NSAttributedString(string: "MODEL 604060   5.55Wh   SHIELDED", attributes: medAttr).draw(at: NSPoint(x: 34, y: 26))
        NSAttributedString(string: "604060 3.7V 1500mAh", attributes: medAttr).draw(at: NSPoint(x: 34, y: 240))
    }
}

func makeThumbDiscTexture(orangePuck: Bool) -> NSImage {
    return drawImage(width: 240, height: 240) { ctx in
        let base = orangePuck
            ? NSColor(calibratedRed: 0.94, green: 0.36, blue: 0.10, alpha: 1)
            : NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.21, alpha: 1)
        ctx.setFillColor(base.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 240, height: 240))

        // Concave PSP-style micro concentric rings
        for r in stride(from: 24, through: 104, by: 16) {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(orangePuck ? 0.28 : 0.20).cgColor)
            ctx.setLineWidth(2.5)
            ctx.strokeEllipse(in: CGRect(x: 120 - r, y: 120 - r, width: r * 2, height: r * 2))
        }
        // Subtle safety-orange center pip on charcoal puck (or white on orange puck)
        let pip = orangePuck ? NSColor.white.withAlphaComponent(0.85) : NSColor(calibratedRed: 0.96, green: 0.38, blue: 0.10, alpha: 0.95)
        ctx.setFillColor(pip.cgColor)
        ctx.fillEllipse(in: CGRect(x: 106, y: 106, width: 28, height: 28))
    }
}

func makeCuttingMatTexture(widthMm: Double, heightMm: Double, label: String) -> NSImage {
    let pxPerMm = 6.0
    let w = Int(widthMm * pxPerMm)
    let h = Int(heightMm * pxPerMm)
    return drawImage(width: w, height: h) { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setStrokeColor(NSColor(calibratedRed: 0.16, green: 0.21, blue: 0.25, alpha: 0.8).cgColor)
        ctx.setLineWidth(1.0)
        var x = 0.0
        while x <= widthMm {
            let px = CGFloat(x * pxPerMm)
            ctx.move(to: CGPoint(x: px, y: 0))
            ctx.addLine(to: CGPoint(x: px, y: CGFloat(h)))
            x += 10.0
        }
        var y = 0.0
        while y <= heightMm {
            let py = CGFloat(y * pxPerMm)
            ctx.move(to: CGPoint(x: 0, y: py))
            ctx.addLine(to: CGPoint(x: CGFloat(w), y: py))
            y += 10.0
        }
        ctx.strokePath()

        ctx.setStrokeColor(NSColor(calibratedRed: 0.25, green: 0.34, blue: 0.40, alpha: 0.95).cgColor)
        ctx.setLineWidth(2.0)
        x = 0.0
        while x <= widthMm {
            let px = CGFloat(x * pxPerMm)
            ctx.move(to: CGPoint(x: px, y: 0))
            ctx.addLine(to: CGPoint(x: px, y: CGFloat(h)))
            x += 50.0
        }
        y = 0.0
        while y <= heightMm {
            let py = CGFloat(y * pxPerMm)
            ctx.move(to: CGPoint(x: 0, y: py))
            ctx.addLine(to: CGPoint(x: CGFloat(w), y: py))
            y += 50.0
        }
        ctx.strokePath()

        let attr: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 22, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.56, green: 0.74, blue: 0.84, alpha: 0.95)]
        NSAttributedString(string: label, attributes: attr).draw(at: NSPoint(x: 24, y: 20))
    }
}

func makeKeycapTexture(_ glyph: String, bg: NSColor, fg: NSColor = .white) -> NSImage {
    return drawImage(width: 160, height: 160) { ctx in
        ctx.setFillColor(bg.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.20).cgColor)
        ctx.setLineWidth(8)
        ctx.stroke(CGRect(x: 6, y: 6, width: 148, height: 148))
        let size: CGFloat = glyph.count <= 2 ? 64 : 34
        let attr: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: size, weight: .heavy), .foregroundColor: fg]
        let str = NSAttributedString(string: glyph, attributes: attr)
        let sz = str.size()
        str.draw(at: NSPoint(x: (160 - sz.width) * 0.5, y: (160 - sz.height) * 0.5))
    }
}

func overlayHeaderOnImage(_ img: NSImage, title: String, subtitle: String, footer: String) -> NSImage {
    let w = Int(img.size.width)
    let h = Int(img.size.height)
    return drawImage(width: w, height: h) { ctx in
        img.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.09, alpha: 0.84).cgColor)
        ctx.fill(CGRect(x: 24, y: h - 98, width: w - 48, height: 76))
        ctx.setStrokeColor(NSColor(calibratedRed: 0.95, green: 0.50, blue: 0.18, alpha: 0.90).cgColor)
        ctx.setLineWidth(2)
        ctx.stroke(CGRect(x: 24, y: h - 98, width: w - 48, height: 76))

        let tAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 25, weight: .bold), .foregroundColor: NSColor.white]
        let sAttr: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .medium), .foregroundColor: NSColor(calibratedRed: 0.62, green: 0.86, blue: 0.96, alpha: 1)]
        NSAttributedString(string: title, attributes: tAttr).draw(at: NSPoint(x: 42, y: h - 58))
        NSAttributedString(string: subtitle, attributes: sAttr).draw(at: NSPoint(x: 42, y: h - 86))

        ctx.setFillColor(NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.09, alpha: 0.84).cgColor)
        ctx.fill(CGRect(x: 24, y: 18, width: w - 48, height: 42))
        let fAttr: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold), .foregroundColor: NSColor(calibratedRed: 0.82, green: 0.90, blue: 0.95, alpha: 1)]
        NSAttributedString(string: footer, attributes: fAttr).draw(at: NSPoint(x: 40, y: 29))
    }
}

// MARK: - Materials
let matPCBGreen = pbrMat(0.06, 0.38, 0.19, 1.0, roughness: 0.35, metalness: 0.10)
let matPCBBlack = pbrMat(0.08, 0.09, 0.11, 1.0, roughness: 0.40, metalness: 0.10)
let matPCBBlue = pbrMat(0.08, 0.24, 0.56, 1.0, roughness: 0.38, metalness: 0.12)
let matGold = pbrMat(0.88, 0.71, 0.24, 1.0, roughness: 0.22, metalness: 0.92)
let matBrassInsert = pbrMat(0.85, 0.66, 0.22, 1.0, roughness: 0.24, metalness: 0.90)
let matSteel = pbrMat(0.76, 0.78, 0.82, 1.0, roughness: 0.22, metalness: 0.92)
let matBlackScrew = pbrMat(0.11, 0.12, 0.14, 1.0, roughness: 0.28, metalness: 0.82)
let matCopperWire = pbrMat(0.86, 0.45, 0.17, 1.0, roughness: 0.26, metalness: 0.86)
let matAmberKapton = pbrMat(0.86, 0.52, 0.06, 0.94, roughness: 0.20, metalness: 0.15)
let matSilverPouch = texMat(makeLiPoLabelTexture(), roughness: 0.30, metalness: 0.65)
let matShieldRib = pbrMat(0.42, 0.46, 0.52, 0.58, roughness: 0.35, metalness: 0.05)
let matEdgeTrim = pbrMat(0.32, 0.36, 0.42, 0.75, roughness: 0.35, metalness: 0.10, depthWrite: false)
let matScreenGlass = pbrMat(0.03, 0.03, 0.04, 1.0, roughness: 0.08, metalness: 0.10)
let matScreenUI = texMat(makeScreenUITexture(), roughness: 0.12, metalness: 0.02)
let matDarkCharcoal = pbrMat(0.14, 0.15, 0.17, 1.0, roughness: 0.55, metalness: 0.05)
let matOrangeKey = pbrMat(0.95, 0.35, 0.09, 1.0, roughness: 0.40, metalness: 0.05)
let matWireInsul = pbrMat(0.16, 0.17, 0.20, 1.0, roughness: 0.60, metalness: 0.05)
let matRedWire = pbrMat(0.82, 0.14, 0.14, 1.0, roughness: 0.50, metalness: 0.05)
let matCyanGuide = pbrMat(0.22, 0.82, 0.94, 0.55, roughness: 0.20, metalness: 0.10)

enum ShellColorway: String {
    case atomicSmoke = "Atomic Smoke"
    case frostedClearIce = "Frosted Clear Ice"
    case atomicPurple = "90s Atomic Purple"

    var bodyMat: SCNMaterial {
        switch self {
        case .atomicSmoke:
            return pbrMat(0.16, 0.18, 0.22, 0.38, roughness: 0.16, metalness: 0.06, depthWrite: false)
        case .frostedClearIce:
            return pbrMat(0.70, 0.86, 0.96, 0.24, roughness: 0.24, metalness: 0.04, depthWrite: false)
        case .atomicPurple:
            return pbrMat(0.46, 0.22, 0.72, 0.38, roughness: 0.18, metalness: 0.06, depthWrite: false)
        }
    }

    var edgeMat: SCNMaterial {
        switch self {
        case .atomicSmoke:
            return pbrMat(0.22, 0.25, 0.30, 0.62, roughness: 0.22, metalness: 0.08, depthWrite: false)
        case .frostedClearIce:
            return pbrMat(0.84, 0.92, 0.98, 0.50, roughness: 0.32, metalness: 0.05, depthWrite: false)
        case .atomicPurple:
            return pbrMat(0.56, 0.30, 0.82, 0.62, roughness: 0.24, metalness: 0.08, depthWrite: false)
        }
    }
}

// MARK: - Option P3-Joy8 Exact Component Builders (76.0 x 118.0 x 19.0 / 22.2 mm)
func buildKY023PlayfulLowProfile(parent: SCNNode, capsLayer: SCNNode, orangePuck: Bool, aabbs: inout [(String, AABB)]) {
    // origin: (29.8, 5.8, 2.8), rotZDeg: 90
    // World pcb_tails: X [3.8, 29.8], Y [5.8, 39.8], Z [1.9, 4.4]
    // World gimbal:    X [8.8, 24.8], Y [12.8, 28.8], Z [4.4, 17.3]
    // World 5p_crimps: X [10.15, 23.45], Y [39.8, 45.2], Z [8.8, 13.0]
    let ky = SCNNode(); ky.name = "ky023_lowprofile"
    let o = (29.8, 5.8, 2.8)
    cadPlace(ky, ox: o.0, oy: o.1, oz: o.2, rotZDeg: 90)

    // Black 34.0 x 26.0 x 1.6 PCB + trimmed -0.9 underside tails
    addBox(ky, "ky_pcb", 0, 34.0, 0, 26.0, 0, 1.6, matPCBBlack, chamfer: 0.2)
    addBox(ky, "ky_tails", 2.0, 32.0, 2.0, 24.0, -0.9, 0.0, matSteel)
    // Gimbal cage (16.0 x 16.0 x 12.9) centered at local (15.0, 13.0) -> world (16.8, 20.8)
    addBox(ky, "ky_gimbal", 7.0, 23.0, 5.0, 21.0, 1.6, 14.5, matSteel, chamfer: 0.3)
    addBox(ky, "ky_pot_x", 11.0, 19.0, 2.0, 5.0, 3.0, 13.0, matPCBGreen, chamfer: 0.15)
    addBox(ky, "ky_pot_y", 23.0, 26.0, 9.0, 17.0, 3.0, 13.0, matPCBBlue, chamfer: 0.15)
    // Stub post rising from gimbal to meet snapped Pocket Thumb-Disc (local Z 14.5..16.2 -> world Z 17.3..19.0)
    addCyl(ky, "ky_stub_post", r: 2.1, h: 2.2, cx: 15.0, cy: 13.0, cz: 15.4, axis: "z", matDarkCharcoal)
    // 5P Light-Mod crimps exiting top edge (+X_local = +Y_world: 39.8..45.2, Z: 8.8..13.0)
    addBox(ky, "ky_5p_crimps", 34.0, 39.4, 6.35, 19.65, 6.0, 10.2, matCopperWire, chamfer: 0.2)
    for j in 0..<5 {
        let py = 7.9 + Double(j) * 2.54
        addBox(ky, "ky_pin_\(j)", 31.0, 38.8, py - 0.35, py + 0.35, 1.6, 10.0, matGold)
    }
    parent.addChildNode(ky)

    // Snap-on 3D-printed Concave Pocket Thumb-Disc (Ø15.5 x 2.4 mm at cx=16.8, cy=20.8, world Z [18.6, 21.0])
    let puckNode = SCNNode(); puckNode.name = "pocket_thumb_disc"
    let puckTex = texMat(makeThumbDiscTexture(orangePuck: orangePuck), roughness: 0.42, metalness: 0.05)
    let rimMat = orangePuck ? matOrangeKey : matDarkCharcoal
    addCyl(puckNode, "disc_body", r: 7.75, h: 1.9, cx: 16.8, cy: 20.8, cz: 19.55, axis: "z", puckTex)
    // Tactile sculpted outer rim gives unmistakable concave dish feel without snagging pockets (<= 21.0 mm)
    addTorusRing(puckNode, "disc_concave_rim", ringR: 7.15, pipeR: 0.65, cx: 16.8, cy: 20.8, cz: 20.35, rimMat)
    capsLayer.addChildNode(puckNode)

    aabbs.append(("ky023", makeAABB(origin: o, rotZDeg: 90, name: "pcb_tails", 0, 34.0, 0, 26.0, -0.9, 1.6)))
    aabbs.append(("ky023", makeAABB(origin: o, rotZDeg: 90, name: "gimbal", 7.0, 23.0, 5.0, 21.0, 1.6, 14.5)))
    aabbs.append(("ky023", makeAABB(origin: o, rotZDeg: 90, name: "5p_crimps", 34.0, 39.4, 6.35, 19.65, 6.0, 10.2)))
}

func buildTightDualKeypads180Flip(ctrlLayer: SCNNode, capsLayer: SCNNode, includeTopRow: Bool = true, aabbs: inout [(String, AABB)]) {
    // 1) Bottom Keypad: 180-deg flip! origin: (70.2, 22.0, 5.8), rotZDeg: 180
    // World X [33.2, 70.2], World Y [7.0, 22.0], Z [5.0, 7.4]
    // Switches sit at Y [13.5, 20.0], 5P crimps exit DOWNWARD Y [2.0, 7.0], Z [7.4, 11.2]
    let botOrigin = includeTopRow ? (70.2, 22.0, 5.8) : (33.2, 15.5, 5.8)
    let botRot = includeTopRow ? 180 : 0
    let padBot = SCNNode(); padBot.name = "pad_bot"
    cadPlace(padBot, ox: botOrigin.0, oy: botOrigin.1, oz: botOrigin.2, rotZDeg: botRot)

    addBox(padBot, "bot_pcb", 0, 37.0, 0, 15.0, 0, 1.6, matPCBGreen, chamfer: 0.15)
    addBox(padBot, "bot_tails", 3.0, 34.0, 1.5, 13.0, -0.8, 0.0, matSteel)
    for hx in [2.5, 34.5] {
        for hy in [2.5, 12.5] {
            addCyl(padBot, "bot_pad", r: 1.35, h: 1.68, cx: hx, cy: hy, cz: 0.8, axis: "z", matGold)
        }
    }
    // 4 switches & steel plungers extending toward faceplate
    for i in 0..<4 {
        let kx = 4.6 + Double(i) * 9.2
        addBox(padBot, "bot_sw_\(i)", kx - 3.0, kx + 3.0, 2.0, 8.5, 1.6, 5.6, matDarkCharcoal, chamfer: 0.1)
        addBox(padBot, "bot_stem_\(i)", kx - 1.6, kx + 1.6, 3.5, 7.0, 5.6, 11.2, matSteel, chamfer: 0.05)
    }
    addBox(padBot, "bot_5p_crimps", 12.15, 24.85, 15.0, 20.0, 1.6, 5.4, matCopperWire, chamfer: 0.15)
    for j in 0..<5 {
        let px = 13.4 + Double(j) * 2.54
        addBox(padBot, "bot_pin_\(j)", px - 0.35, px + 0.35, 12.5, 19.4, 1.6, 5.0, matGold)
    }
    ctrlLayer.addChildNode(padBot)

    aabbs.append(("pad_bot", makeAABB(origin: botOrigin, rotZDeg: botRot, name: "pcb_tails", 0, 37.0, 0, 15.0, -0.8, 1.6)))
    aabbs.append(("pad_bot", makeAABB(origin: botOrigin, rotZDeg: botRot, name: "switches", 1.0, 36.0, 2.0, 8.5, 1.6, 11.2)))
    aabbs.append(("pad_bot", makeAABB(origin: botOrigin, rotZDeg: botRot, name: "5p_crimps", 12.15, 24.85, 15.0, 20.0, 1.6, 5.4)))

    // Place BOTTOM-ROW Keycaps directly in WORLD CAD coordinates so BACK/PLAY/MARK/REC read UPRIGHT left-to-right!
    // NOTE: when botRot=180 & origin=(70.2,22.0), switch world Xs match 70.2 - (4.6 + i*9.2) = {65.6, 56.4, 47.2, 38.0} = same as {38.0, 47.2, 56.4, 65.6}!
    // Switch world Y center is 22.0 - 5.25 = 16.75 (Y [13.5, 20.0]) when J8, or 15.5 + 5.25 = 20.75 when J4!
    let botCapCy = includeTopRow ? 16.75 : 20.75
    let botLabels = ["BACK", "PLAY", "MARK", "REC"]
    for i in 0..<4 {
        let wx = 38.0 + Double(i) * 9.2
        let isOrange = (i == 3)
        let bg = isOrange ? NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.09, alpha: 1) : NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.20, alpha: 1)
        let cMat = texMat(makeKeycapTexture(botLabels[i], bg: bg), roughness: 0.38)
        addBox(capsLayer, "cap_bot_\(i)", wx - 3.6, wx + 3.6, botCapCy - 3.1, botCapCy + 3.1, 17.0, 20.1, cMat, chamfer: 0.45)
    }

    if includeTopRow {
        // 2) Top Keypad: origin: (33.2, 22.6, 5.8), rotZDeg: 0 -> switches at Y [24.6, 31.1] (only 4.6mm edge gap above bottom switches!)
        let topOrigin = (33.2, 22.6, 5.8)
        let padTop = SCNNode(); padTop.name = "pad_top"
        cadPlace(padTop, ox: topOrigin.0, oy: topOrigin.1, oz: topOrigin.2, rotZDeg: 0)

        addBox(padTop, "top_pcb", 0, 37.0, 0, 15.0, 0, 1.6, matPCBGreen, chamfer: 0.15)
        addBox(padTop, "top_tails", 3.0, 34.0, 1.5, 13.0, -0.8, 0.0, matSteel)
        for hx in [2.5, 34.5] {
            for hy in [2.5, 12.5] {
                addCyl(padTop, "top_pad", r: 1.35, h: 1.68, cx: hx, cy: hy, cz: 0.8, axis: "z", matGold)
            }
        }
        let topLabels = ["◀", "▲", "▼", "▶"]
        for i in 0..<4 {
            let kx = 4.6 + Double(i) * 9.2
            addBox(padTop, "top_sw_\(i)", kx - 3.0, kx + 3.0, 2.0, 8.5, 1.6, 5.6, matDarkCharcoal, chamfer: 0.1)
            addBox(padTop, "top_stem_\(i)", kx - 1.6, kx + 1.6, 3.5, 7.0, 5.6, 11.2, matSteel, chamfer: 0.05)

            let wx = 33.2 + kx
            let bg = NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.20, alpha: 1)
            let cMat = texMat(makeKeycapTexture(topLabels[i], bg: bg), roughness: 0.38)
            // Switch world Y center is 22.6 + 5.25 = 27.85 (Y [24.75, 30.95]); 24.75 - 19.85 = 4.9 mm clear edge gap (center pitch 11.1 mm)!
            addBox(capsLayer, "cap_top_\(i)", wx - 3.6, wx + 3.6, 24.75, 30.95, 17.0, 20.1, cMat, chamfer: 0.45)
        }
        // Top 5P bare crimps arched up cleanly at local Z 3.0..7.2 -> World Z 8.8..13.0 (+0.3mm clear over LiPo shield rib Z<=8.5)
        addBox(padTop, "top_5p_crimps", 12.15, 24.85, 15.0, 20.2, 3.0, 7.2, matCopperWire, chamfer: 0.15)
        for j in 0..<5 {
            let px = 13.4 + Double(j) * 2.54
            addBox(padTop, "top_pin_\(j)", px - 0.35, px + 0.35, 12.5, 19.6, 1.6, 7.0, matGold)
        }
        ctrlLayer.addChildNode(padTop)

        aabbs.append(("pad_top", makeAABB(origin: topOrigin, rotZDeg: 0, name: "pcb_tails", 0, 37.0, 0, 15.0, -0.8, 1.6)))
        aabbs.append(("pad_top", makeAABB(origin: topOrigin, rotZDeg: 0, name: "switches", 1.0, 36.0, 2.0, 8.5, 1.6, 11.2)))
        aabbs.append(("pad_top", makeAABB(origin: topOrigin, rotZDeg: 0, name: "5p_crimps", 12.15, 24.85, 15.0, 20.2, 3.0, 7.2)))
    }
}

func buildLiPoAndShield(parent: SCNNode, aabbs: inout [(String, AABB)]) {
    // 604060 LiPo pouch: X [8.0, 68.0], Y [40.2, 80.2], Z [1.9, 7.7]
    let lipo = SCNNode(); lipo.name = "lipo_604060"
    addBox(lipo, "lipo_pouch", 15.5, 68.0, 40.2, 80.2, 1.9, 7.7, matSilverPouch, chamfer: 0.8)
    addBox(lipo, "lipo_pcm_kapton", 8.0, 16.0, 40.7, 79.7, 2.1, 7.5, matAmberKapton, chamfer: 0.4)
    addBox(lipo, "lipo_pcm_pcb", 9.0, 13.0, 44.5, 75.5, 3.0, 6.2, matPCBGreen)
    addBox(lipo, "lipo_kapton_edge", 14.5, 67.8, 40.2, 42.9, 2.0, 7.75, matAmberKapton, chamfer: 0.2)
    addCyl(lipo, "lipo_red_lead", r: 0.70, h: 35.0, cx: 10.0, cy: 64.5, cz: 7.4, axis: "y", matRedWire)
    addCyl(lipo, "lipo_blk_lead", r: 0.70, h: 35.0, cx: 12.0, cy: 64.5, cz: 7.4, axis: "y", matDarkCharcoal)
    parent.addChildNode(lipo)

    // 0.7 mm shield rib: X [7.8, 68.2], Y [40.0, 80.5], Z [7.8, 8.5]
    let shield = SCNNode(); shield.name = "lipo_shield_rib"
    addBox(shield, "shield_plate", 7.8, 68.2, 40.0, 80.5, 7.8, 8.5, matShieldRib, chamfer: 0.15, renderOrder: 4)
    for ry in [45.0, 57.0, 69.0, 77.0] {
        addBox(shield, "rib_\(Int(ry))", 14.0, 67.5, ry, ry + 1.0, 8.2, 8.5, matEdgeTrim, renderOrder: 5)
    }
    parent.addChildNode(shield)

    aabbs.append(("lipo", AABB(name: "pouch_pcm", minX: 8.0, maxX: 68.0, minY: 40.2, maxY: 80.2, minZ: 1.9, maxZ: 7.7)))
    aabbs.append(("lipo_shield_rib", AABB(name: "rib", minX: 7.8, maxX: 68.2, minY: 40.0, maxY: 80.5, minZ: 7.8, maxZ: 8.5)))
}

func buildCombedCopperHarnesses(parent: SCNNode, aabbs: inout [(String, AABB)]) {
    let bus = SCNNode(); bus.name = "combed_copper_spine"

    // Upper left-spine channel: X [4.0, 9.6], Y [40.2, 84.5], Z [8.8, 13.6]
    // Clear of shield rib (Z<=8.5), ky023 5P (X>=10.15), esp32 crimps (X>=13.72), esp32 pcb (Z>=15.3)
    for i in 0..<4 {
        let wx = 4.7 + Double(i) * 1.35
        addBox(bus, "up_wire_\(i)", wx - 0.50, wx + 0.50, 40.2, 84.5, 9.3, 13.1, matCopperWire, chamfer: 0.25)
    }
    addBox(bus, "up_comb_1", 4.0, 9.6, 51.0, 53.8, 8.8, 13.6, matDarkCharcoal, chamfer: 0.3)
    addBox(bus, "up_comb_2", 4.0, 9.6, 78.5, 81.3, 8.8, 13.6, matDarkCharcoal, chamfer: 0.3)

    // Mid-alley combed harness cleanly running between ky023 (X<=29.8) & keypads (X>=33.2):
    // X [30.2, 32.8], Y [7.0, 39.5], Z [5.0, 9.5] (+0.4 mm X clear on each side!)
    for i in 0..<2 {
        let wx = 30.8 + Double(i) * 1.25
        addBox(bus, "alley_wire_\(i)", wx - 0.45, wx + 0.45, 7.0, 39.5, 5.6, 8.8, matCopperWire, chamfer: 0.2)
    }
    addBox(bus, "alley_comb", 30.2, 32.8, 21.0, 23.6, 5.0, 9.5, matDarkCharcoal, chamfer: 0.25)

    parent.addChildNode(bus)

    aabbs.append(("combed_copper_spine", AABB(name: "upper_spine", minX: 4.0, maxX: 9.6, minY: 40.2, maxY: 84.5, minZ: 8.8, maxZ: 13.6)))
    aabbs.append(("combed_copper_alley", AABB(name: "mid_alley", minX: 30.2, maxX: 32.8, minY: 7.0, maxY: 39.5, minZ: 5.0, maxZ: 9.5)))
}

func buildESP32AndWM8960(parent: SCNNode, aabbs: inout [(String, AABB)]) {
    // 1) ESP32 Light-Mod (shifted +1.5mm in Z to Z [15.3, 19.0] for 19.0mm grip):
    let esp = SCNNode(); esp.name = "esp32_lightmod"
    addBox(esp, "esp_pcb", 5.4, 70.6, 53.5, 85.0, 15.3, 16.9, matPCBBlack, chamfer: 0.2)
    addBox(esp, "wroom_can", 55.0, 68.5, 59.5, 79.0, 16.9, 18.6, matSteel, chamfer: 0.2)
    addBox(esp, "esp_usbc", 4.6, 12.0, 64.7, 73.7, 15.9, 18.8, matSteel, chamfer: 0.35)
    addBox(esp, "ips_bezel", 18.5, 67.5, 56.5, 82.0, 16.9, 18.9, matScreenGlass, chamfer: 0.35)
    addBox(esp, "ips_active", 21.0, 63.7, 57.9, 80.6, 18.9, 19.05, matScreenUI)
    addBox(esp, "bent_crimp_top", 13.72, 62.2, 79.5, 84.0, 10.1, 15.3, matAmberKapton, chamfer: 0.2)
    addBox(esp, "bent_crimp_bot", 13.72, 62.2, 54.5, 59.0, 10.1, 15.3, matAmberKapton, chamfer: 0.2)
    for px in stride(from: 14.8, through: 60.8, by: 2.54) {
        addBox(esp, "hpad_\(Int(px))", px - 0.5, px + 0.5, 82.3, 84.1, 16.3, 17.0, matGold)
        addBox(esp, "bpad_\(Int(px))", px - 0.5, px + 0.5, 54.5, 56.3, 16.3, 17.0, matGold)
    }
    parent.addChildNode(esp)

    aabbs.append(("esp32", AABB(name: "pcb_display", minX: 5.4, maxX: 70.6, minY: 53.5, maxY: 85.0, minZ: 15.3, maxZ: 19.0)))
    aabbs.append(("esp32", AABB(name: "bent_crimps", minX: 13.72, maxX: 62.2, minY: 54.5, maxY: 84.0, minZ: 10.1, maxZ: 15.3)))

    // 2) WM8960 HAT (Top 22.2mm Audio Bay)
    let wm = SCNNode(); wm.name = "wm8960_hat"
    addBox(wm, "wm_pcb", 5.5, 70.5, 85.8, 115.8, 12.8, 14.4, matPCBBlack, chamfer: 0.2)
    addBox(wm, "wm_ic", 32.0, 39.0, 96.0, 103.0, 14.4, 15.6, matDarkCharcoal, chamfer: 0.1)
    addBox(wm, "trs_housing", 18.0, 29.0, 104.5, 117.5, 14.4, 20.4, matDarkCharcoal, chamfer: 0.3)
    addCyl(wm, "trs_ring", r: 3.1, h: 2.0, cx: 23.5, cy: 117.2, cz: 17.4, axis: "y", matGold)
    addBox(wm, "mems_L", 12.0, 16.0, 110.0, 113.5, 14.4, 15.8, matGold)
    addBox(wm, "mems_R", 59.0, 63.0, 110.0, 113.5, 14.4, 15.8, matGold)
    addBox(wm, "pi40_90deg", 13.0, 63.0, 86.0, 92.0, 9.4, 12.8, matWireInsul, chamfer: 0.25)
    for j in 0..<10 {
        let px = 15.0 + Double(j) * 4.8
        addBox(wm, "pi40_pin_\(j)", px - 0.5, px + 0.5, 87.0, 91.5, 11.4, 14.5, matGold)
    }
    parent.addChildNode(wm)

    aabbs.append(("wm8960", AABB(name: "pcb_trs", minX: 5.5, maxX: 70.5, minY: 85.8, maxY: 115.8, minZ: 12.8, maxZ: 20.4)))
    aabbs.append(("wm8960", AABB(name: "pi40_90deg", minX: 13.0, maxX: 63.0, minY: 86.0, maxY: 92.0, minZ: 9.4, maxZ: 12.8)))
}

func buildMicroSDAndChargerBoost(parent: SCNNode, aabbs: inout [(String, AABB)]) {
    let sd = SCNNode(); sd.name = "microsd_reader"
    addBox(sd, "sd_pcb", 1.8, 43.8, 92.3, 116.3, 2.8, 4.4, matPCBBlue, chamfer: 0.2)
    addBox(sd, "sd_cage", 6.0, 22.5, 100.0, 116.3, 4.4, 7.6, matSteel, chamfer: 0.15)
    addBox(sd, "sd_card", 8.5, 19.5, 114.5, 117.2, 4.9, 6.2, matDarkCharcoal)
    addBox(sd, "sd_ldo", 27.0, 34.0, 104.0, 111.0, 4.4, 6.4, matDarkCharcoal)
    addBox(sd, "sd_6p_exit", 43.8, 47.0, 94.0, 110.0, 3.2, 6.8, matCopperWire, chamfer: 0.2)
    parent.addChildNode(sd)

    aabbs.append(("microsd", AABB(name: "pcb_cage", minX: 1.8, maxX: 43.8, minY: 92.3, maxY: 116.3, minZ: 2.8, maxZ: 8.8)))
    aabbs.append(("microsd", AABB(name: "wire_exit", minX: 43.8, maxX: 47.0, minY: 94.0, maxY: 110.0, minZ: 3.2, maxZ: 6.8)))

    let chg = SCNNode(); chg.name = "usbc_lipo_boost"
    addBox(chg, "chg_pcb", 48.5, 69.5, 93.0, 111.0, 2.2, 3.8, matPCBBlack, chamfer: 0.15)
    addBox(chg, "chg_usbc", 54.5, 63.5, 108.5, 116.4, 3.8, 7.0, matSteel, chamfer: 0.3)
    addBox(chg, "chg_inductor", 51.0, 56.5, 96.0, 102.0, 3.8, 7.6, matDarkCharcoal, chamfer: 0.2)
    addBox(chg, "chg_ic", 59.5, 66.5, 97.0, 103.5, 3.8, 5.4, matDarkCharcoal)
    parent.addChildNode(chg)

    aabbs.append(("usbc_lipo_boost", AABB(name: "charger_boost", minX: 48.5, maxX: 69.5, minY: 93.0, maxY: 116.4, minZ: 2.2, maxZ: 8.0)))
}

func buildCornerBossesAndScrews(parent: SCNNode, aabbs: inout [(String, AABB)]) -> SCNNode {
    let inserts = SCNNode(); inserts.name = "m2_brass_inserts"
    let screws = SCNNode(); screws.name = "m2_black_screws"

    let bosses: [(String, Double, Double, Double, Double, Double, Double, Double, Double)] = [
        ("boss_bl",  1.6,  5.4,   1.6,   5.4,  1.6, 17.4,  3.5,   3.5),
        ("boss_br", 70.6, 74.4,   1.6,   5.4,  1.6, 17.4, 72.5,   3.5),
        ("boss_tl",  1.6,  5.2, 112.0, 116.4,  9.2, 20.6,  3.4, 114.2),
        ("boss_tr", 70.8, 74.4, 112.0, 116.4,  9.2, 20.6, 72.6, 114.2),
    ]

    for (name, x0, x1, y0, y1, z0, z1, cx, cy) in bosses {
        addCyl(inserts, "\(name)_brass", r: 1.50, h: 4.0, cx: cx, cy: cy, cz: z1 - 2.2, axis: "z", matBrassInsert)
        addCyl(screws, "\(name)_screw", r: 1.65, h: 1.4, cx: cx, cy: cy, cz: z1 + 0.8, axis: "z", matBlackScrew)
        addCyl(screws, "\(name)_shaft", r: 0.95, h: 5.0, cx: cx, cy: cy, cz: z1 - 1.5, axis: "z", matBlackScrew)
        aabbs.append((name, AABB(name: name, minX: x0, maxX: x1, minY: y0, maxY: y1, minZ: z0, maxZ: z1)))
    }
    parent.addChildNode(inserts)
    return screws
}

func buildTranslucentShellPiecesJoy8(colorway: ShellColorway, includeTopRow: Bool = true) -> (rear: SCNNode, front: SCNNode, bossSleeves: SCNNode) {
    let rear = SCNNode(); rear.name = "shell_rear_\(colorway.rawValue)"
    let front = SCNNode(); front.name = "shell_front_\(colorway.rawValue)"
    let bossSleeves = SCNNode(); bossSleeves.name = "shell_boss_sleeves"

    let m = colorway.bodyMat
    let e = colorway.edgeMat

    // Rear lower plate + perimeter walls (19.0 mm lower grip, 22.2 mm top audio bay)
    addBox(rear, "rear_back_plate", 0, 76.0, 0, 118.0, 0, 1.6, m, chamfer: 1.2, renderOrder: 10)
    addBox(rear, "wall_L_low", 0, 1.6, 0, 85.0, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_R_low", 74.4, 76.0, 0, 85.0, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_B", 0, 76.0, 0, 1.6, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)

    addBox(rear, "wall_L_hi", 0, 1.6, 85.0, 118.0, 1.6, 22.2, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_R_hi", 74.4, 76.0, 85.0, 118.0, 1.6, 22.2, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_T", 0, 76.0, 116.4, 118.0, 1.6, 22.2, e, chamfer: 0.6, renderOrder: 11)

    // Stepped top audio hump cover (Y [85.0, 118.0], Z [20.6, 22.2]) & step bridge
    addBox(front, "front_top_hump", 0, 76.0, 85.0, 118.0, 20.6, 22.2, m, chamfer: 0.9, renderOrder: 12)
    addBox(front, "front_step_riser", 0, 76.0, 83.8, 85.6, 17.5, 22.2, e, chamfer: 0.5, renderOrder: 12)

    // Screen frame around 1.9" IPS glass (Y [56.5, 85.0], Z [17.4, 19.0])
    addBox(front, "front_scr_left", 0, 21.0, 53.5, 85.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_scr_right", 63.7, 76.0, 53.5, 85.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_scr_top", 21.0, 63.7, 80.6, 85.0, 17.4, 19.0, e, renderOrder: 12)
    addBox(front, "front_scr_bot", 21.0, 63.7, 53.5, 57.9, 17.4, 19.0, e, renderOrder: 12)

    // Panoramic LiPo Showcase Window (Y [39.0, 53.5], Z [17.4, 19.0])
    addBox(front, "front_lipo_window", 0, 76.0, 39.0, 53.5, 17.4, 19.0, m, chamfer: 0.2, renderOrder: 13)

    // Controls lower faceplate framing Joystick Crater Well (X [1.6..30.0]) & Tight Keypad Grid (X [33.2..70.2])
    addBox(front, "front_ctrl_farL", 0, 6.0, 0, 39.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_ctrl_joy_top", 6.0, 27.6, 31.6, 39.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_ctrl_joy_bot", 6.0, 27.6, 0, 10.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    // Chamfered thumb-disc well ring around cx=16.8, cy=20.8
    addTorusRing(front, "joy_well_ring", ringR: 10.6, pipeR: 0.85, cx: 16.8, cy: 20.8, cz: 18.6, e, renderOrder: 13)
    addBox(front, "front_ctrl_alley", 27.6, 34.0, 0, 39.0, 17.4, 19.0, e, renderOrder: 12)
    addBox(front, "front_ctrl_farR", 69.8, 76.0, 0, 39.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)

    if includeTopRow {
        // Slim 2x4 button bezel dividers: bot caps Y[13.65..19.85], top caps Y[24.75..30.95] -> clean 4.9mm divider bridge!
        addBox(front, "front_pad_bot_strip", 34.0, 69.8, 0, 13.4, 17.4, 19.0, m, renderOrder: 12)
        addBox(front, "front_pad_mid_bridge", 34.0, 69.8, 20.1, 24.5, 17.4, 19.0, e, renderOrder: 12)
        addBox(front, "front_pad_top_strip", 34.0, 69.8, 31.2, 39.0, 17.4, 19.0, m, renderOrder: 12)
    } else {
        addBox(front, "front_pad_bot_strip", 34.0, 69.8, 0, 17.4, 17.4, 19.0, m, renderOrder: 12)
        addBox(front, "front_pad_top_strip", 34.0, 69.8, 24.1, 39.0, 17.4, 19.0, m, renderOrder: 12)
    }

    let posts: [(Double, Double, Double, Double)] = [
        (3.5, 3.5, 1.6, 17.4), (72.5, 3.5, 1.6, 17.4),
        (3.4, 114.2, 9.2, 20.6), (72.6, 114.2, 9.2, 20.6)
    ]
    for (i, (cx, cy, z0, z1)) in posts.enumerated() {
        addCyl(bossSleeves, "boss_post_\(i)", r: 1.9, h: z1 - z0, cx: cx, cy: cy, cz: (z0 + z1) * 0.5, axis: "z", e, renderOrder: 9)
    }
    return (rear, front, bossSleeves)
}

func buildFullOptionP3Joy8(colorway: ShellColorway, orangePuck: Bool = false, includeTopRow: Bool = true, exploded: Bool = false) -> (root: SCNNode, aabbs: [(String, AABB)]) {
    let variant = includeTopRow ? "Option_P3_Joy8" : "Option_P2_Joy4"
    let root = SCNNode(); root.name = "\(variant)_\(colorway.rawValue)"
    var aabbs: [(String, AABB)] = []

    let layerRear = SCNNode(); layerRear.name = "Layer1_Rear"
    let layerLiPo = SCNNode(); layerLiPo.name = "Layer2_LiPo"
    let layerCtrl = SCNNode(); layerCtrl.name = "Layer3_Joy_And_TwinPCBs"
    let layerMain = SCNNode(); layerMain.name = "Layer4_ESP32_WM8960"
    let layerTop  = SCNNode(); layerTop.name  = "Layer5_TopBezel"
    let layerCaps = SCNNode(); layerCaps.name = "Layer5b_Puck_Keys_Screws"

    buildKY023PlayfulLowProfile(parent: layerCtrl, capsLayer: layerCaps, orangePuck: orangePuck, aabbs: &aabbs)
    buildTightDualKeypads180Flip(ctrlLayer: layerCtrl, capsLayer: layerCaps, includeTopRow: includeTopRow, aabbs: &aabbs)
    buildCombedCopperHarnesses(parent: layerCtrl, aabbs: &aabbs)

    buildLiPoAndShield(parent: layerLiPo, aabbs: &aabbs)
    buildESP32AndWM8960(parent: layerMain, aabbs: &aabbs)
    buildMicroSDAndChargerBoost(parent: layerRear, aabbs: &aabbs)

    let screwsNode = buildCornerBossesAndScrews(parent: layerRear, aabbs: &aabbs)
    layerCaps.addChildNode(screwsNode)

    let (rearShell, frontShell, bossSleeves) = buildTranslucentShellPiecesJoy8(colorway: colorway, includeTopRow: includeTopRow)
    layerRear.addChildNode(rearShell)
    layerRear.addChildNode(bossSleeves)
    layerTop.addChildNode(frontShell)

    if exploded {
        layerRear.position = SCNVector3(0, 0, 0)
        layerLiPo.position = SCNVector3(0, 32, 0)
        layerCtrl.position = SCNVector3(0, 62, 0)
        layerMain.position = SCNVector3(0, 92, 0)
        layerTop.position  = SCNVector3(0, 120, 0)
        layerCaps.position = SCNVector3(0, 140, 0)

        let guides = SCNNode(); guides.name = "ExplodeGuides"
        for (i, (gx, gy)) in [(3.5, 3.5), (72.5, 3.5), (3.4, 114.2), (72.6, 114.2)].enumerated() {
            addCyl(guides, "g_\(i)", r: 0.35, h: 162.0, cx: gx, cy: gy, cz: 81.0, axis: "z", matCyanGuide)
        }
        root.addChildNode(guides)
    }

    root.addChildNode(layerRear)
    root.addChildNode(layerLiPo)
    root.addChildNode(layerCtrl)
    root.addChildNode(layerMain)
    root.addChildNode(layerTop)
    root.addChildNode(layerCaps)
    return (root, aabbs)
}

// MARK: - Lighting, Rendering & USDZ Export Helpers
func setupStudioLighting(_ scene: SCNScene, camPos: SCNVector3, lookAt: SCNVector3, fov: CGFloat = 35) {
    scene.background.contents = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 1.0)
    let cam = SCNCamera()
    cam.fieldOfView = fov
    cam.zNear = 1.0
    cam.zFar = 3000.0
    let camNode = SCNNode()
    camNode.name = "StudioCamera"
    camNode.camera = cam
    camNode.position = camPos
    camNode.look(at: lookAt)
    scene.rootNode.addChildNode(camNode)

    let amb = SCNNode(); amb.light = SCNLight(); amb.light?.type = .ambient; amb.light?.intensity = 390
    amb.light?.color = NSColor(calibratedRed: 0.90, green: 0.94, blue: 1.0, alpha: 1)
    scene.rootNode.addChildNode(amb)

    let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 1380
    key.light?.color = NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.95, alpha: 1)
    key.position = SCNVector3(180, 320, 240); key.look(at: lookAt)
    scene.rootNode.addChildNode(key)

    let rim = SCNNode(); rim.light = SCNLight(); rim.light?.type = .directional; rim.light?.intensity = 860
    rim.light?.color = NSColor(calibratedRed: 0.65, green: 0.85, blue: 1.0, alpha: 1)
    rim.position = SCNVector3(-240, 220, -260); rim.look(at: lookAt)
    scene.rootNode.addChildNode(rim)

    let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .omni; fill.light?.intensity = 420
    fill.position = SCNVector3(lookAt.x, 220, lookAt.z + 180)
    scene.rootNode.addChildNode(fill)
}

func renderSceneToImage(_ scene: SCNScene, width: Int = 1920, height: Int = 1080) -> NSImage {
    let device = MTLCreateSystemDefaultDevice()!
    let renderer = SCNRenderer(device: device, options: nil)
    renderer.scene = scene
    renderer.pointOfView = scene.rootNode.childNode(withName: "StudioCamera", recursively: true)
    return renderer.snapshot(atTime: 0, with: CGSize(width: width, height: height), antialiasingMode: .multisampling4X)
}

func savePNG(_ image: NSImage, path1: String, path2: String) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "PNGExport", code: 1)
    }
    try data.write(to: URL(fileURLWithPath: path1))
    try data.write(to: URL(fileURLWithPath: path2))
}

func exportUSDZ(_ root: SCNNode, fileName: String) throws {
    let scene = SCNScene()
    let scaled = root.clone()
    scaled.scale = SCNVector3(0.001, 0.001, 0.001)
    scene.rootNode.addChildNode(scaled)
    let outPath = "\(usdzDir)/\(fileName)"
    let ok = scene.write(to: URL(fileURLWithPath: outPath), options: nil, delegate: nil, progressHandler: nil)
    if !ok {
        throw NSError(domain: "USDZExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to write \(outPath)"])
    }
    print("EXPORTED USDZ: \(outPath)")
}

// MARK: - 1:1 Calibration Props
func buildMetricRuler(width: Double = 160.0) -> SCNNode {
    let r = SCNNode(); r.name = "MetricRuler_160mm"
    let img = drawImage(width: 1200, height: 180) { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.78, green: 0.80, blue: 0.83, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 180))
        ctx.setStrokeColor(NSColor.black.cgColor)
        let pxPerMm = 1200.0 / width
        for mm in 0...Int(width) {
            let x = CGFloat(Double(mm) * pxPerMm)
            let h: CGFloat = (mm % 10 == 0) ? 58 : ((mm % 5 == 0) ? 40 : 24)
            ctx.setLineWidth(mm % 10 == 0 ? 3.0 : 1.5)
            ctx.move(to: CGPoint(x: x, y: 180)); ctx.addLine(to: CGPoint(x: x, y: 180 - h))
            if mm % 20 == 0 && mm < 160 {
                let a: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 28, weight: .bold), .foregroundColor: NSColor.black]
                NSAttributedString(string: "\(mm)", attributes: a).draw(at: NSPoint(x: max(2, x + 4), y: 84))
            }
        }
        ctx.strokePath()
        let lab: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 26, weight: .bold), .foregroundColor: NSColor.darkGray]
        NSAttributedString(string: "160 mm CALIBRATION STEEL RULE (1:1)", attributes: lab).draw(at: NSPoint(x: 24, y: 24))
    }
    addBox(r, "ruler_body", 0, width, 0, 18.0, 0, 1.0, texMat(img, roughness: 0.28, metalness: 0.85), chamfer: 0.2)
    return r
}

func buildAirPodsProCase() -> SCNNode {
    let ap = SCNNode(); ap.name = "AirPodsProCase_21p7mm"
    let whiteGloss = pbrMat(0.95, 0.96, 0.98, 1.0, roughness: 0.14, metalness: 0.04)
    addBox(ap, "ap_case", 0, 60.6, 0, 45.2, 0, 21.7, whiteGloss, chamfer: 6.5)
    addBox(ap, "ap_seam", 0.2, 60.4, 29.0, 29.5, 0.2, 21.5, matDarkCharcoal)
    addCyl(ap, "ap_led", r: 1.0, h: 0.4, cx: 30.3, cy: 23.0, cz: 21.7, axis: "z", matPCBGreen)
    return ap
}

func buildISOCreditCard() -> SCNNode {
    let cc = SCNNode(); cc.name = "ISOCreditCard_85p6x54mm"
    let cardTex = drawImage(width: 680, height: 430) { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.13, green: 0.18, blue: 0.27, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 680, height: 430))
        ctx.setFillColor(NSColor(calibratedRed: 0.85, green: 0.68, blue: 0.28, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 72, y: 185, width: 88, height: 68))
        let a: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 28, weight: .bold), .foregroundColor: NSColor.white]
        NSAttributedString(string: "ISO/IEC 7810 ID-1", attributes: a).draw(at: NSPoint(x: 42, y: 82))
        NSAttributedString(string: "85.6 × 54.0 × 0.8 mm", attributes: a).draw(at: NSPoint(x: 42, y: 42))
    }
    addBox(cc, "cc_body", 0, 85.6, 0, 54.0, 0, 0.8, texMat(cardTex, roughness: 0.22, metalness: 0.15), chamfer: 1.8)
    return cc
}

func buildPhoneProxy() -> SCNNode {
    let p = SCNNode(); p.name = "Smartphone_8p25mm"
    addBox(p, "ph_body", 0, 71.5, 0, 147.6, 0, 8.25, matDarkCharcoal, chamfer: 2.2)
    addBox(p, "ph_screen", 2.0, 69.5, 2.0, 145.6, 8.1, 8.35, matScreenGlass, chamfer: 1.5)
    return p
}

func buildAudioPlug35mm() -> SCNNode {
    let plug = SCNNode(); plug.name = "TRS_3p5mm_Plug"
    addCyl(plug, "plug_barrel", r: 4.5, h: 18.0, cx: 0, cy: 9.0, cz: 4.5, axis: "y", matDarkCharcoal)
    addCyl(plug, "plug_tip", r: 1.75, h: 14.0, cx: 0, cy: -7.0, cz: 4.5, axis: "y", matGold)
    addCyl(plug, "plug_cord", r: 1.8, h: 42.0, cx: 0, cy: 39.0, cz: 4.5, axis: "y", matCopperWire)
    return plug
}

// MARK: - Build, Verify Zero Collisions & Export 3 USDZs
let (joy8Root, joy8Boxes) = buildFullOptionP3Joy8(colorway: .atomicSmoke, orangePuck: false, includeTopRow: true, exploded: false)
let cJoy8 = verifyAABBs(label: "Option_P3_Joy8_19mm", boxes: joy8Boxes)

let (joy4Root, joy4Boxes) = buildFullOptionP3Joy8(colorway: .atomicSmoke, orangePuck: false, includeTopRow: false, exploded: false)
let cJoy4 = verifyAABBs(label: "Option_P2_Joy4_19mm", boxes: joy4Boxes)

let totalCollisions = cJoy8 + cJoy4
if totalCollisions > 0 {
    fputs("FATAL: Non-zero CAD collisions detected (Joy8=\(cJoy8), Joy4=\(cJoy4))\n", stderr)
    exit(2)
}

try exportUSDZ(joy8Root, fileName: "13a_p3_joy8_atomic_smoke_19mm.usdz")
let (joy8Exploded, _) = buildFullOptionP3Joy8(colorway: .atomicSmoke, orangePuck: false, includeTopRow: true, exploded: true)
try exportUSDZ(joy8Exploded, fileName: "13b_p3_joy8_atomic_smoke_exploded.usdz")

let cmpSceneNode = SCNNode(); cmpSceneNode.name = "Joy8_vs_Joy4_Comparison"
let cmpLeft = buildFullOptionP3Joy8(colorway: .atomicSmoke, orangePuck: false, includeTopRow: true).root
let cmpRight = joy4Root.clone(); cmpRight.position = SCNVector3(96, 0, 0)
cmpSceneNode.addChildNode(cmpLeft); cmpSceneNode.addChildNode(cmpRight)
try exportUSDZ(cmpSceneNode, fileName: "13c_joy8_vs_joy4_pocket_comparison.usdz")

// MARK: - Render Guide 13a: Option P3-Joy8 3 Colorways + Calibration Props
do {
    let s = SCNScene()
    let matW = 470.0, matH = 270.0
    let matTex = makeCuttingMatTexture(widthMm: matW, heightMm: matH, label: "10 mm METRIC GRID  |  OPTION P3-JOY8 (LOW-PRO STICK + TIGHT 2×4 KEYPADS, 76×118×19.0 / 22.2 mm)")
    addBox(s.rootNode, "cutting_mat", -105, matW - 105, -75, matH - 75, -2.0, 0.0, texMat(matTex, roughness: 0.85, metalness: 0.02))

    let a1 = buildFullOptionP3Joy8(colorway: .atomicSmoke, orangePuck: false).root; a1.position = SCNVector3(0, 0, 0)
    let a2 = buildFullOptionP3Joy8(colorway: .frostedClearIce, orangePuck: true).root; a2.position = SCNVector3(102, 0, 0)
    let a3 = buildFullOptionP3Joy8(colorway: .atomicPurple, orangePuck: false).root; a3.position = SCNVector3(204, 0, 0)
    s.rootNode.addChildNode(a1); s.rootNode.addChildNode(a2); s.rootNode.addChildNode(a3)

    let card = buildISOCreditCard(); card.position = SCNVector3(-96, 0, 12)
    let ruler = buildMetricRuler(); ruler.position = SCNVector3(60, 0, 38)
    let ap = buildAirPodsProCase(); ap.position = SCNVector3(294, 0, 8)
    let plug = buildAudioPlug35mm(); plug.position = SCNVector3(-56, 0, -90)
    s.rootNode.addChildNode(card); s.rootNode.addChildNode(ruler); s.rootNode.addChildNode(ap); s.rootNode.addChildNode(plug)

    setupStudioLighting(s, camPos: SCNVector3(135, 380, 215), lookAt: SCNVector3(135, 14, -44), fov: 36)
    let raw = renderSceneToImage(s)
    let final13a = overlayHeaderOnImage(
        raw,
        title: "REF 13A • OPTION P3-JOY8 TRANSLUCENT COLORWAYS — STICK + TIGHT 2×4 (1:1 METAL CAD)",
        subtitle: "Left: Atomic Smoke  |  Center: Frosted Clear Ice (Orange Disc)  |  Right: 90s Atomic Purple   (76 × 118 × 19.0 mm grip, 21.0 mm puck)",
        footer: "180° Flipped Twin 1×4 PCBs (4.9 mm row gap / 11.1 mm pitch)  •  Ø15.5 mm Concave Thumb-Disc  •  Beats AirPods Pro 2 (21.7 mm) thickness"
    )
    try savePNG(final13a, path1: "\(renderDir)/ref_13a_joy8_playful_showcase_guide.png",
                path2: "\(artifactDir)/ref_13a_joy8_playful_showcase_guide.png")
    print("RENDERED 13a guide")
}

// MARK: - Render Guide 13b: 5-Layer Isometric Exploded Assembly of Option P3-Joy8
do {
    let s = SCNScene()
    let matW = 360.0, matH = 280.0
    let matTex = makeCuttingMatTexture(widthMm: matW, heightMm: matH, label: "P3-JOY8 5-LAYER EXPLODED STACK  |  180° FLIPPED TWIN 1×4 PCBs + LOW-PRO KY-023  |  COLLISIONS: \(cJoy8)")
    addBox(s.rootNode, "cutting_mat", -130, matW - 130, -90, matH - 90, -2.0, 0.0, texMat(matTex, roughness: 0.85, metalness: 0.02))

    let (ex, _) = buildFullOptionP3Joy8(colorway: .atomicSmoke, orangePuck: false, includeTopRow: true, exploded: true)
    s.rootNode.addChildNode(ex)

    setupStudioLighting(s, camPos: SCNVector3(248, 260, 198), lookAt: SCNVector3(38, 76, -59), fov: 38)
    let raw = renderSceneToImage(s)
    let final13b = overlayHeaderOnImage(
        raw,
        title: "REF 13B • OPTION P3-JOY8 5-LAYER EXPLODED ASSEMBLY (1:1 METAL CAD)",
        subtitle: "L1: Rear+M2 Brass+SD+Boost  →  L2: LiPo+Shield  →  L3: Low-Pro KY-023 + 180° Back-to-Back 1×4 PCBs + Copper Spine  →  L4: ESP32+WM8960  →  L5/5b: Bezel+Disc+8 Keys",
        footer: "Verified Collisions: \(cJoy8) across \(joy8Boxes.count) box groups  •  Pad_Bot rotated 180° (crimps exit down, switches touch back-to-back)"
    )
    try savePNG(final13b, path1: "\(renderDir)/ref_13b_joy8_exploded_cutaway_guide.png",
                path2: "\(artifactDir)/ref_13b_joy8_exploded_cutaway_guide.png")
    print("RENDERED 13b guide")
}

// MARK: - Render Guide 13c: One-Handed Joystick+Buttons Reach & Jeans Pocket Fit
do {
    let s = SCNScene()
    let matW = 420.0, matH = 270.0
    let matTex = makeCuttingMatTexture(widthMm: matW, heightMm: matH, label: "1:1 ERGONOMICS & POCKET FIT  |  P3-JOY8 (19.0 mm grip / 21.0 mm disc) vs AIRPODS (21.7 mm)")
    addBox(s.rootNode, "cutting_mat", -75, matW - 75, -60, matH - 60, -2.0, 0.0, texMat(matTex, roughness: 0.85, metalness: 0.02))

    let devL = buildFullOptionP3Joy8(colorway: .atomicSmoke, orangePuck: false).root; devL.position = SCNVector3(0, 0, 0)
    s.rootNode.addChildNode(devL)
    let plugIn = buildAudioPlug35mm(); plugIn.position = SCNVector3(23.5, 13.0, -131.5)
    s.rootNode.addChildNode(plugIn)

    let palmGhost = pbrMat(0.28, 0.72, 0.88, 0.20, roughness: 0.6, metalness: 0.0, depthWrite: false)
    addBox(s.rootNode, "palm_width_85mm", -6, 79, -16, 92, 0.2, 1.4, palmGhost, chamfer: 8.0, renderOrder: 1)
    let thumbHalo = pbrMat(0.28, 0.82, 0.94, 0.14, roughness: 0.4, metalness: 0.0, depthWrite: false)
    // Centered right between concave thumb-disc (X=16.8) and tight 2x4 button block (X=38..65)
    addCyl(s.rootNode, "thumb_sweep_zone", r: 34.0, h: 0.6, cx: 42.0, cy: 22.0, cz: 21.6, axis: "z", thumbHalo, renderOrder: 20)

    let denimProxy = pbrMat(0.14, 0.22, 0.36, 0.88, roughness: 0.88, metalness: 0.02)
    addBox(s.rootNode, "jeans_pocket_145x165", 132, 277, -10, 155, 0.0, 2.5, denimProxy, chamfer: 2.0)
    let devPocket = buildFullOptionP3Joy8(colorway: .atomicSmoke, orangePuck: false).root; devPocket.position = SCNVector3(148, 3.0, 0)
    let apSide = buildAirPodsProCase(); apSide.position = SCNVector3(244, 3.0, 22)
    let phoneRef = buildPhoneProxy(); phoneRef.position = SCNVector3(244, 3.0, -32)
    s.rootNode.addChildNode(devPocket); s.rootNode.addChildNode(apSide); s.rootNode.addChildNode(phoneRef)

    setupStudioLighting(s, camPos: SCNVector3(142, 390, 225), lookAt: SCNVector3(142, 12, -52), fov: 38)
    let raw = renderSceneToImage(s)
    let final13c = overlayHeaderOnImage(
        raw,
        title: "REF 13C • P3-JOY8 ONE-HANDED THUMB REACH & SNAG-FREE POCKET FIT (1:1 CAD)",
        subtitle: "Left: Concave Thumb-Disc + Tight 2×4 Grid inside single-thumb sweep  |  Right: 145 mm Front Pocket vs AirPods Pro 2 (21.7 mm)",
        footer: "Snag-Free Ø15.5 mm Recessed Pocket Disc (21.0 mm peak) < AirPods Pro (21.7 mm)  •  178.4 cm³ Volume  •  Verified Collisions: \(cJoy8)"
    )
    try savePNG(final13c, path1: "\(renderDir)/ref_13c_joy8_hand_pocket_ergo_guide.png",
                path2: "\(artifactDir)/ref_13c_joy8_hand_pocket_ergo_guide.png")
    print("RENDERED 13c guide")
}

print("ALL_13_JOY8_SHOWCASE_DONE joy8_collisions=\(cJoy8) joy4_collisions=\(cJoy4)")
