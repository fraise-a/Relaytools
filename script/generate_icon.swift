import AppKit
import Foundation

// Vector source for the macOS icon. Regenerate with: swift script/generate_icon.swift
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets", isDirectory: true)
let iconset = assets.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 186, yRadius: 186)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(calibratedRed: 0.10, green: 0.43, blue: 0.38, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.12, green: 0.43, blue: 0.39, alpha: 1),
        NSColor(calibratedRed: 0.14, green: 0.56, blue: 0.49, alpha: 1),
        NSColor(calibratedRed: 0.27, green: 0.69, blue: 0.61, alpha: 1)
    ])!
    gradient.draw(in: tile, angle: 90)

    NSColor.white.withAlphaComponent(0.17).setStroke()
    tile.lineWidth = 2
    tile.stroke()

    // A single bold upward-right relay arrow, matching the in-app brand mark.
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 345, y: 340))
    arrow.line(to: NSPoint(x: 671, y: 666))
    arrow.move(to: NSPoint(x: 398, y: 666))
    arrow.line(to: NSPoint(x: 671, y: 666))
    arrow.line(to: NSPoint(x: 671, y: 393))
    arrow.lineWidth = 76
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSGraphicsContext.saveGraphicsState()
    let markShadow = NSShadow()
    markShadow.shadowColor = NSColor.black.withAlphaComponent(0.12)
    markShadow.shadowBlurRadius = 9
    markShadow.shadowOffset = NSSize(width: 0, height: -5)
    markShadow.set()
    NSColor.white.setStroke()
    arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        try drawIcon(size: points * scale).write(to: iconset.appendingPathComponent(name))
    }
}
try drawIcon(size: 1024).write(to: assets.appendingPathComponent("AppIcon.png"))
print("Generated AppIcon.png and all ten macOS icon representations.")
