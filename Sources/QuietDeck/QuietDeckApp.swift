import AppKit
import OSLog

@main
enum QuietDeckApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.astralworkslabs.QuietDeck",
        category: "Application"
    )
    private var panelController: NotchPanelController?
    private var statusItem: NSStatusItem?
    private var keepOpenMenuItem: NSMenuItem?
    private var nowPlayingMenuItem: NSMenuItem?
    private var visualClipboardMenuItem: NSMenuItem?
    private var accessMenuItem: NSMenuItem?
    private var nativeAppearanceMenuItem: NSMenuItem?
    private var menuBarItemsMenu: NSMenu?
    private var updateMenuItem: NSMenuItem?
    private var updateTask: Task<Void, Never>?
    private let updateService = UpdateService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let otherCopies = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.astralworkslabs.QuietDeck"
        ).filter { $0.processIdentifier != ownPID }
        for existingCopy in otherCopies {
            logger.warning(
                "Closing a duplicate Quiet Deck instance existingPID=\(existingCopy.processIdentifier, privacy: .public)"
            )
            existingCopy.terminate()
        }

        NSApp.setActivationPolicy(.accessory)
        let previewMode = ProcessInfo.processInfo.arguments.contains("--preview")
        let store = ShelfStore.shared
        store.start(previewMode: previewMode)

        if ProcessInfo.processInfo.arguments.contains("--show-menu-items") {
            store.reveal(for: 30)
        }

        let panelController = NotchPanelController(store: store, previewMode: previewMode)
        self.panelController = panelController
        panelController.start()
        installStatusItem()
        logger.info("Launched accessibilityTrusted=\(store.accessibilityGranted, privacy: .public)")

        if ProcessInfo.processInfo.arguments.contains("--request-access"),
           !store.accessibilityGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                store.requestAccessibility()
            }
        }

        if ProcessInfo.processInfo.arguments.contains("--request-screen-recording"),
           !store.screenRecordingGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                store.requestNativeAppearance()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.stop()
        ShelfStore.shared.stop()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        let store = ShelfStore.shared
        keepOpenMenuItem?.state = store.keepOpen ? .on : .off
        nowPlayingMenuItem?.state = store.showsNowPlaying ? .on : .off
        visualClipboardMenuItem?.state = store.showsVisualClipboard ? .on : .off
        accessMenuItem?.title = store.menuAccessStatusTitle
        accessMenuItem?.toolTip = store.menuAccessDiagnostic
        accessMenuItem?.image = NSImage(
            systemSymbolName: store.accessibilityGranted && !store.menuItems.isEmpty
                ? "checkmark.circle.fill"
                : (store.accessibilityGranted ? "exclamationmark.circle.fill" : "hand.raised.fill"),
            accessibilityDescription: nil
        )
        nativeAppearanceMenuItem?.title = store.screenRecordingGranted
            ? "Native Menu Appearance Enabled"
            : "Enable Native Menu Appearance…"
        nativeAppearanceMenuItem?.image = NSImage(
            systemSymbolName: store.screenRecordingGranted
                ? "checkmark.circle.fill"
                : "rectangle.inset.filled.and.person.filled",
            accessibilityDescription: nil
        )
        updateMenuItem?.title = updateTask == nil ? "Check for Updates…" : "Checking for Updates…"
        updateMenuItem?.isEnabled = updateTask == nil
        rebuildMenuBarItemsMenu()
    }

    private func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = CoveMark.image()
            button.image?.isTemplate = true
            button.toolTip = "Cove"
        }

        let menu = NSMenu(title: "Cove")
        menu.delegate = self

        let keepOpenItem = makeMenuItem(title: "Keep Shelf Open", action: #selector(toggleKeepOpen))
        menu.addItem(keepOpenItem)
        keepOpenMenuItem = keepOpenItem

        let nowPlayingItem = makeMenuItem(
            title: "Now Playing",
            action: #selector(toggleNowPlaying)
        )
        nowPlayingItem.state = ShelfStore.shared.showsNowPlaying ? .on : .off
        menu.addItem(nowPlayingItem)
        nowPlayingMenuItem = nowPlayingItem

        let visualClipboardItem = makeMenuItem(
            title: "Visual Clipboard",
            action: #selector(toggleVisualClipboard)
        )
        visualClipboardItem.state = ShelfStore.shared.showsVisualClipboard ? .on : .off
        menu.addItem(visualClipboardItem)
        visualClipboardMenuItem = visualClipboardItem

        menu.addItem(makeMenuItem(title: "Show Cove", action: #selector(showMenuItems)))
        let menuItemsItem = NSMenuItem(title: "Menu Bar Items", action: nil, keyEquivalent: "")
        let menuItemsMenu = NSMenu(title: "Menu Bar Items")
        menuItemsItem.submenu = menuItemsMenu
        menu.addItem(menuItemsItem)
        menuBarItemsMenu = menuItemsMenu
        rebuildMenuBarItemsMenu()
        menu.addItem(.separator())

        let accessItem = makeMenuItem(title: "Enable Menu Access", action: #selector(requestMenuAccess))
        menu.addItem(accessItem)
        accessMenuItem = accessItem

        menu.addItem(
            makeMenuItem(
                title: "Open Accessibility Settings…",
                action: #selector(openAccessibilitySettings)
            )
        )

        let nativeAppearanceItem = makeMenuItem(
            title: "Enable Native Menu Appearance…",
            action: #selector(requestNativeAppearance)
        )
        menu.addItem(nativeAppearanceItem)
        nativeAppearanceMenuItem = nativeAppearanceItem

        let refreshItem = makeMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(refreshItem)
        let updateItem = makeMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates)
        )
        menu.addItem(updateItem)
        updateMenuItem = updateItem
        menu.addItem(.separator())

        let quitItem = makeMenuItem(title: "Quit Cove", action: #selector(quit), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func makeMenuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func toggleKeepOpen() {
        let store = ShelfStore.shared
        store.keepOpen.toggle()
        store.dismissManualReveal()
        store.isPresented = store.keepOpen
    }

    @objc private func showMenuItems() {
        ShelfStore.shared.reveal()
    }

    @objc private func toggleNowPlaying() {
        ShelfStore.shared.toggleNowPlayingVisibility()
    }

    @objc private func toggleVisualClipboard() {
        ShelfStore.shared.toggleVisualClipboardVisibility()
    }

    @objc private func toggleMenuBarItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = ShelfStore.shared.menuItems.first(where: { $0.selectionID == id }) else {
            return
        }
        ShelfStore.shared.toggleMenuItemSelection(item)
    }

    private func rebuildMenuBarItemsMenu() {
        guard let menu = menuBarItemsMenu else { return }
        menu.removeAllItems()
        let store = ShelfStore.shared
        guard !store.menuItems.isEmpty else {
            let emptyItem = NSMenuItem(title: "No menu-bar items found", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }
        for itemModel in store.menuItems {
            let item = makeMenuItem(
                title: itemModel.name,
                action: #selector(toggleMenuBarItem(_:))
            )
            item.representedObject = itemModel.selectionID
            item.state = store.selectedMenuItemIDs.contains(itemModel.selectionID) ? .on : .off
            item.image = itemModel.ownerIcon
            item.image?.size = NSSize(width: 16, height: 16)
            menu.addItem(item)
        }
    }

    @objc private func requestMenuAccess() {
        let store = ShelfStore.shared
        if store.accessibilityGranted {
            store.refresh()
            return
        }
        store.requestAccessibility()
    }

    @objc private func openAccessibilitySettings() {
        ShelfStore.shared.openAccessibilitySettings()
    }

    @objc private func requestNativeAppearance() {
        let store = ShelfStore.shared
        if store.screenRecordingGranted {
            store.refreshNativeAppearance()
        } else {
            store.requestNativeAppearance()
        }
    }

    @objc private func refresh() {
        ShelfStore.shared.refresh()
    }

    @objc private func checkForUpdates() {
        guard updateTask == nil else { return }
        updateMenuItem?.title = "Checking for Updates…"
        updateMenuItem?.isEnabled = false

        updateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.updateTask = nil
                self.updateMenuItem?.title = "Check for Updates…"
                self.updateMenuItem?.isEnabled = true
            }

            do {
                guard let update = try await self.updateService.checkForUpdates() else {
                    self.showUpdateAlert(
                        title: "Cove is up to date",
                        message: "You are running Cove \(self.updateService.versionDescription)."
                    )
                    return
                }

                let alert = NSAlert()
                alert.messageText = "Cove \(update.version) is available"
                alert.informativeText = "Install \(update.releaseName)? Cove will quit and reopen after the signed update is verified."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Install Update")
                alert.addButton(withTitle: "Later")

                guard alert.runModal() == .alertFirstButtonReturn else { return }
                self.updateMenuItem?.title = "Installing Update…"
                try await self.updateService.prepareInstallation(for: update)
                NSApp.terminate(nil)
            } catch {
                self.showUpdateAlert(
                    title: "Update failed",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func showUpdateAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
