import SwiftUI
 
struct SettingsView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var showLogOutConfirm = false
    @State private var showLogin = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
 
    var body: some View {
        NavigationStack {
            List {
                // Profile header
                if let user = userSession.currentUser {
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 60, height: 60)
                                Text(user.name.prefix(1))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.appSecondaryText)
                            }
 
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondaryText)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                } else {
                    Section {
                        Button {
                            showLogin = true
                        } label: {
                            Label("Log In", systemImage: "person.crop.circle.badge.plus")
                                .fontWeight(.semibold)
                        }
                    }
                }
 
                // Account
                if let user = userSession.currentUser {
                    Section {
                        NavigationLink {
                            EditProfileView(user: user)
                        } label: {
                            Label("Edit Profile", systemImage: "person.crop.circle")
                        }

                        NavigationLink {
                            PaymentMethodsView()
                        } label: {
                            Label("Payment Methods", systemImage: "creditcard")
                        }

                        NavigationLink {
                            NotificationSettingsView(user: user)
                        } label: {
                            Label("Notifications", systemImage: "bell")
                        }
                    } header: {
                        Text.darkSectionLabel("Account")
                    }
                }

                // Support & legal
                Section {
                    NavigationLink {
                        HelpCenterView()
                    } label: {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        LegalTextView.termsOfService
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text")
                    }

                    NavigationLink {
                        LegalTextView.privacyPolicy
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                } header: {
                    Text.darkSectionLabel("Support")
                }

                // Log out
                if userSession.currentUser != nil {
                    Section {
                        Button(role: .destructive) {
                            showLogOutConfirm = true
                        } label: {
                            Text("Log Out")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }

                    // Required by App Store Review Guideline 5.1.1(v) --
                    // any app that supports account creation must also let
                    // a user delete their account entirely within the app,
                    // not just via an emailed request.
                    Section {
                        Button(role: .destructive) {
                            showDeleteAccountConfirm = true
                        } label: {
                            if isDeletingAccount {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text("Delete Account")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .disabled(isDeletingAccount)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .brandedNavTitle("Settings")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .confirmationDialog(
                "Are you sure you want to log out?",
                isPresented: $showLogOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) {
                    userSession.logOut()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteAccountConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    isDeletingAccount = true
                    Task {
                        _ = await userSession.deleteAccount()
                        isDeletingAccount = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your personal information and signs you out everywhere. Your booking history is kept in anonymized form, as required for guides' and explorers' records. This can't be undone.")
            }
            .alert(
                "Couldn't Delete Account",
                isPresented: Binding(
                    get: { userSession.errorMessage != nil },
                    set: { if !$0 { userSession.errorMessage = nil } }
                ),
                presenting: userSession.errorMessage
            ) { _ in
                Button("OK") { userSession.errorMessage = nil }
            } message: { message in
                Text(message)
            }
        }
    }
}
 
#Preview {
    SettingsView()
        .environmentObject(UserSession.previewExplorer)
}
