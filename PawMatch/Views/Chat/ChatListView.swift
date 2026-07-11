import Kingfisher
import SwiftUI

/// Chat tab: a list of conversations (matches, most-recent first) with a last
/// message preview. Also the deep-link target — a tapped push sets
/// `DeepLinkRouter.pendingMatchId`, which pushes straight into that chat.
struct ChatListView: View {
    @StateObject private var viewModel = MatchesViewModel()
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.rows.isEmpty {
                    PlaceholderView(
                        systemImage: "bubble.left.and.bubble.right",
                        title: "chat.empty.title",
                        message: "chat.empty.message"
                    )
                } else {
                    List(viewModel.rows) { row in
                        Button {
                            if let id = row.match.id { path.append(id) }
                        } label: {
                            ConversationRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("chat.title")
            .navigationDestination(for: String.self) { matchId in
                conversationDestination(matchId: matchId)
            }
        }
        .onAppear { viewModel.start() }
        .onChange(of: deepLinkRouter.pendingMatchId) { _, matchId in
            handleDeepLink(matchId)
        }
        .onChange(of: viewModel.rows) {
            // A deep link may arrive before matches finish loading; retry once loaded.
            handleDeepLink(deepLinkRouter.pendingMatchId)
        }
    }

    private func handleDeepLink(_ matchId: String?) {
        guard let matchId else { return }
        guard viewModel.rows.contains(where: { $0.match.id == matchId }) else { return }
        if path.last != matchId { path.append(matchId) }
        deepLinkRouter.clear()
    }

    @ViewBuilder
    private func conversationDestination(matchId: String) -> some View {
        if let row = viewModel.rows.first(where: { $0.match.id == matchId }) {
            ChatDetailView(matchId: matchId, otherUserId: row.otherUserId, otherPet: row.otherPet)
        } else {
            ProgressView()
        }
    }
}

private struct ConversationRow: View {
    let row: MatchRow

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = row.otherPet.photoUrls.first, let url = URL(string: urlString) {
                KFImage(url).resizable().scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Circle().fill(Color(.secondarySystemBackground)).frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(row.otherPet.name)
                    .font(.headline)
                Text(row.match.lastMessage ?? String(localized: "chat.noMessagesYet"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
