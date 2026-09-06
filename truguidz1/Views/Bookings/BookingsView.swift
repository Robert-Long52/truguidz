import SwiftUI
 
struct BookingsView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var bookingStore: BookingStore
    @EnvironmentObject var listingStore: ListingStore
    @EnvironmentObject var profileStore: ProfileStore

    @State private var guides: [String: User] = [:]

    // Filters the shared booking list down to just this explorer's bookings.
    private var myBookings: [Booking] {
        guard let userId = userSession.currentUser?.id else { return [] }
        return bookingStore.bookings
            .filter { $0.explorerId == userId }
            .sorted { $0.date < $1.date }
    }

    // Small helper so cards can show trip details, not just raw IDs.
    // Reads from the live ListingStore so bookings against a guide's
    // newly-created listing resolve correctly, not just seeded mock ones.
    private func listing(for booking: Booking) -> Listing? {
        listingStore.listings.first { $0.id == booking.listingId }
    }

    private func guide(for listing: Listing?) -> User? {
        guard let listing else { return nil }
        return guides[listing.guideId]
    }

    private func loadGuides() async {
        let guideIds = Set(myBookings.compactMap { listing(for: $0)?.guideId })
        for id in guideIds where guides[id] == nil {
            guides[id] = await profileStore.profile(for: id)
        }
    }
 
    var body: some View {
        NavigationStack {
            Group {
                if userSession.currentUser == nil {
                    LoginRequiredView(message: "Log in to see your bookings.")
                } else if myBookings.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            AvailabilityCalendarView(bookings: myBookings)

                            ForEach(myBookings) { booking in
                                let matchedListing = listing(for: booking)
                                NavigationLink {
                                    BookingDetailView(
                                        booking: booking,
                                        listing: matchedListing,
                                        guide: guide(for: matchedListing)
                                    )
                                } label: {
                                    BookingCardView(
                                        booking: booking,
                                        listing: matchedListing,
                                        hasUnreadMessages: bookingStore.bookingIdsWithUnreadMessages.contains(booking.id)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                    .background(Color.appBackground)
                    .refreshable {
                        // Pull-to-refresh — otherwise a confirmed/declined
                        // booking or a new message only shows up after
                        // force-quitting and reopening the app.
                        await bookingStore.loadBookings()
                        if let userId = userSession.currentUser?.id {
                            await bookingStore.refreshUnreadMessageIndicators(currentUserId: userId)
                        }
                    }
                }
            }
            .brandedNavTitle("Your Bookings")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task(id: myBookings.map(\.id)) {
            await loadGuides()
        }
        .onAppear {
            // Re-checks on every appearance (not just when the booking list
            // itself changes) so the unread dot clears right away after
            // reading a chat and coming back, not just on the next reload.
            guard let userId = userSession.currentUser?.id else { return }
            Task { await bookingStore.refreshUnreadMessageIndicators(currentUserId: userId) }
        }
    }
 
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(.appSecondaryTextOnDark)
            Text("No bookings yet")
                .font(.headline)
                .foregroundColor(.appTextOnDark)
            Text("Trips you book will show up here.")
                .font(.subheadline)
                .foregroundColor(.appSecondaryTextOnDark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
 
#Preview {
    BookingsView()
        .environmentObject(UserSession.previewExplorer)
        .environmentObject(BookingStore())
        .environmentObject(ListingStore())
        .environmentObject(ProfileStore())
}
