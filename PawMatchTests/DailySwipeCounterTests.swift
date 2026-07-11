import XCTest
@testable import PawMatch

final class DailySwipeCounterTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: iso)!
    }

    func testResetIfNeededZeroesCountsOnNewDay() {
        let counter = DailySwipeCounter(
            swipeCount: 15,
            superlikeCount: 1,
            lastResetDate: date("2026-07-10T23:00:00Z")
        )
        let reset = counter.resetIfNeeded(now: date("2026-07-11T08:00:00Z"), calendar: calendar)

        XCTAssertEqual(reset.swipeCount, 0)
        XCTAssertEqual(reset.superlikeCount, 0)
    }

    func testResetIfNeededKeepsCountsSameDay() {
        let counter = DailySwipeCounter(
            swipeCount: 5,
            superlikeCount: 0,
            lastResetDate: date("2026-07-11T08:00:00Z")
        )
        let same = counter.resetIfNeeded(now: date("2026-07-11T20:00:00Z"), calendar: calendar)

        XCTAssertEqual(same, counter)
    }

    func testFreeUserBlockedAtLimit() {
        let atLimit = DailySwipeCounter(swipeCount: 15, superlikeCount: 0, lastResetDate: Date())
        XCTAssertFalse(atLimit.canSwipe(isPremium: false))
        XCTAssertEqual(atLimit.remainingSwipes(isPremium: false), 0)

        let underLimit = DailySwipeCounter(swipeCount: 14, superlikeCount: 0, lastResetDate: Date())
        XCTAssertTrue(underLimit.canSwipe(isPremium: false))
        XCTAssertEqual(underLimit.remainingSwipes(isPremium: false), 1)
    }

    func testPremiumUserNeverBlockedAndUnlimited() {
        let counter = DailySwipeCounter(swipeCount: 999, superlikeCount: 999, lastResetDate: Date())
        XCTAssertTrue(counter.canSwipe(isPremium: true))
        XCTAssertTrue(counter.canSuperlike(isPremium: true))
        XCTAssertNil(counter.remainingSwipes(isPremium: true))
    }

    func testSuperlikeLimitEnforcedForFreeUsers() {
        let counter = DailySwipeCounter(swipeCount: 0, superlikeCount: 1, lastResetDate: Date())
        XCTAssertFalse(counter.canSuperlike(isPremium: false))
    }

    func testRecordingSwipeIncrementsCountsCorrectly() {
        let base = DailySwipeCounter(swipeCount: 3, superlikeCount: 0, lastResetDate: Date())

        let afterLike = base.recordingSwipe(direction: .like)
        XCTAssertEqual(afterLike.swipeCount, 4)
        XCTAssertEqual(afterLike.superlikeCount, 0)

        let afterSuperlike = base.recordingSwipe(direction: .superlike)
        XCTAssertEqual(afterSuperlike.swipeCount, 4)
        XCTAssertEqual(afterSuperlike.superlikeCount, 1)
    }
}
