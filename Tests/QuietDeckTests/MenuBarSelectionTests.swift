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
            MenuBarSelection.moving("battery", before: "wifi", in: ["wifi", "sound", "battery"]),
            ["battery", "wifi", "sound"]
        )
    }
}
