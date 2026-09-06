import SwiftUI

struct HelpCenterView: View {
    private struct FAQ: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }

    private let faqs: [FAQ] = [
        FAQ(
            question: "How does payment work?",
            answer: "Your card is authorized when you request a booking, but you're only actually charged once the guide confirms. If they decline, the authorization is released and you're never charged."
        ),
        FAQ(
            question: "How do I become a guide?",
            answer: "Go to the Guidz tab and tap \"Apply to Become a Guide.\" You'll fill out some basic info and upload a photo ID for verification -- we manually review every application before approving it."
        ),
        FAQ(
            question: "Can I cancel a booking?",
            answer: "Yes, from the booking's detail page in the Bookings tab. Cancelling a confirmed (already-paid) booking automatically refunds you in full."
        ),
        FAQ(
            question: "How do guides get paid?",
            answer: "Guides connect a Stripe account from their Guide Dashboard. Once a booking is confirmed and paid, funds go directly to the guide's account, minus TruGuidz's platform fee."
        ),
    ]

    var body: some View {
        List {
            Section {
                ForEach(faqs) { faq in
                    DisclosureGroup(faq.question) {
                        Text(faq.answer)
                            .font(.subheadline)
                            .foregroundColor(.appSecondaryText)
                            .padding(.top, 4)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
            } header: {
                Text.darkSectionLabel("Frequently Asked Questions")
            }

            Section {
                Link(destination: URL(string: "mailto:support@truguidz.com")!) {
                    Label("Email Support", systemImage: "envelope.fill")
                }
            } header: {
                Text.darkSectionLabel("Still need help?")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        HelpCenterView()
    }
}
