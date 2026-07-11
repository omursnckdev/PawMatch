import SwiftUI

/// Lists the user's pets with add / edit / delete (Milestone 2, §12). This is
/// the temporary "main" surface until the tab bar and swipe deck land in
/// Milestone 3 — sign-out lives here for now so the app never dead-ends.
struct ManagePetsView: View {
    let pets: [Pet]
    @ObservedObject var homeViewModel: HomeViewModel
    let onSignOut: () -> Void

    @ObservedObject private var entitlements = EntitlementManager.shared
    @State private var editorState: EditorState?
    @State private var petPendingDeletion: Pet?
    @State private var showSecondPetPaywall = false
    @State private var showSettings = false

    /// Wraps the optional pet in an Identifiable so `.sheet(item:)` can drive
    /// both "add" (nil pet) and "edit" (existing pet) from one presentation.
    private struct EditorState: Identifiable {
        let id = UUID()
        let pet: Pet?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if entitlements.billingIssue {
                        billingIssueBanner
                    }

                    ForEach(pets) { pet in
                        petRow(pet)
                    }

                    if pets.isEmpty {
                        Text("managePets.empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }

                    addPetButton
                }
                .padding(20)
            }
            .navigationTitle("managePets.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(isPremium: entitlements.isPremium, onSignOut: onSignOut)
            }
            .sheet(item: $editorState) { editor in
                PetProfileSetupView(
                    viewModel: PetProfileViewModel(editing: editor.pet),
                    onComplete: { _ in
                        editorState = nil
                        Task { await homeViewModel.load() }
                    },
                    onCancel: { editorState = nil }
                )
            }
            .confirmationDialog(
                "managePets.deleteConfirm.title",
                isPresented: deleteDialogBinding,
                titleVisibility: .visible
            ) {
                Button("common.delete", role: .destructive) {
                    if let pet = petPendingDeletion {
                        Task { await homeViewModel.deletePet(pet) }
                    }
                    petPendingDeletion = nil
                }
                Button("common.cancel", role: .cancel) { petPendingDeletion = nil }
            } message: {
                Text("managePets.deleteConfirm.message")
            }
            .sheet(isPresented: $showSecondPetPaywall) {
                PaywallView(source: .secondPet, onDismiss: { showSecondPetPaywall = false })
            }
        }
    }

    private var billingIssueBanner: some View {
        Label("billing.issue.banner", systemImage: "exclamationmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func petRow(_ pet: Pet) -> some View {
        VStack(spacing: 8) {
            PetCardView(pet: pet)
                .frame(height: 380)

            HStack(spacing: 16) {
                Text(verbatim: pet.name)
                    .font(.headline)

                Spacer()

                Button {
                    editorState = EditorState(pet: pet)
                } label: {
                    Image(systemName: "pencil")
                }

                Button(role: .destructive) {
                    petPendingDeletion = pet
                } label: {
                    Image(systemName: "trash")
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var addPetButton: some View {
        Button {
            // A second (and beyond) pet is a PawMatch Plus feature (§3).
            if pets.isEmpty || entitlements.isPremium {
                editorState = EditorState(pet: nil)
            } else {
                showSecondPetPaywall = true
            }
        } label: {
            Label("managePets.add", systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 8)
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { petPendingDeletion != nil },
            set: { if !$0 { petPendingDeletion = nil } }
        )
    }
}
