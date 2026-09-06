import SwiftUI

struct BookingCardView: View {
    let booking: Booking
    let listing: Listing?   // Looked up by listingId; optional in case data's missing
    var hasUnreadMessages: Bool = false

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
        HStack(alignment: .top, spacing: 16) {

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(listing?.title ?? "Trip Unavailable")
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)

                    if hasUnreadMessages {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(.appSecondaryText)
                    Text(formattedDate)
                }
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)

                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .foregroundColor(.appSecondaryText)
                    Text("\(booking.numberOfGuests) guest\(booking.numberOfGuests == 1 ? "" : "s")")
                }
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)

                Spacer()

                HStack {
                    // Status pill
                    Text(booking.status.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15))
                        .foregroundColor(statusColor)
                        .cornerRadius(20)

                    Spacer()

                    Text("$\(Int(booking.totalPrice))")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((listing?.category.color ?? .gray).opacity(0.25))
                    .frame(width: 90, height: 90)

                Image(systemName: listing?.category.icon ?? "mappin.and.ellipse")
                    .font(.title)
                    .foregroundColor(listing?.category.color ?? .appSecondaryText)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    BookingCardView(
        booking: Booking.mockBookings[0],
        listing: Listing.mockListings[0]
    )
    .padding()
    .background(Color(.systemGray6))
}
