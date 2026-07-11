import XCTest
@testable import PawMatch

@MainActor
final class ChatDetailViewModelTests: XCTestCase {
    private var chatService: MockChatService!
    private var userService: MockUserService!
    private var reportService: MockReportService!
    private var analytics: MockAnalyticsService!

    private let otherPet = TestFixtures.pet(id: "petB", ownerId: "owner-2", name: "Buddy")

    override func setUp() {
        chatService = MockChatService()
        userService = MockUserService()
        reportService = MockReportService()
        analytics = MockAnalyticsService()
    }

    private func makeViewModel() -> ChatDetailViewModel {
        ChatDetailViewModel(
            matchId: "petA_petB",
            otherUserId: "owner-2",
            otherPet: otherPet,
            chatService: chatService,
            userService: userService,
            reportService: reportService,
            analytics: analytics,
            currentUserId: { "owner-1" }
        )
    }

    func testSendPostsMessageAndLogsAnalytics() async {
        let vm = makeViewModel()
        vm.draft = "Hello there"

        await vm.send()

        XCTAssertEqual(chatService.sentMessages.count, 1)
        XCTAssertEqual(chatService.sentMessages.first?.text, "Hello there")
        XCTAssertEqual(chatService.sentMessages.first?.senderId, "owner-1")
        XCTAssertEqual(vm.draft, "")
        XCTAssertEqual(analytics.loggedEventNames, ["message_sent"])
    }

    func testSendBlockedWhenIsBlocked() async {
        userService.storedUsers["owner-2"] = TestFixtures.user(id: "owner-2", blockedUserIds: ["owner-1"])
        let vm = makeViewModel()
        // Simulate the block-state refresh that onAppear would perform.
        userService.storedUsers["owner-1"] = TestFixtures.user(id: "owner-1")

        vm.draft = "Hello"
        // canSend should become false once blocked; force a block first.
        await vm.blockOtherUser()
        await vm.send()

        XCTAssertTrue(chatService.sentMessages.isEmpty)
        XCTAssertTrue(vm.isBlocked)
    }

    func testBlockOtherUserPersists() async {
        userService.storedUsers["owner-1"] = TestFixtures.user(id: "owner-1")
        let vm = makeViewModel()

        await vm.blockOtherUser()

        XCTAssertTrue(vm.isBlocked)
        XCTAssertEqual(userService.storedUsers["owner-1"]?.blockedUserIds, ["owner-2"])
    }

    func testReportSubmits() async {
        let vm = makeViewModel()

        await vm.report(reason: .harassment, details: "rude")

        XCTAssertEqual(reportService.reports.count, 1)
        XCTAssertEqual(reportService.reports.first?.reported, "owner-2")
        XCTAssertEqual(reportService.reports.first?.reason, .harassment)
        XCTAssertTrue(vm.didSubmitReport)
    }

    func testSendTrimmedEmptyDoesNothing() async {
        let vm = makeViewModel()
        vm.draft = "   "

        await vm.send()

        XCTAssertTrue(chatService.sentMessages.isEmpty)
    }
}
