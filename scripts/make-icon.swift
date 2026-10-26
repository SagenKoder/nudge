// Draws the Nudge app icon and writes Support/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

let canvas: CGFloat = 1024

func draw(in ctx: CGContext) {
    // macOS icon grid: an 824pt rounded square centred on a 1024pt canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    let rgb = CGColorSpaceCreateDeviceRGB()

    // Drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(CGColor(red: 0.20, green: 0.22, blue: 0.55, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Indigo to blue background.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let background = CGGradient(colorsSpace: rgb, colors: [
        CGColor(red: 0.36, green: 0.31, blue: 0.93, alpha: 1),
        CGColor(red: 0.13, green: 0.55, blue: 0.98, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    ctx.restoreGState()

    // The screen: a faint outline with the right half empty.
    let screen = CGRect(x: 210, y: 270, width: 604, height: 484)
    let screenPath = CGPath(roundedRect: screen, cornerWidth: 44, cornerHeight: 44, transform: nil)
    ctx.addPath(screenPath)
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.12))
    ctx.fillPath()
    ctx.addPath(screenPath)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.55))
    ctx.setLineWidth(14)
    ctx.strokePath()

    // The window, snapped into the left half.
    let window = CGRect(x: 236, y: 296, width: 270, height: 432)
    let windowPath = CGPath(roundedRect: window, cornerWidth: 26, cornerHeight: 26, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: CGColor(gray: 0, alpha: 0.25))
    ctx.addPath(windowPath)
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Title bar with traffic lights.
    ctx.saveGState()
    ctx.addPath(windowPath)
    ctx.clip()
    ctx.setFillColor(CGColor(red: 0.90, green: 0.92, blue: 0.98, alpha: 1))
    ctx.fill(CGRect(x: window.minX, y: window.maxY - 58, width: window.width, height: 58))
    ctx.restoreGState()
    let lights = [
        CGColor(red: 1.00, green: 0.37, blue: 0.34, alpha: 1),
        CGColor(red: 1.00, green: 0.74, blue: 0.18, alpha: 1),
        CGColor(red: 0.16, green: 0.79, blue: 0.25, alpha: 1),
    ]
    for (i, color) in lights.enumerated() {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: window.minX + 26 + CGFloat(i) * 36, y: window.maxY - 41, width: 24, height: 24))
    }

    // Motion trails fading out to the right: the window was just nudged left.
    let trail = CGGradient(colorsSpace: rgb, colors: [
        CGColor(gray: 1, alpha: 0.95),
        CGColor(gray: 1, alpha: 0),
    ] as CFArray, locations: [0, 1])!
    for (y, length, width) in [(620.0, 170.0, 26.0), (512.0, 250.0, 32.0), (404.0, 170.0, 26.0)] {
        let start = window.maxX + 28
        let path = CGMutablePath()
        path.move(to: CGPoint(x: start, y: y))
        path.addLine(to: CGPoint(x: start + length, y: y))
        ctx.saveGState()
        ctx.addPath(path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 1))
        ctx.clip()
        ctx.drawLinearGradient(trail, start: CGPoint(x: start - width / 2, y: y), end: CGPoint(x: start + length, y: y), options: [])
        ctx.restoreGState()
    }
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let ctx = context.cgContext
    ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    draw(in: ctx)
    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try png(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try png(size: 1024).write(to: root.appendingPathComponent("Support/AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Support/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Support/AppIcon.icns" : "iconutil failed")
