import Foundation
import Supabase

// Scoped to a single booking's conversation, unlike the app-wide Stores --
// a chat is only ever viewed one booking at a time, so there's no benefit
// to a shared cache the way BookingStore/ListingStore have one.
//
// No Realtime subscription: polling every few seconds while the view is
// open is simpler to reason about and verify than a websocket channel,
// and more than good enough for a two-person conversation about a trip.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isSending = false
    @Published var errorMessage: String?

    let bookingId: String
    private var pollTask: Task<Void, Never>?

    init(bookingId: String) {
        self.bookingId = bookingId
    }

    func loadMessages() async {
        do {
            let fetched: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("booking_id", value: bookingId)
                .order("created_at", ascending: true)
                .execute()
                .value
            messages = fetched
        } catch {
            print("Failed to load messages for booking \(bookingId): \(error)")
        }
    }

    func sendMessage(senderId: String, body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        isSending = true
        defer { isSending = false }

        let newMessage = Message(
            id: UUID().uuidString,
            bookingId: bookingId,
            senderId: senderId,
            body: trimmed,
            createdAt: Date(),
            readAt: nil
        )

        do {
            let inserted: Message = try await supabase
                .from("messages")
                .insert(newMessage)
                .select()
                .single()
                .execute()
                .value
            messages.append(inserted)
        } catch {
            errorMessage = "Couldn't send your message. Please try again."
            print("Failed to send message: \(error)")
        }
    }

    // Marks every incoming (not-mine) unread message as read -- called
    // once when the chat opens. The messages_protect_content trigger
    // (supabase/add_message_read_receipts.sql) means this update can only
    // ever actually change read_at, never the message body/sender.
    func markIncomingAsRead(currentUserId: String) async {
        let unreadIds = messages
            .filter { $0.senderId != currentUserId && $0.readAt == nil }
            .map(\.id)
        guard !unreadIds.isEmpty else { return }

        do {
            try await supabase
                .from("messages")
                .update(ReadReceiptUpdate(readAt: Date()))
                .in("id", values: unreadIds)
                .execute()
            for id in unreadIds {
                if let index = messages.firstIndex(where: { $0.id == id }) {
                    messages[index].readAt = Date()
                }
            }
        } catch {
            print("Failed to mark messages read for booking \(bookingId): \(error)")
        }
    }

    func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.loadMessages()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}

private struct ReadReceiptUpdate: Encodable {
    let readAt: Date
    enum CodingKeys: String, CodingKey { case readAt = "read_at" }
}
