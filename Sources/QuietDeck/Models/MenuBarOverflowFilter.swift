import Foundation

enum MenuBarOverflowFilter {
    static func overflowItems(
        from items: [MenuBarItemModel],
        visibleItemIDs: Set<String>
    ) -> [MenuBarItemModel] {
        items.filter { !visibleItemIDs.contains($0.id) }
    }
}
