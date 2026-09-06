import SwiftUI
import Supabase

// Shown instead of MainTabView whenever UserSession.isInPasswordRecovery
// is true -- i.e. someone opened the app via a password-reset email link
// rather than a normal login. Supabase's SDK already turned that link into
// a real, valid session by the time this appears (see UserSession's
// .passwordRecovery handling); this screen's only job is to make them set
// a new password before letting them into the app with that session.
struct ResetPasswordView: View {
    @EnvironmentObject var userSession: UserSession

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        password.count >= 8 && password == confirmPassword
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.rotation")
                .font(.system(size: 44))
                .foregroundColor(.appTextOnDark)

            Text("Set a New Password")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appTextOnDark)

            Text("Choose a new password for your TruGuidz account.")
                .font(.subheadline)
                .foregroundColor(.appSecondaryTextOnDark)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                SecureField("New Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)

                if !confirmPassword.isEmpty && password != confirmPassword {
                    Text("Passwords don't match.")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Update Password")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)

            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .colorScheme(.dark)
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await supabase.auth.update(user: UserAttributes(password: password))
                userSession.isInPasswordRecovery = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ResetPasswordView()
        .environmentObject(UserSession.previewExplorer)
}
