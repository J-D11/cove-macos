import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    @Published var menuItems: [MenuBarItemModel] = []
    @Published private(set) var selectedMenuItemIDs: [String] = []
    @Published var nowPlaying: NowPlayingItem?
    @Published private(set) var clipboardItems: [ClipboardItem] = []
    @Published var isPresented = false
    @Published var accessibilityGranted = AccessibilityPermissionService.isTrusted
    @Published var screenRecordingGranted = ScreenRecordingPermissionService.isGranted
    @Published private(set) var lastScanResult: MenuBarScanResult?
    @Published private(set) var visibleMenuItemIDs = Set<String>()
    @Published private(set) var nativeSnapshotPassCompleted = false
    @Published private(set) var manualRevealDeadline = Date.distantPast
    @Published private(set) var externalMenuInteractionActive = false
    @Published var keepOpen: Bool {
        didSet { UserDefaults.standard.set(keepOpen, forKey: Self.keepOpenKey) }
    }
    @Published var showsNowPlaying: Bool {
        didSet { UserDefaults.standard.set(showsNowPlaying, forKey: Self.showsNowPlayingKey) }
    }
    @Published var showsVisualClipboard: Bool {
        didSet { UserDefaults.standard.set(showsVisualClipboard, forKey: Self.showsVisualClipboardKey) }
    }

    private static let keepOpenKey = "QuietDeck.keepOpen"
    private static let selectedMenuItemIDsKey = "Cove.selectedMenuItemIDs"
    private static let showsNowPlayingKey = "Cove.showsNowPlaying"
    private static let showsVisualClipboardKey = "Cove.showsVisualClipboard"
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.astralworkslabs.QuietDeck",
        category: "ShelfStore"
    )
    private let menuBarService = MenuBarItemService()
    private let nativeSnapshotService = NativeMenuBarSnapshotService()
    private let nowPlayingService = NowPlayingService()
    private let clipboardService = ClipboardService()
    private var refreshTimer: Timer?
    private var permissionTimer: Timer?
    private var nativeSnapshotTimer: Timer?
    private var nowPlayingTimer: Timer?
    private var nativeSnapshotTask: Task<Void, Never>?
    private var nowPlayingRequestInFlight = false
    private var externalMenuMonitorTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var previewMode = false

    private init() {
        keepOpen = UserDefaults.standard.bool(forKey: Self.keepOpenKey)
        showsNowPlaying = UserDefaults.standard.object(forKey: Self.showsNowPlayingKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.showsNowPlayingKey)
        showsVisualClipboard = UserDefaults.standard.object(forKey: Self.showsVisualClipboardKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.showsVisualClipboardKey)
        selectedMenuItemIDs = MenuBarSelection.normalizedIDs(
            UserDefaults.standard.stringArray(forKey: Self.selectedMenuItemIDsKey) ?? []
        )
        clipboardService.onItemCaptured = { [weak self] item in
            self?.insertClipboardItem(item)
        }
    }

    var selectedMenuItems: [MenuBarItemModel] {
        let itemsByID = Dictionary(
            menuItems.map { ($0.selectionID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return selectedMenuItemIDs.compactMap { itemsByID[$0] }
    }

    var menuAccessStatusTitle: String {
        guard accessibilityGranted else { return "Enable Menu Access" }
        guard !menuItems.isEmpty else { return "Access Enabled, No Items Found" }
        return "Menu Access: \(menuItems.count) Items Found"
    }

    var menuAccessDiagnostic: String {
        guard accessibilityGranted else {
            return "Cove is not currently trusted by macOS Accessibility."
        }
        guard let result = lastScanResult else {
            return "Accessibility is enabled. The menu-bar scan has not completed yet."
        }
        return "Scanned \(result.candidateCount) processes, found \(result.accessibilityOwnerCount) Accessibility owners, \(result.windowFallbackCount) window fallbacks, and \(result.items.count) total items."
    }

    var preferredExpandedWidth: CGFloat {
        let mediaWidth: CGFloat = showsNowPlaying && nowPlaying != nil ? 248 : 0
        let clipboardWidth: CGFloat
        if showsVisualClipboard {
            clipboardWidth = clipboardItems.isEmpty
                ? 116
                : min(CGFloat(clipboardItems.count), 3) * 56 + 8
        } else {
            clipboardWidth = 0
        }
        let itemsWidth = selectedMenuItems.reduce(CGFloat.zero) { partial, item in
            partial + min(max(item.nativeDisplayWidth + 12, 32), 104)
        }
        let contentWidth: CGFloat
        if !accessibilityGranted || menuItems.isEmpty {
            contentWidth = 190
        } else if selectedMenuItems.isEmpty {
            contentWidth = 160
        } else {
            contentWidth = min(itemsWidth, 520)
        }
        let sectionCount = [mediaWidth, clipboardWidth, contentWidth].filter { $0 > 0 }.count
        let dividerWidth = CGFloat(max(sectionCount - 1, 0)) * 17
        return min(max(mediaWidth + clipboardWidth + contentWidth + dividerWidth + 32, 250), 920)
    }

    func start(previewMode: Bool) {
        self.previewMode = previewMode
        if previewMode {
            isPresented = true
            loadPreviewContent()
            return
        }

        refresh()
        refreshNowPlaying()
        if showsVisualClipboard {
            clipboardService.start()
        }
        installWorkspaceObservers()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isPresented else { return }
                self.refresh()
            }
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissionState()
                self?.refreshScreenRecordingState()
            }
        }
        nativeSnapshotTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPresented else { return }
                self.refreshNativeSnapshots()
            }
        }
        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.showsNowPlaying else { return }
                self.refreshNowPlaying()
            }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        permissionTimer?.invalidate()
        nativeSnapshotTimer?.invalidate()
        nowPlayingTimer?.invalidate()
        clipboardService.stop()
        nativeSnapshotTask?.cancel()
        externalMenuMonitorTask?.cancel()
        refreshTimer = nil
        permissionTimer = nil
        nativeSnapshotTimer = nil
        nowPlayingTimer = nil
        nativeSnapshotTask = nil
        externalMenuMonitorTask = nil
        externalMenuInteractionActive = false
        nowPlayingRequestInFlight = false
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    func refresh() {
        accessibilityGranted = AccessibilityPermissionService.isTrusted
        guard accessibilityGranted else {
            menuItems = []
            visibleMenuItemIDs = []
            nativeSnapshotPassCompleted = false
            lastScanResult = nil
            logger.debug("Refresh completed without Accessibility trust")
            return
        }

        let scanResult = menuBarService.scan()
        lastScanResult = scanResult
        menuItems = scanResult.items
        visibleMenuItemIDs.formIntersection(Set(scanResult.items.map(\.id)))
        refreshNativeSnapshots()
        logger.debug("Refresh completed menuItems=\(scanResult.items.count, privacy: .public)")
    }

    func requestAccessibility() {
        let trusted = AccessibilityPermissionService.requestAccess()
        if !trusted {
            AccessibilityPermissionService.openSettings()
        }
        refreshPermissionState()
    }

    func openAccessibilitySettings() {
        AccessibilityPermissionService.openSettings()
    }

    func requestNativeAppearance() {
        let granted = ScreenRecordingPermissionService.requestAccess()
        screenRecordingGranted = granted
        if granted {
            refreshNativeSnapshots()
        } else {
            ScreenRecordingPermissionService.openSettings()
        }
    }

    func refreshNativeAppearance() {
        refreshNativeSnapshots()
    }

    func activate(_ item: MenuBarItemModel) {
        // Let SwiftUI finish the proxy button's mouse-up before opening the real
        // status item. Keeping this panel stable also prevents transient menus
        // such as CodexBar from treating Quiet Deck's collapse as a dismissal.
        externalMenuMonitorTask?.cancel()
        let baselineWindows = MenuBarTransientWindowMonitor.transientWindowIDs(
            ownerPID: item.ownerPID
        )
        externalMenuInteractionActive = true
        reveal(for: ShelfPresentationPolicy.externalMenuHoldDuration)
        externalMenuMonitorTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: ShelfPresentationPolicy.menuProxyActivationDelayNanoseconds
            )
            guard let self, !Task.isCancelled else { return }
            if !self.menuBarService.activate(item) {
                self.finishExternalMenuInteraction()
                return
            }

            let detectionDeadline = Date().addingTimeInterval(1.5)
            var observedTransientWindow = false
            while !Task.isCancelled {
                let currentWindows = MenuBarTransientWindowMonitor.transientWindowIDs(
                    ownerPID: item.ownerPID
                )
                let openedWindows = currentWindows.subtracting(baselineWindows)
                if !openedWindows.isEmpty {
                    observedTransientWindow = true
                } else if observedTransientWindow || Date() >= detectionDeadline {
                    self.finishExternalMenuInteraction()
                    return
                }

                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    func toggleMenuItemSelection(_ item: MenuBarItemModel) {
        persistSelectedMenuItemIDs(
            MenuBarSelection.toggled(item.selectionID, in: selectedMenuItemIDs)
        )
        reveal()
    }

    func moveSelectedMenuItem(_ id: String, before targetID: String) {
        persistSelectedMenuItemIDs(
            MenuBarSelection.moving(id, before: targetID, in: selectedMenuItemIDs)
        )
    }

    func toggleNowPlayingVisibility() {
        showsNowPlaying.toggle()
        if showsNowPlaying {
            refreshNowPlaying()
            reveal()
        }
    }

    func toggleVisualClipboardVisibility() {
        showsVisualClipboard.toggle()
        if showsVisualClipboard {
            clipboardService.start()
            reveal()
        } else {
            clipboardService.stop()
            clipboardItems = []
        }
    }

    func copyClipboardItem(_ item: ClipboardItem) {
        clipboardService.copy(item)
        insertClipboardItem(item)
        reveal()
    }

    func removeClipboardItem(_ item: ClipboardItem) {
        clipboardItems.removeAll { $0.id == item.id }
    }

    func clearClipboardHistory() {
        clipboardItems = []
    }

    func importClipboardProviders(_ providers: [NSItemProvider]) -> Bool {
        guard showsVisualClipboard, !providers.isEmpty else { return false }
        var accepted = false
        for provider in providers.prefix(ClipboardHistory.maximumItemCount) {
            if provider.canLoadObject(ofClass: NSURL.self) {
                accepted = true
                provider.loadObject(ofClass: NSURL.self) { [weak self] object, _ in
                    guard let url = object as? URL else { return }
                    Task { @MainActor in
                        self?.insertClipboardItem(ClipboardItem(content: .files([url])))
                    }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                accepted = true
                provider.loadObject(ofClass: NSImage.self) { [weak self] object, _ in
                    guard let image = object as? NSImage else { return }
                    Task { @MainActor in
                        self?.insertClipboardItem(ClipboardItem(content: .image(image)))
                    }
                }
            } else if provider.canLoadObject(ofClass: NSString.self) {
                accepted = true
                provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
                    guard let text = object as? String, !text.isEmpty else { return }
                    Task { @MainActor in
                        self?.insertClipboardItem(ClipboardItem(content: .text(text)))
                    }
                }
            }
        }
        if accepted {
            reveal()
        }
        return accepted
    }

    func performNowPlayingCommand(_ command: NowPlayingCommand) {
        guard let nowPlaying else { return }
        nowPlayingService.perform(command, for: nowPlaying)
        if command == .togglePlayback {
            self.nowPlaying = NowPlayingItem(
                title: nowPlaying.title,
                artist: nowPlaying.artist,
                album: nowPlaying.album,
                artwork: nowPlaying.artwork,
                source: nowPlaying.source,
                isPlaying: !(nowPlaying.isPlaying ?? false),
                externalURL: nowPlaying.externalURL
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.refreshNowPlaying()
        }
    }

    func openNowPlaying() {
        guard let url = nowPlaying?.externalURL else { return }
        NSWorkspace.shared.open(url)
    }

    func reveal(for duration: TimeInterval = 2.5) {
        manualRevealDeadline = Date().addingTimeInterval(duration)
        isPresented = true
    }

    func dismissManualReveal() {
        manualRevealDeadline = .distantPast
    }

    private func finishExternalMenuInteraction() {
        externalMenuInteractionActive = false
        externalMenuMonitorTask = nil
        dismissManualReveal()
    }

    private func refreshPermissionState() {
        let granted = AccessibilityPermissionService.isTrusted
        guard granted != accessibilityGranted else { return }
        accessibilityGranted = granted
        logger.info("Accessibility trust changed granted=\(granted, privacy: .public)")
        refresh()
    }

    private func refreshScreenRecordingState() {
        let granted = ScreenRecordingPermissionService.isGranted
        guard granted != screenRecordingGranted else { return }
        screenRecordingGranted = granted
        logger.info("Screen Recording trust changed granted=\(granted, privacy: .public)")
        if granted {
            refreshNativeSnapshots()
        } else {
            visibleMenuItemIDs = []
            nativeSnapshotPassCompleted = false
        }
    }

    private func refreshNativeSnapshots() {
        guard screenRecordingGranted,
              nativeSnapshotTask == nil,
              !menuItems.isEmpty else {
            return
        }

        let items = menuItems
        nativeSnapshotTask = Task { [weak self] in
            guard let self else { return }
            let snapshots = await self.nativeSnapshotService.snapshots(for: items)
            guard !Task.isCancelled else {
                self.nativeSnapshotTask = nil
                return
            }

            if let snapshots {
                self.visibleMenuItemIDs = Set(snapshots.keys)
                self.nativeSnapshotPassCompleted = true
                self.menuItems = self.menuItems.map { item in
                    var updated = item
                    updated.nativeSnapshot = snapshots[item.id]
                    return updated
                }
            }
            self.nativeSnapshotTask = nil
        }
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ] {
            workspaceObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        self?.refresh()
                    }
                }
            )
        }
    }

    private func refreshNowPlaying() {
        guard showsNowPlaying, !nowPlayingRequestInFlight else { return }
        nowPlayingRequestInFlight = true
        nowPlayingService.fetch { [weak self] item in
            guard let self else { return }
            self.nowPlaying = item
            self.nowPlayingRequestInFlight = false
        }
    }

    private func persistSelectedMenuItemIDs(_ ids: [String]) {
        selectedMenuItemIDs = MenuBarSelection.normalizedIDs(ids)
        UserDefaults.standard.set(selectedMenuItemIDs, forKey: Self.selectedMenuItemIDsKey)
    }

    private func insertClipboardItem(_ item: ClipboardItem) {
        clipboardItems = ClipboardHistory.inserting(item, into: clipboardItems)
        reveal()
    }

    private func loadPreviewContent() {
        accessibilityGranted = true
        screenRecordingGranted = true
        nativeSnapshotPassCompleted = true
        menuItems = [
            previewMenuItem(id: "wifi", name: "Wi-Fi", symbol: "wifi"),
            previewMenuItem(id: "sound", name: "Sound", symbol: "speaker.wave.2.fill"),
            previewMenuItem(id: "battery", name: "Battery", symbol: "battery.75percent", value: "85%")
        ]
        selectedMenuItemIDs = menuItems.map(\.selectionID)
        showsNowPlaying = true
        showsVisualClipboard = true
        clipboardItems = [
            ClipboardItem(content: .text("Launch notes")),
            ClipboardItem(
                content: .image(
                    NSImage(
                        systemSymbolName: "photo.fill",
                        accessibilityDescription: "Sample image"
                    ) ?? NSImage(size: NSSize(width: 32, height: 32))
                )
            ),
            ClipboardItem(content: .files([URL(fileURLWithPath: "/tmp/Cove-Mockup.pdf")]))
        ]
        nowPlaying = NowPlayingItem(
            title: "The Creative Act",
            artist: "Rick Rubin",
            album: "An Audiobook",
            artwork: nil,
            source: .spotify,
            isPlaying: true,
            externalURL: URL(string: "spotify:track:preview")
        )
    }

    private func previewMenuItem(id: String, name: String, symbol: String, value: String? = nil) -> MenuBarItemModel {
        MenuBarItemModel(
            id: id,
            ownerBundleIdentifier: "com.apple.controlcenter",
            ownerPID: 0,
            itemIdentifier: id,
            itemIndex: 0,
            name: name,
            symbolName: symbol,
            ownerIcon: nil,
            compactValue: value,
            accessibilityFrame: nil,
            xPosition: 0
        )
    }

}
