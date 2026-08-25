import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_cove_icon.swift <output.png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size: CGFloat = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bitmapFormat: .alphaFirst,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("failed to create icon canvas\n", stderr)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
defer { NSGraphicsContext.restoreGraphicsState() }

let tileRect = NSRect(x: 64, y: 64, width: 896, height: 896)
NSColor(calibratedRed: 0.015, green: 0.025, blue: 0.045, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 232, yRadius: 232).fill()

let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 216, yRadius: 216)
tilePath.addClip()
NSGradient(
    colors: [
        NSColor(calibratedRed: 0.025, green: 0.04, blue: 0.075, alpha: 1),
        NSColor(calibratedRed: 0.055, green: 0.10, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.11, alpha: 1)
    ]
)?.draw(in: tileRect, angle: -45)

let innerBorder = NSBezierPath(roundedRect: NSRect(x: 76, y: 76, width: 872, height: 872), xRadius: 204, yRadius: 204)
innerBorder.lineWidth = 3
NSColor(calibratedRed: 0.72, green: 0.86, blue: 1, alpha: 0.16).setStroke()
innerBorder.stroke()

func waveRibbon(in rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }

    path.move(to: point(0.02, 0.43))
    path.curve(
        to: point(0.50, 0.62),
        controlPoint1: point(0.16, 0.77),
        controlPoint2: point(0.35, 0.78)
    )
    path.curve(
        to: point(0.96, 0.57),
        controlPoint1: point(0.68, 0.44),
        controlPoint2: point(0.82, 0.43)
    )
    path.curve(
        to: point(0.82, 0.27),
        controlPoint1: point(0.94, 0.43),
        controlPoint2: point(0.90, 0.33)
    )
    path.curve(
        to: point(0.48, 0.36),
        controlPoint1: point(0.68, 0.19),
        controlPoint2: point(0.57, 0.22)
    )
    path.curve(
        to: point(0.00, 0.25),
        controlPoint1: point(0.31, 0.50),
        controlPoint2: point(0.15, 0.52)
    )
    path.close()
    return path
}

func drawWave(in rect: NSRect, colors: [NSColor], shadowColor: NSColor) {
    let path = waveRibbon(in: rect)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = shadowColor.withAlphaComponent(0.72)
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    colors.last?.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(colors: colors)?.draw(in: rect, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    path.lineWidth = 3
    NSColor.white.withAlphaComponent(0.17).setStroke()
    path.stroke()
}

drawWave(
    in: NSRect(x: 218, y: 270, width: 588, height: 248),
    colors: [
        NSColor(calibratedRed: 0.015, green: 0.20, blue: 0.52, alpha: 1),
        NSColor(calibratedRed: 0.00, green: 0.34, blue: 0.76, alpha: 1)
    ],
    shadowColor: NSColor(calibratedRed: 0.00, green: 0.08, blue: 0.22, alpha: 1)
)
drawWave(
    in: NSRect(x: 198, y: 390, width: 628, height: 258),
    colors: [
        NSColor(calibratedRed: 0.00, green: 0.36, blue: 0.82, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.52, blue: 0.98, alpha: 1)
    ],
    shadowColor: NSColor(calibratedRed: 0.00, green: 0.12, blue: 0.34, alpha: 1)
)
drawWave(
    in: NSRect(x: 178, y: 516, width: 668, height: 270),
    colors: [
        NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.26, green: 0.72, blue: 1.00, alpha: 1)
    ],
    shadowColor: NSColor(calibratedRed: 0.00, green: 0.20, blue: 0.55, alpha: 1)
)

guard let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
    fputs("failed to encode icon\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
