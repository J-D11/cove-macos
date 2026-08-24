import Foundation

enum MenuBarSelection {
    static func normalizedIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func toggled(_ id: String, in ids: [String]) -> [String] {
        let normalized = normalizedIDs(ids)
        if normalized.contains(id) {
            return normalized.filter { $0 != id }
        }
        return normalized + [id]
    }

    static func moving(_ id: String, over targetID: String, in ids: [String]) -> [String] {
        guard id != targetID else { return normalizedIDs(ids) }
        var result = normalizedIDs(ids)
        guard let sourceIndex = result.firstIndex(of: id),
              let targetIndex = result.firstIndex(of: targetID) else { return result }
        result.remove(at: sourceIndex)
        result.insert(id, at: min(targetIndex, result.endIndex))
        return result
    }
}
