import Foundation
import SwiftUI
import Supabase

// Reviews aren't preloaded app-wide like bookings/listings -- they're
// fetched per-listing (for display) and checked per-booking (to gate the
// "Leave a Review" entry point), so a small on-demand cache is enough.
@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var reviewsByListing: [String: [Review]] = [:]
    @Published private(set) var reviewedBookingIds: Set<String> = []
    @Published var errorMessage: String?

    func loadReviews(forListing listingId: String) async {
        do {
            let reviews: [Review] = try await supabase
                .from("reviews")
                .select()
                .eq("listing_id", value: listingId)
                .order("created_at", ascending: false)
                .execute()
                .value
            reviewsByListing[listingId] = reviews
            for review in reviews {
                reviewedBookingIds.insert(review.bookingId)
            }
        } catch {
            print("Failed to load reviews for listing \(listingId): \(error)")
        }
    }

    // Booking ownership means at most one review can exist for a given
    // booking, so this doubles as "has this booking already been reviewed".
    func hasReview(forBooking bookingId: String) async -> Bool {
        if reviewedBookingIds.contains(bookingId) { return true }
        do {
            let reviews: [Review] = try await supabase
                .from("reviews")
                .select()
                .eq("booking_id", value: bookingId)
                .execute()
                .value
            if !reviews.isEmpty {
                reviewedBookingIds.insert(bookingId)
                return true
            }
            return false
        } catch {
            print("Failed to check review for booking \(bookingId): \(error)")
            return false
        }
    }

    @discardableResult
    func submitReview(
        booking: Booking,
        explorerId: String,
        rating: Int,
        comment: String?
    ) async throws -> Review {
        errorMessage = nil
        let newReview = Review(
            id: UUID().uuidString,
            bookingId: booking.id,
            listingId: booking.listingId,
            explorerId: explorerId,
            rating: rating,
            comment: (comment?.isEmpty ?? true) ? nil : comment,
            createdAt: Date()
        )

        do {
            let inserted: Review = try await supabase
                .from("reviews")
                .insert(newReview)
                .select()
                .single()
                .execute()
                .value

            reviewedBookingIds.insert(booking.id)
            reviewsByListing[booking.listingId, default: []].insert(inserted, at: 0)
            return inserted
        } catch {
            errorMessage = "Couldn't submit your review. Please try again."
            throw error
        }
    }
}
