import Foundation
import SceneKit
import ModelIO
import SceneKit.ModelIO
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

// MARK: - Collision AABB Helpers (CAD Coordinates: +X Right, +Y Up/Top, +Z Front)
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
    let w = max(0.05, x1 - x0)
    let h = max(0.05, y1 - y0)
    let d = max(0.05, z1 - z0)
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
    cyl.radialSegmentCount = 36
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

// MARK: - Procedural Textures (UI, LiPo Label, Keycaps, Cutting Mat)
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

        // Top bar
        ctx.setFillColor(NSColor(calibratedRed: 0.11, green: 0.14, blue: 0.19, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 294, width: 640, height: 46))

        // Audiobook orange cover tile
        ctx.setFillColor(NSColor(calibratedRed: 0.93, green: 0.42, blue: 0.12, alpha: 1).cgColor)
        let cover = CGPath(roundedRect: CGRect(x: 24, y: 54, width: 170, height: 210), cornerWidth: 16, cornerHeight: 16, transform: nil)
        ctx.addPath(cover)
        ctx.fillPath()

        ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.72, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: 68, y: 122, width: 82, height: 82))

        // Progress track & elapsed fill
        ctx.setFillColor(NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.28, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 224, y: 84, width: 386, height: 14))
        ctx.setFillColor(NSColor(calibratedRed: 0.95, green: 0.47, blue: 0.14, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 224, y: 84, width: 248, height: 14))

        // Labels
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 30),
            .foregroundColor: NSColor.white
        ]
        let subAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.62, green: 0.85, blue: 0.96, alpha: 1)
        ]
        let statusAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.42, green: 0.94, blue: 0.68, alpha: 1)
        ]
        NSAttributedString(string: "Audiobookshelf • Ch 14", attributes: statusAttr).draw(at: NSPoint(x: 20, y: 304))
        NSAttributedString(string: "PROJECT HAIL MARY", attributes: titleAttr).draw(at: NSPoint(x: 224, y: 216))
        NSAttributedString(string: "Andy Weir  •  44.1kHz PCM", attributes: subAttr).draw(at: NSPoint(x: 224, y: 174))
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

        let bigAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 34, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.19, alpha: 1)
        ]
        let medAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.22, green: 0.25, blue: 0.30, alpha: 1)
        ]
        NSAttributedString(string: "3.7V  1500mAh  Li-Po", attributes: bigAttr).draw(at: NSPoint(x: 34, y: 66))
        NSAttributedString(string: "MODEL 604060   5.55Wh   + RED / - BLK", attributes: medAttr).draw(at: NSPoint(x: 34, y: 26))
        NSAttributedString(string: "604060 3.7V 1500mAh SHIELDED", attributes: medAttr).draw(at: NSPoint(x: 34, y: 240))
    }
}

func makeCuttingMatTexture(widthMm: Double, heightMm: Double, label: String) -> NSImage {
    let pxPerMm = 6.0
    let w = Int(widthMm * pxPerMm)
    let h = Int(heightMm * pxPerMm)
    return drawImage(width: w, height: h) { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // 10mm minor grid
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

        // 50mm major grid
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

        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.56, green: 0.74, blue: 0.84, alpha: 0.95)
        ]
        NSAttributedString(string: label, attributes: attr).draw(at: NSPoint(x: 24, y: 20))
    }
}

func makeKeycapTexture(_ glyph: String, bg: NSColor, fg: NSColor = .white) -> NSImage {
    return drawImage(width: 160, height: 160) { ctx in
        ctx.setFillColor(bg.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        ctx.setLineWidth(8)
        ctx.stroke(CGRect(x: 6, y: 6, width: 148, height: 148))

        let size: CGFloat = glyph.count <= 2 ? 62 : 34
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .heavy),
            .foregroundColor: fg
        ]
        let str = NSAttributedString(string: glyph, attributes: attr)
        let sz = str.size()
        str.draw(at: NSPoint(x: (160 - sz.width) * 0.5, y: (160 - sz.height) * 0.5))
    }
}

func makeFlatBanner(_ title: String, _ subtitle: String, width: Int = 1600, height: Int = 110) -> NSImage {
    return drawImage(width: width, height: height) { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.11, alpha: 0.92).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setStrokeColor(NSColor(calibratedRed: 0.25, green: 0.62, blue: 0.78, alpha: 0.9).cgColor)
        ctx.setLineWidth(3)
        ctx.stroke(CGRect(x: 4, y: 4, width: width - 8, height: height - 8))
        let tAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let sAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.58, green: 0.84, blue: 0.95, alpha: 1)
        ]
        NSAttributedString(string: title, attributes: tAttr).draw(at: NSPoint(x: 24, y: 58))
        NSAttributedString(string: subtitle, attributes: sAttr).draw(at: NSPoint(x: 24, y: 22))
    }
}

func overlayHeaderOnImage(_ img: NSImage, title: String, subtitle: String, footer: String) -> NSImage {
    let w = Int(img.size.width)
    let h = Int(img.size.height)
    return drawImage(width: w, height: h) { ctx in
        img.draw(in: CGRect(x: 0, y: 0, width: w, height: h))

        // Top HUD bar
        ctx.setFillColor(NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.09, alpha: 0.82).cgColor)
        ctx.fill(CGRect(x: 24, y: h - 98, width: w - 48, height: 76))
        ctx.setStrokeColor(NSColor(calibratedRed: 0.95, green: 0.50, blue: 0.18, alpha: 0.85).cgColor)
        ctx.setLineWidth(2)
        ctx.stroke(CGRect(x: 24, y: h - 98, width: w - 48, height: 76))

        let tAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let sAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 17, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.62, green: 0.86, blue: 0.96, alpha: 1)
        ]
        NSAttributedString(string: title, attributes: tAttr).draw(at: NSPoint(x: 42, y: h - 58))
        NSAttributedString(string: subtitle, attributes: sAttr).draw(at: NSPoint(x: 42, y: h - 86))

        // Bottom HUD footer
        ctx.setFillColor(NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.09, alpha: 0.82).cgColor)
        ctx.fill(CGRect(x: 24, y: 18, width: w - 48, height: 42))
        let fAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.82, green: 0.90, blue: 0.95, alpha: 1)
        ]
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
let matShieldRib = pbrMat(0.42, 0.46, 0.52, 0.60, roughness: 0.35, metalness: 0.05)
let matScreenGlass = pbrMat(0.03, 0.03, 0.04, 1.0, roughness: 0.08, metalness: 0.10)
let matScreenUI = texMat(makeScreenUITexture(), roughness: 0.12, metalness: 0.02)
let matDarkCharcoal = pbrMat(0.14, 0.15, 0.17, 1.0, roughness: 0.55, metalness: 0.05)
let matOrangeKey = pbrMat(0.95, 0.35, 0.09, 1.0, roughness: 0.42, metalness: 0.05)
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
            return pbrMat(0.70, 0.86, 0.96, 0.25, roughness: 0.24, metalness: 0.04, depthWrite: false)
        case .atomicPurple:
            return pbrMat(0.46, 0.22, 0.72, 0.38, roughness: 0.18, metalness: 0.06, depthWrite: false)
        }
    }

    var edgeMat: SCNMaterial {
        switch self {
        case .atomicSmoke:
            return pbrMat(0.22, 0.25, 0.30, 0.62, roughness: 0.22, metalness: 0.08, depthWrite: false)
        case .frostedClearIce:
            return pbrMat(0.88, 0.94, 0.99, 0.56, roughness: 0.32, metalness: 0.05, depthWrite: false)
        case .atomicPurple:
            return pbrMat(0.56, 0.30, 0.82, 0.62, roughness: 0.24, metalness: 0.08, depthWrite: false)
        }
    }
}

// MARK: - Option P1-Smoke Exact Component Builders (1:1 Millimeters)
func buildKeypadLightMod(label: String, origin: (Double, Double, Double),
                         crimpLocalZ0: Double, crimpLocalZ1: Double,
                         keyLabels: [String], rightOrange: Bool,
                         parent: SCNNode, aabbs: inout [(String, AABB)]) -> (body: SCNNode, caps: SCNNode) {
    let body = SCNNode(); body.name = label
    let caps = SCNNode(); caps.name = "\(label)_caps"
    cadPlace(body, ox: origin.0, oy: origin.1, oz: origin.2)
    cadPlace(caps, ox: origin.0, oy: origin.1, oz: origin.2)

    // 37.0 x 15.0 x 1.6 mm emerald-green PCB + 0.8mm underside solder fillets
    addBox(body, "\(label)_pcb", 0, 37.0, 0, 15.0, 0, 1.6, matPCBGreen, chamfer: 0.15)
    addBox(body, "\(label)_tails", 4.0, 33.0, 2.0, 12.0, -0.8, 0, matSteel)

    // 4x mounting holes gold pads
    for hx in [2.5, 34.5] {
        for hy in [2.5, 12.5] {
            addCyl(body, "\(label)_pad", r: 1.4, h: 1.68, cx: hx, cy: hy, cz: 0.8, axis: "z", matGold)
        }
    }

    // 4x tactile switches (6.0x6.0x3.5) + keycaps extending to Z_world 18.3 mm
    let capBottomZ = 18.3 - origin.2 - 3.6
    let switchTopZ = capBottomZ
    for i in 0..<4 {
        let kx = 4.6 + Double(i) * 9.2
        addBox(body, "\(label)_sw_\(i)", kx - 3.0, kx + 3.0, 2.5, 8.5, 1.6, 5.2, matDarkCharcoal, chamfer: 0.1)
        addBox(body, "\(label)_stem_\(i)", kx - 1.8, kx + 1.8, 4.0, 7.0, 5.2, switchTopZ, matSteel, chamfer: 0.05)

        let isOrange = rightOrange && (i == 3)
        let capBg = isOrange ? NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.09, alpha: 1) : NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.20, alpha: 1)
        let capMat = keyLabels.count == 4 ? texMat(makeKeycapTexture(keyLabels[i], bg: capBg), roughness: 0.38) : (isOrange ? matOrangeKey : matDarkCharcoal)
        addBox(caps, "\(label)_cap_\(i)", kx - 3.7, kx + 3.7, 2.0, 9.0, switchTopZ, switchTopZ + 3.6, capMat, chamfer: 0.45)
    }

    // 5P Light-Mod bare bent solder crimps along top edge (+Y)
    addBox(body, "\(label)_5p_crimps", 7.5, 21.5, 15.0, 20.2, crimpLocalZ0, crimpLocalZ1, matCopperWire, chamfer: 0.15)
    for j in 0..<5 {
        let px = 8.4 + Double(j) * 2.54
        addBox(body, "\(label)_pin_\(j)", px - 0.35, px + 0.35, 13.0, 19.6, 1.6, crimpLocalZ1, matGold)
    }

    parent.addChildNode(body)
    parent.addChildNode(caps)

    aabbs.append((label, makeAABB(origin: origin, name: "pcb_tails", 0, 37.0, 0, 15.0, -0.8, 1.6)))
    aabbs.append((label, makeAABB(origin: origin, name: "switches", 1.0, 36.0, 2.0, 10.6, 1.6, 11.0)))
    aabbs.append((label, makeAABB(origin: origin, name: "5p_bare_crimps", 7.5, 21.5, 15.0, 20.2, crimpLocalZ0, crimpLocalZ1)))
    return (body, caps)
}

func buildLiPoAndShield(parent: SCNNode, aabbs: inout [(String, AABB)]) -> (lipo: SCNNode, shield: SCNNode) {
    let lipo = SCNNode(); lipo.name = "lipo_604060"
    // 604060 pouch cell: X [8.0, 68.0], Y [39.5, 79.5], Z [1.9, 7.7]
    addBox(lipo, "lipo_pouch", 15.5, 68.0, 39.5, 79.5, 1.9, 7.7, matSilverPouch, chamfer: 0.8)
    // Left PCM + translucent amber Kapton collar (X [8.0, 16.0], Y [40.0, 79.0])
    addBox(lipo, "lipo_pcm_kapton", 8.0, 16.0, 40.0, 79.0, 2.1, 7.5, matAmberKapton, chamfer: 0.4)
    addBox(lipo, "lipo_pcm_pcb", 9.0, 13.0, 44.0, 75.0, 3.0, 6.2, matPCBGreen)
    // Top fold Kapton stripe visible in panoramic window
    addBox(lipo, "lipo_kapton_edge", 14.5, 67.8, 39.5, 42.2, 2.0, 7.75, matAmberKapton, chamfer: 0.2)
    // Positive & Negative silicon leads rising cleanly from top-left PCM toward upper bay
    addCyl(lipo, "lipo_red_lead", r: 0.75, h: 35.0, cx: 10.0, cy: 64.0, cz: 7.4, axis: "y", matRedWire)
    addCyl(lipo, "lipo_blk_lead", r: 0.75, h: 35.0, cx: 12.0, cy: 64.0, cz: 7.4, axis: "y", matDarkCharcoal)
    parent.addChildNode(lipo)

    // 0.7mm protective shield rib: X [7.8, 68.2], Y [39.2, 79.8], Z [7.8, 8.5]
    let shield = SCNNode(); shield.name = "lipo_shield_rib"
    addBox(shield, "shield_plate", 7.8, 68.2, 39.2, 79.8, 7.8, 8.5, matShieldRib, chamfer: 0.15, renderOrder: 4)
    // Transverse stiffening ribs visible in polycarbonate tint
    for ry in [44.0, 56.0, 68.0, 76.0] {
        addBox(shield, "rib_\(Int(ry))", 14.0, 67.5, ry, ry + 1.0, 8.2, 8.5, matEdgeTrim(), renderOrder: 5)
    }
    parent.addChildNode(shield)

    aabbs.append(("lipo", AABB(name: "pouch_pcm", minX: 8.0, maxX: 68.0, minY: 39.5, maxY: 79.5, minZ: 1.9, maxZ: 7.7)))
    aabbs.append(("lipo_shield_rib", AABB(name: "rib", minX: 7.8, maxX: 68.2, minY: 39.2, maxY: 79.8, minZ: 7.8, maxZ: 8.5)))
    return (lipo, shield)
}

func matEdgeTrim() -> SCNMaterial {
    return pbrMat(0.32, 0.36, 0.42, 0.75, roughness: 0.35, metalness: 0.10, depthWrite: false)
}

func buildCombedCopperBus(parent: SCNNode, aabbs: inout [(String, AABB)]) -> SCNNode {
    let bus = SCNNode(); bus.name = "combed_copper_bus"

    // Lower bus trunk (next to dual keypads): X [7.5, 17.5], Y [10.0, 39.0], Z [4.5, 9.5]
    for i in 0..<6 {
        let wx = 8.4 + Double(i) * 1.45
        addBox(bus, "low_wire_\(i)", wx - 0.52, wx + 0.52, 10.0, 39.0, 5.2, 8.6, matCopperWire, chamfer: 0.25)
    }
    // Lower keypad branch combs entering pad_bot and pad_top from -X
    addBox(bus, "low_comb_1", 7.8, 17.5, 19.0, 22.0, 4.8, 9.2, matDarkCharcoal, chamfer: 0.3)
    addBox(bus, "low_comb_2", 7.8, 17.5, 34.5, 37.5, 4.8, 9.2, matDarkCharcoal, chamfer: 0.3)

    // Upper combed spine channel (running alongside LiPo & left of ESP32 crimps): X [7.5, 13.2], Y [39.2, 84.5], Z [8.7, 12.8]
    for i in 0..<4 {
        let wx = 8.2 + Double(i) * 1.35
        addBox(bus, "up_wire_\(i)", wx - 0.50, wx + 0.50, 39.2, 84.5, 9.2, 12.4, matCopperWire, chamfer: 0.25)
    }
    addBox(bus, "up_comb_mid", 7.5, 13.2, 50.0, 52.8, 8.7, 12.8, matDarkCharcoal, chamfer: 0.3)
    addBox(bus, "up_comb_top", 7.5, 13.2, 79.0, 81.8, 8.7, 12.8, matDarkCharcoal, chamfer: 0.3)

    parent.addChildNode(bus)

    aabbs.append(("combed_copper_lower", AABB(name: "lower_bus", minX: 7.5, maxX: 17.5, minY: 10.0, maxY: 39.0, minZ: 4.5, maxZ: 9.5)))
    aabbs.append(("combed_copper_upper", AABB(name: "upper_bus", minX: 7.5, maxX: 13.2, minY: 39.2, maxY: 84.5, minZ: 8.7, maxZ: 12.8)))
    return bus
}

func buildESP32LightMod(parent: SCNNode, aabbs: inout [(String, AABB)]) -> SCNNode {
    // 65.2 x 31.5 mm PCB seated at X [5.4, 70.6], Y [53.0, 84.5], Z [13.8, 15.4]
    let esp = SCNNode(); esp.name = "esp32_lightmod"
    addBox(esp, "esp_pcb", 5.4, 70.6, 53.0, 84.5, 13.8, 15.4, matPCBBlack, chamfer: 0.2)
    // WROOM-32 shield can & PCB antenna on right end
    addBox(esp, "wroom_can", 55.0, 68.5, 59.0, 78.5, 15.4, 17.1, matSteel, chamfer: 0.2)
    // Left USB-C receptacle & flash/reset buttons
    addBox(esp, "esp_usbc", 4.6, 12.0, 64.2, 73.2, 14.4, 17.3, matSteel, chamfer: 0.35)
    addBox(esp, "esp_boot_btn", 9.0, 13.0, 56.5, 60.0, 15.4, 16.9, matSteel)
    // 1.9" IPS glass & Audiobookshelf active panel on front (+Z), X [18.5, 67.5]
    addBox(esp, "ips_bezel", 18.5, 67.5, 56.0, 81.5, 15.4, 17.4, matScreenGlass, chamfer: 0.35)
    addBox(esp, "ips_active", 21.0, 63.7, 57.4, 80.1, 17.4, 17.55, matScreenUI)
    // Ribbons & Light-Mod flat-bent crimps under PCB (X [13.72, 62.2], Y [54.0, 83.5], Z [10.0, 13.8])
    addBox(esp, "bent_crimp_top", 13.72, 62.2, 79.0, 83.5, 10.0, 13.8, matAmberKapton, chamfer: 0.2)
    addBox(esp, "bent_crimp_bot", 13.72, 62.2, 54.0, 58.5, 10.0, 13.8, matAmberKapton, chamfer: 0.2)
    for px in stride(from: 14.8, through: 60.8, by: 2.54) {
        addBox(esp, "hpad_\(Int(px))", px - 0.5, px + 0.5, 81.8, 83.6, 14.8, 15.5, matGold)
        addBox(esp, "bpad_\(Int(px))", px - 0.5, px + 0.5, 54.0, 55.8, 14.8, 15.5, matGold)
    }

    parent.addChildNode(esp)

    aabbs.append(("esp32", AABB(name: "pcb_display", minX: 5.4, maxX: 70.6, minY: 53.0, maxY: 84.5, minZ: 13.8, maxZ: 17.5)))
    aabbs.append(("esp32", AABB(name: "bent_crimps", minX: 13.72, maxX: 62.2, minY: 54.0, maxY: 83.5, minZ: 10.0, maxZ: 13.8)))
    return esp
}

func buildWM8960NoSpk(parent: SCNNode, aabbs: inout [(String, AABB)]) -> SCNNode {
    // 65.0 x 30.0 mm PCB at ox=5.5, oy=85.8, oz=12.8 -> X [5.5, 70.5], Y [85.8, 115.8], Z [12.8, 14.4]
    let wm = SCNNode(); wm.name = "wm8960_hat"
    addBox(wm, "wm_pcb", 5.5, 70.5, 85.8, 115.8, 12.8, 14.4, matPCBBlack, chamfer: 0.2)
    // WM8960 codec QFN chip + gold passives
    addBox(wm, "wm_ic", 32.0, 39.0, 96.0, 103.0, 14.4, 15.6, matDarkCharcoal, chamfer: 0.1)
    // 3.5mm TRS stereo headphone jack exiting top wall (Y [104.0, 118.2], Z [14.4, 20.4])
    addBox(wm, "trs_housing", 18.0, 29.0, 104.5, 117.5, 14.4, 20.4, matDarkCharcoal, chamfer: 0.3)
    addCyl(wm, "trs_ring", r: 3.1, h: 2.0, cx: 23.5, cy: 117.2, cz: 17.4, axis: "y", matGold)
    // Dual onboard MEMS microphones (front)
    addBox(wm, "mems_L", 12.0, 16.0, 110.0, 113.5, 14.4, 15.8, matGold)
    addBox(wm, "mems_R", 59.0, 63.0, 110.0, 113.5, 14.4, 15.8, matGold)
    // Low-profile bent 40P harness exit along bottom edge (Y [86.0, 92.0], Z [9.4, 12.8])
    addBox(wm, "pi40_90deg", 13.0, 63.0, 86.0, 92.0, 9.4, 12.8, matWireInsul, chamfer: 0.25)
    for j in 0..<10 {
        let px = 15.0 + Double(j) * 4.8
        addBox(wm, "pi40_pin_\(j)", px - 0.5, px + 0.5, 87.0, 91.5, 11.4, 14.5, matGold)
    }

    parent.addChildNode(wm)

    aabbs.append(("wm8960", AABB(name: "pcb_trs", minX: 5.5, maxX: 70.5, minY: 85.8, maxY: 115.8, minZ: 12.8, maxZ: 20.4)))
    aabbs.append(("wm8960", AABB(name: "pi40_90deg", minX: 13.0, maxX: 63.0, minY: 86.0, maxY: 92.0, minZ: 9.4, maxZ: 12.8)))
    return wm
}

func buildMicroSDTopBay(parent: SCNNode, aabbs: inout [(String, AABB)]) -> SCNNode {
    // 42.0 x 24.0 mm PCB + cage seated in rear top bay: X [1.8, 43.8], Y [92.3, 116.3], Z [2.8, 8.8]
    let sd = SCNNode(); sd.name = "microsd_reader"
    addBox(sd, "sd_pcb", 1.8, 43.8, 92.3, 116.3, 2.8, 4.4, matPCBBlue, chamfer: 0.2)
    addBox(sd, "sd_cage", 6.0, 22.5, 100.0, 116.3, 4.4, 7.6, matSteel, chamfer: 0.15)
    // Inserted black MicroSD card tip barely visible in push-push slot
    addBox(sd, "sd_card", 8.5, 19.5, 114.5, 117.2, 4.9, 6.2, matDarkCharcoal)
    // 3.3V AMS1117 & 74LVC125A logic shifter ICs
    addBox(sd, "sd_ldo", 27.0, 34.0, 104.0, 111.0, 4.4, 6.4, matDarkCharcoal)
    // 6-pin low-pro SPI exit to right (+X): X [43.8, 47.0], Y [94.0, 110.0], Z [3.2, 6.8]
    addBox(sd, "sd_6p_exit", 43.8, 47.0, 94.0, 110.0, 3.2, 6.8, matCopperWire, chamfer: 0.2)
    parent.addChildNode(sd)

    aabbs.append(("microsd", AABB(name: "pcb_cage", minX: 1.8, maxX: 43.8, minY: 92.3, maxY: 116.3, minZ: 2.8, maxZ: 8.8)))
    aabbs.append(("microsd", AABB(name: "wire_exit", minX: 43.8, maxX: 47.0, minY: 94.0, maxY: 110.0, minZ: 3.2, maxZ: 6.8)))
    return sd
}

func buildUSBCChargerBoost(parent: SCNNode, aabbs: inout [(String, AABB)]) -> SCNNode {
    // 21 x 20 x 5.8 mm USB-C LiPo Charger + 5V Boost at X [48.5, 69.5], Y [93.0, 116.4], Z [2.2, 8.0]
    let chg = SCNNode(); chg.name = "usbc_lipo_boost"
    addBox(chg, "chg_pcb", 48.5, 69.5, 93.0, 111.0, 2.2, 3.8, matPCBBlack, chamfer: 0.15)
    addBox(chg, "chg_usbc", 54.5, 63.5, 108.5, 116.4, 3.8, 7.0, matSteel, chamfer: 0.3)
    addBox(chg, "chg_inductor", 51.0, 56.5, 96.0, 102.0, 3.8, 7.6, matDarkCharcoal, chamfer: 0.2)
    addBox(chg, "chg_ic", 59.5, 66.5, 97.0, 103.5, 3.8, 5.4, matDarkCharcoal)
    parent.addChildNode(chg)

    aabbs.append(("usbc_lipo_boost", AABB(name: "charger_boost", minX: 48.5, maxX: 69.5, minY: 93.0, maxY: 116.4, minZ: 2.2, maxZ: 8.0)))
    return chg
}

func buildCornerBossesAndScrews(parent: SCNNode, aabbs: inout [(String, AABB)]) -> (inserts: SCNNode, screws: SCNNode) {
    let inserts = SCNNode(); inserts.name = "m2_brass_inserts"
    let screws = SCNNode(); screws.name = "m2_black_screws"

    let bosses: [(String, Double, Double, Double, Double, Double, Double, Double, Double)] = [
        ("boss_bl", 1.6, 6.4,   1.6, 6.4,   1.6, 15.9,  4.0,  4.0),
        ("boss_br", 69.6, 74.4, 1.6, 6.4,   1.6, 15.9, 72.0,  4.0),
        ("boss_tl", 1.6, 5.2, 112.0, 116.4, 9.2, 20.6,  3.4, 114.2),
        ("boss_tr", 70.8, 74.4, 112.0, 116.4, 9.2, 20.6, 72.6, 114.2),
    ]

    for (name, x0, x1, y0, y1, z0, z1, cx, cy) in bosses {
        // Knurled M2 brass heat-set insert anchored into rear boss
        addCyl(inserts, "\(name)_brass", r: 1.55, h: 4.0, cx: cx, cy: cy, cz: z1 - 2.2, axis: "z", matBrassInsert)
        // Black M2 socket/hex cap screw seated flush at front lid face
        addCyl(screws, "\(name)_screw", r: 1.75, h: 1.4, cx: cx, cy: cy, cz: z1 + 0.8, axis: "z", matBlackScrew)
        addCyl(screws, "\(name)_shaft", r: 0.98, h: 5.0, cx: cx, cy: cy, cz: z1 - 1.5, axis: "z", matBlackScrew)
        aabbs.append((name, AABB(name: name, minX: x0, maxX: x1, minY: y0, maxY: y1, minZ: z0, maxZ: z1)))
    }
    parent.addChildNode(inserts)
    parent.addChildNode(screws)
    return (inserts, screws)
}

func buildTranslucentShellPieces(colorway: ShellColorway) -> (rear: SCNNode, front: SCNNode, bossSleeves: SCNNode) {
    let rear = SCNNode(); rear.name = "shell_rear_\(colorway.rawValue)"
    let front = SCNNode(); front.name = "shell_front_\(colorway.rawValue)"
    let bossSleeves = SCNNode(); bossSleeves.name = "shell_boss_sleeves"

    let m = colorway.bodyMat
    let e = colorway.edgeMat

    // Rear lower clam-shell (Y [0, 84.5], Z [0, 9.5]) & stepped audio back (Y [84.5, 118.0], Z [0, 11.5])
    addBox(rear, "rear_back_plate", 0, 76.0, 0, 118.0, 0, 1.6, m, chamfer: 1.2, renderOrder: 10)
    // Perimeter walls (lower)
    addBox(rear, "wall_L_low", 0, 1.6, 0, 84.5, 1.6, 17.5, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_R_low", 74.4, 76.0, 0, 84.5, 1.6, 17.5, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_B", 0, 76.0, 0, 1.6, 1.6, 17.5, e, chamfer: 0.6, renderOrder: 11)
    // Perimeter walls (top stepped 22.2mm audio bay)
    addBox(rear, "wall_L_hi", 0, 1.6, 84.5, 118.0, 1.6, 22.2, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_R_hi", 74.4, 76.0, 84.5, 118.0, 1.6, 22.2, e, chamfer: 0.6, renderOrder: 11)
    addBox(rear, "wall_T", 0, 76.0, 116.4, 118.0, 1.6, 22.2, e, chamfer: 0.6, renderOrder: 11)

    // Stepped top front bezel + flat translucent showcase front around screen & LiPo window
    // Top hump cover (Y [84.5, 118.0], Z [20.6, 22.2])
    addBox(front, "front_top_hump", 0, 76.0, 84.5, 118.0, 20.6, 22.2, m, chamfer: 0.9, renderOrder: 12)
    // Step riser bridging Z=17.5 to Z=22.2 at Y=84.5
    addBox(front, "front_step_riser", 0, 76.0, 83.2, 85.0, 16.2, 22.2, e, chamfer: 0.5, renderOrder: 12)
    // Lower showcase faceplate around buttons & LiPo window (Y [0, 84.5], Z [15.9, 17.5])
    addBox(front, "front_low_left_rib", 0, 19.5, 0, 56.0, 15.9, 17.5, m, chamfer: 0.4, renderOrder: 12)
    addBox(front, "front_low_right_rib", 56.5, 76.0, 0, 56.0, 15.9, 17.5, m, chamfer: 0.4, renderOrder: 12)
    // Panoramic translucent LiPo showcase lens (Y [39.0, 56.0], Z [15.9, 17.5])
    addBox(front, "front_lipo_window", 19.5, 56.5, 39.0, 56.0, 15.9, 17.5, m, chamfer: 0.2, renderOrder: 13)
    // Keypad faceplate bezel frames
    addBox(front, "front_pad_bot_frame", 19.5, 56.5, 0, 4.8, 15.9, 17.5, e, renderOrder: 12)
    addBox(front, "front_pad_mid_frame", 19.5, 56.5, 13.0, 25.4, 15.9, 17.5, e, renderOrder: 12)
    addBox(front, "front_pad_top_frame", 19.5, 56.5, 33.4, 39.0, 15.9, 17.5, e, renderOrder: 12)
    // Screen surround ribs (left translucent copper-channel showcase, right antenna border)
    addBox(front, "front_scr_left", 0, 21.0, 56.0, 84.5, 15.9, 17.5, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_scr_right", 63.7, 76.0, 56.0, 84.5, 15.9, 17.5, m, chamfer: 0.3, renderOrder: 12)
    addBox(front, "front_scr_top", 21.0, 63.7, 80.1, 84.5, 15.9, 17.5, e, renderOrder: 12)
    addBox(front, "front_scr_bot", 21.0, 63.7, 55.8, 57.4, 15.9, 17.5, e, renderOrder: 12)

    // Translucent internal corner standoffs
    let posts: [(Double, Double, Double, Double)] = [
        (4.0, 4.0, 1.6, 15.9), (72.0, 4.0, 1.6, 15.9),
        (3.4, 114.2, 9.2, 20.6), (72.6, 114.2, 9.2, 20.6)
    ]
    for (i, (cx, cy, z0, z1)) in posts.enumerated() {
        addCyl(bossSleeves, "boss_post_\(i)", r: 2.1, h: z1 - z0, cx: cx, cy: cy, cz: (z0 + z1) * 0.5, axis: "z", e, renderOrder: 9)
    }

    return (rear, front, bossSleeves)
}

func buildFullOptionP1Smoke(colorway: ShellColorway, exploded: Bool = false) -> (root: SCNNode, aabbs: [(String, AABB)]) {
    let root = SCNNode(); root.name = "Option_P1_\(colorway.rawValue)"
    var aabbs: [(String, AABB)] = []

    let layerRear = SCNNode(); layerRear.name = "Layer1_Rear"
    let layerLiPo = SCNNode(); layerLiPo.name = "Layer2_LiPo"
    let layerCtrl = SCNNode(); layerCtrl.name = "Layer3_Controls_Harness"
    let layerMain = SCNNode(); layerMain.name = "Layer4_ESP32_WM8960"
    let layerTop  = SCNNode(); layerTop.name  = "Layer5_TopBezel"
    let layerCaps = SCNNode(); layerCaps.name = "Layer5b_Keys_Screws"

    // Populate internals (preserving global AABB verification when unexploded)
    _ = buildKeypadLightMod(label: "pad_bot", origin: (19.5, 3.2, 3.8),
                            crimpLocalZ0: 1.6, crimpLocalZ1: 5.4,
                            keyLabels: ["BACK", "PLAY", "MARK", "REC"], rightOrange: true,
                            parent: layerCtrl, aabbs: &aabbs)
    _ = buildKeypadLightMod(label: "pad_top", origin: (19.5, 23.8, 4.8),
                            crimpLocalZ0: 3.9, crimpLocalZ1: 7.7,
                            keyLabels: ["◀", "▲", "▼", "▶"], rightOrange: false,
                            parent: layerCtrl, aabbs: &aabbs)

    // Move keycap groups up to Layer 5b so exploded view floats the 8 keycaps above the top bezel!
    for child in layerCtrl.childNodes where child.name?.hasSuffix("_caps") == true {
        child.removeFromParentNode()
        layerCaps.addChildNode(child)
    }

    _ = buildCombedCopperBus(parent: layerCtrl, aabbs: &aabbs)

    let (lipoNode, shieldNode) = buildLiPoAndShield(parent: layerLiPo, aabbs: &aabbs)
    _ = (lipoNode, shieldNode)

    _ = buildESP32LightMod(parent: layerMain, aabbs: &aabbs)
    _ = buildWM8960NoSpk(parent: layerMain, aabbs: &aabbs)

    _ = buildMicroSDTopBay(parent: layerRear, aabbs: &aabbs)
    _ = buildUSBCChargerBoost(parent: layerRear, aabbs: &aabbs)

    let (insertsNode, screwsNode) = buildCornerBossesAndScrews(parent: layerRear, aabbs: &aabbs)
    _ = insertsNode
    screwsNode.removeFromParentNode()
    layerCaps.addChildNode(screwsNode)

    let (rearShell, frontShell, bossSleeves) = buildTranslucentShellPieces(colorway: colorway)
    layerRear.addChildNode(rearShell)
    layerRear.addChildNode(bossSleeves)
    layerTop.addChildNode(frontShell)

    if exploded {
        // Shift layers cleanly along scnY (= +cadZ) so zero layers overlap in isometric 5-layer stack
        layerRear.position = SCNVector3(0, 0, 0)
        layerLiPo.position = SCNVector3(0, 32, 0)
        layerCtrl.position = SCNVector3(0, 62, 0)
        layerMain.position = SCNVector3(0, 90, 0)
        layerTop.position  = SCNVector3(0, 118, 0)
        layerCaps.position = SCNVector3(0, 138, 0)

        // Vertical cyan guide rails at 4 screw corners
        let guides = SCNNode(); guides.name = "ExplodeGuides"
        for (i, (gx, gy)) in [(4.0, 4.0), (72.0, 4.0), (3.4, 114.2), (72.6, 114.2)].enumerated() {
            addCyl(guides, "g_\(i)", r: 0.35, h: 158.0, cx: gx, cy: gy, cz: 79.0, axis: "z", matCyanGuide)
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

// MARK: - Studio Lighting, Camera, Export & Snapshot Helpers
func setupStudioLighting(_ scene: SCNScene, camPos: SCNVector3, lookAt: SCNVector3, fov: CGFloat = 32) {
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

    let amb = SCNNode(); amb.light = SCNLight(); amb.light?.type = .ambient
    amb.light?.intensity = 380
    amb.light?.color = NSColor(calibratedRed: 0.90, green: 0.94, blue: 1.0, alpha: 1)
    scene.rootNode.addChildNode(amb)

    let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional
    key.light?.intensity = 1350
    key.light?.color = NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.95, alpha: 1)
    key.position = SCNVector3(180, 320, 240)
    key.look(at: lookAt)
    scene.rootNode.addChildNode(key)

    let rim = SCNNode(); rim.light = SCNLight(); rim.light?.type = .directional
    rim.light?.intensity = 850
    rim.light?.color = NSColor(calibratedRed: 0.65, green: 0.85, blue: 1.0, alpha: 1)
    rim.position = SCNVector3(-240, 220, -260)
    rim.look(at: lookAt)
    scene.rootNode.addChildNode(rim)

    let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .omni
    fill.light?.intensity = 420
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
    scaled.scale = SCNVector3(0.001, 0.001, 0.001) // 1 mm -> 0.001 m
    scene.rootNode.addChildNode(scaled)
    let outPath = "\(usdzDir)/\(fileName)"
    let outURL = URL(fileURLWithPath: outPath)
    let ok = scene.write(to: outURL, options: nil, delegate: nil, progressHandler: nil)
    if !ok {
        throw NSError(domain: "USDZExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to write \(outPath)"])
    }
    print("EXPORTED USDZ: \(outPath)")
}

// MARK: - 1:1 Calibration Props
func buildMetricRuler(width: Double = 160.0) -> SCNNode {
    let r = SCNNode(); r.name = "MetricRuler_160mm"
    let matRuler = drawImage(width: 1200, height: 180) { ctx in
        ctx.setFillColor(NSColor(calibratedRed: 0.78, green: 0.80, blue: 0.83, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 180))
        ctx.setStrokeColor(NSColor.black.cgColor)
        let pxPerMm = 1200.0 / width
        for mm in 0...Int(width) {
            let x = CGFloat(Double(mm) * pxPerMm)
            let h: CGFloat = (mm % 10 == 0) ? 58 : ((mm % 5 == 0) ? 40 : 24)
            ctx.setLineWidth(mm % 10 == 0 ? 3.0 : 1.5)
            ctx.move(to: CGPoint(x: x, y: 180))
            ctx.addLine(to: CGPoint(x: x, y: 180 - h))
            if mm % 20 == 0 && mm < 160 {
                let a: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 28, weight: .bold), .foregroundColor: NSColor.black]
                NSAttributedString(string: "\(mm)", attributes: a).draw(at: NSPoint(x: max(2, x + 4), y: 84))
            }
        }
        ctx.strokePath()
        let lab: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 26, weight: .bold), .foregroundColor: NSColor.darkGray]
        NSAttributedString(string: "160 mm CALIBRATION STEEL RULE (1:1)", attributes: lab).draw(at: NSPoint(x: 24, y: 24))
    }
    addBox(r, "ruler_body", 0, width, 0, 18.0, 0, 1.0, texMat(matRuler, roughness: 0.28, metalness: 0.85), chamfer: 0.2)
    return r
}

func buildAirPodsProCase() -> SCNNode {
    // 60.6 x 45.2 x 21.7 mm
    let ap = SCNNode(); ap.name = "AirPodsProCase_21p7mm"
    let whiteGloss = pbrMat(0.95, 0.96, 0.98, 1.0, roughness: 0.14, metalness: 0.04)
    addBox(ap, "ap_case", 0, 60.6, 0, 45.2, 0, 21.7, whiteGloss, chamfer: 6.5)
    addBox(ap, "ap_seam", 0.2, 60.4, 29.0, 29.5, 0.2, 21.5, matDarkCharcoal)
    addCyl(ap, "ap_led", r: 1.0, h: 0.4, cx: 30.3, cy: 23.0, cz: 21.7, axis: "z", matPCBGreen)
    return ap
}

func buildISOCreditCard() -> SCNNode {
    // 85.6 x 54.0 x 0.8 mm
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
    // 71.5 x 147.6 x 8.25 mm smartphone for pocketability scale comparison
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

// MARK: - Build & Verify Geometry + Export 3 USDZs + Render 3 Calibrated PNG Guides
let (smokeRoot, smokeAABBs) = buildFullOptionP1Smoke(colorway: .atomicSmoke, exploded: false)
let collisionCount = verifyAABBs(label: "Option_P1_Smoke_8Btn", boxes: smokeAABBs)
if collisionCount > 0 {
    fputs("FATAL: Non-zero CAD collisions detected (\(collisionCount))\n", stderr)
    exit(2)
}

// Export 3 USDZ deliverables
try exportUSDZ(smokeRoot, fileName: "12a_p1_atomic_smoke_8btn_showcase.usdz")
let (explodedRoot, _) = buildFullOptionP1Smoke(colorway: .atomicSmoke, exploded: true)
try exportUSDZ(explodedRoot, fileName: "12b_p1_atomic_smoke_8btn_exploded.usdz")

// Colorway lineup USDZ
let colorSceneNode = SCNNode(); colorSceneNode.name = "Translucent_8Btn_Colorways"
let uSmoke = buildFullOptionP1Smoke(colorway: .atomicSmoke).root; uSmoke.position = SCNVector3(0, 0, 0)
let uIce   = buildFullOptionP1Smoke(colorway: .frostedClearIce).root; uIce.position = SCNVector3(96, 0, 0)
let uPurp  = buildFullOptionP1Smoke(colorway: .atomicPurple).root; uPurp.position = SCNVector3(192, 0, 0)
colorSceneNode.addChildNode(uSmoke)
colorSceneNode.addChildNode(uIce)
colorSceneNode.addChildNode(uPurp)
try exportUSDZ(colorSceneNode, fileName: "12c_p1_translucent_8btn_colorways.usdz")

// MARK: - Render Guide 12a: 3 Colorways + Calibration Props
do {
    let s = SCNScene()
    let matW = 470.0, matH = 270.0
    let matTex = makeCuttingMatTexture(widthMm: matW, heightMm: matH, label: "10 mm METRIC GRID  |  OPTION P1-SMOKE 8-BTN COLORWAYS (76.0 × 118.0 × 17.5 / 22.2 mm)")
    addBox(s.rootNode, "cutting_mat", -105, matW - 105, -75, matH - 75, -2.0, 0.0, texMat(matTex, roughness: 0.85, metalness: 0.02))

    let a1 = buildFullOptionP1Smoke(colorway: .atomicSmoke).root; a1.position = SCNVector3(0, 0, 0)
    let a2 = buildFullOptionP1Smoke(colorway: .frostedClearIce).root; a2.position = SCNVector3(102, 0, 0)
    let a3 = buildFullOptionP1Smoke(colorway: .atomicPurple).root; a3.position = SCNVector3(204, 0, 0)
    s.rootNode.addChildNode(a1); s.rootNode.addChildNode(a2); s.rootNode.addChildNode(a3)

    // Perimeter 1:1 props cleanly separated from all 3 units (>= 10mm gap)
    let card = buildISOCreditCard(); card.position = SCNVector3(-96, 0, 12)
    let ruler = buildMetricRuler(); ruler.position = SCNVector3(60, 0, 38)
    let ap = buildAirPodsProCase(); ap.position = SCNVector3(294, 0, 8)
    let plug = buildAudioPlug35mm(); plug.position = SCNVector3(-56, 0, -90)
    s.rootNode.addChildNode(card); s.rootNode.addChildNode(ruler); s.rootNode.addChildNode(ap); s.rootNode.addChildNode(plug)

    setupStudioLighting(s, camPos: SCNVector3(135, 380, 215), lookAt: SCNVector3(135, 14, -44), fov: 36)
    let raw = renderSceneToImage(s)
    let final12a = overlayHeaderOnImage(
        raw,
        title: "REF 12A • OPTION P1 TRANSLUCENT 8-BUTTON COLORWAYS (1:1 METAL CAD)",
        subtitle: "Left: Atomic Smoke  |  Center: Frosted Clear Ice  |  Right: 90s Atomic Purple   (All 76.0 × 118.0 × 17.5 / 22.2 mm)",
        footer: "Props: ISO Credit Card (85.6×54 mm)  •  160 mm Metric Rule  •  AirPods Pro 2 Case (21.7 mm thick vs 17.5 mm lower grip)  •  3.5 mm TRS"
    )
    try savePNG(final12a, path1: "\(renderDir)/ref_12a_8btn_translucent_colorways_guide.png",
                path2: "\(artifactDir)/ref_12a_8btn_translucent_colorways_guide.png")
    print("RENDERED 12a guide")
}

// MARK: - Render Guide 12b: 5-Layer Isometric Exploded Assembly (No Top/Bottom Clipping)
do {
    let s = SCNScene()
    let matW = 360.0, matH = 280.0
    let matTex = makeCuttingMatTexture(widthMm: matW, heightMm: matH, label: "5-LAYER ISOMETRIC EXPLODED STACK  |  COLLISIONS: \(collisionCount)")
    addBox(s.rootNode, "cutting_mat", -130, matW - 130, -90, matH - 90, -2.0, 0.0, texMat(matTex, roughness: 0.85, metalness: 0.02))

    let (ex, _) = buildFullOptionP1Smoke(colorway: .atomicSmoke, exploded: true)
    ex.position = SCNVector3(0, 0, 0)
    s.rootNode.addChildNode(ex)

    setupStudioLighting(s, camPos: SCNVector3(245, 255, 195), lookAt: SCNVector3(38, 76, -59), fov: 38)
    let raw = renderSceneToImage(s)
    let final12b = overlayHeaderOnImage(
        raw,
        title: "REF 12B • OPTION P1-SMOKE 5-LAYER EXPLODED ASSEMBLY (1:1 METAL CAD)",
        subtitle: "L1: Rear Shell+4×M2 Brass+SD+USB-C Boost  →  L2: 604060 LiPo+Shield  →  L3: Copper Harness+Twin 1×4 PCBs  →  L4: ESP32+WM8960  →  L5: Top Bezel+8 Keys+M2",
        footer: "Verified Collisions: \(collisionCount) across 14 hardware & boss volumes  •  Twin Green 1×4 Keypads  •  Left-Spine Combed Copper Bus"
    )
    try savePNG(final12b, path1: "\(renderDir)/ref_12b_8btn_atomic_smoke_exploded_guide.png",
                path2: "\(artifactDir)/ref_12b_8btn_atomic_smoke_exploded_guide.png")
    print("RENDERED 12b guide")
}

// MARK: - Render Guide 12c: One-Handed Scale & Pocketability Comparison
do {
    let s = SCNScene()
    let matW = 420.0, matH = 270.0
    let matTex = makeCuttingMatTexture(widthMm: matW, heightMm: matH, label: "1:1 ERGONOMICS & POCKET FIT  |  P1-SMOKE (17.5 / 22.2 mm) vs AIRPODS (21.7 mm) vs SMARTPHONE (8.25 mm)")
    addBox(s.rootNode, "cutting_mat", -75, matW - 75, -60, matH - 60, -2.0, 0.0, texMat(matTex, roughness: 0.85, metalness: 0.02))

    // Left Zone: Device at 1:1 with rear palm footprint & subtle thumb reach halo + 3.5mm plug inserted at top
    let devL = buildFullOptionP1Smoke(colorway: .atomicSmoke).root; devL.position = SCNVector3(0, 0, 0)
    s.rootNode.addChildNode(devL)
    let plugIn = buildAudioPlug35mm(); plugIn.position = SCNVector3(23.5, 13.0, -131.5)
    s.rootNode.addChildNode(plugIn)
    let palmGhost = pbrMat(0.28, 0.72, 0.88, 0.20, roughness: 0.6, metalness: 0.0, depthWrite: false)
    addBox(s.rootNode, "palm_width_85mm", -6, 79, -16, 92, 0.2, 1.4, palmGhost, chamfer: 8.0, renderOrder: 1)
    let thumbHalo = pbrMat(0.28, 0.82, 0.94, 0.14, roughness: 0.4, metalness: 0.0, depthWrite: false)
    addCyl(s.rootNode, "thumb_sweep_zone", r: 30.0, h: 0.6, cx: 48.0, cy: 20.0, cz: 19.2, axis: "z", thumbHalo, renderOrder: 20)

    // Right Zone: 1:1 Front Jeans Pocket Width (145 mm) & Thickness Comparison
    let denimProxy = pbrMat(0.14, 0.22, 0.36, 0.88, roughness: 0.88, metalness: 0.02)
    addBox(s.rootNode, "jeans_pocket_145x165", 132, 277, -10, 155, 0.0, 2.5, denimProxy, chamfer: 2.0)
    let devPocket = buildFullOptionP1Smoke(colorway: .atomicSmoke).root; devPocket.position = SCNVector3(148, 3.0, 0)
    let apSide = buildAirPodsProCase(); apSide.position = SCNVector3(244, 3.0, 22)
    let phoneRef = buildPhoneProxy(); phoneRef.position = SCNVector3(244, 3.0, -32)
    s.rootNode.addChildNode(devPocket); s.rootNode.addChildNode(apSide); s.rootNode.addChildNode(phoneRef)

    setupStudioLighting(s, camPos: SCNVector3(142, 390, 225), lookAt: SCNVector3(142, 12, -52), fov: 38)
    let raw = renderSceneToImage(s)
    let final12c = overlayHeaderOnImage(
        raw,
        title: "REF 12C • ONE-HANDED THUMB REACH & FRONT JEANS POCKET SCALE (1:1 METAL CAD)",
        subtitle: "Left: 76×118 mm Unit + 3.5 mm Top IEM Plug + 85 mm Palm / Thumb Sweep Zone   |   Right: 145 mm Pocket Zone vs AirPods Pro (21.7 mm) & Phone",
        footer: "17.5 mm Lower Grip clears every AirPods Pro case by 4.2 mm  •  168.7 cm³ Total Volume  •  Both 1×4 Rows inside single-thumb arc"
    )
    try savePNG(final12c, path1: "\(renderDir)/ref_12c_8btn_atomic_smoke_hand_pocket_guide.png",
                path2: "\(artifactDir)/ref_12c_8btn_atomic_smoke_hand_pocket_guide.png")
    print("RENDERED 12c guide")
}

print("ALL_12_SHOWCASE_GENERATION_DONE collisions=\(collisionCount)")
