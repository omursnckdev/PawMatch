import SwiftUI

/// Report flow with a fixed reason list plus optional free-text (§10.8 — a
/// picker is far easier to triage than free-text alone).
struct ReportSheet: View {
    let onSubmit: (Report.Reason, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: Report.Reason = .spam
    @State private var details = ""
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            Form {
                if submitted {
                    Section {
                        Label("report.submitted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Section("report.reason.header") {
                        Picker("report.reason.header", selection: $reason) {
                            ForEach(Report.Reason.allCases) { reason in
                                Text(label(for: reason)).tag(reason)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Section {
                        TextField("report.details.placeholder", text: $details, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    Section {
                        Button("report.submit") {
                            onSubmit(reason, details.isEmpty ? nil : details)
                            submitted = true
                        }
                    }
                }
            }
            .navigationTitle("report.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }

    private func label(for reason: Report.Reason) -> LocalizedStringKey {
        switch reason {
        case .spam: return "report.reason.spam"
        case .inappropriatePhoto: return "report.reason.inappropriatePhoto"
        case .harassment: return "report.reason.harassment"
        case .animalWelfare: return "report.reason.animalWelfare"
        case .other: return "report.reason.other"
        }
    }
}
