import Foundation
import XCTest
@testable import QuietDeck

final class CoveInstallationTargetTests: XCTestCase {
    private let bundleIdentifier = "com.astralworkslabs.QuietDeck"

    func testKeepsCanonicalApplicationsInstallation() {
        XCTAssertEqual(
            CoveInstallationTarget.preferred(
                currentBundleURL: CoveInstallationTarget.canonicalURL,
                canonicalBundleIdentifier: bundleIdentifier,
                expectedBundleIdentifier: bundleIdentifier
            ),
            CoveInstallationTarget.canonicalURL
        )
    }

    func testDownloadedCopyUpdatesExistingCanonicalInstallation() {
        XCTAssertEqual(
            CoveInstallationTarget.preferred(
                currentBundleURL: URL(fileURLWithPath: "/tmp/Downloads/Cove.app"),
                canonicalBundleIdentifier: bundleIdentifier,
                expectedBundleIdentifier: bundleIdentifier
            ),
            CoveInstallationTarget.canonicalURL
        )
    }

    func testDoesNotReplaceUnrelatedApplication() {
        let downloadedURL = URL(fileURLWithPath: "/tmp/Downloads/Cove.app")

        XCTAssertEqual(
            CoveInstallationTarget.preferred(
                currentBundleURL: downloadedURL,
                canonicalBundleIdentifier: "com.example.Unrelated",
                expectedBundleIdentifier: bundleIdentifier
            ),
            downloadedURL
        )
    }
}
