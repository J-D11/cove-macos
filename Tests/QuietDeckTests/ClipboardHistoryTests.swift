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

    func testPinnedItemsSurviveTrimmingAndStayFirst() {
        let pinned = ClipboardItem(content: .text("Favorite"), isPinned: true)
        let items = (0..<4).map { ClipboardItem(content: .text("Item \($0)")) }

        let result = ClipboardHistory.trimming(items + [pinned], limit: 3)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.first?.id, pinned.id)
        XCTAssertTrue(result.first?.isPinned == true)
    }

    func testDuplicateCapturePreservesPinnedState() {
        let pinned = ClipboardItem(content: .text("Favorite"), isPinned: true)
        let recaptured = ClipboardItem(content: .text("Favorite"))

        let result = ClipboardHistory.inserting(recaptured, into: [pinned])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, recaptured.id)
        XCTAssertTrue(result.first?.isPinned == true)
    }

    func testSearchMatchesTextSourceApplicationAndFilePath() {
        let text = ClipboardItem(
            content: .text("Project launch notes"),
            sourceApplicationName: "Notes"
        )
        let file = ClipboardItem(
            content: .files([URL(fileURLWithPath: "/tmp/design/Cove-Mockup.pdf")])
        )

        XCTAssertTrue(text.matchesSearch("launch"))
        XCTAssertTrue(text.matchesSearch("notes"))
        XCTAssertTrue(file.matchesSearch("design"))
        XCTAssertFalse(file.matchesSearch("invoice"))
    }

    func testOnlySavedItemsPersistWhenRecentHistoryIsDisabled() {
        let recent = ClipboardItem(content: .text("Recent"))
        let saved = ClipboardItem(content: .text("Saved"), isPinned: true)

        let result = ClipboardHistory.itemsToPersist(
            from: [recent, saved],
            includesRecentHistory: false
        )

        XCTAssertEqual(result.map(\.id), [saved.id])
    }

    func testRecentAndSavedItemsPersistWhenHistoryIsEnabled() {
        let recent = ClipboardItem(content: .text("Recent"))
        let saved = ClipboardItem(content: .text("Saved"), isPinned: true)

        let result = ClipboardHistory.itemsToPersist(
            from: [recent, saved],
            includesRecentHistory: true
        )

        XCTAssertEqual(result.map(\.id), [recent.id, saved.id])
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

    func testMultiFileDragProviderPreservesAllURLs() {
        let urls = [
            URL(fileURLWithPath: "/tmp/Cove-one.txt"),
            URL(fileURLWithPath: "/tmp/Cove-two.txt")
        ]
        let item = ClipboardItem(content: .files(urls))
        let expectation = expectation(description: "Loads all dragged file URLs")

        item.itemProvider().loadDataRepresentation(
            forTypeIdentifier: ClipboardItem.multipleFileDragType
        ) { data, _ in
            let values = data.flatMap { try? JSONDecoder().decode([String].self, from: $0) }
            XCTAssertEqual(values?.compactMap(URL.init(string:)), urls)
            expectation.fulfill()
        }

        wait(for: [expectation])
    }
}
