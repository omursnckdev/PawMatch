import FirebaseFirestore
import Foundation

final class ChatService: ChatServicing {
    static let shared = ChatService()

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func messagesCollection(_ matchId: String) -> CollectionReference {
        db.collection("chats").document(matchId).collection("messages")
    }

    func observeMessages(matchId: String) -> AsyncStream<[ChatMessage]> {
        let query = messagesCollection(matchId).order(by: "timestamp", descending: false)
        return FirestoreListener.stream(query, as: ChatMessage.self)
    }

    func sendMessage(matchId: String, senderId: String, text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let message = ChatMessage(
            id: nil,
            senderId: senderId,
            text: trimmed,
            timestamp: Timestamp(date: Date()),
            readBy: [senderId]
        )
        _ = try messagesCollection(matchId).addDocument(from: message)
    }

    func markMessagesRead(matchId: String, userId: String, messageIds: [String]) async throws {
        guard !messageIds.isEmpty else { return }
        let batch = db.batch()
        for id in messageIds {
            let ref = messagesCollection(matchId).document(id)
            batch.updateData(["readBy": FieldValue.arrayUnion([userId])], forDocument: ref)
        }
        try await batch.commit()
    }
}
