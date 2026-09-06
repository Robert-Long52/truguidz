import SwiftUI
import Supabase

struct LoginView: View {
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) private var dismiss

    private enum Mode {
        case logIn, signUp
    }

    @State private var mode: Mode = .logIn
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var confirmationMessage: String?
    @State private var showForgotPassword = false

    private var canSubmit: Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty, !password.isEmpty else {
            return false
        }
        if mode == .signUp {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        ZBrandIcon(lineWidth: 4, color: .accentColor)
                            .frame(width: 56, height: 56)
                        Text("TruGuidz")
                            .font(.title)
                            .fontWeight(.black)
                            .foregroundColor(.appTextOnDark)
                        Text("Log in to book trips or manage your guide account.")
                            .font(.subheadline)
                            .foregroundColor(.appSecondaryTextOnDark)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    Picker("Mode", selection: $mode) {
                        Text("Log In").tag(Mode.logIn)
                        Text("Sign Up").tag(Mode.signUp)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        if mode == .signUp {
                            TextField("Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.words)
                        }

                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)

                        if mode == .logIn {
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        if let confirmationMessage {
                            Text(confirmationMessage)
                                .font(.caption)
                                .foregroundColor(.appSecondaryTextOnDark)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            submit()
                        } label: {
                            if isSubmitting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(mode == .signUp ? "Create Account" : "Log In")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSubmit || isSubmitting)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(email: email)
            }
        }
        // This whole screen sits directly on the dark background with no
        // light "card" sections (unlike most other screens), so it's safe
        // to force dark-mode rendering here specifically -- the segmented
        // Picker and the submit button's disabled-state dimming are both
        // system-styled and were using light-mode colors tuned for a white
        // background, which is why they were washing out against the green.
        .colorScheme(.dark)
    }

    private func submit() {
        errorMessage = nil
        confirmationMessage = nil
        isSubmitting = true

        Task {
            defer { isSubmitting = false }
            do {
                switch mode {
                case .signUp:
                    let response = try await supabase.auth.signUp(
                        email: email,
                        password: password,
                        data: ["name": .string(name)]
                    )
                    if response.session != nil {
                        // Email confirmation is off (or already satisfied) — signed in immediately.
                        dismiss()
                    } else {
                        // Email confirmation is on: no session yet until they click the link.
                        confirmationMessage = "Check your email to confirm your account, then log in."
                        mode = .logIn
                    }
                case .logIn:
                    try await supabase.auth.signIn(email: email, password: password)
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(UserSession())
}
