import SwiftUI
 
struct MainTabView: View {
    // Pulled from the environment (injected in truguidz1App.swift) instead of
    // a local @State bool. Any view in the hierarchy can access the same
    // userSession by declaring its own @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var bookingStore: BookingStore
    @EnvironmentObject var listingStore: ListingStore

    var body: some View {
        TabView {
            // Tab 1: The Storefront Feed
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
 
            // Tab 2: The Gatekeeper View
            GuidzTabView()
                .tabItem {
                    ZBrandIcon.tabBarImage()
                    Text("Guidz")
                }
 
            // Tab 3: User Bookings Manager
            BookingsView()
                .tabItem {
                    Label("Bookings", systemImage: "calendar")
                }
 
            // Tab 4: App Admin Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        // Keyed on the signed-in user's id, not a bare `.task` -- MainTabView
        // is mounted once for the app's entire lifetime (RootView shows it
        // unconditionally, login happens inside its own tabs, not as a
        // separate top-level screen), so a bare `.task` only ever fires
        // once, tied to whatever session (or lack of one) happened to exist
        // at that exact moment. That's a real bug, not just a missed
        // optimization: it means switching accounts -- or even the auth
        // listener restoring a saved session slightly after this view's
        // first appearance -- never re-triggers a load for the account
        // that's actually signed in now, leaving bookingStore/listingStore
        // stuck on stale or empty data until the app is force-quit and
        // relaunched. Re-running whenever the user id changes (including
        // nil -> real user on a delayed session restore) fixes this at
        // the root.
        .task(id: userSession.currentUser?.id) {
            async let listings: () = listingStore.loadListings()
            async let bookings: () = bookingStore.loadBookings()
            _ = await (listings, bookings)
        }
    }
}
 
#Preview {
    MainTabView()
        .environmentObject(UserSession.previewApprovedGuide)
        .environmentObject(BookingStore())
        .environmentObject(ListingStore())
        .environmentObject(ProfileStore())
}
