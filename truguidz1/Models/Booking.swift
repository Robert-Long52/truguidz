import Foundation
 
// 1. Tracks where a booking currently stands
enum BookingStatus: String, Codable {
    case pending        // Requested, awaiting guide confirmation
    case confirmed      // Guide accepted, payment authorized
    case completed       // Trip has happened
    case cancelled
}
 
// 2. Define the main blueprint for a booking
struct Booking: Identifiable, Codable {
    let id: String
    let listingId: String           // Which trip was booked
    let explorerId: String          // Who booked it (User.id, role == .explorer)
    let guideId: String             // Who's running it (User.id, role == .guide)
 
    // Trip details captured at booking time
    var date: Date
    // Equals `date` for a single-day trip, or date + packageDayCount - 1
    // for a multi-day package -- snapshotted at booking time (same
    // reasoning as totalPrice/numberOfGuests) so this is what the
    // database's overlap-prevention constraint actually checks against
    // (see add_booking_conflict_prevention.sql).
    var endDate: Date
    var numberOfGuests: Int
    var totalPrice: Double

    // Status tracking
    var status: BookingStatus
    var createdAt: Date

    // Populated once Stripe payment is captured
    var stripePaymentIntentId: String?

    // Maps to the bookings table's snake_case columns (see supabase/schema.sql).
    enum CodingKeys: String, CodingKey {
        case id, date, status
        case listingId = "listing_id"
        case explorerId = "explorer_id"
        case guideId = "guide_id"
        case endDate = "end_date"
        case numberOfGuests = "number_of_guests"
        case totalPrice = "total_price"
        case createdAt = "created_at"
        case stripePaymentIntentId = "stripe_payment_intent_id"
    }
}
 
// 3. Mock data for instant testing, same pattern as Listing.mockListings
extension Booking {
    static let mockBookings: [Booking] = [
        Booking(
            id: "booking_1",
            listingId: "1",                 // Susquehanna Smallmouth Bass Excursion
            explorerId: "user_1",
            guideId: "guide_101",
            date: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            numberOfGuests: 2,
            totalPrice: 700.0,
            status: .confirmed,
            createdAt: Date(),
            stripePaymentIntentId: "pi_mock123"
        ),
        Booking(
            id: "booking_2",
            listingId: "2",                 // Guided Whitetail Deer Archery Hunt
            explorerId: "user_1",
            guideId: "guide_102",
            date: Calendar.current.date(byAdding: .day, value: 21, to: Date())!,
            endDate: Calendar.current.date(byAdding: .day, value: 21, to: Date())!,
            numberOfGuests: 1,
            totalPrice: 600.0,
            status: .pending,
            createdAt: Date(),
            stripePaymentIntentId: nil
        )
    ]
}
