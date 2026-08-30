import CoreGraphics
import XCTest
@testable import QuietDeck

final class SideWingGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)

    func testExpandedWingIsAttachedToRightEdgeAndSitsAboveCenter() {
        let frame = SideWingGeometry.panelFrame(
            screenFrame: screen,
            visibleFrame: visible,
            expanded: true
        )

        XCTAssertEqual(frame.width, SideWingGeometry.expandedWidth, accuracy: 0.001)
        XCTAssertEqual(frame.height, SideWingGeometry.maximumExpandedHeight, accuracy: 0.001)
        XCTAssertEqual(frame.maxX, screen.maxX + SideWingGeometry.trailingOverflow, accuracy: 0.001)
        XCTAssertGreaterThan(frame.midY, visible.midY)
    }

    func testCollapsedWingLeavesOnlyTheEdgeHandleVisible() {
        let frame = SideWingGeometry.panelFrame(
            screenFrame: screen,
            visibleFrame: visible,
            expanded: false
        )

        XCTAssertEqual(frame.size, SideWingGeometry.collapsedSize)
        XCTAssertGreaterThanOrEqual(frame.width, SideWingGeometry.edgeHandleWidth)
        XCTAssertEqual(frame.maxX, screen.maxX + SideWingGeometry.trailingOverflow, accuracy: 0.001)
    }

    func testExpandedHeightCanFollowVisibleModules() {
        let frame = SideWingGeometry.panelFrame(
            screenFrame: screen,
            visibleFrame: visible,
            expanded: true,
            expandedHeight: 364
        )

        XCTAssertEqual(frame.height, 364, accuracy: 0.001)
        XCTAssertEqual(frame.maxX, screen.maxX + SideWingGeometry.trailingOverflow, accuracy: 0.001)
    }

    func testWingFitsInsideAShortVisibleFrame() {
        let shortVisible = CGRect(x: 0, y: 40, width: 900, height: 420)
        let frame = SideWingGeometry.panelFrame(
            screenFrame: CGRect(x: 0, y: 0, width: 900, height: 500),
            visibleFrame: shortVisible,
            expanded: true
        )

        XCTAssertEqual(frame.height, shortVisible.height - 32, accuracy: 0.001)
        XCTAssertEqual(frame.minY, shortVisible.minY + 16, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, shortVisible.maxY - 16, accuracy: 0.001)
    }

    func testTriggerStraddlesTheRightScreenEdgeAtTheWingCenter() {
        let trigger = SideWingGeometry.triggerFrame(
            screenFrame: screen,
            visibleFrame: visible
        )
        let collapsed = SideWingGeometry.panelFrame(
            screenFrame: screen,
            visibleFrame: visible,
            expanded: false
        )

        XCTAssertLessThan(trigger.minX, screen.maxX)
        XCTAssertGreaterThan(trigger.maxX, screen.maxX)
        XCTAssertEqual(trigger.midY, collapsed.midY, accuracy: 0.001)
    }

    func testInteractiveClipboardContentClearsTheEdgeHandleHitArea() {
        XCTAssertLessThanOrEqual(
            SideWingGeometry.interactiveContentMaximumX,
            SideWingGeometry.edgeHandleMinimumX
        )
        XCTAssertGreaterThan(
            SideWingGeometry.edgeHandleMinimumX
                - SideWingGeometry.interactiveContentMaximumX,
            0
        )
    }

    func testFlyoutAndRailFormOneCompactEdgeAssembly() {
        XCTAssertEqual(
            SideWingGeometry.flyoutWidth
                + SideWingGeometry.railWidth
                - SideWingGeometry.flyoutOverlap,
            SideWingGeometry.expandedWidth,
            accuracy: 0.001
        )
        XCTAssertEqual(
            SideWingGeometry.flyoutTrailingInset,
            SideWingGeometry.railWidth - SideWingGeometry.flyoutOverlap,
            accuracy: 0.001
        )
    }

    func testMacBookOnlyUsesSpaciousLayout() {
        XCTAssertEqual(
            SideWingGeometry.layoutMode(
                isBuiltInDisplay: true,
                externalDisplayCount: 0
            ),
            .spacious
        )
        XCTAssertEqual(
            SideWingGeometry.layoutMode(
                isBuiltInDisplay: true,
                externalDisplayCount: 1
            ),
            .compact
        )
        XCTAssertEqual(
            SideWingGeometry.layoutMode(
                isBuiltInDisplay: false,
                externalDisplayCount: 1
            ),
            .compact
        )
    }

    func testSpaciousLayoutStaysAttachedWhileShowingMoreClipboardContent() {
        let compactFrame = SideWingGeometry.panelFrame(
            screenFrame: screen,
            visibleFrame: visible,
            expanded: true,
            layoutMode: .compact
        )
        let spaciousFrame = SideWingGeometry.panelFrame(
            screenFrame: screen,
            visibleFrame: visible,
            expanded: true,
            layoutMode: .spacious
        )
        let compact = SideWingGeometry.metrics(for: .compact)
        let spacious = SideWingGeometry.metrics(for: .spacious)

        XCTAssertGreaterThan(spaciousFrame.width, compactFrame.width)
        XCTAssertGreaterThan(spacious.clipboardListHeight, compact.clipboardListHeight)
        XCTAssertEqual(
            spacious.flyoutWidth + spacious.railWidth - spacious.flyoutOverlap,
            spacious.expandedWidth,
            accuracy: 0.001
        )
        XCTAssertLessThanOrEqual(
            spacious.interactiveContentMaximumX,
            spacious.edgeHandleMinimumX
        )
        XCTAssertEqual(
            spaciousFrame.maxX,
            screen.maxX + SideWingGeometry.trailingOverflow,
            accuracy: 0.001
        )
    }
}
