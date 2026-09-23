import SwiftUI
 
struct GuideBookingCardView: View {
    let booking: Booking
    let listing: Listing?
    let explorer: User?
 
    @EnvironmentObject var bookingStore: BookingStore
 
    private var statusColor: Color {
        switch booking.status {
        case .pending: return .orange
        case .confirmed: return .green
        case .completed: return .blue
        case .cancelled: return .red
        }
    }
 
    private var formattedDate: String {
        booking.date.formatted(date: .abbreviated, time: .omitted)
    }
 
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(listing?.title ?? "Trip Unavailable")
                            .font(.headline)
                            .fontWeight(.bold)
                            .lineLimit(2)

                        if bookingStore.bookingIdsWithUnreadMessages.contains(booking.id) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text("Booked by \(explorer?.name ?? "Unknown Explorer")")
                        .font(.subheadline)
                        .foregroundColor(.appSecondaryText)
                }
 
                Spacer()
 
                Text(booking.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(20)
            }
 
            HStack(spacing: 16) {
                Label(formattedDate, systemImage: "calendar")
                Label(booking.guestSummary, systemImage: "person.2")
                Label("$\(Int(booking.totalPrice))", systemImage: "dollarsign.circle")
            }
            .font(.caption)
            .foregroundColor(.appSecondaryText)
 
            if booking.status == .pending {
                HStack(spacing: 12) {
                    Button {
                        Task { await bookingStore.declineBooking(bookingId: booking.id) }
                    } label: {
                        Text("Decline")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        Task { await bookingStore.confirmBooking(bookingId: booking.id) }
                    } label: {
                        Text("Confirm")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
 
#Preview {
    GuideBookingCardView(
        booking: Booking.mockBookings[0],
        listing: Listing.mockListings[0],
        explorer: .mockExplorer
    )
    .environmentObject(BookingStore())
    .padding()
    .background(Color(.systemGray6))
}
