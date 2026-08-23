import XCTest
@testable import QuietDeck

final class CoveVersionTests: XCTestCase {
    func testParsesReleaseTagsAndDefaultsMissingPatch() {
        XCTAssertEqual(CoveVersion("v0.8"), CoveVersion(major: 0, minor: 8, patch: 0))
        XCTAssertEqual(CoveVersion("0.8.2"), CoveVersion(major: 0, minor: 8, patch: 2))
    }

    func testComparesVersionsNumerically() {
        XCTAssertTrue(CoveVersion("0.8.0")! > CoveVersion("0.7.99")!)
        XCTAssertTrue(CoveVersion("1.0.0")! > CoveVersion("0.99.99")!)
    }

    func testRejectsInvalidVersions() {
        XCTAssertNil(CoveVersion("release-latest"))
        XCTAssertNil(CoveVersion("0"))
        XCTAssertNil(CoveVersion("0.8.beta"))
    }
}
