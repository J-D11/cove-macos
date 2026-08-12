import AppKit

enum CoveMark {
    static func image(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let stroke = NSBezierPath()
            stroke.lineWidth = max(1.5, size * 0.105)
            stroke.lineCapStyle = .round
            stroke.lineJoinStyle = .round

            let inset = size * 0.15
            stroke.move(to: NSPoint(x: inset, y: size * 0.61))
            stroke.curve(
                to: NSPoint(x: size - inset, y: size * 0.61),
                controlPoint1: NSPoint(x: size * 0.31, y: size * 0.26),
                controlPoint2: NSPoint(x: size * 0.69, y: size * 0.26)
            )
            stroke.move(to: NSPoint(x: size * 0.25, y: size * 0.72))
            stroke.curve(
                to: NSPoint(x: size * 0.75, y: size * 0.72),
                controlPoint1: NSPoint(x: size * 0.38, y: size * 0.90),
                controlPoint2: NSPoint(x: size * 0.62, y: size * 0.90)
            )
            NSColor.labelColor.setStroke()
            stroke.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Cove"
        return image
    }
}
