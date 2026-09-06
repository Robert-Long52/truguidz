import SwiftUI
import Supabase

private struct StripeOnboardingResponse: Decodable {
    let url: String
}

struct GuidzDashboardView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var listingStore: ListingStore
    @EnvironmentObject var bookingStore: BookingStore
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.openURL) private var openURL

    @State private var showCreateListingSheet = false
    @State private var explorers: [String: User] = [:]
    @State private var isConnectingStripe = false
    @State private var stripeError: String?
    @State private var selectedBookingId: String?
    @State private var showMessagesInbox = false
    @State private var showNoMessagesInfo = false

    private var myListings: [Listing] {
        guard let guideId = userSession.currentUser?.id else { return [] }
        return listingStore.listings.filter { $0.guideId == guideId }
    }

    private var myBookings: [Booking] {
        guard let guideId = userSession.currentUser?.id else { return [] }
        return bookingStore.bookings
            .filter { $0.guideId == guideId }
            .sorted { $0.date < $1.date }
    }

    // "Incoming Bookings" is meant to be what actually needs the guide's
    // attention or is still ahead of them -- without this, the list only
    // ever grows as every booking a guide has ever had (including trips
    // that happened months ago, or requests that got cancelled) stays on
    // the dashboard forever. Anything that ages out of this is still
    // reachable via "View All Bookings" below.
    private var activeBookings: [Booking] {
        let today = Calendar.current.startOfDay(for: Date())
        return myBookings.filter { booking in
            switch booking.status {
            case .pending: return true
            case .confirmed, .completed: return booking.endDate >= today
            case .cancelled: return false
            }
        }
    }

    // Same eligibility rule as the explorer-facing icon on Explore --
    // messaging only unlocks once a booking is confirmed/completed (see
    // rls_policies.sql). This is the guide side of the exact same
    // conversation set MessagesInboxView(role: .explorer) surfaces for the
    // explorer who booked them.
    private var messageableBookings: [Booking] {
        myBookings.filter { $0.status == .confirmed || $0.status == .completed }
    }

    private var hasUnreadMessages: Bool {
        messageableBookings.contains { bookingStore.bookingIdsWithUnreadMessages.contains($0.id) }
    }

    private func handleMessagesTap() {
        if messageableBookings.isEmpty {
            showNoMessagesInfo = true
        } else {
            showMessagesInbox = true
        }
    }
 
    private func listing(for booking: Booking) -> Listing? {
        listingStore.listings.first { $0.id == booking.listingId }
    }
 
    private func explorer(for booking: Booking) -> User? {
        explorers[booking.explorerId]
    }

    private func booking(withId id: String) -> Booking? {
        myBookings.first { $0.id == id }
    }

    private func loadExplorers() async {
        let explorerIds = Set(myBookings.map(\.explorerId))
        for id in explorerIds where explorers[id] == nil {
            explorers[id] = await profileStore.profile(for: id)
        }
    }

    private var isStripeConnected: Bool {
        userSession.currentUser?.stripeChargesEnabled == true
    }

    private func connectStripe() {
        stripeError = nil
        isConnectingStripe = true
        Task {
            defer { isConnectingStripe = false }
            do {
                let response: StripeOnboardingResponse = try await supabase.functions.invoke("stripe-connect-onboarding")
                guard let url = URL(string: response.url) else {
                    stripeError = "Got an invalid link back — try again."
                    return
                }
                openURL(url)
            } catch let FunctionsError.httpError(code, data) {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                print("stripe-connect-onboarding \(code): \(body)")
                stripeError = "\(code): \(body)"
            } catch {
                stripeError = error.localizedDescription
            }
        }
    }
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
 
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back, \(userSession.currentUser?.name ?? "Guide")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appTextOnDark)
                            Text("Here's what's happening with your trips.")
                                .font(.subheadline)
                                .foregroundColor(.appSecondaryTextOnDark)
                        }

                        Spacer()

                        Button {
                            handleMessagesTap()
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bubble.right.fill")
                                    .font(.title3)
                                    .foregroundColor(.appTextOnDark)
                                    .padding(10)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Circle())

                                if hasUnreadMessages {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 11, height: 11)
                                        .overlay(Circle().stroke(Color.appBackground, lineWidth: 2))
                                        .offset(x: 3, y: -3)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Availability Calendar
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Availability")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.appTextOnDark)
                            .padding(.horizontal)

                        AvailabilityCalendarView(bookings: myBookings)
                            .padding(.horizontal)
                    }

                    // Incoming Bookings -- only what's still pending or
                    // upcoming; anything older lives in "View All Bookings"
                    // instead of piling up here forever.
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Incoming Bookings")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.appTextOnDark)
                            .padding(.horizontal)

                        if activeBookings.isEmpty {
                            emptyState(
                                icon: "calendar.badge.exclamationmark",
                                title: "No bookings yet",
                                message: "Bookings against your listings will show up here."
                            )
                        } else {
                            // Not a NavigationLink -- GuideBookingCardView has its
                            // own Confirm/Decline Buttons, and a Button nested
                            // inside a NavigationLink's label is a known SwiftUI
                            // trap (the outer link and inner button end up
                            // fighting over the same tap, so Confirm/Decline
                            // becomes unreliable). A tap gesture alongside real
                            // Buttons is unambiguous: tapping a Button fires the
                            // Button, tapping anywhere else on the card navigates.
                            VStack(spacing: 12) {
                                ForEach(activeBookings) { booking in
                                    GuideBookingCardView(
                                        booking: booking,
                                        listing: listing(for: booking),
                                        explorer: explorer(for: booking)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedBookingId = booking.id
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        if myBookings.count > activeBookings.count {
                            NavigationLink {
                                GuideAllBookingsView(
                                    bookings: myBookings.sorted { $0.date > $1.date },
                                    listing: listing(for:),
                                    explorer: explorer(for:),
                                    onSelect: { selectedBookingId = $0.id }
                                )
                            } label: {
                                Text("View All Bookings")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Your Listings
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your Listings")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.appTextOnDark)
                            Spacer()
                            Button {
                                showCreateListingSheet = true
                            } label: {
                                Label("New", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal)

                        if myListings.isEmpty {
                            emptyState(
                                icon: "mappin.slash",
                                title: "No listings yet",
                                message: "Publish your first trip to start getting bookings."
                            )
                        } else {
                            VStack(spacing: 12) {
                                ForEach(myListings) { listing in
                                    NavigationLink {
                                        EditListingView(listing: listing)
                                    } label: {
                                        GuideCardView(listing: listing)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    payoutsSection
                        .padding(.bottom, 20)
                }
            }
            .background(Color.appBackground)
            .refreshable {
                // Pull-to-refresh — otherwise a new booking request or a
                // guest's message only shows up after force-quitting and
                // reopening the app.
                await bookingStore.loadBookings()
                await listingStore.loadListings()
                if let userId = userSession.currentUser?.id {
                    await bookingStore.refreshUnreadMessageIndicators(currentUserId: userId)
                }
            }
            .brandedNavTitle("Guide Dashboard")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showCreateListingSheet) {
                CreateListingView()
            }
            .navigationDestination(item: $selectedBookingId) { bookingId in
                if let booking = booking(withId: bookingId) {
                    GuideBookingDetailView(
                        booking: booking,
                        listing: listing(for: booking),
                        explorer: explorer(for: booking)
                    )
                }
            }
            .sheet(isPresented: $showMessagesInbox) {
                MessagesInboxView(role: .guide)
            }
            .alert(
                "Couldn't Confirm Booking",
                isPresented: Binding(
                    get: { bookingStore.errorMessage != nil },
                    set: { if !$0 { bookingStore.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(bookingStore.errorMessage ?? "")
            }
            .alert("No Messages Yet", isPresented: $showNoMessagesInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Messaging opens once one of your bookings is confirmed.")
            }
        }
        .task(id: myBookings.map(\.id)) {
            await loadExplorers()
        }
        .onAppear {
            // Re-checks on every appearance, not just when the booking list
            // changes, so the unread dot clears right away after reading a
            // chat and coming back to the dashboard.
            guard let userId = userSession.currentUser?.id else { return }
            Task { await bookingStore.refreshUnreadMessageIndicators(currentUserId: userId) }
        }
    }
 
    private var payoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payouts")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.appTextOnDark)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                if isStripeConnected {
                    Label("Stripe account connected", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                } else {
                    Text("Connect a Stripe account to receive payouts from bookings.")
                        .font(.subheadline)
                        .foregroundColor(.appSecondaryText)

                    if let stripeError {
                        Text(stripeError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        connectStripe()
                    } label: {
                        if isConnectingStripe {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(userSession.currentUser?.stripeConnectId == nil ? "Connect with Stripe" : "Finish Stripe Setup")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConnectingStripe)
                }
            }
            .padding()
            .background(Color.appCard)
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.appSecondaryText)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(message)
                .font(.caption)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appCard)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
 
#Preview {
    GuidzDashboardView()
        .environmentObject(UserSession.previewApprovedGuide)
        .environmentObject(ListingStore())
        .environmentObject(BookingStore())
        .environmentObject(ProfileStore())
}
