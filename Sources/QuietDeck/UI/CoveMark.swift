import AppKit

enum CoveMark {
    static func image(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let waves = [
                NSRect(x: size * 0.08, y: size * 0.55, width: size * 0.84, height: size * 0.34),
                NSRect(x: size * 0.10, y: size * 0.34, width: size * 0.80, height: size * 0.32),
                NSRect(x: size * 0.12, y: size * 0.13, width: size * 0.76, height: size * 0.30)
            ]
            NSColor.labelColor.setFill()
            for wave in waves.reversed() {
                waveRibbon(in: wave).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Cove"
        return image
    }

    private static func waveRibbon(in rect: NSRect) -> NSBezierPath {
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
}
