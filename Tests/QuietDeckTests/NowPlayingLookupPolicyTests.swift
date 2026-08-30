import XCTest
@testable import QuietDeck

final class NowPlayingLookupPolicyTests: XCTestCase {
    func testUnavailableSystemLookupUsesBackoff() {
        let now = Date(timeIntervalSince1970: 1_000)
        let nextDate = NowPlayingLookupPolicy.nextEligibleDate(
            after: now,
            foundItem: false
        )

        XCTAssertFalse(
            NowPlayingLookupPolicy.canAttemptLookup(
                at: now.addingTimeInterval(10),
                nextEligibleDate: nextDate
            )
        )
        XCTAssertTrue(
            NowPlayingLookupPolicy.canAttemptLookup(
                at: now.addingTimeInterval(
                    NowPlayingLookupPolicy.unavailableRetryInterval
                ),
                nextEligibleDate: nextDate
            )
        )
    }

    func testSuccessfulSystemLookupCanRefreshImmediately() {
        let now = Date(timeIntervalSince1970: 1_000)
        let nextDate = NowPlayingLookupPolicy.nextEligibleDate(
            after: now,
            foundItem: true
        )

        XCTAssertTrue(
            NowPlayingLookupPolicy.canAttemptLookup(at: now, nextEligibleDate: nextDate)
        )
    }
}
