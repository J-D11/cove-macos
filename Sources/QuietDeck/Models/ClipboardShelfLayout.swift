import Foundation

enum ClipboardShelfLayout {
    static let compactMinimumWidth: CGFloat = 232
    static let searchMinimumWidth: CGFloat = 232
    private static let cardWidth: CGFloat = 116
    private static let maximumVisibleCardCount: CGFloat = 3

    static func width(itemCount: Int, isSearchPresented: Bool) -> CGFloat {
        let visibleCount = min(CGFloat(max(itemCount, 0)), maximumVisibleCardCount)
        let cardsWidth = visibleCount > 0
            ? visibleCount * cardWidth + 8
            : compactMinimumWidth
        let minimumWidth = isSearchPresented
            ? searchMinimumWidth
            : compactMinimumWidth
        return max(cardsWidth, minimumWidth)
    }
}
