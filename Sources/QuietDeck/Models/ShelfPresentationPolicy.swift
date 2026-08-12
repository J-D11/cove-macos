import Foundation

enum ShelfPresentationPolicy {
    static let hoverExitGraceInterval: TimeInterval = 0.22
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
