import SwiftUI

// Drop this in anywhere an action needs a logged-in user — booking a trip,
// viewing your bookings, applying as a guide, etc — instead of letting
// the action silently fail when currentUser is nil.
struct LoginRequiredView: View {
    let message: String
    @State private var showLogin = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(.appSecondaryTextOnDark)

            Text("Log In Required")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.appTextOnDark)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.appSecondaryTextOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showLogin = true
            } label: {
                Text("Log In")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

#Preview {
    LoginRequiredView(message: "Log in to book this trip.")
        .environmentObject(UserSession())
}
