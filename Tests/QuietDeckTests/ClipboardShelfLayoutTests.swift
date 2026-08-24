import XCTest
@testable import QuietDeck

final class ClipboardShelfLayoutTests: XCTestCase {
    func testEmptyClipboardStillFitsFullHeader() {
        XCTAssertEqual(
            ClipboardShelfLayout.width(itemCount: 0, isSearchPresented: false),
            232
        )
    }

    func testSearchProvidesRoomForFieldAndControls() {
        XCTAssertEqual(
            ClipboardShelfLayout.width(itemCount: 0, isSearchPresented: true),
            232
        )
    }

    func testSearchDoesNotShrinkMultipleClipboardCards() {
        XCTAssertEqual(
            ClipboardShelfLayout.width(itemCount: 3, isSearchPresented: true),
            356
        )
    }
}
