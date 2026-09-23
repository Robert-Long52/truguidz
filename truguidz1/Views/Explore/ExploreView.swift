import SwiftUI
 
struct ExploreView: View {
    @EnvironmentObject var listingStore: ListingStore
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var bookingStore: BookingStore

    @State private var selectedRegion: String? = nil
    @State private var selectedType: ExperienceType? = nil
    @State private var selectedMinRating: Double? = nil
    @State private var searchText: String = ""
    @State private var sortOption: ListingSortOption = .recommended

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

    // Matches title, location, or category against the search text -- a
    // plain case/diacritic-insensitive substring check covers "bass",
    // "Catawissa", or "fishing" all landing on the same listing without
    // needing a real search index for a feed this size.
    private func matchesSearch(_ listing: Listing) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return listing.title.localizedStandardContains(trimmed) ||
            listing.locationName.localizedStandardContains(trimmed) ||
            listing.category.rawValue.localizedStandardContains(trimmed)
    }

    // Sorted by qualityScore (not raw rating) so the best-reviewed trips
    // lead the feed rather than whichever happens to have one perfect
    // review -- unless the explorer has explicitly asked for a price sort,
    // which overrides that ranking entirely rather than blending with it.
    private var filteredListings: [Listing] {
        let matches = listingStore.bookableListings
            .filter { listing in
                matchesSearch(listing) &&
                (selectedRegion == nil || listing.locationName == selectedRegion) &&
                (selectedType == nil || listing.category == selectedType) &&
                (selectedMinRating == nil || listing.qualityScore >= selectedMinRating!)
            }
        switch sortOption {
        case .recommended: return matches.sorted { $0.qualityScore > $1.qualityScore }
        case .priceLowToHigh: return matches.sorted { $0.pricePerPerson < $1.pricePerPerson }
        case .priceHighToLow: return matches.sorted { $0.pricePerPerson > $1.pricePerPerson }
        }
    }

    private var hasActiveFilters: Bool {
        selectedRegion != nil || selectedType != nil || selectedMinRating != nil || sortOption != .recommended
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

                    // Search -- filters the main feed below by title,
                    // location, or category. Deliberately doesn't touch the
                    // Featured Guides carousel above, same reasoning as the
                    // filter badges: that strip is curated promo, not part
                    // of the searchable/filterable results.
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.appSecondaryText)
                        TextField("Search trips, locations, categories", text: $searchText)
                            .foregroundColor(.primary)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.appSecondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.appCard)
                    .cornerRadius(14)
                    .padding(.horizontal)

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
                                    sortOption = .recommended
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

                                SortMenuBadge(selection: $sortOption)
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
                                sortOption = .recommended
                                searchText = ""
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
 
// Overrides the default qualityScore ranking entirely when set to either
// price direction -- an explorer who explicitly asked to sort by price
// wants that respected exactly, not blended with review quality.
enum ListingSortOption: Equatable {
    case recommended, priceLowToHigh, priceHighToLow

    var label: String {
        switch self {
        case .recommended: return "Sort"
        case .priceLowToHigh: return "Price: Low to High"
        case .priceHighToLow: return "Price: High to Low"
        }
    }
}

struct SortMenuBadge: View {
    @Binding var selection: ListingSortOption

    var body: some View {
        Menu {
            Button {
                selection = .recommended
            } label: {
                if selection == .recommended {
                    Label("Recommended", systemImage: "checkmark")
                } else {
                    Text("Recommended")
                }
            }
            Button {
                selection = .priceLowToHigh
            } label: {
                if selection == .priceLowToHigh {
                    Label("Price: Low to High", systemImage: "checkmark")
                } else {
                    Text("Price: Low to High")
                }
            }
            Button {
                selection = .priceHighToLow
            } label: {
                if selection == .priceHighToLow {
                    Label("Price: High to Low", systemImage: "checkmark")
                } else {
                    Text("Price: High to Low")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption2)
                Text(selection.label)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.footnote)
            .fontWeight(.semibold)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selection == .recommended ? Color.appCard : Color.accentColor)
            .foregroundColor(selection == .recommended ? .primary : .appTextOnDark)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
