import SwiftUI

// TruGuidz doesn't save cards today -- every booking and guide
// verification fee goes through a fresh PaymentSheet, and nothing is
// stored beyond what Stripe itself keeps. This is an honest reflection
// of that, not a placeholder for a "saved cards" UI that doesn't exist --
// building real saved-card management would mean a Stripe Customer object
// per user + SetupIntents, a real feature worth its own pass if wanted.
struct PaymentMethodsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 44))
                .foregroundColor(.appSecondaryText)

            Text("No Saved Cards")
                .font(.title3)
                .fontWeight(.bold)

            Text("TruGuidz doesn't save payment methods yet. You'll enter your card details each time you book a trip or pay a guide verification fee -- nothing is stored beyond what Stripe itself keeps for that one payment.")
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appCard)
        .navigationTitle("Payment Methods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        PaymentMethodsView()
    }
}
