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

    static func moving(_ id: String, before targetID: String, in ids: [String]) -> [String] {
        guard id != targetID else { return normalizedIDs(ids) }
        var result = normalizedIDs(ids)
        guard let sourceIndex = result.firstIndex(of: id),
              result.contains(targetID) else { return result }
        result.remove(at: sourceIndex)
        guard let targetIndex = result.firstIndex(of: targetID) else { return result }
        result.insert(id, at: targetIndex)
        return result
    }
}
