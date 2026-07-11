import SwiftUI

/// The swipe deck (Milestone 3). Shows a card stack; the top card is draggable
/// (drag past a threshold to like/pass) with tappable button fallbacks for
/// accessibility. Hitting the free daily limit presents the paywall.
struct SwipeDeckView: View {
    @StateObject private var viewModel: SwipeDeckViewModel
    @State private var dragOffset: CGSize = .zero

    private let swipeThreshold: CGFloat = 120

    init(activePet: Pet) {
        _viewModel = StateObject(wrappedValue: SwipeDeckViewModel(activePet: activePet))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                content
                if !viewModel.isLoading && !viewModel.isDeckExhausted {
                    actionButtons
                    remainingLabel
                }
            }
            .padding()
            .navigationTitle("deck.title")
            .background(Color(.systemBackground))
            .task { await viewModel.load() }
            .sheet(item: $viewModel.paywallSource) { source in
                PaywallView(source: source, onDismiss: { viewModel.dismissPaywall() })
            }
            .alert(
                "error.generic",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("common.retry") { Task { await viewModel.load() } }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingState
        } else if viewModel.isDeckExhausted {
            PlaceholderView(
                systemImage: "pawprint",
                title: "deck.empty.title",
                message: "deck.empty.message"
            )
        } else {
            cardStack
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .redacted(reason: .placeholder)
            Text("deck.loading")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var cardStack: some View {
        ZStack {
            if let next = viewModel.nextCard {
                PetCardView(pet: next.pet, distanceKm: next.distanceKm, isSuperliked: next.isSuperlikedByTarget)
                    .scaleEffect(0.95)
                    .opacity(0.9)
            }

            if let current = viewModel.currentCard {
                PetCardView(pet: current.pet, distanceKm: current.distanceKm, isSuperliked: current.isSuperlikedByTarget)
                    .overlay(alignment: .top) { swipeHintOverlay }
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                    .gesture(dragGesture)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dragOffset)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var swipeHintOverlay: some View {
        HStack {
            Text("deck.action.like")
                .hintStyle(color: .green)
                .opacity(Double(max(0, dragOffset.width) / swipeThreshold))
            Spacer()
            Text("deck.action.pass")
                .hintStyle(color: .red)
                .opacity(Double(max(0, -dragOffset.width) / swipeThreshold))
        }
        .padding()
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                if value.translation.width > swipeThreshold {
                    performSwipe(.like, exitX: 500)
                } else if value.translation.width < -swipeThreshold {
                    performSwipe(.pass, exitX: -500)
                } else {
                    dragOffset = .zero
                }
            }
    }

    private var actionButtons: some View {
        HStack(spacing: 28) {
            circleButton(systemImage: "xmark", tint: .red, label: "deck.action.pass") {
                performSwipe(.pass, exitX: -500)
            }
            circleButton(systemImage: "star.fill", tint: .blue, label: "deck.action.superlike") {
                performSwipe(.superlike, exitX: 0, exitY: -500)
            }
            circleButton(systemImage: "heart.fill", tint: .green, label: "deck.action.like") {
                performSwipe(.like, exitX: 500)
            }
        }
    }

    private var remainingLabel: some View {
        Group {
            if let remaining = viewModel.remainingSwipes {
                Text(String(format: String(localized: "deck.remaining"), remaining))
            } else {
                Text("deck.remaining.unlimited")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func circleButton(systemImage: String, tint: Color, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 60, height: 60)
                .background(Color(.secondarySystemBackground), in: Circle())
        }
        .accessibilityLabel(Text(label))
    }

    private func performSwipe(_ direction: Swipe.Direction, exitX: CGFloat, exitY: CGFloat = 0) {
        Task {
            let recorded = await viewModel.swipe(direction)
            if recorded {
                withAnimation(.easeOut(duration: 0.25)) {
                    dragOffset = CGSize(width: exitX, height: exitY)
                }
                // Reset offset for the next card after the exit animation.
                try? await Task.sleep(nanoseconds: 250_000_000)
                dragOffset = .zero
            } else {
                // Blocked by the daily limit (paywall shown) — snap back.
                withAnimation { dragOffset = .zero }
            }
        }
    }
}

private extension View {
    func hintStyle(color: Color) -> some View {
        font(.pawHeading(28))
            .foregroundStyle(color)
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(-12))
    }
}
