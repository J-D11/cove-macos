import AppKit
import XCTest
@testable import QuietDeck

@MainActor
final class ClipboardServiceTests: XCTestCase {
    func testCopiesTextBackToPasteboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)

        service.copy(ClipboardItem(content: .text("Ready to paste")))

        XCTAssertEqual(pasteboard.string(forType: .string), "Ready to paste")
    }

    func testCopiesFileURLsBackToPasteboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)
        let urls = [
            URL(fileURLWithPath: "/tmp/Cove-one.txt"),
            URL(fileURLWithPath: "/tmp/Cove-two.txt")
        ]

        service.copy(ClipboardItem(content: .files(urls)))

        let copiedURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL]
        XCTAssertEqual(copiedURLs?.map { $0 as URL }, urls)
    }
}
