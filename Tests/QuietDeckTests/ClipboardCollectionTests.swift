import XCTest
@testable import QuietDeck

final class ClipboardCollectionTests: XCTestCase {
    func testCollectionNamesAreTrimmedAndDeduplicated() {
        XCTAssertEqual(
            ShelfStore.normalizedCollectionNames([" Work ", "work", "Prompts", ""]),
            ["Work", "Prompts"]
        )
    }

    func testAssigningCollectionSavesItemAndCanClearCollection() {
        let item = ClipboardItem(content: .text("Prompt"))
        let saved = item.withCollection("Prompts")
        let cleared = saved.withPinned(false).withCollection(nil)

        XCTAssertTrue(saved.isPinned)
        XCTAssertEqual(saved.collectionName, "Prompts")
        XCTAssertFalse(cleared.isPinned)
        XCTAssertNil(cleared.collectionName)
    }
}
