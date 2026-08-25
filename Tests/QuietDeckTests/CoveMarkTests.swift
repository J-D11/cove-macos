import XCTest
@testable import QuietDeck

final class CoveMarkTests: XCTestCase {
    func testMenuBarMarkIsAProperTemplateImage() {
        let mark = CoveMark.image(size: 18)

        XCTAssertEqual(mark.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(mark.isTemplate)
        XCTAssertEqual(mark.accessibilityDescription, "Cove")
        XCTAssertNotNil(mark.tiffRepresentation)
    }
}
