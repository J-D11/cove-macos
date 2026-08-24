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
    private var clipboardCaptureMenuItem: NSMenuItem?
    private var clipboardItemsMenu: NSMenu?
    private var accessMenuItem: NSMenuItem?
    private var nativeAppearanceMenuItem: NSMenuItem?
    private var menuBarItemsMenu: NSMenu?
    private var updateMenuItem: NSMenuItem?
    private var updateTask: Task<Void, Never>?
    private var automaticUpdateTask: Task<Void, Never>?
    private var availableUpdate: CoveUpdate?
    private var keyboardShortcutService: ClipboardKeyboardShortcutService?
    private var settingsWindowController: SettingsWindowController?
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
        installKeyboardShortcuts()
        scheduleAutomaticUpdateCheckIfNeeded()
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
        keyboardShortcutService?.stop()
        automaticUpdateTask?.cancel()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        let store = ShelfStore.shared
        keepOpenMenuItem?.state = store.keepOpen ? .on : .off
        nowPlayingMenuItem?.state = store.showsNowPlaying ? .on : .off
        visualClipboardMenuItem?.state = store.showsVisualClipboard ? .on : .off
        clipboardCaptureMenuItem?.state = store.clipboardCapturePaused ? .on : .off
        clipboardCaptureMenuItem?.title = store.clipboardCapturePaused
            ? "Resume Clipboard Capture"
            : "Pause Clipboard Capture"
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
        updateUpdateMenuAppearance()
        rebuildClipboardItemsMenu()
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

        let clipboardCaptureItem = makeMenuItem(
            title: "Pause Clipboard Capture",
            action: #selector(toggleClipboardCapture)
        )
        menu.addItem(clipboardCaptureItem)
        clipboardCaptureMenuItem = clipboardCaptureItem

        let clipboardItemsItem = NSMenuItem(title: "Clipboard History", action: nil, keyEquivalent: "")
        let clipboardItemsMenu = NSMenu(title: "Clipboard History")
        clipboardItemsItem.submenu = clipboardItemsMenu
        menu.addItem(clipboardItemsItem)
        self.clipboardItemsMenu = clipboardItemsMenu
        rebuildClipboardItemsMenu()

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

        menu.addItem(
            makeMenuItem(
                title: "Settings…",
                action: #selector(openSettings),
                keyEquivalent: ","
            )
        )
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

    @objc private func toggleClipboardCapture() {
        ShelfStore.shared.toggleClipboardCapturePaused()
    }

    @objc private func pasteClipboardMenuItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = ShelfStore.shared.clipboardItems.first(where: { $0.id == id }) else {
            return
        }
        ShelfStore.shared.pasteClipboardItem(item)
    }

    @objc private func clearClipboardHistory() {
        ShelfStore.shared.clearClipboardHistory()
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
        let unavailableItems = store.unavailableSelectedMenuItems
        guard !store.menuItems.isEmpty || !unavailableItems.isEmpty else {
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

        if !unavailableItems.isEmpty {
            if !store.menuItems.isEmpty {
                menu.addItem(.separator())
            }
            let unavailableRoot = NSMenuItem(title: "Unavailable Items", action: nil, keyEquivalent: "")
            let unavailableMenu = NSMenu(title: "Unavailable Items")
            for unavailableItem in unavailableItems {
                let itemRoot = NSMenuItem(
                    title: unavailableItem.name,
                    action: nil,
                    keyEquivalent: ""
                )
                itemRoot.image = NSImage(
                    systemSymbolName: "exclamationmark.circle",
                    accessibilityDescription: "Unavailable"
                )
                let actions = NSMenu(title: unavailableItem.name)
                let repairItem = makeMenuItem(
                    title: "Open App and Rescan",
                    action: #selector(repairUnavailableMenuItem(_:))
                )
                repairItem.representedObject = unavailableItem.id
                actions.addItem(repairItem)
                let removeItem = makeMenuItem(
                    title: "Remove from Cove",
                    action: #selector(removeUnavailableMenuItem(_:))
                )
                removeItem.representedObject = unavailableItem.id
                actions.addItem(removeItem)
                itemRoot.submenu = actions
                unavailableMenu.addItem(itemRoot)
            }
            unavailableRoot.submenu = unavailableMenu
            menu.addItem(unavailableRoot)
        }
    }

    private func rebuildClipboardItemsMenu() {
        guard let menu = clipboardItemsMenu else { return }
        menu.removeAllItems()
        let store = ShelfStore.shared
        let items = Array(store.clipboardItems.prefix(9))
        guard !items.isEmpty else {
            let emptyItem = NSMenuItem(
                title: store.clipboardCapturePaused ? "Capture is paused" : "No clipboard history",
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        for (index, clipboardItem) in items.enumerated() {
            let prefix = clipboardItem.isPinned ? "📌 " : ""
            let title = menuTitle("\(index + 1). \(prefix)\(clipboardItem.previewTitle)")
            let item = makeMenuItem(
                title: title,
                action: #selector(pasteClipboardMenuItem(_:)),
                keyEquivalent: String(index + 1)
            )
            item.keyEquivalentModifierMask = [.command, .option]
            item.representedObject = clipboardItem.id
            item.toolTip = clipboardItem.previewTitle
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(
            makeMenuItem(
                title: "Clear History",
                action: #selector(clearClipboardHistory)
            )
        )
    }

    private func menuTitle(_ value: String) -> String {
        guard value.count > 30 else { return value }
        return String(value.prefix(29)) + "…"
    }

    @objc private func repairUnavailableMenuItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = ShelfStore.shared.unavailableSelectedMenuItems.first(where: { $0.id == id }) else {
            return
        }
        ShelfStore.shared.repairMenuItem(item)
    }

    @objc private func removeUnavailableMenuItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = ShelfStore.shared.unavailableSelectedMenuItems.first(where: { $0.id == id }) else {
            return
        }
        ShelfStore.shared.removeUnavailableMenuItem(item)
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

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                store: ShelfStore.shared,
                checkForUpdates: { [weak self] in
                    self?.checkForUpdates()
                }
            )
        }
        settingsWindowController?.show()
    }

    private func installKeyboardShortcuts() {
        let service = ClipboardKeyboardShortcutService()
        service.isEnabled = {
            ShelfStore.shared.quickPasteShortcutsEnabled
        }
        service.pasteItemAtIndex = { index in
            let store = ShelfStore.shared
            guard store.filteredClipboardItems.indices.contains(index) else { return }
            store.pasteClipboardItem(store.filteredClipboardItems[index])
        }
        service.moveSelection = { offset in
            ShelfStore.shared.moveClipboardSelection(by: offset)
        }
        service.pasteSelectedItem = {
            ShelfStore.shared.pasteSelectedClipboardItem()
        }
        service.start()
        keyboardShortcutService = service
    }

    private func scheduleAutomaticUpdateCheckIfNeeded() {
        guard automaticUpdateTask == nil else { return }
        automaticUpdateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.automaticUpdateTask = nil }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            while !Task.isCancelled {
                let store = ShelfStore.shared
                let lastCheck = UserDefaults.standard.object(
                    forKey: CovePreferences.lastAutomaticUpdateCheckKey
                ) as? Date ?? .distantPast
                let isDue = Date().timeIntervalSince(lastCheck) >= 24 * 60 * 60

                if store.automaticUpdateChecksEnabled, isDue, self.updateTask == nil {
                    do {
                        self.availableUpdate = try await self.updateService.checkForUpdates()
                        self.updateUpdateMenuAppearance()
                    } catch {
                        self.logger.info(
                            "Automatic update check failed: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                    UserDefaults.standard.set(
                        Date(),
                        forKey: CovePreferences.lastAutomaticUpdateCheckKey
                    )
                }

                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private func updateUpdateMenuAppearance() {
        guard let updateMenuItem else { return }
        if updateTask != nil {
            updateMenuItem.isEnabled = false
            if !updateMenuItem.title.contains("%") {
                updateMenuItem.title = "Checking for Updates…"
            }
            return
        }

        updateMenuItem.isEnabled = true
        if let availableUpdate {
            updateMenuItem.title = "Install Cove \(availableUpdate.version)…"
            updateMenuItem.image = NSImage(
                systemSymbolName: "arrow.down.circle.fill",
                accessibilityDescription: "Update available"
            )
        } else {
            updateMenuItem.title = "Check for Updates…"
            updateMenuItem.image = nil
        }
    }

    @objc private func checkForUpdates() {
        guard updateTask == nil else { return }
        updateMenuItem?.title = "Checking for Updates…"
        updateMenuItem?.isEnabled = false

        updateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.updateTask = nil
                self.updateUpdateMenuAppearance()
            }

            do {
                let update: CoveUpdate?
                if let availableUpdate = self.availableUpdate {
                    update = availableUpdate
                } else {
                    update = try await self.updateService.checkForUpdates()
                }
                guard let update else {
                    self.availableUpdate = nil
                    self.showUpdateAlert(
                        title: "Cove is up to date",
                        message: "You are running Cove \(self.updateService.versionDescription)."
                    )
                    return
                }
                self.availableUpdate = update

                let alert = NSAlert()
                alert.messageText = "Cove \(update.version) is available"
                alert.informativeText = "Install \(update.releaseName)? Cove will quit and reopen after the signed update is verified."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Install Update")
                alert.addButton(withTitle: "Release Notes")
                alert.addButton(withTitle: "Later")

                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    break
                case .alertSecondButtonReturn:
                    NSWorkspace.shared.open(update.releaseURL)
                    return
                default:
                    return
                }

                let progressPanel = UpdateProgressPanelController(version: update.version)
                progressPanel.show()
                defer { progressPanel.close() }
                self.updateMenuItem?.title = "Installing Update…"
                try await self.updateService.prepareInstallation(for: update) { progress in
                    progressPanel.update(progress: progress)
                    if let progress {
                        self.updateMenuItem?.title = "Installing Update \(Int(progress * 100))%…"
                    }
                }
                self.availableUpdate = nil
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
