import SwiftUI
import Supabase

private struct ProfileUpdate: Encodable {
    let name: String
    let phoneNumber: String
    let bio: String?
    let yearsExperience: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case phoneNumber = "phone_number"
        case bio
        case yearsExperience = "years_experience"
    }
}

// Edits the fields on the user's own profiles row that aren't locked down
// by the profiles_protect_verification trigger (role/verification_status
// are off-limits to a plain client update -- see
// add_verification_fee_and_checkr.sql -- everything here is fine for a
// normal "Users can update their own profile" RLS write).
struct EditProfileView: View {
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var phoneNumber: String
    @State private var bio: String
    @State private var yearsExperience: Int

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let isGuide: Bool

    init(user: User) {
        _name = State(initialValue: user.name)
        _phoneNumber = State(initialValue: user.phoneNumber ?? "")
        _bio = State(initialValue: user.bio ?? "")
        _yearsExperience = State(initialValue: user.yearsExperience ?? 0)
        isGuide = user.role == .guide
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Full Name", text: $name)
            } header: {
                Text.darkSectionLabel("Name")
            }

            Section {
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
            } header: {
                Text.darkSectionLabel("Contact")
            }

            if isGuide {
                Section {
                    TextEditor(text: $bio)
                        .frame(height: 120)
                    Stepper(value: $yearsExperience, in: 0...50) {
                        Text("\(yearsExperience) year\(yearsExperience == 1 ? "" : "s") guiding")
                    }
                } header: {
                    Text.darkSectionLabel("Guide Info")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Changes")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave || isSaving)
                .listRowInsets(EdgeInsets())
                .padding()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func save() {
        guard let userId = userSession.currentUser?.id else { return }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                let update = ProfileUpdate(
                    name: name,
                    phoneNumber: phoneNumber,
                    bio: isGuide ? bio : nil,
                    yearsExperience: isGuide ? yearsExperience : nil
                )
                try await supabase
                    .from("profiles")
                    .update(update)
                    .eq("id", value: userId)
                    .execute()

                if var user = userSession.currentUser {
                    user.name = name
                    user.phoneNumber = phoneNumber
                    if isGuide {
                        user.bio = bio
                        user.yearsExperience = yearsExperience
                    }
                    userSession.currentUser = user
                }

                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView(user: .mockGuide)
    }
    .environmentObject(UserSession.previewApprovedGuide)
}
