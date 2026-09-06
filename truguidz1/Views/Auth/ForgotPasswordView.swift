import SwiftUI
import Supabase

// First attempt at this redirected to a hosted HTML page (an Edge
// Function, then a Storage-hosted static file) -- both dead ends, because
// every *.supabase.co response claiming to be text/html gets silently
// rewritten to text/plain by the platform itself (confirmed: Storage's own
// object metadata said "text/html", the actual served response still said
// "text/plain" -- this is a deliberate, project-independent restriction on
// the shared supabase.co domain, not something fixable via headers or
// upload options). Real fix: a custom URL scheme (see Info.plist's
// CFBundleURLTypes and truguidz1App's .onOpenURL) that hands the recovery
// link straight to ResetPasswordView natively -- no hosted page needed at
// all.
private let passwordResetRedirectURL = URL(string: "truguidz://reset-password")!

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State var email: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if didSubmit {
                    confirmation
                } else {
                    form
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .colorScheme(.dark)
    }

    private var form: some View {
        VStack(spacing: 16) {
            Text("Enter the email on your account and we'll send you a link to reset your password.")
                .font(.subheadline)
                .foregroundColor(.appSecondaryTextOnDark)
                .multilineTextAlignment(.center)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

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
                    Text("Send Reset Link")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit || isSubmitting)
        }
    }

    private var confirmation: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 44))
                .foregroundColor(.appTextOnDark)

            Text("Check Your Email")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.appTextOnDark)

            Text("If an account exists for \(email), we've sent a link to reset your password.")
                .font(.subheadline)
                .foregroundColor(.appSecondaryTextOnDark)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await supabase.auth.resetPasswordForEmail(
                    email.trimmingCharacters(in: .whitespaces),
                    redirectTo: passwordResetRedirectURL
                )
                didSubmit = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ForgotPasswordView(email: "")
}
