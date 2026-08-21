import XCTest
@testable import QuietDeck

final class MenuExtraClassifierTests: XCTestCase {
    func testMapsKnownSystemItemsToSymbols() {
        XCTAssertEqual(
            MenuExtraClassifier.symbolName(
                identifier: "com.apple.menuextra.wifi",
                label: "Wi-Fi",
                ownerBundleIdentifier: "com.apple.controlcenter"
            ),
            "wifi"
        )
        XCTAssertEqual(
            MenuExtraClassifier.symbolName(
                identifier: "com.apple.menuextra.battery",
                label: "Battery 85%",
                ownerBundleIdentifier: "com.apple.controlcenter"
            ),
            "battery.75percent"
        )
    }

    func testThirdPartyItemsUseOwningApplicationIcon() {
        XCTAssertNil(
            MenuExtraClassifier.symbolName(
                identifier: "com.example.vpn.status",
                label: "Connected",
                ownerBundleIdentifier: "com.example.vpn"
            )
        )
    }

    func testCodexMenuAppsUseTheirDedicatedSymbols() {
        XCTAssertEqual(
            MenuExtraClassifier.dedicatedOwnerIconResource(
                ownerBundleIdentifier: "com.steipete.codexbar"
            ),
            MenuExtraClassifier.DedicatedOwnerIconResource(
                name: "ProviderIcon-codex",
                fileExtension: "svg"
            )
        )
        XCTAssertEqual(
            MenuExtraClassifier.dedicatedOwnerIconResource(
                ownerBundleIdentifier: "com.openai.codex"
            ),
            MenuExtraClassifier.DedicatedOwnerIconResource(
                name: "chatgptTemplate@2x",
                fileExtension: "png"
            )
        )
        XCTAssertTrue(
            MenuExtraClassifier.prefersOwnerIconOverNativeSnapshot(
                ownerBundleIdentifier: "COM.STEIPETE.CODEXBAR"
            )
        )
        XCTAssertTrue(
            MenuExtraClassifier.prefersOwnerIconOverNativeSnapshot(
                ownerBundleIdentifier: "COM.RAYCAST.MACOS"
            )
        )
        XCTAssertNil(
            MenuExtraClassifier.dedicatedOwnerIconResource(
                ownerBundleIdentifier: "com.example.menu-extra"
            )
        )
        XCTAssertEqual(
            MenuExtraClassifier.dedicatedOwnerIconResource(
                ownerBundleIdentifier: "COM.RAYCAST.MACOS"
            ),
            MenuExtraClassifier.DedicatedOwnerIconResource(
                name: "production-appicon",
                fileExtension: "icns"
            )
        )
    }

    func testUsesDistinctSymbolsForThirdPartySystemMetrics() {
        let cases = [
            ("CPU: Mini", "cpu"),
            ("GPU: Mini", "display"),
            ("RAM: Mini", "memorychip"),
            ("Disk: Mini", "internaldrive"),
            ("Sensors: Mini", "thermometer.medium"),
            ("Network: Speed", "arrow.up.arrow.down")
        ]

        for (label, expectedSymbol) in cases {
            XCTAssertEqual(
                MenuExtraClassifier.symbolName(
                    identifier: nil,
                    label: label,
                    ownerBundleIdentifier: "eu.exelban.Stats"
                ),
                expectedSymbol
            )
        }

        XCTAssertNil(
            MenuExtraClassifier.symbolName(
                identifier: nil,
                label: "Telegram Desktop",
                ownerBundleIdentifier: "com.tdesktop.Telegram"
            )
        )
    }

    func testExtractsCompactPercentage() {
        XCTAssertEqual(MenuExtraClassifier.compactValue(from: "Battery 85%"), "85%")
        XCTAssertNil(MenuExtraClassifier.compactValue(from: "Wi-Fi"))
    }

    func testUsesKnownIdentifierWhenLabelIsInternal() {
        XCTAssertEqual(
            MenuExtraClassifier.displayName(
                identifier: "com.apple.menuextra.volume",
                label: "_NS:Item-0",
                ownerName: "Control Center"
            ),
            "Sound"
        )
    }
}
