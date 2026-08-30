import Foundation

enum ShelfPresentationPolicy {
    // Keep a short buffer so crossing the notch edge does not flicker, while
    // keeping dismissal responsive once the pointer has clearly left the shelf.
    static let hoverExitGraceInterval: TimeInterval = 0.10
    static let appearanceAnimationDuration: TimeInterval = 0.26
    static let disappearanceAnimationDuration: TimeInterval = 0.20
    static let menuProxyActivationDelayNanoseconds: UInt64 = 80_000_000
    static let externalMenuHoldDuration: TimeInterval = 2.5

    static func shouldPresent(
        keepOpen: Bool,
        externalMenuInteractionActive: Bool = false,
        cursorInside: Bool,
        lastInsideDate: Date,
        manualRevealDeadline: Date,
        now: Date
    ) -> Bool {
        keepOpen ||
            externalMenuInteractionActive ||
            cursorInside ||
            now.timeIntervalSince(lastInsideDate) < hoverExitGraceInterval ||
            now < manualRevealDeadline
    }
}
