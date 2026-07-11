import Kingfisher
import SwiftUI

/// Matches tab: a grid of mutual matches; tapping one opens the conversation.
struct MatchesView: View {
    @StateObject private var viewModel = MatchesViewModel()
    @State private var path: [String] = []

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.isLoading {
                    ProgressView("matches.loading")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.rows.isEmpty {
                    PlaceholderView(
                        systemImage: "square.grid.2x2",
                        title: "matches.empty.title",
                        message: "matches.empty.message"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.rows) { row in
                                Button {
                                    if let id = row.match.id { path.append(id) }
                                } label: {
                                    MatchGridCell(row: row)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("matches.title")
            .navigationDestination(for: String.self) { matchId in
                conversationDestination(matchId: matchId)
            }
        }
        .onAppear { viewModel.start() }
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

private struct MatchGridCell: View {
    let row: MatchRow

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let urlString = row.otherPet.photoUrls.first, let url = URL(string: urlString) {
                    KFImage(url).resizable().scaledToFill()
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(row.otherPet.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
    }
}
