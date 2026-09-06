import SwiftUI
 
struct ExploreView: View {
    @EnvironmentObject var listingStore: ListingStore
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var bookingStore: BookingStore

    @State private var selectedRegion: String? = nil
    @State private var selectedType: ExperienceType? = nil
    @State private var selectedMinRating: Double? = nil

    @State private var showMessagesInbox = false
    @State private var showNoMessagesInfo = false
    @State private var showLoginRequired = false

    // Selecting a listing to view (rather than wrapping each card in a
    // NavigationLink) sidesteps a real, confirmed bug: NavigationLink's
    // built-in tap activation inside a ScrollView stops tracking the
    // correct row once the view has been scrolled -- taps land accurately
    // before any scrolling, then drift by roughly however far you've
    // scrolled, opening a different listing than the one actually tapped.
    // Reproduced on-device on iOS 26.6 and in the iOS 26.5 simulator, with
    // both a LazyVStack and a plain VStack, so it isn't a laziness/caching
    // issue -- it's the ScrollView + NavigationLink combination itself.
    // Driving navigation from a plain tap gesture and a single
    // .navigationDestination(item:) avoids NavigationLink's activation
    // path entirely and has not reproduced the drift in the same testing.
    @State private var selectedListing: Listing?

    // Messaging only ever unlocks once a guide confirms a booking (see
    // "Only participants on a confirmed booking can message" in
    // rls_policies.sql) -- an explorer who's never gotten that far has
    // nothing to open yet, so the icon shows an explainer instead of an
    // empty inbox.
    private var messageableBookings: [Booking] {
        guard let userId = userSession.currentUser?.id else { return [] }
        return bookingStore.bookings.filter {
            $0.explorerId == userId && ($0.status == .confirmed || $0.status == .completed)
        }
    }

    private var hasUnreadMessages: Bool {
        messageableBookings.contains { bookingStore.bookingIdsWithUnreadMessages.contains($0.id) }
    }

    private func handleMessagesTap() {
        guard userSession.currentUser != nil else {
            showLoginRequired = true
            return
        }
        if messageableBookings.isEmpty {
            showNoMessagesInfo = true
        } else {
            showMessagesInbox = true
        }
    }

    // Regions are derived from whatever locations actually exist in the
    // data, rather than a hardcoded list, so this stays correct as guides
    // add listings in new areas.
    private var availableRegions: [String] {
        Array(Set(listingStore.bookableListings.map { $0.locationName })).sorted()
    }

    private static let ratingOptions: [Double] = [4.5, 4.0, 3.5]

    // Sorted by qualityScore (not raw rating) so the best-reviewed trips
    // lead the feed rather than whichever happens to have one perfect review.
    private var filteredListings: [Listing] {
        listingStore.bookableListings
            .filter { listing in
                (selectedRegion == nil || listing.locationName == selectedRegion) &&
                (selectedType == nil || listing.category == selectedType) &&
                (selectedMinRating == nil || listing.qualityScore >= selectedMinRating!)
            }
            .sorted { $0.qualityScore > $1.qualityScore }
    }

    private var hasActiveFilters: Bool {
        selectedRegion != nil || selectedType != nil || selectedMinRating != nil
    }
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
 
                    // 1. App Header Text Section
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TruGuidz")
                                .font(.largeTitle)
                                .fontWeight(.black)
                                .foregroundColor(.appTextOnDark)

                            Text("Find your next outdoor adventure")
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
 
                    // 2. Featured Guides — horizontal scrolling carousel,
                    // shown as soon as the screen opens per the sketch.
                    // Unfiltered on purpose — this is a curated promo strip,
                    // not part of the search/filter results below.
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Featured Guides")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.appTextOnDark)
                            .padding(.horizontal)
 
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(listingStore.bookableListings) { listing in
                                    FeaturedGuideCard(listing: listing)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedListing = listing }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
 
                    // 3. Find Your Experience — functional filters
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Find your experience")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appTextOnDark)
                            Spacer()
                            if hasActiveFilters {
                                Button("Clear") {
                                    selectedRegion = nil
                                    selectedType = nil
                                    selectedMinRating = nil
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
 
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                FilterMenuBadge(
                                    title: "Region",
                                    options: availableRegions,
                                    selection: $selectedRegion,
                                    label: { $0 }
                                )
 
                                FilterMenuBadge(
                                    title: "Type",
                                    options: ExperienceType.allCases,
                                    selection: $selectedType,
                                    label: { $0.rawValue.capitalized }
                                )
 
                                FilterMenuBadge(
                                    title: "Rating",
                                    options: Self.ratingOptions,
                                    selection: $selectedMinRating,
                                    label: { "\(String(format: "%.1f", $0))+ Stars" }
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
 
                    // 4. Main feed — larger, more immersive cards, filtered
                    if filteredListings.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "binoculars")
                                .font(.system(size: 36))
                                .foregroundColor(.appSecondaryTextOnDark)
                            Text("No trips match your filters")
                                .font(.headline)
                                .foregroundColor(.appTextOnDark)
                            Button("Clear Filters") {
                                selectedRegion = nil
                                selectedType = nil
                                selectedMinRating = nil
                            }
                            .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 20) {
                            ForEach(filteredListings) { listing in
                                ListingFeedCard(listing: listing)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedListing = listing }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color.appBackground)
            .refreshable {
                // Pull-to-refresh — otherwise a newly-published or
                // just-edited listing only shows up after force-quitting
                // and reopening the app.
                await listingStore.loadListings()
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedListing) { listing in
                ListingDetailView(listing: listing)
            }
        }
        .onAppear {
            // Re-checks every time this tab appears (not just once) so the
            // unread dot clears promptly after reading a conversation and
            // coming back -- same reasoning as BookingsView/
            // GuidzDashboardView's identical onAppear.
            guard let userId = userSession.currentUser?.id else { return }
            Task { await bookingStore.refreshUnreadMessageIndicators(currentUserId: userId) }
        }
        .sheet(isPresented: $showMessagesInbox) {
            MessagesInboxView(role: .explorer)
        }
        .sheet(isPresented: $showLoginRequired) {
            LoginRequiredView(message: "Log in to see your messages.")
        }
        .alert("No Messages Yet", isPresented: $showNoMessagesInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Messaging opens once you've booked a trip and a guide has confirmed it.")
        }
    }
}
 
// Generic filter badge — shows a Menu of options for the given type,
// with a checkmark on the current selection and an "All" option to clear it.
struct FilterMenuBadge<T: Hashable>: View {
    let title: String
    let options: [T]
    @Binding var selection: T?
    let label: (T) -> String
 
    var body: some View {
        Menu {
            Button {
                selection = nil
            } label: {
                if selection == nil {
                    Label("All", systemImage: "checkmark")
                } else {
                    Text("All")
                }
            }
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if selection == option {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.map(label) ?? title)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.footnote)
            .fontWeight(.semibold)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selection == nil ? Color.appCard : Color.accentColor)
            .foregroundColor(selection == nil ? .primary : .appTextOnDark)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}
 
#Preview {
    ExploreView()
        .environmentObject(ListingStore())
        .environmentObject(ProfileStore())
        .environmentObject(UserSession.previewExplorer)
        .environmentObject(BookingStore())
}
