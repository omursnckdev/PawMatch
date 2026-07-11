import RevenueCat
import SwiftUI

/// PawMatch Plus paywall (§8, §13). Presents RevenueCat packages with price /
/// duration, a purchase + Restore Purchases action, and the subscription-terms
/// disclosure Apple requires. Logs the paywall funnel events.
struct PaywallView: View {
    let source: PaywallSource
    let onDismiss: () -> Void

    @StateObject private var viewModel: PaywallViewModel
    @State private var selectedPackage: Package?

    init(source: PaywallSource, onDismiss: @escaping () -> Void) {
        self.source = source
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: PaywallViewModel(source: source))
    }

    private let benefits: [(icon: String, title: LocalizedStringKey)] = [
        ("infinity", "paywall.benefit.unlimited"),
        ("pawprint.fill", "paywall.benefit.multiPet"),
        ("slider.horizontal.3", "paywall.benefit.filters"),
        ("arrow.uturn.backward", "paywall.benefit.rewind"),
        ("heart.fill", "paywall.benefit.whoLiked"),
        ("bolt.fill", "paywall.benefit.boost"),
        ("nosign", "paywall.benefit.noAds")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                benefitsCard
                packagesSection
                footer
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .task { await viewModel.onAppear() }
        .onChange(of: viewModel.didPurchase) { _, purchased in
            if purchased { onDismiss() }
        }
        .overlay {
            if viewModel.isPurchasing {
                ProgressView().padding(24).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.pawOrange)
            Text("paywall.title").font(.pawHeading(26))
            Text(headline)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(benefits, id: \.icon) { benefit in
                HStack(spacing: 12) {
                    Image(systemName: benefit.icon)
                        .foregroundStyle(Color.pawOrange).frame(width: 28)
                    Text(benefit.title).font(.body)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var packagesSection: some View {
        if viewModel.isLoading {
            ProgressView().padding()
        } else if viewModel.packages.isEmpty {
            Text("paywall.unavailable")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 10) {
                ForEach(viewModel.packages, id: \.identifier) { package in
                    packageRow(package)
                }

                Button {
                    if let package = selectedPackage ?? viewModel.packages.first {
                        Task { await viewModel.purchase(package) }
                    }
                } label: {
                    Text("paywall.subscribe")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isPurchasing)
            }
        }
    }

    private func packageRow(_ package: Package) -> some View {
        let isSelected = (selectedPackage ?? viewModel.packages.first)?.identifier == package.identifier
        return Button {
            selectedPackage = package
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.storeProduct.localizedTitle).font(.headline)
                    Text(package.storeProduct.localizedPriceString).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(Color.pawOrange)
            }
            .padding()
            .background(isSelected ? Color.pawOrange.opacity(0.12) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button("paywall.restore") { Task { await viewModel.restore() } }
                .font(.subheadline)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }

            Text("paywall.terms")
                .font(.caption2).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("legal.terms", destination: LegalLinks.termsOfService)
                Link("legal.privacy", destination: LegalLinks.privacyPolicy)
            }
            .font(.caption2)

            Button("paywall.maybeLater") {
                viewModel.dismissed()
                onDismiss()
            }
            .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var headline: LocalizedStringKey {
        switch source {
        case .swipeLimit: return "paywall.headline.swipeLimit"
        case .superlikeLimit: return "paywall.headline.superlikeLimit"
        case .secondPet: return "paywall.headline.secondPet"
        case .likesTab: return "paywall.headline.likesTab"
        case .rewind: return "paywall.headline.rewind"
        case .boost: return "paywall.headline.boost"
        }
    }
}
