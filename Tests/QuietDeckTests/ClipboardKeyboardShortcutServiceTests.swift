import AppKit
import XCTest
@testable import QuietDeck

@MainActor
final class ClipboardKeyboardShortcutServiceTests: XCTestCase {
    func testShiftArrowRoutesToMenuItemReordering() throws {
        let service = ClipboardKeyboardShortcutService()
        var moveOffset: Int?
        service.moveMenuItemForReordering = { moveOffset = $0 }
        let event = try XCTUnwrap(
            keyEvent(keyCode: 123, modifiers: [.command, .option, .shift])
        )

        XCTAssertTrue(service.handle(event))
        XCTAssertEqual(moveOffset, -1)
    }

    func testCommandOptionNumberRoutesToQuickPaste() throws {
        let service = ClipboardKeyboardShortcutService()
        var pastedIndex: Int?
        service.pasteItemAtIndex = { pastedIndex = $0 }
        let event = try XCTUnwrap(
            keyEvent(
                keyCode: 19,
                modifiers: [.command, .option],
                characters: "2"
            )
        )

        XCTAssertTrue(service.handle(event))
        XCTAssertEqual(pastedIndex, 1)
    }

    private func keyEvent(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        characters: String = ""
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )
    }
}
