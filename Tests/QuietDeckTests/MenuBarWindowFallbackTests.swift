import CoreGraphics
import XCTest
@testable import QuietDeck

final class MenuBarWindowFallbackTests: XCTestCase {
    func testAcceptsStatusItemWindowLayersForCandidateProcess() {
        let info: [[String: Any]] = [
            windowInfo(processIdentifier: 42, layer: 24, x: 120, width: 28),
            windowInfo(processIdentifier: 42, layer: 25, x: 80, width: 24),
            windowInfo(processIdentifier: 99, layer: 24, x: 30, width: 20)
        ]

        let items = MenuBarWindowFallback.items(
            from: info,
            candidateProcessIdentifiers: [42]
        )

        XCTAssertEqual(items.map(\.processIdentifier), [42, 42])
        XCTAssertEqual(items.map(\.frame.minX), [80, 120])
        XCTAssertEqual(items.map(\.index), [0, 1])
    }

    func testRejectsRegularAndInvisibleWindows() {
        var invisible = windowInfo(processIdentifier: 42, layer: 24, x: 120, width: 28)
        invisible[kCGWindowAlpha as String] = 0
        let info: [[String: Any]] = [
            windowInfo(processIdentifier: 42, layer: 0, x: 20, width: 400),
            invisible
        ]

        XCTAssertTrue(
            MenuBarWindowFallback.items(
                from: info,
                candidateProcessIdentifiers: [42]
            ).isEmpty
        )
    }

    private func windowInfo(
        processIdentifier: Int,
        layer: Int,
        x: CGFloat,
        width: CGFloat
    ) -> [String: Any] {
        [
            kCGWindowOwnerPID as String: processIdentifier,
            kCGWindowLayer as String: layer,
            kCGWindowAlpha as String: 1,
            kCGWindowBounds as String: [
                "X": x,
                "Y": 0,
                "Width": width,
                "Height": 24
            ]
        ]
    }
}
