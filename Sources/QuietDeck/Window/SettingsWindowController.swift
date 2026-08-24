import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(store: ShelfStore, checkForUpdates: @escaping () -> Void) {
        let hostingController = NSHostingController(
            rootView: CoveSettingsView(
                store: store,
                checkForUpdates: checkForUpdates
            )
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Cove Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 390))
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
