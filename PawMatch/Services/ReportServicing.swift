import Foundation

protocol ReportServicing {
    func submitReport(
        reporterUserId: String,
        reportedUserId: String,
        reportedPetId: String?,
        reason: Report.Reason,
        details: String?
    ) async throws
}
