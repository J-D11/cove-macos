import XCTest
@testable import QuietDeck

final class ShelfPresentationPolicyTests: XCTestCase {
    func testPinnedShelfAlwaysStaysPresented() {
        let now = Date()

        XCTAssertTrue(
            ShelfPresentationPolicy.shouldPresent(
                keepOpen: true,
                cursorInside: false,
                lastInsideDate: .distantPast,
                manualRevealDeadline: .distantPast,
                now: now
            )
        )
    }

    func testHoverExitClosesAfterGraceInterval() {
        let now = Date()

        XCTAssertFalse(
            ShelfPresentationPolicy.shouldPresent(
                keepOpen: false,
                cursorInside: false,
                lastInsideDate: now.addingTimeInterval(-1),
                manualRevealDeadline: .distantPast,
                now: now
            )
        )
    }

    func testHoverExitUsesResponsiveGraceInterval() {
        let now = Date()

        XCTAssertTrue(
            ShelfPresentationPolicy.shouldPresent(
                keepOpen: false,
                cursorInside: false,
                lastInsideDate: now.addingTimeInterval(-0.07),
                manualRevealDeadline: .distantPast,
                now: now
            )
        )
        XCTAssertFalse(
            ShelfPresentationPolicy.shouldPresent(
                keepOpen: false,
                cursorInside: false,
                lastInsideDate: now.addingTimeInterval(-0.14),
                manualRevealDeadline: .distantPast,
                now: now
            )
        )
    }

    func testManualRevealExpiresWithoutPinningShelf() {
        let now = Date()
        let deadline = now.addingTimeInterval(2.5)

        XCTAssertTrue(
            ShelfPresentationPolicy.shouldPresent(
                keepOpen: false,
                cursorInside: false,
                lastInsideDate: .distantPast,
                manualRevealDeadline: deadline,
                now: now
            )
        )
        XCTAssertFalse(
            ShelfPresentationPolicy.shouldPresent(
                keepOpen: false,
                cursorInside: false,
                lastInsideDate: .distantPast,
                manualRevealDeadline: deadline,
                now: deadline.addingTimeInterval(0.1)
            )
        )
    }

    func testExternalMenuHoldOutlastsHoverExitGrace() {
        XCTAssertGreaterThan(
            ShelfPresentationPolicy.externalMenuHoldDuration,
            ShelfPresentationPolicy.hoverExitGraceInterval
        )
        XCTAssertGreaterThan(
            ShelfPresentationPolicy.menuProxyActivationDelayNanoseconds,
            0
        )
    }

    func testOpenExternalMenuKeepsShelfPresented() {
        XCTAssertTrue(
            ShelfPresentationPolicy.shouldPresent(
                keepOpen: false,
                externalMenuInteractionActive: true,
                cursorInside: false,
                lastInsideDate: .distantPast,
                manualRevealDeadline: .distantPast,
                now: Date()
            )
        )
    }
}
