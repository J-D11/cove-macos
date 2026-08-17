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
}
