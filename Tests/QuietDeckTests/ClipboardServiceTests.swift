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

    func testCopiesRichTextFormatsBackToPasteboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)
        let rtf = Data("{\\rtf1 Cove}".utf8)
        let html = Data("<strong>Cove</strong>".utf8)

        service.copy(
            ClipboardItem(
                content: .richText(
                    RichTextContent(
                        plainText: "Cove",
                        rtfData: rtf,
                        htmlData: html
                    )
                )
            )
        )

        XCTAssertEqual(pasteboard.string(forType: .string), "Cove")
        XCTAssertEqual(pasteboard.data(forType: .rtf), rtf)
        XCTAssertEqual(pasteboard.data(forType: .html), html)
    }

    func testCapturesRichTextFormats() {
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)
        let rtf = Data("{\\rtf1\\ansi Saved}".utf8)
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString("Saved", forType: .string)
        pasteboardItem.setData(rtf, forType: .rtf)
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([pasteboardItem]))
        XCTAssertEqual(pasteboard.string(forType: .string), "Saved")
        XCTAssertEqual(pasteboard.data(forType: .rtf), rtf)
        var capturedItem: ClipboardItem?
        service.onItemCaptured = { capturedItem = $0 }

        service.capturePasteboardChange()

        guard let capturedItem else {
            return XCTFail("Expected a captured item")
        }
        guard case .richText(let richText) = capturedItem.content else {
            return XCTFail("Expected rich text, got \(capturedItem.title)")
        }
        XCTAssertEqual(richText.plainText, "Saved")
        XCTAssertEqual(richText.rtfData, rtf)
    }

    func testPrivacyCallbackCanRejectPasteboardChange() {
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("Secret", forType: .string)
        var privacyCallbackWasEvaluated = false
        service.shouldCapture = { _, _ in
            privacyCallbackWasEvaluated = true
            return false
        }
        var didCapture = false
        service.onItemCaptured = { _ in didCapture = true }

        service.capturePasteboardChange()

        XCTAssertTrue(privacyCallbackWasEvaluated)
        XCTAssertFalse(didCapture)
    }
}
