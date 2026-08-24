import XCTest
@testable import QuietDeck

final class ClipboardUndoBufferTests: XCTestCase {
    func testRestoresOneSnapshotAndThenClearsUndoState() {
        let item = ClipboardItem(content: .text("Recover me"))
        var buffer = ClipboardUndoBuffer()

        buffer.capture([item])

        XCTAssertTrue(buffer.canUndo)
        XCTAssertEqual(buffer.restore()?.map(\.id), [item.id])
        XCTAssertFalse(buffer.canUndo)
        XCTAssertNil(buffer.restore())
    }

    func testEmptyHistoryDoesNotCreateUndoState() {
        var buffer = ClipboardUndoBuffer()
        buffer.capture([])
        XCTAssertFalse(buffer.canUndo)
    }
}
