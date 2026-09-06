import Foundation
 
// 1. Define the categories of trips available
enum ExperienceType: String, Codable, CaseIterable {
    case hunting
    case fishing
    case hiking
    case trailRiding = "Trail Riding"
}

// How a listing's pricePerPerson field is actually meant to be applied.
// Kept the underlying column name pricePerPerson/price_per_person as-is
// rather than renaming it -- this is now really just "price", but a
// rename would touch every already-tested display site and the live
// Stripe payment-intent Edge Function for no functional benefit.
enum PricingUnit: String, Codable, CaseIterable {
    case perPerson = "per_person"
    case perHour = "per_hour"
    case perDay = "per_day"
    case flatRate = "flat_rate"    // one price for the whole trip, regardless of group size ("pay by the guide")

    var label: String {
        switch self {
        case .perPerson: return "Per Person"
        case .perHour: return "Per Hour"
        case .perDay: return "Per Day"
        case .flatRate: return "Flat Rate"
        }
    }

    var priceSuffix: String {
        switch self {
        case .perPerson: return "/ person"
        case .perHour: return "/ hour"
        case .perDay: return "/ day"
        case .flatRate: return "flat rate"
        }
    }
}

// Which day(s) of the week a guide runs this trip.
enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 0, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { rawValue }
    var short: String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][rawValue]
    }
}

// How long this specific trip runs. One listing is always exactly one of
// these -- a guide who offers both a morning hunt and a full-day hunt
// makes two separate listings, not one listing with several selectable
// slots (that would need a slot picker at booking time, which nothing
// here actually implements).
enum TripLength: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case fullDay = "full_day"
    case multiDay = "multi_day"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .fullDay: return "Full Day"
        case .multiDay: return "Multi-Day Package"
        }
    }
}

// 2. Define the main blueprint for a trip listing
struct Listing: Identifiable, Codable, Hashable {
    let id: String                  // Uniquely identifies this exact card
    let guideId: String             // Keeps track of which guide owns it

    // Display Content
    var title: String
    var description: String
    var category: ExperienceType
    var imageUrls: [String]         // Names of the image files to show

    // Logistics & Pricing
    var pricePerPerson: Double
    var pricingUnit: PricingUnit = .perPerson
    var maxGroupSize: Int
    var locationName: String        // e.g., "Catawissa, PA"
    var latitude: Double
    var longitude: Double

    // How long the trip runs, and which days of the week the guide offers it.
    var tripLength: TripLength = .fullDay
    var packageDays: Int? = nil     // only meaningful when tripLength == .multiDay
    var availableDays: [Weekday] = Weekday.allCases

    // Social proof — shown as stars on the card
    var rating: Double              // 0.0 to 5.0
    var reviewCount: Int

    // false once the guide's account has been deleted (see
    // supabase/functions/delete-account) -- the listing itself can't be
    // hard-deleted (bookings reference it with ON DELETE NO ACTION), so
    // this is what actually hides it from Explore instead.
    var isActive: Bool = true

    // Maps to the listings table's snake_case columns (see supabase/schema.sql).
    enum CodingKeys: String, CodingKey {
        case id, title, description, category, latitude, longitude, rating
        case guideId = "guide_id"
        case imageUrls = "image_urls"
        case pricePerPerson = "price_per_person"
        case pricingUnit = "pricing_unit"
        case maxGroupSize = "max_group_size"
        case locationName = "location_name"
        case reviewCount = "review_count"
        case tripLength = "trip_length"
        case packageDays = "package_days"
        case availableDays = "available_days"
        case isActive = "is_active"
    }

    // Booking.date is always a single "start" date -- a multi-day package's
    // actual day count lives on the listing (it's fixed per package, not
    // chosen per booking), so the implied end date is just start + that.
    var packageDayCount: Int {
        tripLength == .multiDay ? max(packageDays ?? 1, 1) : 1
    }

    // The dollar amount a booking with this configuration should charge.
    // Only .perHour actually varies with hours; guests only matters for
    // .perPerson. .perDay scales by the package's day count for a multi-day
    // trip (a 3-day package at a day rate should charge 3x), but is a
    // single flat charge for anything else -- same as .flatRate.
    func totalPrice(numberOfGuests: Int, hours: Int? = nil) -> Double {
        switch pricingUnit {
        case .perPerson: return pricePerPerson * Double(numberOfGuests)
        case .perHour: return pricePerPerson * Double(hours ?? 1)
        case .perDay: return pricePerPerson * Double(packageDayCount)
        case .flatRate: return pricePerPerson
        }
    }
}
 
// 3. Blend rating with review volume so a single 5-star review can't
// outrank a guide with dozens of solidly-good ones -- a plain average
// treats "1 review, 5.0" and "80 reviews, 4.8" as if the first is better.
// Standard Bayesian-average fix: pull low-review-count listings toward a
// neutral prior until real review volume outweighs it.
extension Listing {
    private static let ratingPriorMean = 4.0
    private static let ratingPriorWeight = 10.0

    var qualityScore: Double {
        let n = Double(reviewCount)
        return (Listing.ratingPriorWeight * Listing.ratingPriorMean + n * rating) / (Listing.ratingPriorWeight + n)
    }
}

// 4. Create mock data right inside the file for instant testing
extension Listing {
    static let mockListings: [Listing] = [
        Listing(
            id: "1",
            guideId: "guide_101",
            title: "Susquehanna Smallmouth Bass Excursion",
            description: "Spend a full day tracking world-class smallmouth bass down the river flats. All gear and rods provided.",
            category: .fishing,
            imageUrls: ["river_fishing_hero"],
            pricePerPerson: 350.0,
            maxGroupSize: 3,
            locationName: "Catawissa, PA",
            latitude: 40.9523,
            longitude: -76.4608,
            rating: 4.8,
            reviewCount: 27
        ),
        Listing(
            id: "2",
            guideId: "guide_103",
            title: "Guided Whitetail Deer Archery Hunt",
            description: "Access to private managed timber stands in the PA Wilds region. Pre-scouted locations with ladder stands ready.",
            category: .hunting,
            imageUrls: ["deer_hunting_hero"],
            pricePerPerson: 600.0,
            maxGroupSize: 2,
            locationName: "Wellsboro, PA",
            latitude: 41.7484,
            longitude: -77.3005,
            rating: 5.0,
            reviewCount: 14
        ),
        Listing(
            id: "3",
            guideId: "guide_101",
            title: "Backcountry Trail Ride Through the PA Wilds",
            description: "A half-day horseback trail ride through scenic ridge trails, suited for beginners and experienced riders alike.",
            category: .trailRiding,
            imageUrls: ["trail_riding_hero"],
            pricePerPerson: 175.0,
            maxGroupSize: 6,
            locationName: "Coudersport, PA",
            latitude: 41.7726,
            longitude: -78.0217,
            rating: 4.6,
            reviewCount: 9
        ),
        Listing(
            id: "4",
            guideId: "guide_103",
            title: "Sunrise Ridge Hiking Trek",
            description: "A guided sunrise hike up one of the region's best overlooks, with a packed breakfast at the summit.",
            category: .hiking,
            imageUrls: ["hiking_hero"],
            pricePerPerson: 90.0,
            maxGroupSize: 8,
            locationName: "Renovo, PA",
            latitude: 41.3273,
            longitude: -77.7530,
            rating: 4.9,
            reviewCount: 41
        )
    ]
}
