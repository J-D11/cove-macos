import Foundation

enum CovePreferences {
    static let clipboardCapturePausedKey = "Cove.clipboardCapturePaused"
    static let clipboardClearOnQuitKey = "Cove.clipboardClearOnQuit"
    static let clipboardPersistenceEnabledKey = "Cove.clipboardPersistenceEnabled"
    static let clipboardHistoryLimitKey = "Cove.clipboardHistoryLimit"
    static let excludeCommonSensitiveAppsKey = "Cove.excludeCommonSensitiveApps"
    static let excludedClipboardBundleIdentifiersKey = "Cove.excludedClipboardBundleIdentifiers"
    static let quickPasteShortcutsEnabledKey = "Cove.quickPasteShortcutsEnabled"
    static let automaticUpdateChecksEnabledKey = "Cove.automaticUpdateChecksEnabled"
    static let enhancedGlassContrastKey = "Cove.enhancedGlassContrast"
    static let clipboardCollectionsKey = "Cove.clipboardCollections"
    static let perAppProfilesEnabledKey = "Cove.perAppProfilesEnabled"
    static let shelfProfilesKey = "Cove.shelfProfiles"
    static let updateChannelKey = "Cove.updateChannel"
    static let selectedMenuItemNamesKey = "Cove.selectedMenuItemNames"
    static let lastAutomaticUpdateCheckKey = "Cove.lastAutomaticUpdateCheck"

    static func bool(
        forKey key: String,
        default defaultValue: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.object(forKey: key) == nil
            ? defaultValue
            : defaults.bool(forKey: key)
    }
}

enum CoveUpdateChannel: String, CaseIterable, Identifiable {
    case stable
    case beta

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stable: return "Stable"
        case .beta: return "Beta"
        }
    }

    var allowsPrereleases: Bool { self == .beta }
}
