import XCTest
@testable import QuietDeck

final class MenuBarOverflowFilterTests: XCTestCase {
    func testReturnsOnlyItemsMissingFromVisibleMenuBarCapture() {
        let hidden = item(id: "hidden")
        let visible = item(id: "visible")

        let result = MenuBarOverflowFilter.overflowItems(
            from: [hidden, visible],
            visibleItemIDs: [visible.id]
        )

        XCTAssertEqual(result.map(\.id), [hidden.id])
    }

    private func item(id: String) -> MenuBarItemModel {
        MenuBarItemModel(
            id: id,
            ownerBundleIdentifier: "com.example.\(id)",
            ownerPID: 1,
            itemIdentifier: nil,
            itemIndex: 0,
            name: id,
            symbolName: nil,
            ownerIcon: nil,
            compactValue: nil,
            accessibilityFrame: nil,
            xPosition: 0
        )
    }
}
