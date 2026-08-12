import Foundation

struct MenuBarDeduplicationResult {
    let items: [MenuBarItemModel]
    let duplicateCount: Int
    let placeholderCount: Int
}

enum MenuBarItemDeduplicator {
    static func deduplicate(_ items: [MenuBarItemModel]) -> MenuBarDeduplicationResult {
        var seenKeys = Set<String>()
        var uniqueItems: [MenuBarItemModel] = []
        var duplicateCount = 0
        var placeholderCount = 0

        for item in items {
            if isUnusableSystemPlaceholder(item) {
                placeholderCount += 1
                continue
            }

            let key = identityKey(for: item)
            guard seenKeys.insert(key).inserted else {
                duplicateCount += 1
                continue
            }
            uniqueItems.append(item)
        }

        return MenuBarDeduplicationResult(
            items: uniqueItems,
            duplicateCount: duplicateCount,
            placeholderCount: placeholderCount
        )
    }

    static func identityKey(for item: MenuBarItemModel) -> String {
        if let identifier = normalized(item.itemIdentifier), !identifier.isEmpty {
            return "identifier|\(item.ownerBundleIdentifier.lowercased())|\(identifier)"
        }

        let position: String
        if item.xPosition.isFinite, abs(item.xPosition) < 100_000 {
            position = String(Int(item.xPosition.rounded()))
        } else {
            position = "unknown"
        }

        return [
            "position",
            item.ownerBundleIdentifier.lowercased(),
            normalized(item.name) ?? "menu-item",
            position
        ].joined(separator: "|")
    }

    private static func isUnusableSystemPlaceholder(_ item: MenuBarItemModel) -> Bool {
        guard item.itemIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
              item.ownerBundleIdentifier == "com.apple.controlcenter"
                || item.ownerBundleIdentifier == "com.apple.systemuiserver" else {
            return false
        }

        let genericNames: Set<String> = ["control center", "systemuiserver", "menu item"]
        guard genericNames.contains(normalized(item.name) ?? "") else { return false }

        guard let frame = item.accessibilityFrame else { return true }
        return frame.width <= 1 || frame.minX <= 0
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? nil : normalized
    }
}
