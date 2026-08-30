import CoreGraphics

enum SideWingLayoutMode: Equatable {
    case compact
    case spacious
}

struct SideWingLayoutMetrics: Equatable {
    let expandedWidth: CGFloat
    let maximumExpandedHeight: CGFloat
    let minimumExpandedHeight: CGFloat
    let minimumRailHeight: CGFloat
    let railWidth: CGFloat
    let flyoutWidth: CGFloat
    let flyoutOverlap: CGFloat
    let flyoutContentInset: CGFloat
    let nowPlayingFlyoutHeight: CGFloat
    let clipboardFlyoutHeight: CGFloat
    let clipboardListHeight: CGFloat
    let appsFlyoutHeight: CGFloat
    let menuItemListMaximumHeight: CGFloat

    var flyoutTrailingInset: CGFloat {
        railWidth - flyoutOverlap
    }

    var edgeHandleMinimumX: CGFloat {
        expandedWidth - railWidth
    }

    var interactiveContentMaximumX: CGFloat {
        expandedWidth - flyoutTrailingInset - flyoutOverlap - flyoutContentInset
    }
}

enum SideWingGeometry {
    static let compactMetrics = SideWingLayoutMetrics(
        expandedWidth: 280,
        maximumExpandedHeight: 530,
        minimumExpandedHeight: 172,
        minimumRailHeight: 410,
        railWidth: 60,
        flyoutWidth: 234,
        flyoutOverlap: 14,
        flyoutContentInset: 14,
        nowPlayingFlyoutHeight: 232,
        clipboardFlyoutHeight: 190,
        clipboardListHeight: 132,
        appsFlyoutHeight: 108,
        menuItemListMaximumHeight: 178
    )
    static let spaciousMetrics = SideWingLayoutMetrics(
        expandedWidth: 352,
        maximumExpandedHeight: 610,
        minimumExpandedHeight: 220,
        minimumRailHeight: 500,
        railWidth: 64,
        flyoutWidth: 304,
        flyoutOverlap: 16,
        flyoutContentInset: 16,
        nowPlayingFlyoutHeight: 252,
        clipboardFlyoutHeight: 284,
        clipboardListHeight: 226,
        appsFlyoutHeight: 124,
        menuItemListMaximumHeight: 224
    )

    // Compact aliases preserve the approved external-display geometry and
    // keep existing callers source-compatible.
    static var expandedWidth: CGFloat { compactMetrics.expandedWidth }
    static var maximumExpandedHeight: CGFloat { compactMetrics.maximumExpandedHeight }
    static var minimumExpandedHeight: CGFloat { compactMetrics.minimumExpandedHeight }
    static var minimumRailHeight: CGFloat { compactMetrics.minimumRailHeight }
    static var railWidth: CGFloat { compactMetrics.railWidth }
    static var flyoutWidth: CGFloat { compactMetrics.flyoutWidth }
    static var flyoutOverlap: CGFloat { compactMetrics.flyoutOverlap }
    static let edgeHandleWidth: CGFloat = 32
    static let edgeHandleHeight: CGFloat = 78
    static let edgeHandleHorizontalOffset: CGFloat = 0
    static let collapsedSize = CGSize(width: edgeHandleWidth, height: 90)
    static let trailingOverflow: CGFloat = 8
    static let verticalOffset: CGFloat = 24
    static var flyoutContentInset: CGFloat { compactMetrics.flyoutContentInset }

    static var flyoutTrailingInset: CGFloat {
        compactMetrics.flyoutTrailingInset
    }

    static var edgeHandleMinimumX: CGFloat {
        compactMetrics.edgeHandleMinimumX
    }

    static var interactiveContentMaximumX: CGFloat {
        compactMetrics.interactiveContentMaximumX
    }

    private static let screenMargin: CGFloat = 16
    private static let triggerWidth: CGFloat = 42
    private static let triggerHeight: CGFloat = 124

    static func panelFrame(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        expanded: Bool,
        expandedHeight: CGFloat? = nil,
        layoutMode: SideWingLayoutMode = .compact
    ) -> CGRect {
        let metrics = metrics(for: layoutMode)
        let size: CGSize
        if expanded {
            let availableHeight = max(
                metrics.minimumExpandedHeight,
                visibleFrame.height - (screenMargin * 2)
            )
            let height = min(
                max(
                    expandedHeight ?? metrics.maximumExpandedHeight,
                    metrics.minimumExpandedHeight
                ),
                min(metrics.maximumExpandedHeight, availableHeight)
            )
            size = CGSize(width: metrics.expandedWidth, height: height)
        } else {
            size = collapsedSize
        }

        let centerY = verticalCenter(in: visibleFrame)
        let proposedY = centerY - (size.height / 2)
        let minimumY = visibleFrame.minY + screenMargin
        let maximumY = visibleFrame.maxY - size.height - screenMargin
        let y: CGFloat
        if maximumY >= minimumY {
            y = min(max(proposedY, minimumY), maximumY)
        } else {
            y = visibleFrame.midY - (size.height / 2)
        }

        return CGRect(
            x: screenFrame.maxX - size.width + trailingOverflow,
            y: y,
            width: size.width,
            height: size.height
        )
    }

    static func triggerFrame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.maxX - triggerWidth,
            y: verticalCenter(in: visibleFrame) - (triggerHeight / 2),
            width: triggerWidth + trailingOverflow,
            height: triggerHeight
        )
    }

    static func layoutMode(
        isBuiltInDisplay: Bool,
        externalDisplayCount: Int
    ) -> SideWingLayoutMode {
        isBuiltInDisplay && externalDisplayCount == 0 ? .spacious : .compact
    }

    static func metrics(for layoutMode: SideWingLayoutMode) -> SideWingLayoutMetrics {
        switch layoutMode {
        case .compact:
            return compactMetrics
        case .spacious:
            return spaciousMetrics
        }
    }

    private static func verticalCenter(in visibleFrame: CGRect) -> CGFloat {
        visibleFrame.midY + min(verticalOffset, visibleFrame.height * 0.04)
    }
}
