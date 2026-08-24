import AppKit

@MainActor
final class ClipboardKeyboardShortcutService {
    var isEnabled: () -> Bool = { true }
    var pasteItemAtIndex: (Int) -> Void = { _ in }
    var moveSelection: (Int) -> Void = { _ in }
    var pasteSelectedItem: () -> Void = {}
    var setShortcutHUDPresented: (Bool) -> Void = { _ in }
    var selectMenuItemForReordering: (Int) -> Void = { _ in }
    var moveMenuItemForReordering: (Int) -> Void = { _ in }

    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleMonitoredEvent(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .flagsChanged {
                self.handleModifierChange(event)
                return event
            }
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
        setShortcutHUDPresented(false)
    }

    private func handleMonitoredEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            handleModifierChange(event)
        } else {
            _ = handle(event)
        }
    }

    func handleModifierChange(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isPresented = isEnabled()
            && modifiers.contains(.command)
            && modifiers.contains(.option)
        setShortcutHUDPresented(isPresented)
    }

    @discardableResult
    func handle(_ event: NSEvent) -> Bool {
        guard isEnabled() else { return false }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == [.command, .option, .shift] {
            switch event.keyCode {
            case 123:
                moveMenuItemForReordering(-1)
                return true
            case 124:
                moveMenuItemForReordering(1)
                return true
            case 125:
                selectMenuItemForReordering(1)
                return true
            case 126:
                selectMenuItemForReordering(-1)
                return true
            default:
                return false
            }
        }
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
