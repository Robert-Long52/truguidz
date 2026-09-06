import Foundation

// Maps to the reviews table (see supabase/schema.sql). booking_id is
// unique on the table, so a booking can have at most one review -- the
// enforce_review_after_completion trigger additionally requires the
// booking be confirmed and its date already passed before an insert
// is allowed at all.
struct Review: Identifiable, Codable {
    let id: String
    let bookingId: String
    let listingId: String
    let explorerId: String
    var rating: Int
    var comment: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, rating, comment
        case bookingId = "booking_id"
        case listingId = "listing_id"
        case explorerId = "explorer_id"
        case createdAt = "created_at"
    }
}
