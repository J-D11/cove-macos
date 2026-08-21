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
NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.09, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 232, yRadius: 232).fill()

let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 216, yRadius: 216)
tilePath.addClip()
NSGradient(
    colors: [
        NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.15, alpha: 1),
        NSColor(calibratedRed: 0.11, green: 0.19, blue: 0.28, alpha: 1),
        NSColor(calibratedRed: 0.06, green: 0.29, blue: 0.35, alpha: 1)
    ]
)?.draw(in: tileRect, angle: -45)

let innerBorder = NSBezierPath(roundedRect: NSRect(x: 76, y: 76, width: 872, height: 872), xRadius: 204, yRadius: 204)
innerBorder.lineWidth = 4
NSColor(calibratedRed: 0.84, green: 1, blue: 1, alpha: 0.18).setStroke()
innerBorder.stroke()

func drawWave(
    start: NSPoint,
    control1: NSPoint,
    control2: NSPoint,
    end: NSPoint,
    color: NSColor
) {
    let path = NSBezierPath()
    path.move(to: start)
    path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
    path.lineWidth = 38
    path.lineCapStyle = .round
    path.lineJoinStyle = .round

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color.withAlphaComponent(0.55)
    shadow.shadowBlurRadius = 22
    shadow.set()
    color.setStroke()
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()

    color.setStroke()
    path.stroke()
}

drawWave(
    start: NSPoint(x: 230, y: 474),
    control1: NSPoint(x: 356, y: 304),
    control2: NSPoint(x: 668, y: 304),
    end: NSPoint(x: 794, y: 474),
    color: NSColor(calibratedRed: 0.96, green: 1, blue: 1, alpha: 1)
)
drawWave(
    start: NSPoint(x: 250, y: 576),
    control1: NSPoint(x: 386, y: 724),
    control2: NSPoint(x: 638, y: 724),
    end: NSPoint(x: 774, y: 576),
    color: NSColor(calibratedRed: 0.38, green: 0.88, blue: 0.84, alpha: 1)
)

guard let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
    fputs("failed to encode icon\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
