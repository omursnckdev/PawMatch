import Kingfisher
import SwiftUI

/// Multi-step pet profile setup (§4): basics → photos → purpose → location.
/// Reused for both first-run onboarding (create) and editing an existing pet.
struct PetProfileSetupView: View {
    @StateObject var viewModel: PetProfileViewModel
    /// Called with the saved pet id once the flow completes successfully.
    let onComplete: (String) -> Void
    var onCancel: (() -> Void)? = nil

    @State private var step: Step = .basics
    @State private var isPhotoPickerPresented = false

    enum Step: Int, CaseIterable {
        case basics, photos, purpose, location
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
                .tint(Color.pawOrange)
                .padding(.horizontal, 24)

            ScrollView {
                stepContent
                    .padding(24)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            footer
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $isPhotoPickerPresented) {
            PhotoPicker(selectionLimit: 6) { images in
                viewModel.addImages(images)
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack {
            if let onCancel {
                Button("common.cancel", action: onCancel)
                    .font(.subheadline)
            }
            Spacer()
            Text(viewModel.isEditing ? "petSetup.title.edit" : "petSetup.title.create")
                .font(.pawHeading(18))
            Spacer()
            // Balance the cancel button's width so the title stays centered.
            if onCancel != nil {
                Text("common.cancel").font(.subheadline).opacity(0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .basics: basicsStep
        case .photos: photosStep
        case .purpose: purposeStep
        case .location: locationStep
        }
    }

    // MARK: - Steps

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("petSetup.step.basics").font(.pawHeading(24))

            labeledField("petSetup.field.name") {
                TextField("petSetup.field.name", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                    .fieldStyle()
            }

            labeledField("petSetup.field.species") {
                Picker("petSetup.field.species", selection: $viewModel.species) {
                    Text("species.dog").tag(Pet.Species.dog)
                    Text("species.cat").tag(Pet.Species.cat)
                    Text("species.other").tag(Pet.Species.other)
                }
                .pickerStyle(.segmented)
            }

            labeledField("petSetup.field.breed") {
                TextField("petSetup.field.breed", text: $viewModel.breed)
                    .textInputAutocapitalization(.words)
                    .fieldStyle()
            }

            labeledField("petSetup.field.age") {
                TextField("petSetup.field.age", text: $viewModel.ageText)
                    .keyboardType(.numberPad)
                    .fieldStyle()
            }

            labeledField("petSetup.field.sex") {
                Picker("petSetup.field.sex", selection: $viewModel.sex) {
                    Text("sex.male").tag(Pet.Sex.male)
                    Text("sex.female").tag(Pet.Sex.female)
                }
                .pickerStyle(.segmented)
            }

            labeledField("petSetup.field.bio") {
                TextField("petSetup.field.bio", text: $viewModel.bio, axis: .vertical)
                    .lineLimit(3...6)
                    .fieldStyle()
            }
        }
    }

    private var photosStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("petSetup.step.photos").font(.pawHeading(24))
            Text("petSetup.photos.hint")
                .font(.subheadline).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                ForEach(viewModel.existingPhotoUrls, id: \.self) { url in
                    photoThumb(remoteURL: url) {
                        viewModel.removeExistingPhoto(url)
                    }
                }
                ForEach(Array(viewModel.newImages.enumerated()), id: \.offset) { index, image in
                    photoThumb(image: image) {
                        viewModel.removeNewImage(at: index)
                    }
                }
                addPhotoButton
            }
        }
    }

    private var purposeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("petSetup.step.purpose").font(.pawHeading(24))
            Text("petSetup.purpose.hint")
                .font(.subheadline).foregroundStyle(.secondary)

            purposeToggle(.playdate, systemImage: "figure.play")
            purposeToggle(.breeding, systemImage: "heart.circle.fill")
        }
    }

    private var locationStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pawOrange)
            Text("petSetup.step.location").font(.pawHeading(24))
            Text("petSetup.location.priming")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.isLocationValid {
                Label("petSetup.location.set", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                Button {
                    Task { await viewModel.requestLocation() }
                } label: {
                    if viewModel.isRequestingLocation {
                        ProgressView().tint(.white)
                    } else {
                        Text("petSetup.location.enable")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isRequestingLocation)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: - Footer navigation

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .basics {
                Button("common.back") { goBack() }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
            }

            if step == .location {
                Button {
                    Task {
                        if let id = await viewModel.save() { onComplete(id) }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("petSetup.finish")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: !viewModel.canSave))
                .disabled(!viewModel.canSave)
            } else {
                Button("common.continue") { goNext() }
                    .buttonStyle(PrimaryButtonStyle(isDisabled: !isCurrentStepValid))
                    .disabled(!isCurrentStepValid)
            }
        }
        .padding(24)
    }

    private var isCurrentStepValid: Bool {
        switch step {
        case .basics: return viewModel.isBasicsValid
        case .photos: return viewModel.isPhotosValid
        case .purpose: return viewModel.isPurposeValid
        case .location: return viewModel.isLocationValid
        }
    }

    private func goNext() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation { step = next }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation { step = previous }
    }

    // MARK: - Small builders

    private func labeledField<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private var addPhotoButton: some View {
        Button {
            isPhotoPickerPresented = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title2)
                Text("petSetup.photos.add").font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .foregroundStyle(Color.pawOrange)
    }

    private func photoThumb(image: UIImage, onRemove: @escaping () -> Void) -> some View {
        thumbFrame(onRemove: onRemove) {
            Image(uiImage: image).resizable().scaledToFill()
        }
    }

    private func photoThumb(remoteURL: String, onRemove: @escaping () -> Void) -> some View {
        thumbFrame(onRemove: onRemove) {
            KFImage(URL(string: remoteURL)).resizable().scaledToFill()
        }
    }

    private func thumbFrame<Content: View>(onRemove: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .font(.title3)
                }
                .padding(4)
            }
    }

    private func purposeToggle(_ purpose: Pet.Purpose, systemImage: String) -> some View {
        let isOn = viewModel.purposes.contains(purpose)
        return Button {
            viewModel.togglePurpose(purpose)
        } label: {
            HStack {
                Image(systemName: systemImage)
                Text(purpose == .playdate ? "purpose.playdate" : "purpose.breeding")
                    .font(.headline)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            }
            .padding()
            .background(isOn ? Color.pawOrange.opacity(0.15) : Color(.secondarySystemBackground))
            .foregroundStyle(isOn ? Color.pawOrange : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
