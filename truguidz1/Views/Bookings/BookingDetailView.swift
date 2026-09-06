import SwiftUI
 
struct BookingDetailView: View {
    let booking: Booking
    let listing: Listing?
    let guide: User?
 
    @EnvironmentObject var bookingStore: BookingStore
    @EnvironmentObject var reviewStore: ReviewStore
    @EnvironmentObject var userSession: UserSession
    @State private var showCancelConfirm = false
    @State private var showChat = false
    @State private var showWriteReview = false
    @State private var alreadyReviewed = false

    // Reviews can only be left once the trip has actually happened -- see
    // enforce_review_after_completion in supabase/schema.sql, which is the
    // rule of record. This mirrors it client-side just to decide whether
    // to show the button; the trigger is what actually enforces it.
    private var isEligibleForReview: Bool {
        booking.status == .confirmed && booking.date < Date()
    }

    // Mirrors the "Only participants on a confirmed booking can message"
    // RLS policy (supabase/rls_policies.sql) -- stripePaymentIntentId is
    // set at *request* time (card authorized, not yet confirmed), so
    // gating on it instead of status would show a Message button that
    // fails to actually send anything until the guide confirms.
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
 
                // Guide info
                if let guide {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Guide")
                            .font(.headline)
 
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 46, height: 46)
                                Text(guide.name.prefix(1))
                                    .font(.headline)
                                    .foregroundColor(.appSecondaryText)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(guide.name)
                                    .fontWeight(.semibold)
                                if let years = guide.yearsExperience {
                                    Text("\(years) years experience")
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                }
                            }
                        }
                    }
 
                    Divider()
                }
 
                // Trip details
                VStack(alignment: .leading, spacing: 10) {
                    Text("Trip Details")
                        .font(.headline)
                    detailRow("Date", booking.date.formatted(date: .abbreviated, time: .omitted))
                    detailRow("Guests", "\(booking.numberOfGuests)")
                    detailRow(booking.stripePaymentIntentId != nil ? "Total Paid" : "Total (Due on Confirmation)", "$\(Int(booking.totalPrice))")
                    detailRow("Requested", booking.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
 
                Divider()
 
                // Actions
                VStack(spacing: 12) {
                    if isEligibleForReview && !alreadyReviewed {
                        Button {
                            showWriteReview = true
                        } label: {
                            Label("Leave a Review", systemImage: "star.fill")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if canMessage {
                        let messageLabel = Label("Message \(guide?.name.components(separatedBy: " ").first ?? "Guide")", systemImage: "message.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)

                        if isEligibleForReview && !alreadyReviewed {
                            Button { showChat = true } label: { messageLabel }
                                .buttonStyle(.bordered)
                        } else {
                            Button { showChat = true } label: { messageLabel }
                                .buttonStyle(.borderedProminent)
                        }
                    }

                    if booking.status == .pending || booking.status == .confirmed {
                        Button(role: .destructive) {
                            showCancelConfirm = true
                        } label: {
                            Text("Cancel Booking")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
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
        .task(id: booking.id) {
            guard isEligibleForReview else { return }
            alreadyReviewed = await reviewStore.hasReview(forBooking: booking.id)
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView(booking: booking, listing: listing)
        }
        .confirmationDialog(
            "Cancel this booking?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel Booking", role: .destructive) {
                Task {
                    // A confirmed booking has actually been charged --
                    // cancelling it needs to go through stripe-refund-payment
                    // to actually issue the refund, not just flip the status.
                    // A pending booking was only ever authorized, so a plain
                    // status update (no money involved) is correct there.
                    if booking.status == .confirmed {
                        await bookingStore.refundAndCancelBooking(bookingId: booking.id)
                    } else {
                        await bookingStore.updateStatus(bookingId: booking.id, to: .cancelled)
                    }
                }
            }
            Button("Keep Booking", role: .cancel) {}
        } message: {
            if booking.status == .confirmed {
                Text("This trip has already been paid for. Cancelling will refund you in full.")
            } else {
                Text("Your card hasn't been charged yet, so there's nothing to refund.")
            }
        }
        .navigationDestination(isPresented: $showChat) {
            if let currentUserId = userSession.currentUser?.id {
                ChatView(booking: booking, currentUserId: currentUserId, otherPartyName: guide?.name ?? "Guide")
            }
        }
        .alert(
            "Couldn't Cancel Booking",
            isPresented: Binding(
                get: { bookingStore.errorMessage != nil },
                set: { if !$0 { bookingStore.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(bookingStore.errorMessage ?? "")
        }
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
        BookingDetailView(
            booking: Booking.mockBookings[0],
            listing: Listing.mockListings[0],
            guide: .mockGuide
        )
    }
    .environmentObject(BookingStore())
    .environmentObject(ReviewStore())
    .environmentObject(UserSession.previewExplorer)
}
