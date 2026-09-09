import Foundation
import UIKit
import UserNotifications
import Supabase

// Two halves of getting push notifications working, kept deliberately
// separate from *sending* one: this only ever gets a device permission +
// token and hands it to Supabase. The actual "notify a guide when they get
// a booking request" logic lives server-side (a future Edge Function
// triggered off inserts/updates to bookings/messages), which needs Apple's
// own APNs auth key -- something only available from the Apple Developer
// account, not something this file can provide.
enum PushNotificationService {
    // Called once a user is actually logged in (see UserSession.loadProfile)
    // -- requesting authorization for a signed-out visitor makes no sense
    // (there's no account yet to attach a token to), and repeating this
    // call on every session restore is harmless: iOS only ever shows the
    // system prompt once per install and just returns the existing
    // decision on every call after that.
    static func requestAuthorizationAndRegister() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else { return }
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                print("Push notification authorization failed: \(error)")
            }
        }
    }

    // Called from AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken
    // once APNs actually hands back a token -- reads the current session
    // directly off the shared `supabase` client rather than needing
    // UserSession threaded into the AppDelegate, since this can fire
    // independently of any particular view's lifecycle.
    static func uploadToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        Task {
            do {
                let session = try await supabase.auth.session
                try await supabase
                    .from("profiles")
                    .update([
                        "device_push_token": token,
                        "device_push_platform": "ios",
                    ])
                    .eq("id", value: session.user.id)
                    .execute()
            } catch {
                print("Failed to upload push token: \(error)")
            }
        }
    }
}
