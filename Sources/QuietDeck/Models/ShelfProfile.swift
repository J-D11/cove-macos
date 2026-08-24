import Foundation

struct ShelfProfile: Codable, Identifiable, Equatable {
    let bundleIdentifier: String
    var applicationName: String
    var selectedMenuItemIDs: [String]
    var selectedMenuItemNames: [String: String]
    var showsNowPlaying: Bool
    var showsVisualClipboard: Bool
    var clipboardCollectionName: String?

    var id: String { bundleIdentifier }
}

final class ShelfProfileService {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [ShelfProfile] {
        guard let data = defaults.data(forKey: CovePreferences.shelfProfilesKey) else {
            return []
        }
        return (try? JSONDecoder().decode([ShelfProfile].self, from: data)) ?? []
    }

    func save(_ profiles: [ShelfProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: CovePreferences.shelfProfilesKey)
    }
}
