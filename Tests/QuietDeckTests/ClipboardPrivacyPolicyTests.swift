import XCTest
@testable import QuietDeck

final class ClipboardPrivacyPolicyTests: XCTestCase {
    func testPausedAndConcealedClipboardContentAreRejected() {
        XCTAssertFalse(
            shouldCapture(isPaused: true)
        )
        XCTAssertFalse(
            shouldCapture(pasteboardTypes: ["org.nspasteboard.ConcealedType"])
        )
    }

    func testCommonAndCustomSensitiveApplicationsAreRejected() {
        XCTAssertFalse(
            shouldCapture(sourceBundleIdentifier: "com.apple.Terminal")
        )
        XCTAssertFalse(
            shouldCapture(
                sourceBundleIdentifier: "com.example.private",
                customExcludedBundleIdentifiers: ["com.example.private"]
            )
        )
    }

    func testCommonExclusionsCanBeDisabledWithoutBypassingConcealedTypes() {
        XCTAssertTrue(
            shouldCapture(
                sourceBundleIdentifier: "com.apple.Terminal",
                excludesCommonSensitiveApps: false
            )
        )
        XCTAssertFalse(
            shouldCapture(
                pasteboardTypes: ["com.agilebits.onepassword"],
                excludesCommonSensitiveApps: false
            )
        )
    }

    func testBundleIdentifierParserAcceptsCommonSeparators() {
        let result = ClipboardPrivacyPolicy.bundleIdentifiers(
            from: "com.example.One\ncom.example.Two, com.example.Three;com.example.Four"
        )

        XCTAssertEqual(
            result,
            [
                "com.example.one",
                "com.example.two",
                "com.example.three",
                "com.example.four"
            ]
        )
    }

    private func shouldCapture(
        sourceBundleIdentifier: String? = "com.example.notes",
        pasteboardTypes: [String] = ["public.utf8-plain-text"],
        isPaused: Bool = false,
        excludesCommonSensitiveApps: Bool = true,
        customExcludedBundleIdentifiers: Set<String> = []
    ) -> Bool {
        ClipboardPrivacyPolicy.shouldCapture(
            sourceBundleIdentifier: sourceBundleIdentifier,
            pasteboardTypes: pasteboardTypes,
            isPaused: isPaused,
            excludesCommonSensitiveApps: excludesCommonSensitiveApps,
            customExcludedBundleIdentifiers: customExcludedBundleIdentifiers
        )
    }
}
