import AppKit

@MainActor
final class ClipboardKeyboardShortcutService {
    var isEnabled: () -> Bool = { true }
    var pasteItemAtIndex: (Int) -> Void = { _ in }
    var moveSelection: (Int) -> Void = { _ in }
    var pasteSelectedItem: () -> Void = {}

    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                _ = self?.handle(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        guard isEnabled() else { return false }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == [.command, .option] else { return false }

        if let characters = event.charactersIgnoringModifiers,
           let number = Int(characters),
           (1...9).contains(number) {
            pasteItemAtIndex(number - 1)
            return true
        }

        switch event.keyCode {
        case 123:
            moveSelection(-1)
            return true
        case 124:
            moveSelection(1)
            return true
        case 36, 76:
            pasteSelectedItem()
            return true
        default:
            return false
        }
    }
}
