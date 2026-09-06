import SwiftUI

// Full booking history, reached via "View All Bookings" on the dashboard --
// GuidzDashboardView's own "Incoming Bookings" section only shows what's
// still pending or upcoming, so this is where anything older (completed
// trips, cancelled requests) stays reachable instead of disappearing.
struct GuideAllBookingsView: View {
    let bookings: [Booking]
    let listing: (Booking) -> Listing?
    let explorer: (Booking) -> User?
    let onSelect: (Booking) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(bookings) { booking in
                    GuideBookingCardView(
                        booking: booking,
                        listing: listing(booking),
                        explorer: explorer(booking)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(booking)
                    }
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .brandedNavTitle("All Bookings")
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        GuideAllBookingsView(
            bookings: Booking.mockBookings,
            listing: { _ in Listing.mockListings.first },
            explorer: { _ in .mockExplorer },
            onSelect: { _ in }
        )
    }
}
