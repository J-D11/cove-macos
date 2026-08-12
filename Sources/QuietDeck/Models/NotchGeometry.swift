import CoreGraphics

enum NotchGeometry {
    static let expandedSize = CGSize(width: 500, height: 72)
    static let minimumCollapsedWidth: CGFloat = 176
    static let collapsedHeight: CGFloat = 7

    static func panelFrame(
        screenFrame: CGRect,
        topInset: CGFloat,
        notchWidth: CGFloat?,
        expanded: Bool,
        expandedWidth: CGFloat? = nil
    ) -> CGRect {
        let resolvedInset = topInset > 0 ? topInset : 28
        let size: CGSize

        if expanded {
            size = CGSize(
                width: expandedWidth ?? expandedSize.width,
                height: expandedSize.height
            )
        } else {
            size = CGSize(
                width: max(minimumCollapsedWidth, (notchWidth ?? 156) + 18),
                height: collapsedHeight
            )
        }

        let x = screenFrame.midX - (size.width / 2)
        let top = screenFrame.maxY - resolvedInset
        return CGRect(x: x, y: top - size.height, width: size.width, height: size.height)
    }

    static func triggerFrame(
        screenFrame: CGRect,
        topInset: CGFloat,
        notchWidth: CGFloat?
    ) -> CGRect {
        let width = max(220, (notchWidth ?? 156) + 64)
        let height = max(42, topInset + 12)
        return CGRect(
            x: screenFrame.midX - (width / 2),
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }
}
