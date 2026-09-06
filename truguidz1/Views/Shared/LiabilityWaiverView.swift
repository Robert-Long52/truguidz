import SwiftUI
import Supabase

// Gates booking a trip (explorer) and applying to guide (guide) on
// accepting a liability waiver / ToS -- these are real physical activities
// (hunting, trail riding, etc.), so this exists for real liability
// protection, not just a formality.
//
// The text below is a fuller draft (v2), still clearly marked as
// unreviewed. Real legal language needs to come from a lawyer before this
// app handles real bookings -- swap placeholderWaiverText for the real
// thing and bump currentWaiverVersion so everyone (even people who
// already accepted an earlier version) is required to re-accept.
struct LiabilityWaiverView: View {
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) private var dismiss
    var onAccepted: () -> Void = {}

    static let currentWaiverVersion = "v2-draft"

    @State private var hasRead = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Placeholder legal text", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(8)

                        Text(Self.placeholderWaiverText)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                }
                .background(Color.appCard)

                VStack(spacing: 12) {
                    Toggle(isOn: $hasRead) {
                        Text("I have read and agree to the Liability Waiver and Terms of Service.")
                            .font(.subheadline)
                            .foregroundColor(.appTextOnDark)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        acceptWaiver()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("I Agree & Continue")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasRead || isSaving)
                }
                .padding()
                .background(Color.appBackground)
            }
            .navigationTitle("Liability Waiver")
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
    }

    private func acceptWaiver() {
        guard let userId = userSession.currentUser?.id else { return }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                let acceptedAt = ISO8601DateFormatter().string(from: Date())
                try await supabase
                    .from("profiles")
                    .update(["waiver_accepted_at": acceptedAt, "waiver_version": Self.currentWaiverVersion])
                    .eq("id", value: userId)
                    .execute()

                if var user = userSession.currentUser {
                    user.waiverAcceptedAt = Date()
                    user.waiverVersion = Self.currentWaiverVersion
                    userSession.currentUser = user
                }

                isSaving = false
                onAccepted()
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private static let placeholderWaiverText = """
    [DRAFT -- not yet reviewed by a lawyer. Do not rely on this text for actual legal protection.]

    Assumption of Risk, Release, and Waiver of Liability

    This waiver applies to trips booked or offered through TruGuidz, an app operated by Robert Long (the "Service Provider") that connects independent guides ("Guides") with individuals seeking guided outdoor trips ("Explorers"). Guides are independent third parties -- they are not employees, agents, or representatives of the Service Provider, and the Service Provider does not supervise or control how a Guide conducts a trip.

    Inherent Risks

    You acknowledge that hunting, fishing, hiking, and trail-riding activities carry inherent risks that cannot be eliminated regardless of the care taken, including but not limited to:

    - Injury, illness, or death arising from firearm or archery use, falls, drowning, animal encounters, exposure to weather, or remote/rugged terrain
    - Risks associated with being in a remote location without immediate access to emergency medical care
    - The unpredictable behavior of wildlife, watercraft, trail animals, and other participants
    - Risks arising from a Guide's own decisions, equipment, or conduct during a trip

    Assumption of Risk

    By accepting this waiver, you voluntarily assume all risks of participating in a trip booked through TruGuidz, known or unknown, whether arising from the nature of the activity, the conduct of a Guide, the conduct of other participants, or your own actions.

    Release and Covenant Not to Sue

    To the fullest extent permitted by law, you release, discharge, and agree not to sue the Service Provider and the Guide leading your trip, along with their respective affiliates, officers, employees, and agents, for any injury, loss, illness, or damage arising from your participation in a trip booked through TruGuidz, except where caused by gross negligence, recklessness, or willful misconduct.

    You acknowledge that the Service Provider is a booking platform, not the provider of the guided trip itself, and that any claim related to how a trip was actually conducted is a matter between you and the Guide, not the Service Provider, except as described above.

    Your Responsibilities

    You represent that you are physically able to participate in the trip you are booking, that you will follow your Guide's safety instructions, and that you will comply with all applicable laws, including any hunting or fishing license requirements for your trip and jurisdiction. If you are booking a hunting trip, you represent that you hold any license required by law to participate, or will obtain one before the trip.

    Indemnification

    You agree to indemnify and hold harmless the Service Provider and your Guide from claims, damages, or expenses (including reasonable legal fees) arising from your own actions, negligence, or violation of applicable law during a trip.

    Minors

    If the Explorer participating in the trip is under the legal age to enter into this waiver in their jurisdiction, a parent or legal guardian must review and accept this waiver on the minor's behalf, and by doing so accepts these terms individually and on behalf of the minor.

    Severability

    If any part of this waiver is found unenforceable, the remainder will continue to apply to the fullest extent permitted by law.

    This is a draft, not a substitute for a real, lawyer-drafted waiver. Do not rely on this text for actual legal protection until it has been reviewed.
    """
}

#Preview {
    LiabilityWaiverView()
        .environmentObject(UserSession.previewExplorer)
}
