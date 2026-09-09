//
//  truguidz1App.swift
//  truguidz1
//
//  Created by Robert Long on 8/2/26.
//
 
import SwiftUI
import UIKit
import Supabase

@main
struct truguidz1App: App {
    // Needed for one thing only: didRegisterForRemoteNotificationsWithDeviceToken
    // is a UIApplicationDelegate callback, not something SwiftUI's App
    // protocol exposes directly.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Created once for the lifetime of the app, then handed down
    // to every view via .environmentObject below.
    // Starts with no user and lets UserSession's Supabase auth listener
    // populate currentUser -- either from a restored on-device session or
    // once someone logs in / signs up via LoginView.
    @StateObject private var userSession = UserSession()
    @StateObject private var bookingStore = BookingStore()
    @StateObject private var listingStore = ListingStore()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var reviewStore = ReviewStore()

    init() {
        StripeConfig.configure()
        Self.configureTabBarAppearance()
    }

    // SwiftUI's .toolbarBackground(for: .tabBar) turned out unreliable on
    // tabs with short, non-scrolling content (Bookings, the "not a guide
    // yet" Guidz state) -- the bar kept showing the page's dark green
    // background bleeding through, with unselected icons nearly invisible.
    // Configuring UITabBar's appearance proxy directly is the traditional,
    // version-agnostic fix: it sets the bar's look once, globally, with no
    // dependency on scroll state or per-screen toolbar modifiers.
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appCard)

        let unselected = UIColor(Color.appSecondaryText)
        appearance.stackedLayoutAppearance.normal.iconColor = unselected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // The whole visual theme (tab bar, cards, backgrounds) is
                // built from fixed, non-adaptive colors -- Dark Mode was
                // never actually designed for. Without this, only the
                // system's own semantic colors (default Text, which is
                // unstyled almost everywhere) still respond to Dark Mode,
                // flipping to white on top of the app's light parchment
                // cards that never change, making that text disappear.
                // Locking the whole app to Light matches every other color
                // in the app and fixes that mismatch at the root instead of
                // hunting down every unstyled Text.
                .preferredColorScheme(.light)
                .environmentObject(userSession)
                .environmentObject(bookingStore)
                .environmentObject(listingStore)
                .environmentObject(profileStore)
                .environmentObject(reviewStore)
        }
    }
}

// Push Notifications capability still needs to be added once in Xcode
// (Signing & Capabilities -> + Capability -> Push Notifications, needs the
// Apple Developer account signed in) -- that's what actually registers the
// entitlement with Apple and generates the paired provisioning profile;
// nothing in source alone can do that part.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.uploadToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
}

// Split out from the App itself because handling a deep link that can fail
// needs somewhere to hold state (@State/.alert only work on a View, not
// directly on an App/Scene) -- `supabase.auth.handle(url)` alone swallows
// every error into a debug log line nobody sees, which is exactly why the
// password-reset link silently doing nothing was so hard to diagnose the
// first time around. Calling session(from:) directly here instead means a
// bad/expired/already-used recovery link surfaces a real, visible error.
private struct RootView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var deepLinkError: String?

    var body: some View {
        Group {
            // A password-reset email link lands here as a real signed-in
            // session (see UserSession's .passwordRecovery handling) --
            // this takes priority over currentUser so that session gets
            // used to set a new password, not to just silently open the
            // app as if it were a normal login.
            if userSession.isInPasswordRecovery {
                ResetPasswordView()
            } else {
                MainTabView()
            }
        }
        .onOpenURL { url in
            Task {
                do {
                    try await supabase.auth.session(from: url)
                } catch {
                    deepLinkError = error.localizedDescription
                }
            }
        }
        .alert(
            "Couldn't Open Link",
            isPresented: Binding(get: { deepLinkError != nil }, set: { if !$0 { deepLinkError = nil } }),
            presenting: deepLinkError
        ) { _ in
            Button("OK") { deepLinkError = nil }
        } message: { message in
            Text(message)
        }
    }
}
