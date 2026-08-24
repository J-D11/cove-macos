import XCTest
@testable import QuietDeck

final class ClipboardIntelligenceServiceTests: XCTestCase {
    private let service = ClipboardIntelligenceService()

    func testRemovesKnownTrackingParametersWithoutDroppingUsefulQuery() {
        let url = URL(string: "https://example.com/story?id=42&utm_source=cove&fbclid=abc")!

        let cleaned = service.removingTrackingParameters(from: url)

        XCTAssertEqual(cleaned?.absoluteString, "https://example.com/story?id=42")
    }

    func testFormatsJSONDeterministically() {
        let formatted = service.formattedJSON(from: #"{"z":1,"a":true}"#)

        XCTAssertEqual(formatted, "{\n  \"a\" : true,\n  \"z\" : 1\n}")
    }

    func testDetectsURLJSONEmailPhoneColorAndRichTextActions() {
        XCTAssertTrue(actionIDs(for: "https://example.com?utm_source=cove").contains("open-link"))
        XCTAssertTrue(actionIDs(for: #"{"value":1}"#).contains("format-json"))
        XCTAssertTrue(actionIDs(for: "hello@example.com").contains("compose-email"))
        XCTAssertTrue(actionIDs(for: "+1 (915) 555-1212").contains("call-number"))
        XCTAssertTrue(actionIDs(for: "#3366FF").contains("copy-rgb"))

        let richText = ClipboardItem(
            content: .richText(
                RichTextContent(plainText: "Cove", rtfData: Data(), htmlData: nil)
            )
        )
        XCTAssertTrue(service.actions(for: richText).map(\.id).contains("paste-plain"))
    }

    private func actionIDs(for text: String) -> [String] {
        service.actions(for: ClipboardItem(content: .text(text))).map(\.id)
    }
}
