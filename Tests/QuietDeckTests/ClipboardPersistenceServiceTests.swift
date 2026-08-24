import Foundation
import XCTest
@testable import QuietDeck

final class ClipboardPersistenceServiceTests: XCTestCase {
    func testRoundTripsMetadataPinningRichTextAndFiles() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoveTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let service = ClipboardPersistenceService(directoryURL: directoryURL)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let rtf = Data("{\\rtf1 Cove}".utf8)
        let html = Data("<strong>Cove</strong>".utf8)
        let richText = ClipboardItem(
            content: .richText(
                RichTextContent(
                    plainText: "Cove",
                    rtfData: rtf,
                    htmlData: html
                )
            ),
            createdAt: createdAt,
            sourceApplicationName: "Notes",
            sourceApplicationBundleIdentifier: "com.apple.Notes",
            isPinned: true
        )
        let fileURLs = [
            URL(fileURLWithPath: "/tmp/Cove-one.txt"),
            URL(fileURLWithPath: "/tmp/Cove-two.txt")
        ]
        let files = ClipboardItem(content: .files(fileURLs))

        try service.save([richText, files])
        let loaded = try service.load()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, richText.id)
        XCTAssertEqual(loaded[0].createdAt, createdAt)
        XCTAssertEqual(loaded[0].sourceApplicationName, "Notes")
        XCTAssertEqual(loaded[0].sourceApplicationBundleIdentifier, "com.apple.Notes")
        XCTAssertTrue(loaded[0].isPinned)
        guard case .richText(let loadedRichText) = loaded[0].content else {
            return XCTFail("Expected rich text")
        }
        XCTAssertEqual(loadedRichText.plainText, "Cove")
        XCTAssertEqual(loadedRichText.rtfData, rtf)
        XCTAssertEqual(loadedRichText.htmlData, html)
        XCTAssertEqual(loaded[1].fileURLs, fileURLs)
    }

    func testClearRemovesPersistedHistory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoveTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let service = ClipboardPersistenceService(directoryURL: directoryURL)
        try service.save([ClipboardItem(content: .text("Temporary"))])

        try service.clear()

        XCTAssertEqual(try service.load().count, 0)
    }
}
