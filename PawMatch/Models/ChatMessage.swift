import FirebaseFirestore

/// Mirrors a document at `chats/{matchId}/messages/{messageId}`.
struct ChatMessage: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var timestamp: Timestamp
    var readBy: [String]
}
