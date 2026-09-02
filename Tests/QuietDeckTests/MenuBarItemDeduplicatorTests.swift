import AppKit
import CoreGraphics
import XCTest
@testable import QuietDeck

final class MenuBarItemDeduplicatorTests: XCTestCase {
    @MainActor
    func testApplicationIndexCoalescesDuplicateProcessIdentifiers() {
        let application = NSRunningApplication.current

        let indexedApplications = MenuBarItemService.applicationsByProcessIdentifier([
            application,
            application,
        ])

        XCTAssertEqual(indexedApplications.count, 1)
        XCTAssertTrue(
            indexedApplications[application.processIdentifier] === application
        )
    }

    func testRemovesFallbackCopyAtSameOwnerNameAndPosition() {
        let direct = item(id: "direct", owner: "com.example.App", name: "Example", x: 120)
        let fallback = item(id: "fallback", owner: "com.example.App", name: "Example", x: 120)

        let result = MenuBarItemDeduplicator.deduplicate([direct, fallback])

        XCTAssertEqual(result.items.map(\.id), ["direct"])
        XCTAssertEqual(result.duplicateCount, 1)
    }

    func testPreservesDistinctControlsFromSameOwner() {
        let cpu = item(id: "cpu", owner: "eu.exelban.Stats", name: "CPU: Mini", x: 120)
        let memory = item(id: "memory", owner: "eu.exelban.Stats", name: "RAM: Mini", x: 160)

        let result = MenuBarItemDeduplicator.deduplicate([cpu, memory])

        XCTAssertEqual(result.items.map(\.id), ["cpu", "memory"])
        XCTAssertEqual(result.duplicateCount, 0)
    }

    func testDropsUnlabeledZeroPositionSystemPlaceholder() {
        let placeholder = item(
            id: "placeholder",
            owner: "com.apple.controlcenter",
            name: "Control Center",
            x: 0,
            frame: CGRect(x: 0, y: 0, width: 0, height: 0)
        )
        let identified = item(
            id: "wifi",
            owner: "com.apple.controlcenter",
            identifier: "com.apple.menuextra.wifi",
            name: "Wi-Fi",
            x: 1_400
        )

        let result = MenuBarItemDeduplicator.deduplicate([placeholder, identified])

        XCTAssertEqual(result.items.map(\.id), ["wifi"])
        XCTAssertEqual(result.placeholderCount, 1)
    }

    private func item(
        id: String,
        owner: String,
        identifier: String? = nil,
        name: String,
        x: CGFloat,
        frame: CGRect? = nil
    ) -> MenuBarItemModel {
        MenuBarItemModel(
            id: id,
            ownerBundleIdentifier: owner,
            ownerPID: 1,
            itemIdentifier: identifier,
            itemIndex: 0,
            name: name,
            symbolName: nil,
            ownerIcon: nil,
            compactValue: nil,
            accessibilityFrame: frame ?? CGRect(x: x, y: 0, width: 24, height: 24),
            xPosition: x
        )
    }
}
