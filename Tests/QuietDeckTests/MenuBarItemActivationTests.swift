import XCTest
@testable import QuietDeck

@MainActor
final class MenuBarItemActivationTests: XCTestCase {
    func testHiddenOwnerOpensApplicationWithoutAccessibilityPermission() {
        var openedBundleIdentifier: String?
        let service = MenuBarItemService(
            accessibilityTrustProvider: { false },
            applicationOpenHandler: { bundleIdentifier, _ in
                openedBundleIdentifier = bundleIdentifier
                return true
            }
        )

        let activated = service.activate(item(isHiddenOwnerFallback: true))

        XCTAssertTrue(activated)
        XCTAssertEqual(openedBundleIdentifier, "com.raycast.macos")
    }

    func testOrdinaryMenuItemStillRequiresAccessibilityPermission() {
        var attemptedApplicationOpen = false
        let service = MenuBarItemService(
            accessibilityTrustProvider: { false },
            applicationOpenHandler: { _, _ in
                attemptedApplicationOpen = true
                return true
            }
        )

        let activated = service.activate(item(isHiddenOwnerFallback: false))

        XCTAssertFalse(activated)
        XCTAssertFalse(attemptedApplicationOpen)
    }

    private func item(isHiddenOwnerFallback: Bool) -> MenuBarItemModel {
        MenuBarItemModel(
            id: "raycast",
            ownerBundleIdentifier: "com.raycast.macos",
            ownerPID: 42,
            itemIdentifier: nil,
            itemIndex: 0,
            name: "Raycast",
            symbolName: nil,
            ownerIcon: nil,
            compactValue: nil,
            accessibilityFrame: nil,
            xPosition: .greatestFiniteMagnitude,
            isHiddenOwnerFallback: isHiddenOwnerFallback
        )
    }
}
