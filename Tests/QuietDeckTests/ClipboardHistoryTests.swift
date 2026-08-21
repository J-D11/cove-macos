import XCTest
@testable import QuietDeck

final class ClipboardHistoryTests: XCTestCase {
    func testNewestItemIsInsertedFirst() {
        let earlier = ClipboardItem(content: .text("Earlier"))
        let newest = ClipboardItem(content: .text("Newest"))

        let result = ClipboardHistory.inserting(newest, into: [earlier])

        XCTAssertEqual(result.map(\.fingerprint), [newest.fingerprint, earlier.fingerprint])
    }

    func testDuplicateContentMovesToFrontWithoutGrowingHistory() {
        let first = ClipboardItem(content: .text("Repeated"))
        let other = ClipboardItem(content: .text("Other"))
        let repeated = ClipboardItem(content: .text("Repeated"))

        let result = ClipboardHistory.inserting(repeated, into: [other, first])

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.id, repeated.id)
        XCTAssertEqual(result.last?.id, other.id)
    }

    func testHistoryRespectsLimit() {
        let items = (0..<4).map { ClipboardItem(content: .text("Item \($0)")) }
        let newest = ClipboardItem(content: .text("Newest"))

        let result = ClipboardHistory.inserting(newest, into: items, limit: 3)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.first?.id, newest.id)
    }

    func testPreviewTitleShowsCopiedTextInsteadOfGenericType() {
        let item = ClipboardItem(content: .text("Launch\nnotes for the new shelf"))

        XCTAssertEqual(item.previewTitle, "Launch notes for the new shelf")
    }

    func testPreviewTitleShowsCopiedFileNames() {
        let item = ClipboardItem(content: .files([
            URL(fileURLWithPath: "/tmp/Cove-one.txt"),
            URL(fileURLWithPath: "/tmp/Cove-two.txt")
        ]))

        XCTAssertEqual(item.previewTitle, "Cove-one.txt, Cove-two.txt")
    }
}
