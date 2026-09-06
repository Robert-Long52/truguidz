import SwiftUI
import Supabase

private struct NotificationPreferencesUpdate: Encodable {
    let notifyBookingUpdates: Bool
    let notifyPromotions: Bool

    enum CodingKeys: String, CodingKey {
        case notifyBookingUpdates = "notify_booking_updates"
        case notifyPromotions = "notify_promotions"
    }
}

// Preferences are real and persisted, but there's no push (APNs)
// infrastructure yet to actually deliver anything based on them --
// this is ready for whenever that gets built, not a fake settings screen.
struct NotificationSettingsView: View {
    @EnvironmentObject var userSession: UserSession

    @State private var notifyBookingUpdates: Bool
    @State private var notifyPromotions: Bool
    @State private var errorMessage: String?

    init(user: User) {
        _notifyBookingUpdates = State(initialValue: user.notifyBookingUpdates)
        _notifyPromotions = State(initialValue: user.notifyPromotions)
    }

    var body: some View {
        List {
            Section {
                Toggle("Booking Updates", isOn: $notifyBookingUpdates)
                Toggle("Promotions & News", isOn: $notifyPromotions)
            } footer: {
                Text.darkSectionLabel("Push notifications aren't turned on for TruGuidz yet -- these preferences are saved and will take effect once they are.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: notifyBookingUpdates) { _, _ in save() }
        .onChange(of: notifyPromotions) { _, _ in save() }
    }

    private func save() {
        guard let userId = userSession.currentUser?.id else { return }
        errorMessage = nil
        Task {
            do {
                try await supabase
                    .from("profiles")
                    .update(NotificationPreferencesUpdate(
                        notifyBookingUpdates: notifyBookingUpdates,
                        notifyPromotions: notifyPromotions
                    ))
                    .eq("id", value: userId)
                    .execute()

                if var user = userSession.currentUser {
                    user.notifyBookingUpdates = notifyBookingUpdates
                    user.notifyPromotions = notifyPromotions
                    userSession.currentUser = user
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView(user: .mockExplorer)
    }
    .environmentObject(UserSession.previewExplorer)
}
