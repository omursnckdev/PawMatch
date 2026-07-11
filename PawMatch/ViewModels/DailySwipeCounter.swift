import Foundation

/// Pure, dependency-free value type holding the daily swipe/superlike limit
/// logic (§3, §12 M3). Kept separate from `SwipeDeckViewModel` so the limit +
/// midnight-reset rules can be unit tested without Firebase or a live clock.
struct DailySwipeCounter: Equatable {
    static let freeDailyLimit = 15
    static let freeDailySuperlikeLimit = 1

    var swipeCount: Int
    var superlikeCount: Int
    var lastResetDate: Date

    /// Returns a counter reset to zero if `now` falls on a different calendar day
    /// than the last reset — this is the "resets at local midnight" behavior.
    func resetIfNeeded(now: Date, calendar: Calendar = .current) -> DailySwipeCounter {
        guard !calendar.isDate(lastResetDate, inSameDayAs: now) else { return self }
        return DailySwipeCounter(swipeCount: 0, superlikeCount: 0, lastResetDate: now)
    }

    /// Remaining swipes for the day, or `nil` for premium users (unlimited).
    func remainingSwipes(isPremium: Bool) -> Int? {
        isPremium ? nil : max(0, Self.freeDailyLimit - swipeCount)
    }

    func canSwipe(isPremium: Bool) -> Bool {
        isPremium || swipeCount < Self.freeDailyLimit
    }

    func canSuperlike(isPremium: Bool) -> Bool {
        isPremium || superlikeCount < Self.freeDailySuperlikeLimit
    }

    /// A superlike also consumes a regular swipe from the daily allowance.
    func recordingSwipe(direction: Swipe.Direction) -> DailySwipeCounter {
        var copy = self
        copy.swipeCount += 1
        if direction == .superlike {
            copy.superlikeCount += 1
        }
        return copy
    }
}
