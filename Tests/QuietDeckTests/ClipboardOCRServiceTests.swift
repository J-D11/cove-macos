import AppKit
import XCTest
@testable import QuietDeck

final class ClipboardOCRServiceTests: XCTestCase {
    func testRecognizesLocallyRenderedText() async {
        let image = NSImage(size: NSSize(width: 520, height: 120))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        ("COVE OCR 7391" as NSString).draw(
            at: NSPoint(x: 24, y: 34),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 42, weight: .bold),
                .foregroundColor: NSColor.black
            ]
        )
        image.unlockFocus()

        let recognized = await ClipboardOCRService().recognizeText(in: image)

        XCTAssertTrue(recognized?.localizedCaseInsensitiveContains("COVE") == true)
        XCTAssertTrue(recognized?.contains("7391") == true)
    }
}
