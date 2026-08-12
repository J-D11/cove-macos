import CoreGraphics
import XCTest
@testable import QuietDeck

final class NotchGeometryTests: XCTestCase {
    func testExpandedPanelIsCenteredAndBelowSafeArea() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen,
            topInset: 38,
            notchWidth: 180,
            expanded: true
        )

        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, screen.maxY - 38, accuracy: 0.001)
        XCTAssertEqual(frame.size, NotchGeometry.expandedSize)
    }

    func testCollapsedPanelTracksNotchWidth() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen,
            topInset: 38,
            notchWidth: 210,
            expanded: false
        )

        XCTAssertEqual(frame.width, 228, accuracy: 0.001)
        XCTAssertEqual(frame.height, NotchGeometry.collapsedHeight, accuracy: 0.001)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.001)
    }

    func testNotchlessDisplayUsesMenuBarFallbackInset() {
        let screen = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen,
            topInset: 0,
            notchWidth: nil,
            expanded: true
        )

        XCTAssertEqual(frame.maxY, screen.maxY - 28, accuracy: 0.001)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.001)
    }

    func testExpandedPanelAcceptsContentFittingWidth() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen,
            topInset: 38,
            notchWidth: 180,
            expanded: true,
            expandedWidth: 442
        )

        XCTAssertEqual(frame.width, 442, accuracy: 0.001)
        XCTAssertEqual(frame.height, NotchGeometry.expandedSize.height, accuracy: 0.001)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.001)
    }
}
