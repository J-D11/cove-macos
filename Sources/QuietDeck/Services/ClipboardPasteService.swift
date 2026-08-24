import AppKit
import CoreGraphics

@MainActor
final class ClipboardPasteService {
    func paste(
        _ item: ClipboardItem,
        using clipboardService: ClipboardService
    ) -> Bool {
        guard AccessibilityPermissionService.isTrusted else {
            AccessibilityPermissionService.openSettings()
            return false
        }

        let targetApplication = NSWorkspace.shared.frontmostApplication
        clipboardService.copy(item)
        targetApplication?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: 9,
                keyDown: true
            )
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: 9,
                keyDown: false
            )
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
        return true
    }
}
