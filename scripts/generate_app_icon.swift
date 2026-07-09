import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("MacExplorer.iconset", isDirectory: true)
let iconURL = resourcesURL.appendingPathComponent("MacExplorer.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconVariant {
    let points: Int
    let scale: Int

    var pixels: Int { points * scale }

    var filename: String {
        scale == 1
            ? "icon_\(points)x\(points).png"
            : "icon_\(points)x\(points)@2x.png"
    }
}

let variants = [
    IconVariant(points: 16, scale: 1),
    IconVariant(points: 16, scale: 2),
    IconVariant(points: 32, scale: 1),
    IconVariant(points: 32, scale: 2),
    IconVariant(points: 128, scale: 1),
    IconVariant(points: 128, scale: 2),
    IconVariant(points: 256, scale: 1),
    IconVariant(points: 256, scale: 2),
    IconVariant(points: 512, scale: 1),
    IconVariant(points: 512, scale: 2)
]

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let scale = CGFloat(size) / 1024
    func r(_ value: CGFloat) -> CGFloat { value * scale }
    func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    func drawWithShadow(
        color shadowColor: NSColor,
        blur: CGFloat,
        offset: NSSize,
        drawing: () -> Void
    ) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowBlurRadius = blur
        shadow.shadowOffset = offset
        shadow.set()
        drawing()
        NSGraphicsContext.restoreGraphicsState()
    }

    let baseRect = NSRect(x: r(74), y: r(64), width: r(876), height: r(900))
    let base = NSBezierPath(roundedRect: baseRect, xRadius: r(206), yRadius: r(206))
    drawWithShadow(color: .black.withAlphaComponent(0.24), blur: r(34), offset: NSSize(width: 0, height: -r(18))) {
        NSGradient(
            starting: color(0.08, 0.22, 0.56),
            ending: color(0.13, 0.78, 0.93)
        )?.draw(in: base, angle: 88)
    }

    NSGraphicsContext.saveGraphicsState()
    base.addClip()
    color(1, 1, 1, 0.18).setFill()
    NSBezierPath(ovalIn: NSRect(x: r(118), y: r(646), width: r(620), height: r(360))).fill()
    color(0.02, 0.08, 0.25, 0.16).setFill()
    NSBezierPath(ovalIn: NSRect(x: r(238), y: r(6), width: r(680), height: r(250))).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.28).setStroke()
    base.lineWidth = r(8)
    base.stroke()

    let windowRect = NSRect(x: r(166), y: r(244), width: r(692), height: r(584))
    let windowPath = NSBezierPath(roundedRect: windowRect, xRadius: r(64), yRadius: r(64))
    drawWithShadow(color: .black.withAlphaComponent(0.24), blur: r(28), offset: NSSize(width: 0, height: -r(14))) {
        color(0.96, 0.98, 1, 0.96).setFill()
        windowPath.fill()
    }

    NSGradient(
        starting: color(1, 1, 1),
        ending: color(0.86, 0.91, 0.97)
    )?.draw(in: windowPath, angle: 90)

    NSGraphicsContext.saveGraphicsState()
    windowPath.addClip()

    color(0.88, 0.92, 0.98).setFill()
    NSBezierPath(rect: NSRect(x: r(166), y: r(710), width: r(692), height: r(118))).fill()

    color(0.90, 0.95, 1).setFill()
    NSBezierPath(rect: NSRect(x: r(198), y: r(288), width: r(176), height: r(410))).fill()

    color(0.76, 0.84, 0.94, 0.72).setStroke()
    for y in [r(640), r(566), r(492), r(418), r(344)] {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: r(410), y: y))
        line.line(to: NSPoint(x: r(798), y: y))
        line.lineWidth = r(5)
        line.lineCapStyle = .round
        line.stroke()
    }

    color(0.60, 0.72, 0.88, 0.52).setStroke()
    let sidebarSeparator = NSBezierPath()
    sidebarSeparator.move(to: NSPoint(x: r(374), y: r(286)))
    sidebarSeparator.line(to: NSPoint(x: r(374), y: r(706)))
    sidebarSeparator.lineWidth = r(4)
    sidebarSeparator.stroke()

    NSGraphicsContext.restoreGraphicsState()

    color(0.16, 0.22, 0.35, 0.18).setStroke()
    windowPath.lineWidth = r(5)
    windowPath.stroke()

    for (index, dotColor) in [color(0.98, 0.37, 0.34), color(1.0, 0.75, 0.28), color(0.31, 0.78, 0.43)].enumerated() {
        dotColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: r(226 + CGFloat(index) * 48), y: r(754), width: r(28), height: r(28))).fill()
    }

    let addressBar = NSBezierPath(roundedRect: NSRect(x: r(394), y: r(746), width: r(350), height: r(42)), xRadius: r(21), yRadius: r(21))
    color(1, 1, 1, 0.82).setFill()
    addressBar.fill()
    color(0.58, 0.70, 0.84, 0.38).setStroke()
    addressBar.lineWidth = r(3)
    addressBar.stroke()

    let folderBack = NSBezierPath(roundedRect: NSRect(x: r(282), y: r(404), width: r(484), height: r(244)), xRadius: r(42), yRadius: r(42))
    drawWithShadow(color: .black.withAlphaComponent(0.22), blur: r(22), offset: NSSize(width: 0, height: -r(10))) {
        color(0.06, 0.45, 0.88).setFill()
        folderBack.fill()
    }

    let tab = NSBezierPath(roundedRect: NSRect(x: r(306), y: r(610), width: r(206), height: r(82)), xRadius: r(32), yRadius: r(32))
    NSGradient(
        starting: color(0.34, 0.83, 1),
        ending: color(0.08, 0.55, 0.94)
    )?.draw(in: tab, angle: 90)

    let folderFront = NSBezierPath(roundedRect: NSRect(x: r(236), y: r(306), width: r(560), height: r(318)), xRadius: r(56), yRadius: r(56))
    NSGradient(
        starting: color(0.37, 0.86, 1),
        ending: color(0.05, 0.40, 0.89)
    )?.draw(in: folderFront, angle: 90)

    NSGraphicsContext.saveGraphicsState()
    folderFront.addClip()
    color(1, 1, 1, 0.18).setFill()
    NSBezierPath(ovalIn: NSRect(x: r(250), y: r(498), width: r(520), height: r(170))).fill()
    color(0.01, 0.14, 0.48, 0.16).setFill()
    NSBezierPath(rect: NSRect(x: r(236), y: r(306), width: r(560), height: r(86))).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.34).setStroke()
    folderFront.lineWidth = r(8)
    folderFront.stroke()

    let pathLine = NSBezierPath()
    pathLine.move(to: NSPoint(x: r(328), y: r(456)))
    pathLine.line(to: NSPoint(x: r(438), y: r(456)))
    pathLine.line(to: NSPoint(x: r(500), y: r(516)))
    pathLine.line(to: NSPoint(x: r(694), y: r(516)))
    NSColor.white.withAlphaComponent(0.93).setStroke()
    pathLine.lineWidth = r(34)
    pathLine.lineCapStyle = .round
    pathLine.lineJoinStyle = .round
    pathLine.stroke()

    color(0.57, 0.90, 1, 0.36).setStroke()
    let lowerGleam = NSBezierPath()
    lowerGleam.move(to: NSPoint(x: r(316), y: r(358)))
    lowerGleam.line(to: NSPoint(x: r(704), y: r(358)))
    lowerGleam.lineWidth = r(5)
    lowerGleam.lineCapStyle = .round
    lowerGleam.stroke()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try data.write(to: url)
}

for variant in variants {
    let image = drawIcon(size: variant.pixels)
    try writePNG(image, to: iconsetURL.appendingPathComponent(variant.filename), pixels: variant.pixels)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", iconURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus))
}

print(iconURL.path)
