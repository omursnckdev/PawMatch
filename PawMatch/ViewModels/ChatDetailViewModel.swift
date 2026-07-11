import Foundation

@MainActor
final class ChatDetailViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var draft = ""
    @Published private(set) var isBlocked = false
    @Published var errorMessage: String?
    @Published var didSubmitReport = false

    let matchId: String
    let otherUserId: String
    let otherPet: Pet

    private let chatService: ChatServicing
    private let userService: UserServicing
    private let reportService: ReportServicing
    private let analytics: AnalyticsServicing
    private let currentUserId: () -> String?

    private var observeTask: Task<Void, Never>?

    init(
        matchId: String,
        otherUserId: String,
        otherPet: Pet,
        chatService: ChatServicing = ChatService.shared,
        userService: UserServicing = UserService.shared,
        reportService: ReportServicing = ReportService.shared,
        analytics: AnalyticsServicing = AnalyticsService.shared,
        currentUserId: @escaping () -> String? = { AuthService.shared.currentUserId }
    ) {
        self.matchId = matchId
        self.otherUserId = otherUserId
        self.otherPet = otherPet
        self.chatService = chatService
        self.userService = userService
        self.reportService = reportService
        self.analytics = analytics
        self.currentUserId = currentUserId
    }

    deinit { observeTask?.cancel() }

    var myUserId: String? { currentUserId() }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBlocked
    }

    func onAppear() {
        guard let uid = currentUserId() else { return }
        Task { try? await userService.setActiveChat(uid: uid, matchId: matchId) }
        Task { await refreshBlockState(uid: uid) }
        startObserving()
    }

    func onDisappear() {
        observeTask?.cancel()
        observeTask = nil
        guard let uid = currentUserId() else { return }
        Task { try? await userService.setActiveChat(uid: uid, matchId: nil) }
    }

    func send() async {
        guard let uid = currentUserId(), canSend else { return }
        let text = draft
        draft = ""
        do {
            try await chatService.sendMessage(matchId: matchId, senderId: uid, text: text)
            analytics.log(.messageSent)
        } catch {
            draft = text
            errorMessage = error.localizedDescription
        }
    }

    func blockOtherUser() async {
        guard let uid = currentUserId() else { return }
        do {
            try await userService.setBlocked(uid: uid, otherUserId: otherUserId, isBlocked: true)
            isBlocked = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func report(reason: Report.Reason, details: String?) async {
        guard let uid = currentUserId() else { return }
        do {
            try await reportService.submitReport(
                reporterUserId: uid,
                reportedUserId: otherUserId,
                reportedPetId: otherPet.id,
                reason: reason,
                details: details
            )
            didSubmitReport = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startObserving() {
        guard observeTask == nil else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await messages in self.chatService.observeMessages(matchId: self.matchId) {
                self.messages = messages
                await self.markIncomingRead(messages)
            }
        }
    }

    private func markIncomingRead(_ messages: [ChatMessage]) async {
        guard let uid = currentUserId() else { return }
        let unreadIds = messages.compactMap { message -> String? in
            guard let id = message.id, message.senderId != uid, !message.readBy.contains(uid) else { return nil }
            return id
        }
        try? await chatService.markMessagesRead(matchId: matchId, userId: uid, messageIds: unreadIds)
    }

    /// Blocked either way: I blocked them, or they blocked me. The reverse is
    /// also enforced by security rules on the message write (§6.3).
    private func refreshBlockState(uid: String) async {
        let mine = (try? await userService.fetchUser(uid: uid))?.blockedUserIds ?? []
        let theirs = (try? await userService.fetchUser(uid: otherUserId))?.blockedUserIds ?? []
        isBlocked = mine.contains(otherUserId) || theirs.contains(uid)
    }
}
