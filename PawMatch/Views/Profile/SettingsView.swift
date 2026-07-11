import SwiftUI

/// Profile → Settings (§4). Subscription management, legal links, and (added in
/// Milestone 6) the Delete Account flow.
struct SettingsView: View {
    let isPremium: Bool
    let onSignOut: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                subscriptionSection
                legalSection
                accountSection
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private var subscriptionSection: some View {
        Section("settings.subscription.header") {
            HStack {
                Text("settings.subscription.status")
                Spacer()
                Text(isPremium ? "settings.subscription.plus" : "settings.subscription.free")
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await restore() }
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("paywall.restore")
                }
            }
            .disabled(isRestoring)

            Link("legal.manageSubscription", destination: LegalLinks.manageSubscription)

            if let restoreMessage {
                Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var legalSection: some View {
        Section("settings.legal.header") {
            Link("legal.terms", destination: LegalLinks.termsOfService)
            Link("legal.privacy", destination: LegalLinks.privacyPolicy)
            Link("legal.community", destination: LegalLinks.communityGuidelines)
        }
    }

    private var accountSection: some View {
        Section {
            Button("common.signOut", action: onSignOut)
            Button("settings.deleteAccount", role: .destructive) {
                showDeleteConfirm = true
            }
        }
        .sheet(isPresented: $showDeleteConfirm) {
            DeleteAccountView(onDeleted: {
                showDeleteConfirm = false
                onSignOut()
            })
        }
    }

    private func restore() async {
        isRestoring = true
        restoreMessage = nil
        defer { isRestoring = false }
        do {
            let active = try await PurchaseService.shared.restorePurchases()
            restoreMessage = String(localized: active ? "settings.restore.success" : "paywall.restore.none")
            if active { EntitlementManager.shared.applyOptimisticPremium() }
        } catch {
            restoreMessage = error.localizedDescription
        }
    }
}
