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

    // Individual dates the guide has manually blocked off, on top of their
    // recurring availableDays pattern (a vacation, a maintenance day, etc).
    // Kept as plain "yyyy-MM-dd" strings rather than Date -- Postgres's
    // bare `date` column has no time-of-day/timezone component at all, and
    // decoding it straight into Date would mean picking a decoding
    // strategy that has to agree with whatever format PostgREST happens to
    // serialize a date (not timestamptz) column as. Comparing/parsing
    // these against a real Date only ever needs to happen at the "yyyy-MM-dd"
    // granularity anyway, so working with the raw string sidesteps that
    // ambiguity entirely.
    var blockedDates: [String] = []

    // Social proof — shown as stars on the card
    var rating: Double              // 0.0 to 5.0
    var reviewCount: Int

    // false once the guide's account has been deleted (see
    // supabase/functions/delete-account) -- the listing itself can't be
    // hard-deleted (bookings reference it with ON DELETE NO ACTION), so
    // this is what actually hides it from Explore instead.
    var isActive: Bool = true

    // Maps to the listings table's snake_case columns (see
    // supabase/schema.sql and supabase/bookable_listings_view.sql -- this
    // gets decoded from both the raw table and that view, and the view's
    // column list has to be kept in sync by hand since it doesn't use
    // `select *`).
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
        case blockedDates = "blocked_dates"
        case isActive = "is_active"
    }

    // Defining init(from:) below removes Swift's free memberwise
    // initializer (any custom init does, not just a Decodable one) -- this
    // restores it explicitly, same parameter list/defaults as before, so
    // mockListings and ListingStore.createListing can still construct a
    // Listing directly.
    init(
        id: String,
        guideId: String,
        title: String,
        description: String,
        category: ExperienceType,
        imageUrls: [String],
        pricePerPerson: Double,
        pricingUnit: PricingUnit = .perPerson,
        maxGroupSize: Int,
        locationName: String,
        latitude: Double,
        longitude: Double,
        tripLength: TripLength = .fullDay,
        packageDays: Int? = nil,
        availableDays: [Weekday] = Weekday.allCases,
        blockedDates: [String] = [],
        rating: Double,
        reviewCount: Int,
        isActive: Bool = true
    ) {
        self.id = id
        self.guideId = guideId
        self.title = title
        self.description = description
        self.category = category
        self.imageUrls = imageUrls
        self.pricePerPerson = pricePerPerson
        self.pricingUnit = pricingUnit
        self.maxGroupSize = maxGroupSize
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.tripLength = tripLength
        self.packageDays = packageDays
        self.availableDays = availableDays
        self.blockedDates = blockedDates
        self.rating = rating
        self.reviewCount = reviewCount
        self.isActive = isActive
    }

    // Confirmed live: bookable_listings_view.sql went stale for a while
    // after blocked_dates was added to the listings table (its column
    // list is explicit, not `select *`, so it silently never picked up
    // the new column) -- decoding a row missing that key threw
    // keyNotFound, which failed ListingStore.loadListings() as a whole
    // (it loads the raw table and this view together) and blanked every
    // guide's "Your Listings" screen, not just the affected row. The real
    // fix is keeping that view's column list current, but this custom
    // decode is the defense-in-depth half: blockedDates specifically
    // degrading to its default instead of hard-failing means the next
    // view/query that lags behind a new listings column can't take down
    // the whole listings screen over just this one field again.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        guideId = try container.decode(String.self, forKey: .guideId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(ExperienceType.self, forKey: .category)
        imageUrls = try container.decode([String].self, forKey: .imageUrls)
        pricePerPerson = try container.decode(Double.self, forKey: .pricePerPerson)
        pricingUnit = try container.decodeIfPresent(PricingUnit.self, forKey: .pricingUnit) ?? .perPerson
        maxGroupSize = try container.decode(Int.self, forKey: .maxGroupSize)
        locationName = try container.decode(String.self, forKey: .locationName)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        tripLength = try container.decodeIfPresent(TripLength.self, forKey: .tripLength) ?? .fullDay
        packageDays = try container.decodeIfPresent(Int.self, forKey: .packageDays)
        availableDays = try container.decodeIfPresent([Weekday].self, forKey: .availableDays) ?? Weekday.allCases
        blockedDates = try container.decodeIfPresent([String].self, forKey: .blockedDates) ?? []
        rating = try container.decode(Double.self, forKey: .rating)
        reviewCount = try container.decode(Int.self, forKey: .reviewCount)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
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
 
// A single shared formatter for blockedDates' "yyyy-MM-dd" strings -- every
// call site needs to agree on the exact same format, both when parsing
// them back into Date and when writing new ones out to save.
enum ListingDateFormat {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone.current
        return f
    }()
}

extension Listing {
    // Start-of-day Date values for each blocked date string, in the
    // device's current calendar -- ready to union straight into
    // BookingRequestView's blockedDates set.
    var blockedDateValues: Set<Date> {
        let calendar = Calendar.current
        return Set(blockedDates.compactMap { dateString in
            ListingDateFormat.formatter.date(from: dateString).map { calendar.startOfDay(for: $0) }
        })
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
