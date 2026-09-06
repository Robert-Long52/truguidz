import SwiftUI

struct WriteReviewView: View {
    let booking: Booking
    let listing: Listing?

    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var reviewStore: ReviewStore
    @Environment(\.dismiss) private var dismiss

    @State private var rating = 0
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Group {
                if didSubmit {
                    confirmation
                } else {
                    form
                }
            }
            .navigationTitle(didSubmit ? "" : "Leave a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !didSubmit {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing?.title ?? "Your Trip")
                        .font(.headline)
                    if let listing {
                        Text(listing.locationName)
                            .font(.subheadline)
                            .foregroundColor(.appSecondaryText)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                HStack {
                    Spacer()
                    starPicker
                    Spacer()
                }
                .padding(.vertical, 8)
            } header: {
                Text.darkSectionLabel("How was your trip?")
            }

            Section {
                TextEditor(text: $comment)
                    .frame(minHeight: 120)
            } header: {
                Text.darkSectionLabel("Comments (optional)")
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
                    submit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Submit Review")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || rating == 0)
                .listRowInsets(EdgeInsets())
                .padding()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private var starPicker: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: 32))
                    .foregroundColor(star <= rating ? .yellow : .appSecondaryText)
                    .onTapGesture {
                        rating = star
                    }
            }
        }
    }

    private func submit() {
        guard let explorerId = userSession.currentUser?.id, rating > 0 else { return }
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                try await reviewStore.submitReview(
                    booking: booking,
                    explorerId: explorerId,
                    rating: rating,
                    comment: comment
                )
                isSubmitting = false
                didSubmit = true
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private var confirmation: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Review Submitted")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appTextOnDark)

            Text("Thanks for sharing your experience.")
                .font(.subheadline)
                .foregroundColor(.appSecondaryTextOnDark)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

#Preview {
    WriteReviewView(booking: Booking.mockBookings[0], listing: Listing.mockListings[0])
        .environmentObject(UserSession.previewExplorer)
        .environmentObject(ReviewStore())
}
