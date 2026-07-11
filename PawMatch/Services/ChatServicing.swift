import Foundation

protocol ChatServicing {
    /// Live stream of a conversation's messages, oldest first.
    func observeMessages(matchId: String) -> AsyncStream<[ChatMessage]>
    func sendMessage(matchId: String, senderId: String, text: String) async throws
    func markMessagesRead(matchId: String, userId: String, messageIds: [String]) async throws
}
