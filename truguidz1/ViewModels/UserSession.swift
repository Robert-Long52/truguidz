import Foundation
import SwiftUI
import Supabase

// Holds the logged-in user's state for the whole app.
// Injected once at the root (see truguidz1App.swift) and read anywhere
// via @EnvironmentObject, instead of passing a User down through every view.
@MainActor
final class UserSession: ObservableObject {

    // Published means any view reading this automatically redraws when it changes
    @Published var currentUser: User?
    @Published var isLoading = true

    // Set when the auth stream reports a PASSWORD_RECOVERY event -- i.e.
    // someone opened the app via a password-reset email link, not a normal
    // login. Supabase's SDK treats this as a real signed-in session (it has
    // to, in order to let update(user:) actually change the password), so
    // without this flag the app would otherwise just silently log them
    // into their existing account instead of prompting for a new password.
    // The root view checks this before showing MainTabView.
    @Published var isInPasswordRecovery = false

    @Published var errorMessage: String?

    init(currentUser: User? = nil) {
        self.currentUser = currentUser
        if currentUser == nil {
            listenForAuthChanges()
        } else {
            isLoading = false
        }
    }

    // Convenience passthroughs so views don't need to unwrap currentUser everywhere
    var isLoggedIn: Bool {
        currentUser != nil
    }

    var isVerifiedGuide: Bool {
        currentUser?.isVerifiedGuide ?? false
    }

    // Fires once immediately with whatever session Supabase already has
    // stored on-device (so a login survives an app relaunch), then again
    // every time someone signs in, signs out, or their token refreshes.
    // This is the one place that decides "who's logged in" for the app.
    private func listenForAuthChanges() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                    if let session {
                        await loadProfile(userId: session.user.id)
                    }
                case .signedOut, .userDeleted:
                    currentUser = nil
                case .passwordRecovery:
                    // Fires right after the .signedIn case above for the
                    // same event (the SDK emits both for a recovery link),
                    // so currentUser is already populated by the time this
                    // runs -- this just adds the "show the reset screen
                    // instead of the app" flag on top.
                    isInPasswordRecovery = true
                default:
                    break
                }
                isLoading = false
            }
        }
    }

    private func loadProfile(userId: UUID) async {
        do {
            currentUser = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
        } catch {
            print("Failed to load profile for \(userId): \(error)")
        }
    }

    func logOut() {
        // Update locally right away so the UI responds instantly, then
        // actually revoke the session server-side in the background.
        currentUser = nil
        Task {
            try? await supabase.auth.signOut()
        }
    }

    // Required by App Store Review Guideline 5.1.1(v): any app that
    // supports account creation must also let a user delete their account
    // entirely within the app, not just via an emailed request. Unlike
    // logOut, this has to wait for the server call to actually finish
    // before clearing currentUser -- the caller needs to know whether it
    // really succeeded before treating the account as gone.
    func deleteAccount() async -> Bool {
        errorMessage = nil
        do {
            try await supabase.functions.invoke("delete-account")
            currentUser = nil
            try? await supabase.auth.signOut()
            return true
        } catch {
            errorMessage = "Could not delete your account: \(Self.serverErrorMessage(from: error))"
            return false
        }
    }

    private static func serverErrorMessage(from error: Error) -> String {
        if case let FunctionsError.httpError(_, data) = error,
           let body = try? JSONDecoder().decode([String: String].self, from: data),
           let message = body["error"] {
            return message
        }
        return error.localizedDescription
    }
}

// Preview/testing helpers — swap these in during development,
// same idea as Listing.mockListings and User.mockGuide
extension UserSession {
    static var previewExplorer: UserSession {
        UserSession(currentUser: .mockExplorer)
    }

    static var previewApprovedGuide: UserSession {
        UserSession(currentUser: .mockGuide)
    }

    static var previewPendingGuide: UserSession {
        UserSession(currentUser: .mockPendingGuide)
    }
}
