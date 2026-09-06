import SwiftUI
 
// The "Guidz" tab's gatekeeper. Shows one of three states depending on
// the current user's verification status — same logic that lived inline
// in MainTabView before, pulled out here since the guide side is about
// to grow (dashboard, listings management, etc).
struct GuidzTabView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var showApplicationSheet = false
 
    var body: some View {
        Group {
            if userSession.currentUser == nil {
                LoginRequiredView(message: "Log in to become a guide or manage your listings.")
            } else if userSession.isVerifiedGuide {
                GuidzDashboardView()
            } else if userSession.currentUser?.verificationStatus == .pending {
                VStack(spacing: 20) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 44))
                        .foregroundColor(.appSecondaryTextOnDark)
                    Text("Verification In Progress")
                        .font(.title2).bold()
                        .foregroundColor(.appTextOnDark)
                    Text("We're reviewing your background check. This usually takes 2-3 business days.")
                        .foregroundColor(.appSecondaryTextOnDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
            } else if userSession.currentUser?.verificationStatus == .rejected {
                VStack(spacing: 20) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                    Text("Application Not Approved")
                        .font(.title2).bold()
                        .foregroundColor(.appTextOnDark)
                    Text("Your guide application wasn't approved at this time. Contact support if you think this is a mistake.")
                        .foregroundColor(.appSecondaryTextOnDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
            } else {
                VStack(spacing: 20) {
                    Text("Earn Money Guiding Trips")
                        .font(.title2).bold()
                        .foregroundColor(.appTextOnDark)
                    Text("List your hunting, fishing, or trail excursions on Truguidz.")
                        .foregroundColor(.appSecondaryTextOnDark)
                        .multilineTextAlignment(.center)

                    Button("Apply to Become a Guide") {
                        showApplicationSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
            }
        }
        .sheet(isPresented: $showApplicationSheet) {
            GuideApplicationView()
        }
    }
}
 
#Preview("Not Logged In") {
    GuidzTabView()
        .environmentObject(UserSession())
}
 
#Preview("Not Applied") {
    GuidzTabView()
        .environmentObject(UserSession.previewExplorer)
}
 
#Preview("Pending") {
    GuidzTabView()
        .environmentObject(UserSession(currentUser: .mockPendingGuide))
}
 
#Preview("Approved") {
    GuidzTabView()
        .environmentObject(UserSession.previewApprovedGuide)
        .environmentObject(ListingStore())
        .environmentObject(BookingStore())
}
