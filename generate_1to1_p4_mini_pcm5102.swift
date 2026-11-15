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
        NSAttributedString(string: "Audiobookshelf • PCM5102 I2S", attributes: statusAttr).draw(at: NSPoint(x: 20, y: 304))
        NSAttributedString(string: "PROJECT HAIL MARY", attributes: titleAttr).draw(at: NSPoint(x: 224, y: 216))
        NSAttributedString(string: "Andy Weir  •  Scrub: +1.8×", attributes: subAttr).draw(at: NSPoint(x: 224, y: 174))
        NSAttributedString(string: "14:22 / 10:53:10   24-bit INMP441", attributes: subAttr).draw(at: NSPoint(x: 224, y: 112))
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

        for r in stride(from: 24, through: 104, by: 16) {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(orangePuck ? 0.28 : 0.20).cgColor)
            ctx.setLineWidth(2.5)
            ctx.strokeEllipse(in: CGRect(x: 120 - r, y: 120 - r, width: r * 2, height: r * 2))
        }
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
let matPCBPurple = pbrMat(0.36, 0.12, 0.54, 1.0, roughness: 0.34, metalness: 0.14)
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

// MARK: - Shared Lower & Mid Subsystems
func buildKY023PlayfulLowProfile(parent: SCNNode, capsLayer: SCNNode, orangePuck: Bool, aabbs: inout [(String, AABB)]) {
    let ky = SCNNode(); ky.name = "ky023_lowprofile"
    let o = (29.8, 5.8, 2.8)
    cadPlace(ky, ox: o.0, oy: o.1, oz: o.2, rotZDeg: 90)

    addBox(ky, "ky_pcb", 0, 34.0, 0, 26.0, 0, 1.6, matPCBBlack, chamfer: 0.2)
    addBox(ky, "ky_tails", 2.0, 32.0, 2.0, 24.0, -0.9, 0.0, matSteel)
    addBox(ky, "ky_gimbal", 7.0, 23.0, 5.0, 21.0, 1.6, 14.5, matSteel, chamfer: 0.3)
    addBox(ky, "ky_pot_x", 11.0, 19.0, 2.0, 5.0, 3.0, 13.0, matPCBGreen, chamfer: 0.15)
    addBox(ky, "ky_pot_y", 23.0, 26.0, 9.0, 17.0, 3.0, 13.0, matPCBBlue, chamfer: 0.15)
    addCyl(ky, "ky_stub_post", r: 2.1, h: 2.2, cx: 15.0, cy: 13.0, cz: 15.4, axis: "z", matDarkCharcoal)
    addBox(ky, "ky_5p_crimps", 34.0, 39.4, 6.35, 19.65, 6.0, 10.2, matCopperWire, chamfer: 0.2)
    for j in 0..<5 {
        let py = 7.9 + Double(j) * 2.54
        addBox(ky, "ky_pin_\(j)", 31.0, 38.8, py - 0.35, py + 0.35, 1.6, 10.0, matGold)
    }
    parent.addChildNode(ky)

    let puckNode = SCNNode(); puckNode.name = "pocket_thumb_disc"
    let puckTex = texMat(makeThumbDiscTexture(orangePuck: orangePuck), roughness: 0.42, metalness: 0.05)
    let rimMat = orangePuck ? matOrangeKey : matDarkCharcoal
    addCyl(puckNode, "disc_body", r: 7.75, h: 1.9, cx: 16.8, cy: 20.8, cz: 19.55, axis: "z", puckTex)
    addTorusRing(puckNode, "disc_concave_rim", ringR: 7.15, pipeR: 0.65, cx: 16.8, cy: 20.8, cz: 20.35, rimMat)
    capsLayer.addChildNode(puckNode)

    aabbs.append(("ky023", makeAABB(origin: o, rotZDeg: 90, name: "pcb_tails", 0, 34.0, 0, 26.0, -0.9, 1.6)))
    aabbs.append(("ky023", makeAABB(origin: o, rotZDeg: 90, name: "gimbal", 7.0, 23.0, 5.0, 21.0, 1.6, 14.5)))
    aabbs.append(("ky023", makeAABB(origin: o, rotZDeg: 90, name: "5p_crimps", 34.0, 39.4, 6.35, 19.65, 6.0, 10.2)))
}

func buildTightDualKeypads180Flip(ctrlLayer: SCNNode, capsLayer: SCNNode, aabbs: inout [(String, AABB)]) {
    let botOrigin = (70.2, 22.0, 5.8)
    let padBot = SCNNode(); padBot.name = "pad_bot"
    cadPlace(padBot, ox: botOrigin.0, oy: botOrigin.1, oz: botOrigin.2, rotZDeg: 180)

    addBox(padBot, "bot_pcb", 0, 37.0, 0, 15.0, 0, 1.6, matPCBGreen, chamfer: 0.15)
    addBox(padBot, "bot_tails", 3.0, 34.0, 1.5, 13.0, -0.8, 0.0, matSteel)
    for hx in [2.5, 34.5] {
        for hy in [2.5, 12.5] {
            addCyl(padBot, "bot_pad", r: 1.35, h: 1.68, cx: hx, cy: hy, cz: 0.8, axis: "z", matGold)
        }
    }
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

    aabbs.append(("pad_bot", makeAABB(origin: botOrigin, rotZDeg: 180, name: "pcb_tails", 0, 37.0, 0, 15.0, -0.8, 1.6)))
    aabbs.append(("pad_bot", makeAABB(origin: botOrigin, rotZDeg: 180, name: "switches", 1.0, 36.0, 2.0, 8.5, 1.6, 11.2)))
    aabbs.append(("pad_bot", makeAABB(origin: botOrigin, rotZDeg: 180, name: "5p_crimps", 12.15, 24.85, 15.0, 20.0, 1.6, 5.4)))

    // World coordinates so BACK/PLAY/MARK/REC read UPRIGHT left-to-right!
    let botLabels = ["BACK", "PLAY", "MARK", "REC"]
    for i in 0..<4 {
        let wx = 38.0 + Double(i) * 9.2
        let isOrange = (i == 3)
        let bg = isOrange ? NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.09, alpha: 1) : NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.20, alpha: 1)
        let cMat = texMat(makeKeycapTexture(botLabels[i], bg: bg), roughness: 0.38)
        addBox(capsLayer, "cap_bot_\(i)", wx - 3.6, wx + 3.6, 13.65, 19.85, 17.0, 20.1, cMat, chamfer: 0.45)
    }

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
        addBox(capsLayer, "cap_top_\(i)", wx - 3.6, wx + 3.6, 24.75, 30.95, 17.0, 20.1, cMat, chamfer: 0.45)
    }
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

func buildLiPoAndShield(parent: SCNNode, aabbs: inout [(String, AABB)]) {
    let lipo = SCNNode(); lipo.name = "lipo_604060"
    addBox(lipo, "lipo_pouch", 15.5, 68.0, 40.2, 80.2, 1.9, 7.7, matSilverPouch, chamfer: 0.8)
    addBox(lipo, "lipo_pcm_kapton", 8.0, 16.0, 40.7, 79.7, 2.1, 7.5, matAmberKapton, chamfer: 0.4)
    addBox(lipo, "lipo_pcm_pcb", 9.0, 13.0, 44.5, 75.5, 3.0, 6.2, matPCBGreen)
    addBox(lipo, "lipo_kapton_edge", 14.5, 67.8, 40.2, 42.9, 2.0, 7.75, matAmberKapton, chamfer: 0.2)
    addCyl(lipo, "lipo_red_lead", r: 0.70, h: 35.0, cx: 10.0, cy: 64.5, cz: 7.4, axis: "y", matRedWire)
    addCyl(lipo, "lipo_blk_lead", r: 0.70, h: 35.0, cx: 12.0, cy: 64.5, cz: 7.4, axis: "y", matDarkCharcoal)
    parent.addChildNode(lipo)

    let shield = SCNNode(); shield.name = "lipo_shield_rib"
    addBox(shield, "shield_plate", 7.8, 68.2, 40.0, 80.5, 7.8, 8.5, matShieldRib, chamfer: 0.15, renderOrder: 4)
    for ry in [45.0, 57.0, 69.0, 77.0] {
        addBox(shield, "rib_\(Int(ry))", 14.0, 67.5, ry, ry + 1.0, 8.2, 8.5, matEdgeTrim, renderOrder: 5)
    }
    parent.addChildNode(shield)

    aabbs.append(("lipo", AABB(name: "pouch_pcm", minX: 8.0, maxX: 68.0, minY: 40.2, maxY: 80.2, minZ: 1.9, maxZ: 7.7)))
    aabbs.append(("lipo_shield_rib", AABB(name: "rib", minX: 7.8, maxX: 68.2, minY: 40.0, maxY: 80.5, minZ: 7.8, maxZ: 8.5)))
}

func buildCombedCopperHarnesses(parent: SCNNode, minSpineZ: Double = 9.0, aabbs: inout [(String, AABB)]) {
    let bus = SCNNode(); bus.name = "combed_copper_spine"

    for i in 0..<4 {
        let wx = 4.7 + Double(i) * 1.35
        addBox(bus, "up_wire_\(i)", wx - 0.50, wx + 0.50, 40.2, 84.5, minSpineZ + 0.4, 13.1, matCopperWire, chamfer: 0.25)
    }
    addBox(bus, "up_comb_1", 4.0, 9.6, 51.0, 53.8, minSpineZ, 13.6, matDarkCharcoal, chamfer: 0.3)
    addBox(bus, "up_comb_2", 4.0, 9.6, 78.5, 81.3, minSpineZ, 13.6, matDarkCharcoal, chamfer: 0.3)

    for i in 0..<2 {
        let wx = 30.8 + Double(i) * 1.25
        addBox(bus, "alley_wire_\(i)", wx - 0.45, wx + 0.45, 7.0, 39.5, 5.6, 8.8, matCopperWire, chamfer: 0.2)
    }
    addBox(bus, "alley_comb", 30.2, 32.8, 21.0, 23.6, 5.0, 9.5, matDarkCharcoal, chamfer: 0.25)

    parent.addChildNode(bus)

    aabbs.append(("combed_copper_spine", AABB(name: "upper_spine", minX: 4.0, maxX: 9.6, minY: 40.2, maxY: 84.5, minZ: minSpineZ, maxZ: 13.6)))
    aabbs.append(("combed_copper_alley", AABB(name: "mid_alley", minX: 30.2, maxX: 32.8, minY: 7.0, maxY: 39.5, minZ: 5.0, maxZ: 9.5)))
}

func buildESP32LightMod(parent: SCNNode, aabbs: inout [(String, AABB)]) {
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
}

// MARK: - Option P4-Mini Way 2 Audio Bay (76.0 x 106.5 x 19.0 mm Flat Uniform Slab)
func buildPCM5102AndINMP441(parent: SCNNode, aabbs: inout [(String, AABB)]) {
    // 1) GY-PCM5102 Stereo I2S DAC (Purple PCB: 32.0 x 17.0 mm + 3.5 mm TRS Jack)
    let dac = SCNNode(); dac.name = "gy_pcm5102_dac"
    addBox(dac, "pcm_pcb", 8.0, 40.0, 87.5, 104.5, 10.4, 12.0, matPCBPurple, chamfer: 0.2)
    addBox(dac, "pcm_pads", 10.0, 38.0, 88.5, 103.5, 9.8, 10.4, matSteel)
    addBox(dac, "pcm5102a_ic", 22.0, 29.0, 92.5, 99.0, 12.0, 13.1, matDarkCharcoal, chamfer: 0.1)
    // SMD decoupling caps + oscillator/LDO detail
    addBox(dac, "pcm_ldo", 31.0, 35.0, 94.0, 98.0, 12.0, 13.3, matDarkCharcoal, chamfer: 0.1)
    addBox(dac, "pcm_cap_1", 31.5, 34.0, 89.5, 92.0, 12.0, 13.0, matGold)
    addBox(dac, "pcm_cap_2", 35.5, 38.0, 89.5, 92.0, 12.0, 13.0, matGold)
    // Backside solder jumper indicators + trimmed bottom edge gold header pads (VIN/GND/LCK/DIN/BCK/SCK)
    for j in 0..<6 {
        let px = 12.5 + Double(j) * 2.54
        addBox(dac, "pcm_pin_\(j)", px - 0.5, px + 0.5, 87.6, 89.4, 10.2, 12.4, matGold)
    }
    // 5-wire I2S + 5V/GND copper-amber harness connecting ESP32 to GY-PCM5102
    addBox(dac, "pcm_i2s_wires", 12.0, 27.0, 85.4, 87.5, 10.2, 13.4, matCopperWire, chamfer: 0.25)
    // Onboard 3.5 mm stereo jack housing + flush gold barrel exiting top edge
    addBox(dac, "trs_35_housing", 11.0, 22.0, 93.5, 104.9, 12.0, 17.0, matDarkCharcoal, chamfer: 0.3)
    addCyl(dac, "trs_35_ring", r: 3.0, h: 1.8, cx: 16.5, cy: 105.7, cz: 14.5, axis: "y", matGold)
    addCyl(dac, "trs_35_bore", r: 1.75, h: 2.0, cx: 16.5, cy: 105.8, cz: 14.5, axis: "y", matDarkCharcoal)
    parent.addChildNode(dac)

    aabbs.append(("pcm5102", AABB(name: "pcb_jack", minX: 8.0, maxX: 40.0, minY: 87.5, maxY: 104.9, minZ: 9.8, maxZ: 17.0)))
    aabbs.append(("pcm5102", AABB(name: "i2s_wires", minX: 12.0, maxX: 27.0, minY: 85.4, maxY: 87.5, minZ: 10.2, maxZ: 13.4)))

    // 2) INMP441 Circular Ø14.0 mm 24-bit Omnidirectional I2S MEMS Mic + Foam Gasket
    let mic = SCNNode(); mic.name = "inmp441_mems_mic"
    addCyl(mic, "mic_pcb", r: 7.0, h: 1.6, cx: 56.0, cy: 95.5, cz: 16.0, axis: "z", matPCBBlack)
    addCyl(mic, "mic_copper_ring", r: 6.2, h: 1.65, cx: 56.0, cy: 95.5, cz: 16.0, axis: "z", matGold)
    // Bottom-port MEMS sensor faces UP toward front acoustic hole; silver MEMS IC shield faces rear
    addBox(mic, "mic_mems_ic", 53.6, 58.4, 93.6, 97.4, 14.0, 15.2, matSteel, chamfer: 0.1)
    addTorusRing(mic, "mic_foam_gasket", ringR: 2.2, pipeR: 0.35, cx: 56.0, cy: 95.5, cz: 17.1, matDarkCharcoal)
    addBox(mic, "mic_i2s_wires", 46.0, 49.0, 92.0, 99.0, 13.2, 15.2, matCopperWire, chamfer: 0.25)
    for j in 0..<3 {
        let py = 93.0 + Double(j) * 2.54
        addBox(mic, "mic_pad_\(j)", 48.2, 50.2, py - 0.45, py + 0.45, 14.2, 16.9, matGold)
    }
    parent.addChildNode(mic)

    aabbs.append(("inmp441", AABB(name: "mic_gasket", minX: 49.0, maxX: 63.0, minY: 88.5, maxY: 102.5, minZ: 13.2, maxZ: 17.4)))
    aabbs.append(("inmp441", AABB(name: "i2s_wires", minX: 46.0, maxX: 49.0, minY: 92.0, maxY: 99.0, minZ: 13.2, maxZ: 15.2)))
}

func buildRearTuckedMicroSDAndBoost(parent: SCNNode, aabbs: inout [(String, AABB)]) {
    // Tucked under top 4.0mm of ESP32 crimps (Y [81.0, 105.0], Z [2.2, 8.2]) -> saves 11.5 mm of overall height!
    let sd = SCNNode(); sd.name = "microsd_reader_tucked"
    addBox(sd, "sd_pcb", 2.2, 44.2, 81.0, 105.0, 2.2, 3.8, matPCBBlue, chamfer: 0.2)
    addBox(sd, "sd_cage", 6.4, 22.9, 88.7, 105.0, 3.8, 7.0, matSteel, chamfer: 0.15)
    addBox(sd, "sd_card", 8.9, 19.9, 103.5, 106.2, 4.3, 5.6, matDarkCharcoal)
    addBox(sd, "sd_ldo", 27.4, 34.4, 92.5, 99.5, 3.8, 5.8, matDarkCharcoal)
    addBox(sd, "sd_6p_exit", 44.2, 47.6, 86.0, 99.0, 3.2, 6.8, matCopperWire, chamfer: 0.2)
    parent.addChildNode(sd)

    aabbs.append(("microsd", AABB(name: "pcb_cage", minX: 2.2, maxX: 44.2, minY: 81.0, maxY: 105.0, minZ: 2.2, maxZ: 8.2)))
    aabbs.append(("microsd", AABB(name: "wire_exit", minX: 44.2, maxX: 47.6, minY: 86.0, maxY: 99.0, minZ: 3.2, maxZ: 6.8)))

    let chg = SCNNode(); chg.name = "usbc_lipo_boost"
    addBox(chg, "chg_pcb", 48.5, 69.5, 86.5, 103.5, 2.2, 3.8, matPCBBlack, chamfer: 0.15)
    addBox(chg, "chg_usbc", 54.5, 63.5, 99.0, 105.8, 3.8, 7.0, matSteel, chamfer: 0.3)
    addBox(chg, "chg_inductor", 51.0, 56.5, 89.0, 95.0, 3.8, 7.6, matDarkCharcoal, chamfer: 0.2)
    addBox(chg, "chg_ic", 59.5, 66.5, 89.5, 96.0, 3.8, 5.4, matDarkCharcoal)
    parent.addChildNode(chg)

    aabbs.append(("usbc_lipo_boost", AABB(name: "charger_boost", minX: 48.5, maxX: 69.5, minY: 86.5, maxY: 104.9, minZ: 2.2, maxZ: 8.0)))
}

func buildCornerBossesAndScrewsP4Mini(parent: SCNNode, aabbs: inout [(String, AABB)]) -> SCNNode {
    let inserts = SCNNode(); inserts.name = "m2_brass_inserts"
    let screws = SCNNode(); screws.name = "m2_black_screws"

    let bosses: [(String, Double, Double, Double, Double, Double, Double, Double, Double)] = [
        ("boss_bl",  1.6,  5.4,   1.6,   5.4,  1.6, 17.4,  3.5,   3.5),
        ("boss_br", 70.6, 74.4,   1.6,   5.4,  1.6, 17.4, 72.5,   3.5),
        ("boss_tl",  1.6,  5.4, 100.5, 104.9,  9.0, 17.4,  3.5, 102.7),
        ("boss_tr", 70.6, 74.4, 100.5, 104.9,  9.0, 17.4, 72.5, 102.7),
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

func buildTranslucentShellPiecesP4Mini(colorway: ShellColorway) -> (rear: SCNNode, front: SCNNode, bossSleeves: SCNNode) {
    let rear = SCNNode(); rear.name = "shell_rear_\(colorway.rawValue)"
    let front = SCNNode(); front.name = "shell_front_\(colorway.rawValue)"
    let bossSleeves = SCNNode(); bossSleeves.name = "shell_boss_sleeves"

    let m = colorway.bodyMat
    let e = colorway.edgeMat

    // 100% UNIFORM FLAT 19.0 mm SLAB: 76.0 x 106.5 x 19.0 mm (zero 22.2 mm camera-bar bump!)
    addBox(rear, "rear_back_plate", 0, 76.0, 0, 106.5, 0, 1.6, m, chamfer: 1.2, renderOrder: 10)
    addBox(rear, "wall_L", 0, 1.6, 0, 106.5, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_R", 74.4, 76.0, 0, 106.5, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_B", 0, 76.0, 0, 1.6, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_T", 0, 76.0, 104.9, 106.5, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)

    // FLUSH Top Audio Showcase Window (Y [85.0, 106.5], Z [17.4, 19.0]) — coplanar with IPS & controls!
    addBox(front, "front_top_audio_window", 0, 76.0, 85.0, 106.5, 17.4, 19.0, m, chamfer: 0.6, renderOrder: 12)
    // Chamfered 1.5 mm INMP441 bottom-port soundhole bezel at (56.0, 95.5)
    addTorusRing(front, "inmp441_soundhole_bezel", ringR: 1.35, pipeR: 0.45, cx: 56.0, cy: 95.5, cz: 18.8, matDarkCharcoal, renderOrder: 14)

    // Screen frame around 1.9" IPS glass (Y [53.5, 85.0], Z [17.4, 19.0])
    addBox(front, "front_scr_left", 0, 21.0, 53.5, 85.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_scr_right", 63.7, 76.0, 53.5, 85.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_scr_top", 21.0, 63.7, 80.6, 85.0, 17.4, 19.0, e, renderOrder: 12)
    addBox(front, "front_scr_bot", 21.0, 63.7, 53.5, 57.9, 17.4, 19.0, e, renderOrder: 12)

    // Panoramic LiPo Showcase Window (Y [39.0, 53.5], Z [17.4, 19.0])
    addBox(front, "front_lipo_window", 0, 76.0, 39.0, 53.5, 17.4, 19.0, m, chamfer: 0.2, renderOrder: 13)

    // Lower Controls Faceplate (Y [0.0, 39.0], Z [17.4, 19.0])
    addBox(front, "front_ctrl_farL", 0, 6.0, 0, 39.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_ctrl_joy_top", 6.0, 27.6, 31.6, 39.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_ctrl_joy_bot", 6.0, 27.6, 0, 10.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addTorusRing(front, "joy_well_ring", ringR: 10.6, pipeR: 0.85, cx: 16.8, cy: 20.8, cz: 18.6, e, renderOrder: 13)
    addBox(front, "front_ctrl_alley", 27.6, 34.0, 0, 39.0, 17.4, 19.0, e, renderOrder: 12)
    addBox(front, "front_ctrl_farR", 69.8, 76.0, 0, 39.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)

    addBox(front, "front_pad_bot_strip", 34.0, 69.8, 0, 13.4, 17.4, 19.0, m, renderOrder: 12)
    addBox(front, "front_pad_mid_bridge", 34.0, 69.8, 20.1, 24.5, 17.4, 19.0, e, renderOrder: 12)
    addBox(front, "front_pad_top_strip", 34.0, 69.8, 31.2, 39.0, 17.4, 19.0, m, renderOrder: 12)

    let posts: [(Double, Double, Double, Double)] = [
        (3.5, 3.5, 1.6, 17.4), (72.5, 3.5, 1.6, 17.4),
        (3.5, 102.7, 9.0, 17.4), (72.5, 102.7, 9.0, 17.4)
    ]
    for (i, (cx, cy, z0, z1)) in posts.enumerated() {
        addCyl(bossSleeves, "boss_post_\(i)", r: 1.9, h: z1 - z0, cx: cx, cy: cy, cz: (z0 + z1) * 0.5, axis: "z", e, renderOrder: 9)
    }
    return (rear, front, bossSleeves)
}

func buildFullOptionP4Mini(colorway: ShellColorway, orangePuck: Bool = false, exploded: Bool = false) -> (root: SCNNode, aabbs: [(String, AABB)]) {
    let root = SCNNode(); root.name = "Option_P4_Mini_\(colorway.rawValue)"
    var aabbs: [(String, AABB)] = []

    let layerRear = SCNNode(); layerRear.name = "Layer1_Rear_TuckedSD_Boost"
    let layerLiPo = SCNNode(); layerLiPo.name = "Layer2_LiPo"
    let layerCtrl = SCNNode(); layerCtrl.name = "Layer3_Joy_And_TwinPCBs"
    let layerMain = SCNNode(); layerMain.name = "Layer4_ESP32_PCM5102_INMP441"
    let layerTop  = SCNNode(); layerTop.name  = "Layer5_Flat19mm_TopBezel"
    let layerCaps = SCNNode(); layerCaps.name = "Layer5b_Puck_Keys_Screws"

    buildKY023PlayfulLowProfile(parent: layerCtrl, capsLayer: layerCaps, orangePuck: orangePuck, aabbs: &aabbs)
    buildTightDualKeypads180Flip(ctrlLayer: layerCtrl, capsLayer: layerCaps, aabbs: &aabbs)
    buildCombedCopperHarnesses(parent: layerCtrl, minSpineZ: 9.0, aabbs: &aabbs)

    buildLiPoAndShield(parent: layerLiPo, aabbs: &aabbs)
    buildESP32LightMod(parent: layerMain, aabbs: &aabbs)
    buildPCM5102AndINMP441(parent: layerMain, aabbs: &aabbs)
    buildRearTuckedMicroSDAndBoost(parent: layerRear, aabbs: &aabbs)

    let screwsNode = buildCornerBossesAndScrewsP4Mini(parent: layerRear, aabbs: &aabbs)
    layerCaps.addChildNode(screwsNode)

    let (rearShell, frontShell, bossSleeves) = buildTranslucentShellPiecesP4Mini(colorway: colorway)
    layerRear.addChildNode(rearShell)
    layerRear.addChildNode(bossSleeves)
    layerTop.addChildNode(frontShell)

    if exploded {
        layerRear.position = SCNVector3(0, 0, 0)
        layerLiPo.position = SCNVector3(0, 32, 0)
        layerCtrl.position = SCNVector3(0, 62, 0)
        layerMain.position = SCNVector3(0, 96, 0)
        layerTop.position  = SCNVector3(0, 134, 0)
        layerCaps.position = SCNVector3(0, 156, 0)

        let guides = SCNNode(); guides.name = "ExplodeGuides"
        for (i, (gx, gy)) in [(3.5, 3.5), (72.5, 3.5), (3.5, 102.7), (72.5, 102.7)].enumerated() {
            addCyl(guides, "g_\(i)", r: 0.35, h: 178.0, cx: gx, cy: gy, cz: 89.0, axis: "z", matCyanGuide)
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

// MARK: - Reference Option P3-Joy8 (WM8960 Stepped 118.0 mm x 22.2 mm) for 1:1 Comparison
func buildFullOptionP3Joy8Ref(colorway: ShellColorway) -> (root: SCNNode, aabbs: [(String, AABB)]) {
    let root = SCNNode(); root.name = "Option_P3_Joy8_WM8960_Ref"
    var aabbs: [(String, AABB)] = []
    let caps = SCNNode(); caps.name = "caps"

    buildKY023PlayfulLowProfile(parent: root, capsLayer: caps, orangePuck: false, aabbs: &aabbs)
    buildTightDualKeypads180Flip(ctrlLayer: root, capsLayer: caps, aabbs: &aabbs)
    buildCombedCopperHarnesses(parent: root, minSpineZ: 8.8, aabbs: &aabbs)
    buildLiPoAndShield(parent: root, aabbs: &aabbs)
    buildESP32LightMod(parent: root, aabbs: &aabbs)

    // WM8960 HAT (Y [85.8, 115.8], Z [12.8, 20.4])
    addBox(root, "wm_pcb", 5.5, 70.5, 85.8, 115.8, 12.8, 14.4, matPCBBlack, chamfer: 0.2)
    addBox(root, "wm_trs", 18.0, 29.0, 104.5, 117.5, 14.4, 20.4, matDarkCharcoal, chamfer: 0.3)
    addCyl(root, "wm_ring", r: 3.1, h: 2.0, cx: 23.5, cy: 117.2, cz: 17.4, axis: "y", matGold)
    addBox(root, "pi40", 13.0, 63.0, 86.0, 92.0, 9.4, 12.8, matWireInsul, chamfer: 0.25)
    aabbs.append(("wm8960", AABB(name: "pcb_trs", minX: 5.5, maxX: 70.5, minY: 85.8, maxY: 115.8, minZ: 12.8, maxZ: 20.4)))
    aabbs.append(("wm8960", AABB(name: "pi40", minX: 13.0, maxX: 63.0, minY: 86.0, maxY: 92.0, minZ: 9.4, maxZ: 12.8)))

    // Standard non-tucked MicroSD + Boost (Y [92.3, 116.4])
    addBox(root, "sd_pcb", 1.8, 43.8, 92.3, 116.3, 2.8, 4.4, matPCBBlue, chamfer: 0.2)
    addBox(root, "sd_cage", 6.0, 22.5, 100.0, 116.3, 4.4, 7.6, matSteel, chamfer: 0.15)
    addBox(root, "chg_pcb", 48.5, 69.5, 93.0, 111.0, 2.2, 3.8, matPCBBlack, chamfer: 0.15)
    addBox(root, "chg_usbc", 54.5, 63.5, 108.5, 116.4, 3.8, 7.0, matSteel, chamfer: 0.3)
    aabbs.append(("microsd_ref", AABB(name: "sd", minX: 1.8, maxX: 43.8, minY: 92.3, maxY: 116.3, minZ: 2.8, maxZ: 8.8)))
    aabbs.append(("boost_ref", AABB(name: "boost", minX: 48.5, maxX: 69.5, minY: 93.0, maxY: 116.4, minZ: 2.2, maxZ: 8.0)))

    // Stepped 19.0 / 22.2 mm shell
    let m = colorway.bodyMat, e = colorway.edgeMat
    addBox(root, "r_plate", 0, 76.0, 0, 118.0, 0, 1.6, m, chamfer: 1.2, renderOrder: 10)
    addBox(root, "r_wL1", 0, 1.6, 0, 85.0, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)
    addBox(root, "r_wR1", 74.4, 76.0, 0, 85.0, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)
    addBox(root, "r_wB", 0, 76.0, 0, 1.6, 1.6, 19.0, e, chamfer: 0.6, renderOrder: 11)
    addBox(root, "r_wL2", 0, 1.6, 85.0, 118.0, 1.6, 22.2, e, chamfer: 0.6, renderOrder: 11)
    addBox(root, "r_wR2", 74.4, 76.0, 85.0, 118.0, 1.6, 22.2, e, chamfer: 0.6, renderOrder: 11)
    addBox(root, "r_wT", 0, 76.0, 116.4, 118.0, 1.6, 22.2, e, chamfer: 0.6, renderOrder: 11)
    addBox(root, "r_hump", 0, 76.0, 85.0, 118.0, 20.6, 22.2, m, chamfer: 0.9, renderOrder: 12)
    addBox(root, "r_step", 0, 76.0, 83.8, 85.6, 17.5, 22.2, e, chamfer: 0.5, renderOrder: 12)
    addBox(root, "r_scrL", 0, 21.0, 53.5, 85.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(root, "r_scrR", 63.7, 76.0, 53.5, 85.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(root, "r_scrT", 21.0, 63.7, 80.6, 85.0, 17.4, 19.0, e, renderOrder: 12)
    addBox(root, "r_scrB", 21.0, 63.7, 53.5, 57.9, 17.4, 19.0, e, renderOrder: 12)
    addBox(root, "r_lipo", 0, 76.0, 39.0, 53.5, 17.4, 19.0, m, chamfer: 0.2, renderOrder: 13)
    addBox(root, "r_c1", 0, 6.0, 0, 39.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(root, "r_c2", 6.0, 27.6, 31.6, 39.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(root, "r_c3", 6.0, 27.6, 0, 10.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addTorusRing(root, "r_well", ringR: 10.6, pipeR: 0.85, cx: 16.8, cy: 20.8, cz: 18.6, e, renderOrder: 13)
    addBox(root, "r_alley", 27.6, 34.0, 0, 39.0, 17.4, 19.0, e, renderOrder: 12)
    addBox(root, "r_cR", 69.8, 76.0, 0, 39.0, 17.4, 19.0, m, chamfer: 0.3, renderOrder: 12)
    addBox(root, "r_pb", 34.0, 69.8, 0, 13.4, 17.4, 19.0, m, renderOrder: 12)
    addBox(root, "r_pm", 34.0, 69.8, 20.1, 24.5, 17.4, 19.0, e, renderOrder: 12)
    addBox(root, "r_pt", 34.0, 69.8, 31.2, 39.0, 17.4, 19.0, m, renderOrder: 12)

    for (i, (cx, cy, z1)) in [(3.5, 3.5, 17.4), (72.5, 3.5, 17.4), (3.4, 114.2, 20.6), (72.6, 114.2, 20.6)].enumerated() {
        addCyl(caps, "r_scr_\(i)", r: 1.65, h: 1.4, cx: cx, cy: cy, cz: z1 + 0.8, axis: "z", matBlackScrew)
    }
    root.addChildNode(caps)
    return (root, aabbs)
}

// MARK: - Lighting, Rendering & USDZ Export
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
let (p4Root, p4Boxes) = buildFullOptionP4Mini(colorway: .atomicSmoke, orangePuck: false, exploded: false)
let cP4 = verifyAABBs(label: "Option_P4_Mini_19mm", boxes: p4Boxes)

let (p3RefRoot, p3RefBoxes) = buildFullOptionP3Joy8Ref(colorway: .atomicSmoke)
let cP3 = verifyAABBs(label: "Option_P3_Joy8_19mm", boxes: p3RefBoxes)

if cP4 + cP3 > 0 {
    fputs("FATAL: Non-zero CAD collisions detected (P4=\(cP4), P3=\(cP3))\n", stderr)
    exit(2)
}

try exportUSDZ(p4Root, fileName: "14a_p4_mini_pcm5102_flat19mm.usdz")
let (p4Exploded, _) = buildFullOptionP4Mini(colorway: .atomicSmoke, orangePuck: false, exploded: true)
try exportUSDZ(p4Exploded, fileName: "14b_p4_mini_pcm5102_exploded.usdz")

let cmpNode = SCNNode(); cmpNode.name = "P4_Mini_vs_P3_WM8960"
let cmpP3 = p3RefRoot.clone(); cmpP3.position = SCNVector3(0, 0, 0)
let cmpP4 = p4Root.clone(); cmpP4.position = SCNVector3(98, 0, 0)
cmpNode.addChildNode(cmpP3); cmpNode.addChildNode(cmpP4)
try exportUSDZ(cmpNode, fileName: "14c_p4_mini_vs_p3_wm8960_comparison.usdz")

// MARK: - Render Guide 14a: Option P3 (Stepped 118mm) vs Option P4-Mini (Flat 106.5mm) + Ice Side-Angle
do {
    let s = SCNScene()
    let matW = 520.0, matH = 265.0
    let matTex = makeCuttingMatTexture(widthMm: matW, heightMm: matH, label: "10 mm METRIC GRID  |  WAY 2 COMPARISON: P3-WM8960 (118 × 22.2 mm) vs P4-MINI PCM5102 (106.5 × 19.0 mm FLAT)")
    addBox(s.rootNode, "cutting_mat", -110, matW - 110, -70, matH - 70, -2.0, 0.0, texMat(matTex, roughness: 0.85, metalness: 0.02))

    // Left: Stepped P3-Joy8 (WM8960 76x118x19/22.2mm)
    let leftP3 = buildFullOptionP3Joy8Ref(colorway: .atomicSmoke).root; leftP3.position = SCNVector3(0, 0, 0)
    // Center Hero: P4-Mini Atomic Smoke (76x106.5x19.0mm flat)
    let midP4 = buildFullOptionP4Mini(colorway: .atomicSmoke, orangePuck: false).root; midP4.position = SCNVector3(96, 0, 0)
    // Right: P4-Mini Frosted Clear Ice w/ Orange Disc turned ~20 deg with clear separation showing flat 19.0 mm side edge
    let rightP4Ice = buildFullOptionP4Mini(colorway: .frostedClearIce, orangePuck: true).root
    rightP4Ice.position = SCNVector3(228, 0, -4)
    rightP4Ice.eulerAngles = SCNVector3(0, 0.34, 0)

    s.rootNode.addChildNode(leftP3); s.rootNode.addChildNode(midP4); s.rootNode.addChildNode(rightP4Ice)

    let card = buildISOCreditCard(); card.position = SCNVector3(-100, 0, 10)
    let ruler = buildMetricRuler(); ruler.position = SCNVector3(58, 0, 34)
    let ap = buildAirPodsProCase(); ap.position = SCNVector3(322, 0, 4)
    s.rootNode.addChildNode(card); s.rootNode.addChildNode(ruler); s.rootNode.addChildNode(ap)

    setupStudioLighting(s, camPos: SCNVector3(145, 360, 240), lookAt: SCNVector3(145, 12, -45), fov: 36)
    let raw = renderSceneToImage(s)
    let final14a = overlayHeaderOnImage(
        raw,
        title: "REF 14A • OPTION P4-MINI (PCM5102A + INMP441) vs WM8960 STEPPED BUILD (1:1 CAD)",
        subtitle: "Left: Old P3 WM8960 (118 × 22.2 mm bump)  |  Center: P4-Mini Smoke (106.5 × 19.0 mm FLAT)  |  Right: P4-Mini Clear Ice (19.0 mm edge) < AirPods (21.7 mm)",
        footer: "PCM5102A (32×17mm) + INMP441 (Ø14mm) + Rear-Tucked MicroSD = -11.5 mm shorter, 0.0 mm bump, 153.8 cm³ (-13.8%), True 0V Ground AUX!"
    )
    try savePNG(final14a, path1: "\(renderDir)/ref_14a_p4_mini_vs_wm8960_evolution_guide.png",
                path2: "\(artifactDir)/ref_14a_p4_mini_vs_wm8960_evolution_guide.png")
    print("RENDERED 14a guide")
}

// MARK: - Render Guide 14b: 5-Layer Isometric Exploded Assembly of Option P4-Mini
do {
    let s = SCNScene()
    let matW = 360.0, matH = 260.0
    let matTex = makeCuttingMatTexture(widthMm: matW, heightMm: matH, label: "P4-MINI 5-LAYER EXPLODED STACK  |  PCM5102A + INMP441 FLAT 19.0 mm SLAB  |  COLLISIONS: \(cP4)")
    addBox(s.rootNode, "cutting_mat", -130, matW - 130, -80, matH - 80, -2.0, 0.0, texMat(matTex, roughness: 0.85, metalness: 0.02))

    let (ex, _) = buildFullOptionP4Mini(colorway: .atomicSmoke, orangePuck: false, exploded: true)
    s.rootNode.addChildNode(ex)

    setupStudioLighting(s, camPos: SCNVector3(246, 224, 186), lookAt: SCNVector3(38, 84, -54), fov: 38)
    let raw = renderSceneToImage(s)
    let final14b = overlayHeaderOnImage(
        raw,
        title: "REF 14B • OPTION P4-MINI 5-LAYER EXPLODED ASSEMBLY (1:1 METAL CAD)",
        subtitle: "L1: Rear+Tucked SD+Boost  →  L2: LiPo+Shield  →  L3: Low-Pro KY-023+180° 2×4 PCBs  →  L4: ESP32 + Purple GY-PCM5102 + Ø14mm INMP441  →  L5: FLAT 19mm Lid",
        footer: "Verified Collisions: \(cP4) across \(p4Boxes.count) box groups  •  Zero 22.2 mm bump  •  Freed GPIO 21 (Dedicated KY-023 SW) + GPIO 22"
    )
    try savePNG(final14b, path1: "\(renderDir)/ref_14b_p4_mini_flat19mm_exploded_guide.png",
                path2: "\(artifactDir)/ref_14b_p4_mini_flat19mm_exploded_guide.png")
    print("RENDERED 14b guide")
}

// MARK: - Render Guide 14c: Handheld Reach w/ 3.5mm Jack & Flush 19mm Pocket Fit
do {
    let s = SCNScene()
    let matW = 440.0, matH = 260.0
    let matTex = makeCuttingMatTexture(widthMm: matW, heightMm: matH, label: "1:1 ERGONOMICS & POCKET FIT  |  P4-MINI (76 × 106.5 × 19.0 mm FLAT) vs AIRPODS (21.7 mm) & PHONE (8.25 mm)")
    addBox(s.rootNode, "cutting_mat", -75, matW - 75, -55, matH - 55, -2.0, 0.0, texMat(matTex, roughness: 0.85, metalness: 0.02))

    let devL = buildFullOptionP4Mini(colorway: .atomicSmoke, orangePuck: false).root; devL.position = SCNVector3(0, 0, 0)
    s.rootNode.addChildNode(devL)
    let plugIn = buildAudioPlug35mm(); plugIn.position = SCNVector3(16.5, 10.0, -120.0)
    s.rootNode.addChildNode(plugIn)

    let palmGhost = pbrMat(0.28, 0.72, 0.88, 0.20, roughness: 0.6, metalness: 0.0, depthWrite: false)
    addBox(s.rootNode, "palm_width_85mm", -6, 79, -14, 88, 0.2, 1.4, palmGhost, chamfer: 8.0, renderOrder: 1)
    let thumbHalo = pbrMat(0.28, 0.82, 0.94, 0.14, roughness: 0.4, metalness: 0.0, depthWrite: false)
    addCyl(s.rootNode, "thumb_sweep_zone", r: 34.0, h: 0.6, cx: 42.0, cy: 22.0, cz: 21.6, axis: "z", thumbHalo, renderOrder: 20)

    let denimProxy = pbrMat(0.14, 0.22, 0.36, 0.88, roughness: 0.88, metalness: 0.02)
    addBox(s.rootNode, "jeans_pocket_145x165", 132, 277, -10, 155, 0.0, 2.5, denimProxy, chamfer: 2.0)
    let devPocket = buildFullOptionP4Mini(colorway: .atomicSmoke, orangePuck: false).root; devPocket.position = SCNVector3(166, 12.0, 0)
    let apSide = buildAirPodsProCase(); apSide.position = SCNVector3(286, 3.0, 22)
    let phoneRef = buildPhoneProxy(); phoneRef.position = SCNVector3(286, 3.0, -32)
    s.rootNode.addChildNode(devPocket); s.rootNode.addChildNode(apSide); s.rootNode.addChildNode(phoneRef)

    setupStudioLighting(s, camPos: SCNVector3(154, 385, 220), lookAt: SCNVector3(154, 12, -48), fov: 38)
    let raw = renderSceneToImage(s)
    let final14c = overlayHeaderOnImage(
        raw,
        title: "REF 14C • P4-MINI ONE-HANDED GRIP (3.5 mm PLUGGED) & BUMP-FREE POCKET FIT (1:1 CAD)",
        subtitle: "Left: Compact 106.5 mm height w/ Concave Disc + 2×4 Keys + Top-Left PCM5102 3.5 mm Jack  |  Right: 145 mm Front Pocket vs AirPods Pro 2",
        footer: "76.0 × 106.5 × 19.0 mm (153.8 cm³)  •  Flush top edge never catches pocket hem  •  Verified Collisions: \(cP4)"
    )
    try savePNG(final14c, path1: "\(renderDir)/ref_14c_p4_mini_hand_pocket_ergo_guide.png",
                path2: "\(artifactDir)/ref_14c_p4_mini_hand_pocket_ergo_guide.png")
    print("RENDERED 14c guide")
}

print("ALL_14_P4_MINI_DONE p4_collisions=\(cP4) p3_collisions=\(cP3) p4_boxes=\(p4Boxes.count)")
