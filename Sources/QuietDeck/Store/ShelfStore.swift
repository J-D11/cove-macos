import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    @Published var menuItems: [MenuBarItemModel] = []
    @Published private(set) var selectedMenuItemIDs: [String] = []
    @Published private(set) var selectedMenuItemNames: [String: String] = [:]
    @Published var nowPlaying: NowPlayingItem?
    @Published private(set) var clipboardItems: [ClipboardItem] = []
    @Published var clipboardSearchQuery = ""
    @Published var isClipboardSearchPresented = false
    @Published var selectedClipboardItemID: UUID?
    @Published var clipboardCollectionFilter: String?
    @Published var isClipboardShortcutHUDPresented = false
    @Published private(set) var canUndoClipboardChange = false
    @Published private(set) var shelfProfiles: [ShelfProfile] = []
    @Published private(set) var activeApplicationName: String?
    @Published private(set) var activeApplicationBundleIdentifier: String?
    @Published private(set) var keyboardReorderItemID: String?
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
        didSet {
            if !isApplyingShelfProfile {
                UserDefaults.standard.set(showsNowPlaying, forKey: Self.showsNowPlayingKey)
            }
            if showsNowPlaying {
                refreshNowPlaying()
            } else {
                nowPlaying = nil
            }
        }
    }
    @Published var showsVisualClipboard: Bool {
        didSet {
            if !isApplyingShelfProfile {
                UserDefaults.standard.set(showsVisualClipboard, forKey: Self.showsVisualClipboardKey)
            }
            if !showsVisualClipboard {
                isClipboardSearchPresented = false
                clipboardSearchQuery = ""
            }
            updateClipboardCaptureState()
        }
    }
    @Published var clipboardCapturePaused: Bool {
        didSet {
            UserDefaults.standard.set(
                clipboardCapturePaused,
                forKey: CovePreferences.clipboardCapturePausedKey
            )
            updateClipboardCaptureState()
        }
    }
    @Published var clipboardClearOnQuit: Bool {
        didSet {
            UserDefaults.standard.set(
                clipboardClearOnQuit,
                forKey: CovePreferences.clipboardClearOnQuitKey
            )
        }
    }
    @Published var clipboardPersistenceEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                clipboardPersistenceEnabled,
                forKey: CovePreferences.clipboardPersistenceEnabledKey
            )
            persistClipboardHistory()
        }
    }
    @Published var clipboardHistoryLimit: Int {
        didSet {
            let clamped = min(
                max(clipboardHistoryLimit, ClipboardHistory.minimumItemCount),
                ClipboardHistory.maximumItemCount
            )
            if clamped != clipboardHistoryLimit {
                clipboardHistoryLimit = clamped
                return
            }
            UserDefaults.standard.set(
                clipboardHistoryLimit,
                forKey: CovePreferences.clipboardHistoryLimitKey
            )
            clipboardItems = ClipboardHistory.trimming(
                clipboardItems,
                limit: clipboardHistoryLimit
            )
            persistClipboardHistory()
        }
    }
    @Published var excludeCommonSensitiveApps: Bool {
        didSet {
            UserDefaults.standard.set(
                excludeCommonSensitiveApps,
                forKey: CovePreferences.excludeCommonSensitiveAppsKey
            )
        }
    }
    @Published var excludedClipboardBundleIdentifiersText: String {
        didSet {
            UserDefaults.standard.set(
                excludedClipboardBundleIdentifiersText,
                forKey: CovePreferences.excludedClipboardBundleIdentifiersKey
            )
        }
    }
    @Published var quickPasteShortcutsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                quickPasteShortcutsEnabled,
                forKey: CovePreferences.quickPasteShortcutsEnabledKey
            )
        }
    }
    @Published var automaticUpdateChecksEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                automaticUpdateChecksEnabled,
                forKey: CovePreferences.automaticUpdateChecksEnabledKey
            )
        }
    }
    @Published var enhancedGlassContrast: Bool {
        didSet {
            UserDefaults.standard.set(
                enhancedGlassContrast,
                forKey: CovePreferences.enhancedGlassContrastKey
            )
        }
    }
    @Published var clipboardCollections: [String] {
        didSet {
            let normalized = Self.normalizedCollectionNames(clipboardCollections)
            if normalized != clipboardCollections {
                clipboardCollections = normalized
                return
            }
            UserDefaults.standard.set(
                clipboardCollections,
                forKey: CovePreferences.clipboardCollectionsKey
            )
        }
    }
    @Published var perAppProfilesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                perAppProfilesEnabled,
                forKey: CovePreferences.perAppProfilesEnabledKey
            )
            applyProfileForFrontmostApplication()
        }
    }
    @Published var updateChannel: CoveUpdateChannel {
        didSet {
            UserDefaults.standard.set(updateChannel.rawValue, forKey: CovePreferences.updateChannelKey)
            UserDefaults.standard.removeObject(forKey: CovePreferences.lastAutomaticUpdateCheckKey)
        }
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
    private let clipboardPasteService = ClipboardPasteService()
    private let clipboardPersistenceService = ClipboardPersistenceService()
    private let clipboardIntelligenceService = ClipboardIntelligenceService()
    private let clipboardOCRService = ClipboardOCRService()
    private let shelfProfileService = ShelfProfileService()
    private var refreshTimer: Timer?
    private var permissionTimer: Timer?
    private var nativeSnapshotTimer: Timer?
    private var nowPlayingTimer: Timer?
    private var expirationTimer: Timer?
    private var nativeSnapshotTask: Task<Void, Never>?
    private var nowPlayingRequestInFlight = false
    private var externalMenuMonitorTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var previewMode = false
    private var draggedMenuItemID: String?
    private var lastMenuItemDropTargetID: String?
    private var clipboardUndoBuffer = ClipboardUndoBuffer()
    private var isApplyingShelfProfile = false

    static let defaultClipboardCollections = ["Prompts", "Links", "Work", "Personal"]

    private init() {
        keepOpen = UserDefaults.standard.bool(forKey: Self.keepOpenKey)
        showsNowPlaying = UserDefaults.standard.object(forKey: Self.showsNowPlayingKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.showsNowPlayingKey)
        showsVisualClipboard = UserDefaults.standard.object(forKey: Self.showsVisualClipboardKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.showsVisualClipboardKey)
        clipboardCapturePaused = UserDefaults.standard.bool(
            forKey: CovePreferences.clipboardCapturePausedKey
        )
        clipboardClearOnQuit = CovePreferences.bool(
            forKey: CovePreferences.clipboardClearOnQuitKey,
            default: true
        )
        clipboardPersistenceEnabled = CovePreferences.bool(
            forKey: CovePreferences.clipboardPersistenceEnabledKey,
            default: false
        )
        let storedHistoryLimit = UserDefaults.standard.integer(
            forKey: CovePreferences.clipboardHistoryLimitKey
        )
        clipboardHistoryLimit = storedHistoryLimit == 0
            ? ClipboardHistory.defaultItemCount
            : min(
                max(storedHistoryLimit, ClipboardHistory.minimumItemCount),
                ClipboardHistory.maximumItemCount
            )
        excludeCommonSensitiveApps = CovePreferences.bool(
            forKey: CovePreferences.excludeCommonSensitiveAppsKey,
            default: true
        )
        excludedClipboardBundleIdentifiersText = UserDefaults.standard.string(
            forKey: CovePreferences.excludedClipboardBundleIdentifiersKey
        ) ?? ""
        quickPasteShortcutsEnabled = CovePreferences.bool(
            forKey: CovePreferences.quickPasteShortcutsEnabledKey,
            default: true
        )
        automaticUpdateChecksEnabled = CovePreferences.bool(
            forKey: CovePreferences.automaticUpdateChecksEnabledKey,
            default: true
        )
        enhancedGlassContrast = CovePreferences.bool(
            forKey: CovePreferences.enhancedGlassContrastKey,
            default: false
        )
        clipboardCollections = Self.normalizedCollectionNames(
            UserDefaults.standard.stringArray(forKey: CovePreferences.clipboardCollectionsKey)
                ?? Self.defaultClipboardCollections
        )
        perAppProfilesEnabled = CovePreferences.bool(
            forKey: CovePreferences.perAppProfilesEnabledKey,
            default: false
        )
        updateChannel = CoveUpdateChannel(
            rawValue: UserDefaults.standard.string(forKey: CovePreferences.updateChannelKey) ?? ""
        ) ?? .stable
        clipboardCollectionFilter = nil
        selectedMenuItemIDs = MenuBarSelection.normalizedIDs(
            UserDefaults.standard.stringArray(forKey: Self.selectedMenuItemIDsKey) ?? []
        )
        selectedMenuItemNames = UserDefaults.standard.dictionary(
            forKey: CovePreferences.selectedMenuItemNamesKey
        ) as? [String: String] ?? [:]
        shelfProfiles = shelfProfileService.load()
        configureClipboardCapture()
        clipboardService.onItemCaptured = { [weak self] item in
            self?.insertClipboardItem(item)
        }
        if let loadedItems = try? clipboardPersistenceService.load() {
            clipboardItems = ClipboardHistory.trimming(
                ClipboardHistory.itemsToPersist(
                    from: loadedItems,
                    includesRecentHistory: clipboardPersistenceEnabled
                ),
                limit: clipboardHistoryLimit
            )
        }
    }

    var selectedMenuItems: [MenuBarItemModel] {
        let itemsByID = Dictionary(
            menuItems.map { ($0.selectionID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return selectedMenuItemIDs.compactMap { itemsByID[$0] }
    }

    var unavailableSelectedMenuItems: [UnavailableMenuBarItem] {
        let availableIDs = Set(menuItems.map(\.selectionID))
        return selectedMenuItemIDs
            .filter { !availableIDs.contains($0) }
            .map {
                UnavailableMenuBarItem(
                    id: $0,
                    name: selectedMenuItemNames[$0] ?? "Unavailable item"
                )
            }
    }

    var filteredClipboardItems: [ClipboardItem] {
        clipboardItems.filter { item in
            guard !item.isExpired, item.matchesSearch(clipboardSearchQuery) else { return false }
            if clipboardCollectionFilter == Self.savedCollectionFilter {
                return item.isPinned
            }
            guard let clipboardCollectionFilter else { return true }
            return item.collectionName == clipboardCollectionFilter
        }
    }

    static let savedCollectionFilter = "__saved__"

    var selectedClipboardItem: ClipboardItem? {
        guard let selectedClipboardItemID else { return filteredClipboardItems.first }
        return filteredClipboardItems.first { $0.id == selectedClipboardItemID }
            ?? filteredClipboardItems.first
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
            clipboardWidth = ClipboardShelfLayout.width(
                itemCount: isClipboardSearchPresented
                    ? clipboardItems.count
                    : filteredClipboardItems.count,
                isSearchPresented: isClipboardSearchPresented
            )
        } else {
            clipboardWidth = 0
        }
        let itemsWidth = selectedMenuItems.reduce(CGFloat.zero) { partial, item in
            partial + min(max(item.nativeDisplayWidth + 12, 32), 104)
        } + CGFloat(unavailableSelectedMenuItems.count) * 40
        let contentWidth: CGFloat
        if !accessibilityGranted || menuItems.isEmpty {
            contentWidth = 190
        } else if selectedMenuItems.isEmpty && unavailableSelectedMenuItems.isEmpty {
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
        updateClipboardCaptureState()
        for item in clipboardItems where item.image != nil && item.ocrText == nil {
            indexOCRIfNeeded(forFingerprint: item.fingerprint)
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
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.purgeExpiredClipboardItems() }
        }
        updateActiveApplication(NSWorkspace.shared.frontmostApplication)
    }

    func stop() {
        refreshTimer?.invalidate()
        permissionTimer?.invalidate()
        nativeSnapshotTimer?.invalidate()
        nowPlayingTimer?.invalidate()
        expirationTimer?.invalidate()
        clipboardService.stop()
        if clipboardClearOnQuit {
            clipboardItems = clipboardItems.filter(\.isPinned)
        }
        persistClipboardHistory()
        nativeSnapshotTask?.cancel()
        externalMenuMonitorTask?.cancel()
        refreshTimer = nil
        permissionTimer = nil
        nativeSnapshotTimer = nil
        nowPlayingTimer = nil
        expirationTimer = nil
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
        for item in scanResult.items where selectedMenuItemIDs.contains(item.selectionID) {
            selectedMenuItemNames[item.selectionID] = item.name
        }
        persistSelectedMenuItemNames()
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
        selectedMenuItemNames[item.selectionID] = item.name
        let updatedIDs = MenuBarSelection.toggled(item.selectionID, in: selectedMenuItemIDs)
        persistSelectedMenuItemIDs(updatedIDs)
        reveal()
    }

    func beginMenuItemReordering(_ id: String) {
        draggedMenuItemID = id
        lastMenuItemDropTargetID = nil
    }

    func reorderDraggedMenuItem(over targetID: String) {
        guard let draggedMenuItemID,
              draggedMenuItemID != targetID,
              lastMenuItemDropTargetID != targetID else {
            return
        }
        lastMenuItemDropTargetID = targetID
        let reorderedIDs = MenuBarSelection.moving(
            draggedMenuItemID,
            over: targetID,
            in: selectedMenuItemIDs
        )
        guard reorderedIDs != selectedMenuItemIDs else { return }
        selectedMenuItemIDs = reorderedIDs
    }

    func finishMenuItemReordering() {
        guard draggedMenuItemID != nil else { return }
        draggedMenuItemID = nil
        lastMenuItemDropTargetID = nil
        saveSelectedMenuItemIDs()
    }

    func repairMenuItem(_ item: UnavailableMenuBarItem) {
        if let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: item.ownerBundleIdentifier
        ) {
            NSWorkspace.shared.open(applicationURL)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refresh()
        }
    }

    func removeUnavailableMenuItem(_ item: UnavailableMenuBarItem) {
        persistSelectedMenuItemIDs(selectedMenuItemIDs.filter { $0 != item.id })
    }

    func toggleNowPlayingVisibility() {
        showsNowPlaying.toggle()
        if showsNowPlaying {
            reveal()
        }
    }

    func toggleVisualClipboardVisibility() {
        showsVisualClipboard.toggle()
        if showsVisualClipboard {
            reveal()
        }
    }

    func toggleClipboardCapturePaused() {
        clipboardCapturePaused.toggle()
    }

    func copyClipboardItem(_ item: ClipboardItem) {
        clipboardService.copy(item)
        insertClipboardItem(item)
        reveal()
    }

    @discardableResult
    func pasteClipboardItem(_ item: ClipboardItem) -> Bool {
        let pasted = clipboardPasteService.paste(item, using: clipboardService)
        if pasted {
            if item.removesAfterPaste {
                clipboardItems.removeAll { $0.id == item.id || $0.fingerprint == item.fingerprint }
                persistClipboardHistory()
            } else {
                insertClipboardItem(item)
            }
            dismissManualReveal()
        }
        return pasted
    }

    func toggleClipboardItemPinned(_ item: ClipboardItem) {
        if item.isPinned {
            clipboardItems = clipboardItems.map { candidate in
                candidate.id == item.id
                    ? candidate.withPinned(false).withCollection(nil)
                    : candidate
            }
            clipboardItems = ClipboardHistory.trimming(
                clipboardItems,
                limit: clipboardHistoryLimit
            )
        } else {
            clipboardItems = ClipboardHistory.pinning(
                item,
                isPinned: true,
                in: clipboardItems,
                limit: clipboardHistoryLimit
            )
        }
        persistClipboardHistory()
    }

    func smartActions(for item: ClipboardItem) -> [ClipboardSmartAction] {
        clipboardIntelligenceService.actions(for: item)
    }

    func performSmartAction(_ action: ClipboardSmartAction, for item: ClipboardItem) {
        switch action.operation {
        case .open(let url):
            NSWorkspace.shared.open(url)
        case .copy(let text):
            copyClipboardItem(ClipboardItem(content: .text(text)))
        case .paste(let text):
            _ = pasteClipboardItem(ClipboardItem(content: .text(text)))
        }
    }

    func assignClipboardItem(_ item: ClipboardItem, toCollection name: String?) {
        clipboardItems = clipboardItems.map { candidate in
            candidate.id == item.id ? candidate.withCollection(name) : candidate
        }
        persistClipboardHistory()
    }

    func setClipboardItemExpiration(
        _ item: ClipboardItem,
        expiresAt: Date?,
        removesAfterPaste: Bool = false
    ) {
        clipboardItems = clipboardItems.map { candidate in
            candidate.id == item.id
                ? candidate.withExpiration(
                    expiresAt: expiresAt,
                    removesAfterPaste: removesAfterPaste
                )
                : candidate
        }
        persistClipboardHistory()
    }

    func setClipboardShortcutHUDPresented(_ presented: Bool) {
        guard quickPasteShortcutsEnabled else {
            isClipboardShortcutHUDPresented = false
            return
        }
        isClipboardShortcutHUDPresented = presented
        if presented, showsVisualClipboard {
            reveal(for: 1.2)
        }
    }

    func selectClipboardItem(_ item: ClipboardItem) {
        selectedClipboardItemID = item.id
    }

    func selectClipboardItem(at index: Int) {
        guard filteredClipboardItems.indices.contains(index) else { return }
        selectedClipboardItemID = filteredClipboardItems[index].id
        reveal()
    }

    func moveClipboardSelection(by offset: Int) {
        let items = filteredClipboardItems
        guard !items.isEmpty else { return }
        let currentIndex = selectedClipboardItem
            .flatMap { selected in items.firstIndex { $0.id == selected.id } }
            ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), items.count - 1)
        selectedClipboardItemID = items[nextIndex].id
        reveal()
    }

    @discardableResult
    func pasteSelectedClipboardItem() -> Bool {
        guard let selectedClipboardItem else { return false }
        return pasteClipboardItem(selectedClipboardItem)
    }

    func removeClipboardItem(_ item: ClipboardItem) {
        captureClipboardUndoSnapshot()
        clipboardItems.removeAll { $0.id == item.id }
        if selectedClipboardItemID == item.id {
            selectedClipboardItemID = filteredClipboardItems.first?.id
        }
        persistClipboardHistory()
    }

    func clearClipboardHistory() {
        captureClipboardUndoSnapshot()
        clipboardItems = []
        selectedClipboardItemID = nil
        try? clipboardPersistenceService.clear()
    }

    func undoClipboardChange() {
        guard let snapshot = clipboardUndoBuffer.restore() else { return }
        clipboardItems = snapshot
        canUndoClipboardChange = false
        selectedClipboardItemID = clipboardItems.first?.id
        persistClipboardHistory()
        reveal()
    }

    func moveMenuItem(_ id: String, by offset: Int) {
        let updated = MenuBarSelection.moving(id, by: offset, in: selectedMenuItemIDs)
        guard updated != selectedMenuItemIDs else { return }
        selectedMenuItemIDs = updated
        keyboardReorderItemID = id
        saveSelectedMenuItemIDs()
    }

    func selectKeyboardReorderItem(by offset: Int) {
        guard !selectedMenuItemIDs.isEmpty else { return }
        let currentIndex = keyboardReorderItemID
            .flatMap { selectedMenuItemIDs.firstIndex(of: $0) } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), selectedMenuItemIDs.count - 1)
        keyboardReorderItemID = selectedMenuItemIDs[nextIndex]
        reveal(for: 1.2)
    }

    func moveKeyboardReorderItem(by offset: Int) {
        if keyboardReorderItemID == nil {
            keyboardReorderItemID = selectedMenuItemIDs.first
        }
        guard let keyboardReorderItemID else { return }
        moveMenuItem(keyboardReorderItemID, by: offset)
        reveal(for: 1.2)
    }

    func saveCurrentShelfProfile() {
        guard let bundleIdentifier = activeApplicationBundleIdentifier else { return }
        let profile = ShelfProfile(
            bundleIdentifier: bundleIdentifier,
            applicationName: activeApplicationName ?? bundleIdentifier,
            selectedMenuItemIDs: selectedMenuItemIDs,
            selectedMenuItemNames: selectedMenuItemNames,
            showsNowPlaying: showsNowPlaying,
            showsVisualClipboard: showsVisualClipboard,
            clipboardCollectionName: clipboardCollectionFilter
        )
        shelfProfiles.removeAll { $0.id == profile.id }
        shelfProfiles.append(profile)
        shelfProfiles.sort { $0.applicationName.localizedCaseInsensitiveCompare($1.applicationName) == .orderedAscending }
        shelfProfileService.save(shelfProfiles)
        activeApplicationName = profile.applicationName
    }

    func removeShelfProfile(_ profile: ShelfProfile) {
        shelfProfiles.removeAll { $0.id == profile.id }
        shelfProfileService.save(shelfProfiles)
        applyProfileForFrontmostApplication()
    }

    func importClipboardProviders(_ providers: [NSItemProvider]) -> Bool {
        guard showsVisualClipboard, !providers.isEmpty else { return false }
        var accepted = false
        for provider in providers.prefix(clipboardHistoryLimit) {
            if provider.registeredTypeIdentifiers.contains(ClipboardItem.multipleFileDragType) {
                accepted = true
                provider.loadDataRepresentation(
                    forTypeIdentifier: ClipboardItem.multipleFileDragType
                ) { [weak self] data, _ in
                    guard let data,
                          let values = try? JSONDecoder().decode([String].self, from: data) else {
                        return
                    }
                    let urls = values.compactMap(URL.init(string:))
                    guard !urls.isEmpty else { return }
                    Task { @MainActor in
                        self?.insertClipboardItem(ClipboardItem(content: .files(urls)))
                    }
                }
            } else if provider.canLoadObject(ofClass: NSURL.self) {
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
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
                Task { @MainActor in self?.updateActiveApplication(application) }
            }
        )
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
        saveSelectedMenuItemIDs()
    }

    private func saveSelectedMenuItemIDs() {
        selectedMenuItemNames = selectedMenuItemNames.filter {
            selectedMenuItemIDs.contains($0.key)
        }
        UserDefaults.standard.set(selectedMenuItemIDs, forKey: Self.selectedMenuItemIDsKey)
        persistSelectedMenuItemNames()
    }

    private func insertClipboardItem(_ item: ClipboardItem) {
        clipboardItems = ClipboardHistory.inserting(
            item,
            into: clipboardItems,
            limit: clipboardHistoryLimit
        )
        selectedClipboardItemID = clipboardItems.first?.id
        persistClipboardHistory()
        reveal()
        indexOCRIfNeeded(forFingerprint: item.fingerprint)
    }

    private func indexOCRIfNeeded(forFingerprint fingerprint: String) {
        guard let item = clipboardItems.first(where: { $0.fingerprint == fingerprint }),
              item.ocrText == nil,
              let image = item.image else { return }
        Task { [weak self] in
            guard let self, let text = await self.clipboardOCRService.recognizeText(in: image) else {
                return
            }
            guard let index = self.clipboardItems.firstIndex(where: { $0.fingerprint == fingerprint }) else {
                return
            }
            self.clipboardItems[index] = self.clipboardItems[index].withOCRText(text)
            self.persistClipboardHistory()
        }
    }

    private func purgeExpiredClipboardItems() {
        let active = clipboardItems.filter { !$0.isExpired }
        guard active.count != clipboardItems.count else { return }
        clipboardItems = active
        if !clipboardItems.contains(where: { $0.id == selectedClipboardItemID }) {
            selectedClipboardItemID = filteredClipboardItems.first?.id
        }
        persistClipboardHistory()
    }

    private func captureClipboardUndoSnapshot() {
        clipboardUndoBuffer.capture(clipboardItems)
        canUndoClipboardChange = clipboardUndoBuffer.canUndo
    }

    private func updateActiveApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        activeApplicationName = application.localizedName
        activeApplicationBundleIdentifier = application.bundleIdentifier
        applyProfile(for: application.bundleIdentifier)
    }

    private func applyProfileForFrontmostApplication() {
        let application = frontmostExternalApplication()
        if let application {
            activeApplicationName = application.localizedName
            activeApplicationBundleIdentifier = application.bundleIdentifier
        }
        applyProfile(for: application?.bundleIdentifier ?? activeApplicationBundleIdentifier)
    }

    private func applyProfile(for bundleIdentifier: String?) {
        guard perAppProfilesEnabled else { return }
        guard let bundleIdentifier,
              let profile = shelfProfiles.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            restoreDefaultShelfConfiguration()
            return
        }
        isApplyingShelfProfile = true
        selectedMenuItemIDs = MenuBarSelection.normalizedIDs(profile.selectedMenuItemIDs)
        selectedMenuItemNames.merge(profile.selectedMenuItemNames) { _, profileValue in profileValue }
        showsNowPlaying = profile.showsNowPlaying
        showsVisualClipboard = profile.showsVisualClipboard
        clipboardCollectionFilter = profile.clipboardCollectionName
        isApplyingShelfProfile = false
        reveal(for: 1.2)
    }

    private func restoreDefaultShelfConfiguration() {
        isApplyingShelfProfile = true
        selectedMenuItemIDs = MenuBarSelection.normalizedIDs(
            UserDefaults.standard.stringArray(forKey: Self.selectedMenuItemIDsKey) ?? []
        )
        selectedMenuItemNames = UserDefaults.standard.dictionary(
            forKey: CovePreferences.selectedMenuItemNamesKey
        ) as? [String: String] ?? [:]
        showsNowPlaying = UserDefaults.standard.object(forKey: Self.showsNowPlayingKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.showsNowPlayingKey)
        showsVisualClipboard = UserDefaults.standard.object(forKey: Self.showsVisualClipboardKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.showsVisualClipboardKey)
        clipboardCollectionFilter = nil
        isApplyingShelfProfile = false
    }

    private func frontmostExternalApplication() -> NSRunningApplication? {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != ownBundleIdentifier {
            return frontmost
        }
        return NSWorkspace.shared.runningApplications.first {
            $0.isActive && $0.bundleIdentifier != ownBundleIdentifier
        }
    }

    nonisolated static func normalizedCollectionNames(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let key = name.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return name
        }
    }

    private func persistSelectedMenuItemNames() {
        UserDefaults.standard.set(
            selectedMenuItemNames,
            forKey: CovePreferences.selectedMenuItemNamesKey
        )
    }

    private func configureClipboardCapture() {
        clipboardService.shouldCapture = { [weak self] sourceBundleIdentifier, types in
            guard let self else { return false }
            return ClipboardPrivacyPolicy.shouldCapture(
                sourceBundleIdentifier: sourceBundleIdentifier,
                pasteboardTypes: types,
                isPaused: self.clipboardCapturePaused,
                excludesCommonSensitiveApps: self.excludeCommonSensitiveApps,
                customExcludedBundleIdentifiers: ClipboardPrivacyPolicy.bundleIdentifiers(
                    from: self.excludedClipboardBundleIdentifiersText
                )
            )
        }
    }

    private func updateClipboardCaptureState() {
        guard !previewMode else { return }
        if showsVisualClipboard && !clipboardCapturePaused {
            clipboardService.start()
        } else {
            clipboardService.stop()
        }
    }

    private func persistClipboardHistory() {
        let itemsToPersist = ClipboardHistory.itemsToPersist(
            from: clipboardItems,
            includesRecentHistory: clipboardPersistenceEnabled
        )
        do {
            if itemsToPersist.isEmpty {
                try clipboardPersistenceService.clear()
            } else {
                try clipboardPersistenceService.save(itemsToPersist)
            }
        } catch {
            logger.error(
                "Could not persist clipboard history: \(error.localizedDescription, privacy: .public)"
            )
        }
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
