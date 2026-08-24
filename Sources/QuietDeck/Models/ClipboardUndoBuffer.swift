import Foundation

struct ClipboardUndoBuffer {
    private(set) var snapshot: [ClipboardItem]?

    var canUndo: Bool { snapshot?.isEmpty == false }

    mutating func capture(_ items: [ClipboardItem]) {
        snapshot = items.isEmpty ? nil : items
    }

    mutating func restore() -> [ClipboardItem]? {
        defer { snapshot = nil }
        return snapshot
    }
}
