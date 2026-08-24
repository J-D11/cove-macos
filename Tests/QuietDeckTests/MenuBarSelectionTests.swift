import XCTest
@testable import QuietDeck

final class MenuBarSelectionTests: XCTestCase {
    func testNormalizationPreservesOrderAndRemovesDuplicates() {
        XCTAssertEqual(
            MenuBarSelection.normalizedIDs(["wifi", "battery", "wifi", ""]),
            ["wifi", "battery"]
        )
    }

    func testToggleAddsAndRemovesItems() {
        XCTAssertEqual(MenuBarSelection.toggled("battery", in: ["wifi"]), ["wifi", "battery"])
        XCTAssertEqual(MenuBarSelection.toggled("wifi", in: ["wifi", "battery"]), ["battery"])
    }

    func testMovePlacesDraggedItemBeforeTarget() {
        XCTAssertEqual(
            MenuBarSelection.moving("battery", over: "wifi", in: ["wifi", "sound", "battery"]),
            ["battery", "wifi", "sound"]
        )
    }

    func testMoveAdvancesOnePositionWhenDraggingForward() {
        XCTAssertEqual(
            MenuBarSelection.moving("wifi", over: "sound", in: ["wifi", "sound", "battery"]),
            ["sound", "wifi", "battery"]
        )
    }

    func testMoveCanReachLastPosition() {
        XCTAssertEqual(
            MenuBarSelection.moving("wifi", over: "battery", in: ["wifi", "sound", "battery"]),
            ["sound", "battery", "wifi"]
        )
    }

    func testOffsetMoveSupportsAccessibleReordering() {
        XCTAssertEqual(
            MenuBarSelection.moving("sound", by: -1, in: ["wifi", "sound", "battery"]),
            ["sound", "wifi", "battery"]
        )
        XCTAssertEqual(
            MenuBarSelection.moving("sound", by: 1, in: ["wifi", "sound", "battery"]),
            ["wifi", "battery", "sound"]
        )
    }

    func testOffsetMoveStopsAtCollectionEdges() {
        XCTAssertEqual(
            MenuBarSelection.moving("wifi", by: -1, in: ["wifi", "sound"]),
            ["wifi", "sound"]
        )
    }
}
