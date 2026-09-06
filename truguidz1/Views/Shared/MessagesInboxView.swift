import SwiftUI

// Which side of a booking "my conversations" means -- an explorer's
// inbox is their guides, a guide's inbox is their explorers. Kept as one
// shared view rather than two near-duplicates since the only real
// difference is which id on Booking is "me" vs "them"; everything else
// (row layout, unread dots, ChatView hand-off) is identical.
enum MessagingRole {
    case explorer
    case guide
}

// Reached from the message bubble icon on Explore (role: .explorer) and
// the equivalent one on the Guide Dashboard (role: .guide). Lists every
// conversation this account can actually message -- booking confirmed or
// completed; a still-pending request hasn't unlocked messaging yet (see
// rls_policies.sql). Callers already check this list isn't empty before
// presenting this sheet at all, so there's no empty-state to design for
// here.
struct MessagesInboxView: View {
    let role: MessagingRole

    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var bookingStore: BookingStore
    @EnvironmentObject var listingStore: ListingStore
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var otherParties: [String: User] = [:]

    private var conversations: [Booking] {
        guard let userId = userSession.currentUser?.id else { return [] }
        return bookingStore.bookings
            .filter {
                let mine = role == .explorer ? $0.explorerId : $0.guideId
                return mine == userId && ($0.status == .confirmed || $0.status == .completed)
            }
            .sorted { $0.date > $1.date }
    }

    private func otherPartyId(for booking: Booking) -> String {
        role == .explorer ? booking.guideId : booking.explorerId
    }

    private func otherParty(for booking: Booking) -> User? {
        otherParties[otherPartyId(for: booking)]
    }

    private func listing(for booking: Booking) -> Listing? {
        listingStore.listings.first { $0.id == booking.listingId }
    }

    private func loadOtherParties() async {
        let ids = Set(conversations.map { otherPartyId(for: $0) })
        for id in ids where otherParties[id] == nil {
            otherParties[id] = await profileStore.profile(for: id)
        }
    }

    private var placeholderName: String {
        role == .explorer ? "Guide" : "Explorer"
    }

    var body: some View {
        NavigationStack {
            List(conversations) { booking in
                NavigationLink {
                    if let userId = userSession.currentUser?.id {
                        ChatView(
                            booking: booking,
                            currentUserId: userId,
                            otherPartyName: otherParty(for: booking)?.name ?? placeholderName
                        )
                    }
                } label: {
                    conversationRow(booking)
                }
                .listRowBackground(Color.appCard)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: conversations.map(\.id)) {
            await loadOtherParties()
        }
        .onAppear {
            // Clears a conversation's unread dot right away after coming
            // back from reading it, not just on the next natural reload.
            guard let userId = userSession.currentUser?.id else { return }
            Task { await bookingStore.refreshUnreadMessageIndicators(currentUserId: userId) }
        }
    }

    private func conversationRow(_ booking: Booking) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 46, height: 46)
                Text(otherParty(for: booking)?.name.prefix(1) ?? "?")
                    .font(.headline)
                    .foregroundColor(.appSecondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(otherParty(for: booking)?.name ?? placeholderName)
                        .fontWeight(.semibold)

                    if bookingStore.bookingIdsWithUnreadMessages.contains(booking.id) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(listing(for: booking)?.title ?? "Trip")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.appSecondaryText)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    MessagesInboxView(role: .explorer)
        .environmentObject(UserSession.previewExplorer)
        .environmentObject(BookingStore())
        .environmentObject(ListingStore())
        .environmentObject(ProfileStore())
}
