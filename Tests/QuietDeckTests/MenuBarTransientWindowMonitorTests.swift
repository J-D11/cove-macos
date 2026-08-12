import CoreGraphics
import XCTest
@testable import QuietDeck

final class MenuBarTransientWindowMonitorTests: XCTestCase {
    func testFindsLargePopupWindowForOwner() {
        let windowInfo: [[String: Any]] = [
            window(processIdentifier: 42, number: 7, layer: 101, width: 310, height: 785),
            window(processIdentifier: 99, number: 8, layer: 101, width: 310, height: 785)
        ]

        XCTAssertEqual(
            MenuBarTransientWindowMonitor.transientWindowIDs(
                from: windowInfo,
                ownerPID: 42
            ),
            [7]
        )
    }

    func testRejectsStatusItemsAndKeepaliveWindows() {
        let windowInfo: [[String: Any]] = [
            window(processIdentifier: 42, number: 7, layer: 25, width: 42, height: 33),
            window(processIdentifier: 42, number: 8, layer: 3, width: 20, height: 20)
        ]

        XCTAssertTrue(
            MenuBarTransientWindowMonitor.transientWindowIDs(
                from: windowInfo,
                ownerPID: 42
            ).isEmpty
        )
    }

    private func window(
        processIdentifier: Int,
        number: Int,
        layer: Int,
        width: CGFloat,
        height: CGFloat
    ) -> [String: Any] {
        [
            kCGWindowOwnerPID as String: processIdentifier,
            kCGWindowNumber as String: number,
            kCGWindowLayer as String: layer,
            kCGWindowAlpha as String: 1,
            kCGWindowBounds as String: [
                "X": 100,
                "Y": 34,
                "Width": width,
                "Height": height
            ]
        ]
    }
}
