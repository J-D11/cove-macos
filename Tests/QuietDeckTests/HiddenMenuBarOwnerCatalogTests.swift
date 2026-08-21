import XCTest
@testable import QuietDeck

final class HiddenMenuBarOwnerCatalogTests: XCTestCase {
    func testIncludesBetterDisplayAndInput() {
        XCTAssertEqual(
            HiddenMenuBarOwnerCatalog.owner(for: "PRO.BETTERDISPLAY.BETTERDISPLAY"),
            HiddenMenuBarOwner(
                bundleIdentifier: "pro.betterdisplay.BetterDisplay",
                displayName: "BetterDisplay",
                symbolName: "display"
            )
        )
        XCTAssertEqual(
            HiddenMenuBarOwnerCatalog.owner(for: "it.focusense.input-app"),
            HiddenMenuBarOwner(
                bundleIdentifier: "it.focusense.input-app",
                displayName: "Input",
                symbolName: "keyboard"
            )
        )
        XCTAssertEqual(
            HiddenMenuBarOwnerCatalog.owner(for: "APP.BUSY"),
            HiddenMenuBarOwner(
                bundleIdentifier: "app.busy",
                displayName: "BUSY",
                symbolName: "chart.bar.fill"
            )
        )
    }

    func testDoesNotTurnEveryRunningAppIntoAHiddenMenuBarProxy() {
        XCTAssertNil(HiddenMenuBarOwnerCatalog.owner(for: "com.google.Chrome"))
    }
}
