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
                identifier: "com.apple.menuextra.bluetooth",
                label: "Bluetooth",
                ownerBundleIdentifier: "com.apple.controlcenter"
            ),
            "antenna.radiowaves.left.and.right"
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

    func testHidesSystemControlsAlreadyAvailableInTheMenuBar() {
        let controls = [
            ("com.apple.menuextra.wifi", "Wi-Fi"),
            ("com.apple.menuextra.bluetooth", "Bluetooth"),
            ("com.apple.menuextra.battery", "Battery 85%"),
            ("com.apple.menuextra.volume", "Sound"),
            ("com.apple.menuextra.clock", "Date and Time"),
            ("com.apple.controlcenter", "Control Center")
        ]

        for (identifier, label) in controls {
            XCTAssertTrue(
                MenuExtraClassifier.isRedundantSystemControl(
                    identifier: identifier,
                    label: label,
                    ownerBundleIdentifier: "com.apple.controlcenter"
                ),
                "Expected \(label) to stay in the macOS menu bar instead of Cove"
            )
        }
    }

    func testKeepsThirdPartyAndUnknownAppleExtras() {
        XCTAssertFalse(
            MenuExtraClassifier.isRedundantSystemControl(
                identifier: "raycast",
                label: "Raycast",
                ownerBundleIdentifier: "com.raycast.macos"
            )
        )
        XCTAssertFalse(
            MenuExtraClassifier.isRedundantSystemControl(
                identifier: "com.apple.developerutility.status",
                label: "Developer Utility",
                ownerBundleIdentifier: "com.apple.developerutility"
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
