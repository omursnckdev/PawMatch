import SwiftUI

struct ChatDetailView: View {
    @StateObject private var viewModel: ChatDetailViewModel
    @State private var showBlockConfirm = false
    @State private var showReportSheet = false

    init(matchId: String, otherUserId: String, otherPet: Pet) {
        _viewModel = StateObject(wrappedValue: ChatDetailViewModel(
            matchId: matchId,
            otherUserId: otherUserId,
            otherPet: otherPet
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if viewModel.isBlocked {
                blockedBanner
            } else {
                inputBar
            }
        }
        .navigationTitle(viewModel.otherPet.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("chat.menu.report", systemImage: "flag") { showReportSheet = true }
                    Button("chat.menu.block", systemImage: "hand.raised", role: .destructive) {
                        showBlockConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("chat.block.confirm.title", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("chat.menu.block", role: .destructive) {
                Task { await viewModel.blockOtherUser() }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("chat.block.confirm.message")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet { reason, details in
                Task { await viewModel.report(reason: reason, details: details) }
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.messages.isEmpty {
                        Text("chat.noMessagesYet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message, isMine: message.senderId == viewModel.myUserId)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) {
                if let lastId = viewModel.messages.last?.id {
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("chat.message.placeholder", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(viewModel.canSend ? Color.pawOrange : .secondary)
            }
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var blockedBanner: some View {
        Text("chat.blocked.banner")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            Text(message.text)
                .font(.body)
                .foregroundStyle(isMine ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isMine ? Color.pawOrange : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !isMine { Spacer(minLength: 40) }
        }
    }
}
