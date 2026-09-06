import SwiftUI

struct ChatView: View {
    let booking: Booking
    let currentUserId: String
    let otherPartyName: String

    @StateObject private var viewModel: ChatViewModel
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    init(booking: Booking, currentUserId: String, otherPartyName: String) {
        self.booking = booking
        self.currentUserId = currentUserId
        self.otherPartyName = otherPartyName
        _viewModel = StateObject(wrappedValue: ChatViewModel(bookingId: booking.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if viewModel.messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message, isMine: message.senderId == currentUserId)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) {
                    scrollToBottom(proxy)
                }
                .onAppear {
                    scrollToBottom(proxy, animated: false)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            inputBar
        }
        .background(Color.appBackground)
        .navigationTitle(otherPartyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadMessages()
            await viewModel.markIncomingAsRead(currentUserId: currentUserId)
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "message")
                .font(.system(size: 36))
                .foregroundColor(.appSecondaryTextOnDark)
            Text("Say hello to \(otherPartyName) about your trip.")
                .font(.subheadline)
                .foregroundColor(.appSecondaryTextOnDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appCard)
                .cornerRadius(18)
                .focused($inputFocused)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func send() {
        let body = draft
        draft = ""
        Task {
            await viewModel.sendMessage(senderId: currentUserId, body: body)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastId = viewModel.messages.last?.id else { return }
        if animated {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMine ? Color.accentColor : Color.appCard)
                    .foregroundColor(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.appSecondaryTextOnDark)
            }

            if !isMine { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(booking: Booking.mockBookings[0], currentUserId: "user_1", otherPartyName: "Jake Miller")
    }
}
