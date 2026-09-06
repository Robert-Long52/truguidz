import Foundation

// Maps to the messages table (see supabase/schema.sql). Only ever
// insertable once a booking has moved past 'pending' -- see the
// "Only participants on a confirmed booking can message" RLS policy in
// supabase/rls_policies.sql, which is the actual "no guide contact info
// before payment" enforcement, not just a UI gate.
struct Message: Identifiable, Codable, Equatable {
    let id: String
    let bookingId: String
    let senderId: String
    var body: String
    let createdAt: Date
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body
        case bookingId = "booking_id"
        case senderId = "sender_id"
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}
