import FirebaseFirestore
import Foundation

final class ReportService: ReportServicing {
    static let shared = ReportService()

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func submitReport(
        reporterUserId: String,
        reportedUserId: String,
        reportedPetId: String?,
        reason: Report.Reason,
        details: String?
    ) async throws {
        let report = Report(
            id: nil,
            reporterUserId: reporterUserId,
            reportedUserId: reportedUserId,
            reportedPetId: reportedPetId,
            reason: reason,
            details: details?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Timestamp(date: Date())
        )
        _ = try db.collection("reports").addDocument(from: report)
    }
}
