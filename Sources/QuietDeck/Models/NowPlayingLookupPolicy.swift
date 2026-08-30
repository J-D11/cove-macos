import Foundation

enum NowPlayingLookupPolicy {
    static let unavailableRetryInterval: TimeInterval = 60

    static func canAttemptLookup(at date: Date, nextEligibleDate: Date) -> Bool {
        date >= nextEligibleDate
    }

    static func nextEligibleDate(after date: Date, foundItem: Bool) -> Date {
        foundItem ? .distantPast : date.addingTimeInterval(unavailableRetryInterval)
    }
}
