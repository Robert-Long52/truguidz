import Foundation
 
// 1. Defines whether this account is browsing trips or offering them
enum UserRole: String, Codable {
    case explorer
    case guide
}
 
// 2. Tracks a guide's progress through the verification pipeline
//    (background check + identity verification before they can list trips)
enum VerificationStatus: String, Codable {
    case notStarted
    case pending
    case approved
    case rejected
}
 
// 3. Define the main blueprint for any account in the app
struct User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String
    var profileImageUrl: String?
    var role: UserRole

    // Guide-only fields — irrelevant/nil for explorers
    var verificationStatus: VerificationStatus
    var bio: String?
    var yearsExperience: Int?
    var stripeConnectId: String?        // Populated once Stripe Connect account is created
    var stripeChargesEnabled: Bool = false  // True once Connect onboarding is actually complete

    // Liability waiver / ToS -- nil means never accepted. A version bump
    // (see LiabilityWaiverView.currentWaiverVersion) invalidates a prior
    // acceptance without needing to touch old rows.
    var waiverAcceptedAt: Date? = nil
    var waiverVersion: String? = nil

    // No push (APNs) infrastructure exists yet -- these are just persisted
    // preferences, ready for whenever that gets wired up.
    var notifyBookingUpdates: Bool = true
    var notifyPromotions: Bool = false

    // Shared fields
    var phoneNumber: String?
    var createdAt: Date

    // Supabase's Postgrest client doesn't auto-convert JSON keys, so this
    // spells out the mapping to the profiles table's snake_case columns
    // explicitly (see supabase/schema.sql).
    enum CodingKeys: String, CodingKey {
        case id, name, email, role, bio
        case profileImageUrl = "profile_image_url"
        case verificationStatus = "verification_status"
        case yearsExperience = "years_experience"
        case stripeConnectId = "stripe_connect_id"
        case stripeChargesEnabled = "stripe_charges_enabled"
        case waiverAcceptedAt = "waiver_accepted_at"
        case waiverVersion = "waiver_version"
        case notifyBookingUpdates = "notify_booking_updates"
        case notifyPromotions = "notify_promotions"
        case phoneNumber = "phone_number"
        case createdAt = "created_at"
    }
 
    // Convenience flag — mirrors what MainTabView currently hardcodes as isVerifiedGuide
    var isVerifiedGuide: Bool {
        role == .guide && verificationStatus == .approved
    }

    // True once this account has accepted the CURRENT waiver version --
    // a version bump means everyone needs to re-accept, not just new users.
    var hasAcceptedCurrentWaiver: Bool {
        waiverAcceptedAt != nil && waiverVersion == LiabilityWaiverView.currentWaiverVersion
    }
}
 
// 4. Mock data for instant testing, same pattern as Listing.mockListings
extension User {
    static let mockExplorer = User(
        id: "user_1",
        name: "Sam Carter",
        email: "sam.carter@example.com",
        profileImageUrl: nil,
        role: .explorer,
        verificationStatus: .notStarted,
        bio: nil,
        yearsExperience: nil,
        stripeConnectId: nil,
        phoneNumber: "570-555-0142",
        createdAt: Date()
    )
 
    static let mockGuide = User(
        id: "guide_101",
        name: "Jake Miller",
        email: "jake.miller@example.com",
        profileImageUrl: nil,
        role: .guide,
        verificationStatus: .approved,
        bio: "10 years guiding smallmouth trips on the Susquehanna.",
        yearsExperience: 10,
        stripeConnectId: "acct_mock123",
        phoneNumber: "570-555-0198",
        createdAt: Date()
    )
 
    static let mockPendingGuide = User(
        id: "guide_102",
        name: "Alex Rivera",
        email: "alex.rivera@example.com",
        profileImageUrl: nil,
        role: .guide,
        verificationStatus: .pending,
        bio: "New to the app, background check submitted.",
        yearsExperience: 4,
        stripeConnectId: nil,
        phoneNumber: "570-555-0176",
        createdAt: Date()
    )
 
    static let mockGuideTwo = User(
        id: "guide_103",
        name: "Maria Chen",
        email: "maria.chen@example.com",
        profileImageUrl: nil,
        role: .guide,
        verificationStatus: .approved,
        bio: "PA Wilds native guiding hunting and hiking trips for 6 years.",
        yearsExperience: 6,
        stripeConnectId: "acct_mock456",
        phoneNumber: "570-555-0134",
        createdAt: Date()
    )
 
    // Convenience for looking up a guide by id, e.g. Listing.guideId,
    // the same way Listing.mockListings is used for listingId lookups
    static let mockGuides: [User] = [mockGuide, mockPendingGuide, mockGuideTwo]
 
    // Covers every mock account, guides and explorers alike — used when a
    // lookup could resolve to either, e.g. finding who made a booking
    static let mockUsers: [User] = [mockExplorer, mockGuide, mockPendingGuide, mockGuideTwo]
}
