import SwiftUI
 
struct GuideBookingDetailView: View {
    let booking: Booking
    let listing: Listing?
    let explorer: User?
 
    @EnvironmentObject var bookingStore: BookingStore
    @EnvironmentObject var userSession: UserSession
    @State private var showChat = false

    // Mirrors the "Only participants on a confirmed booking can message"
    // RLS policy (supabase/rls_policies.sql) -- stripePaymentIntentId is
    // set at *request* time (card authorized, not yet confirmed), so
    // gating on it instead of status would show a Message button that
    // fails to actually send anything until this guide confirms it.
    private var canMessage: Bool {
        booking.status == .confirmed || booking.status == .completed
    }

    private var statusColor: Color {
        switch booking.status {
        case .pending: return .orange
        case .confirmed: return .green
        case .completed: return .blue
        case .cancelled: return .red
        }
    }
 
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
 
                // Trip summary
                VStack(alignment: .leading, spacing: 8) {
                    Text(listing?.title ?? "Trip Unavailable")
                        .font(.title2)
                        .fontWeight(.bold)
 
                    if let listing {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.appSecondaryText)
                            Text(listing.locationName)
                        }
                        .font(.subheadline)
                        .foregroundColor(.appSecondaryText)
                    }
 
                    Text(booking.status.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15))
                        .foregroundColor(statusColor)
                        .cornerRadius(20)
                }
 
                Divider()
 
                // Explorer info
                VStack(alignment: .leading, spacing: 10) {
                    Text("Booked By")
                        .font(.headline)
 
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 46, height: 46)
                            Text(explorer?.name.prefix(1) ?? "?")
                                .font(.headline)
                                .foregroundColor(.appSecondaryText)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(explorer?.name ?? "Unknown Explorer")
                                .fontWeight(.semibold)
                            if let phone = explorer?.phoneNumber {
                                Text(phone)
                                    .font(.caption)
                                    .foregroundColor(.appSecondaryText)
                            }
                            if let email = explorer?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.appSecondaryText)
                            }
                        }
                    }
                }
 
                Divider()
 
                // Trip details
                VStack(alignment: .leading, spacing: 10) {
                    Text("Trip Details")
                        .font(.headline)
                    detailRow("Date", booking.date.formatted(date: .abbreviated, time: .omitted))
                    detailRow("Guests", "\(booking.numberOfGuests)")
                    detailRow("Total", "$\(Int(booking.totalPrice))")
                    detailRow("Requested", booking.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
 
                Divider()
 
                // Actions
                VStack(spacing: 12) {
                    if booking.status == .pending {
                        HStack(spacing: 12) {
                            Button(role: .destructive) {
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
                    }
 
                    if canMessage {
                        Button {
                            showChat = true
                        } label: {
                            Label("Message \(explorer?.name.components(separatedBy: " ").first ?? "Explorer")", systemImage: "message.fill")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
        }
        .background(Color.appCard)
        .navigationTitle("Booking Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appCard, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $showChat) {
            if let currentUserId = userSession.currentUser?.id {
                ChatView(booking: booking, currentUserId: currentUserId, otherPartyName: explorer?.name ?? "Explorer")
            }
        }
        // Confirm/decline failures (e.g. the booking-conflict rejection)
        // are surfaced one level up, on GuidzDashboardView's NavigationStack
        // root -- not here too, since both this view and the dashboard
        // watch the same shared bookingStore.errorMessage, and having two
        // .alert modifiers both live at once (this view pushed on top of
        // that one) risks both trying to present simultaneously.
    }
 
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.appSecondaryText)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}
 
#Preview {
    NavigationStack {
        GuideBookingDetailView(
            booking: Booking.mockBookings[0],
            listing: Listing.mockListings[0],
            explorer: .mockExplorer
        )
    }
    .environmentObject(BookingStore())
    .environmentObject(UserSession.previewApprovedGuide)
}
