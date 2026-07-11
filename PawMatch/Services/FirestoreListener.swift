import FirebaseFirestore

/// Bridges a Firestore query's snapshot listener into an `AsyncStream` of decoded
/// models (§5 — live updates for chat, matches, and deck refresh). The listener
/// is registered when iteration starts and removed when the stream terminates.
enum FirestoreListener {
    static func stream<T: Decodable>(
        _ query: Query,
        as type: T.Type
    ) -> AsyncStream<[T]> {
        AsyncStream { continuation in
            let registration = query.addSnapshotListener { snapshot, error in
                guard let snapshot, error == nil else { return }
                let models = snapshot.documents.compactMap { try? $0.data(as: T.self) }
                continuation.yield(models)
            }
            continuation.onTermination = { _ in
                registration.remove()
            }
        }
    }
}
