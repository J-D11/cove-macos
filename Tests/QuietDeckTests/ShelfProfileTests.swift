import XCTest
@testable import QuietDeck

final class ShelfProfileTests: XCTestCase {
    func testProfileServiceRoundTripsPerAppConfiguration() throws {
        let suiteName = "CoveShelfProfileTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = ShelfProfileService(defaults: defaults)
        let profile = ShelfProfile(
            bundleIdentifier: "com.apple.dt.Xcode",
            applicationName: "Xcode",
            selectedMenuItemIDs: ["wifi", "battery"],
            selectedMenuItemNames: ["wifi": "Wi-Fi", "battery": "Battery"],
            showsNowPlaying: false,
            showsVisualClipboard: true,
            clipboardCollectionName: "Work"
        )

        service.save([profile])

        XCTAssertEqual(service.load(), [profile])
    }
}
