import Foundation
import SwiftUI
import Supabase

// Holds all listings for the app session, same pattern as BookingStore.
// Starts empty and loads from Supabase; createListing inserts a guide's
// new trip into the database, then appends the inserted row so it shows
// up live in Explore without a full reload.
@MainActor
final class ListingStore: ObservableObject {
    @Published var listings: [Listing] = []
    // Explore-facing subset of `listings` -- a listing whose guide hasn't
    // finished Stripe Connect onboarding yet (stripe_charges_enabled still
    // false) can't actually be booked: stripe-create-payment-intent
    // rejects it with a 422. Rather than let an explorer find a listing
    // that looks bookable and hit that error, this is what Explore reads
    // from instead of `listings` directly -- a guide's own dashboard still
    // reads `listings` (see GuidzDashboardView.myListings) so they can see
    // and manage a listing they're still setting up payouts for.
    //
    // Sourced from the `bookable_listings` view (see supabase/schema.sql),
    // which joins listings to profiles server-side and returns only
    // listings columns -- filtering by the guide's stripe_charges_enabled
    // client-side would mean embedding profiles data into this query, and
    // profiles' own RLS only allows an authenticated user to read *their
    // own* row's private columns (email, phone, Stripe account id) -- a
    // signed-out explorer browsing Explore would need that same embed to
    // work too, which would mean opening profiles' RLS to anon and leaking
    // that private data to anyone, logged in or not. The view sidesteps
    // that entirely: it never returns a profiles column at all, so there's
    // nothing sensitive for its own (separately granted) anon access to expose.
    @Published var bookableListings: [Listing] = []
    @Published var isLoading = false

    func loadListings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // is_active is only ever false after the owning guide's account
            // has been deleted (see supabase/functions/delete-account) --
            // a deleted account is also banned from signing in, so there's
            // no legitimate case where a signed-in user needs to see one
            // of their own inactive listings. Filtering here, once,
            // instead of in every view that reads listingStore.listings.
            async let allListings: [Listing] = supabase
                .from("listings")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            async let bookable: [Listing] = supabase
                .from("bookable_listings")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            (listings, bookableListings) = try await (allListings, bookable)
        } catch {
            print("Failed to load listings: \(error)")
        }
    }

    @discardableResult
    func createListing(
        guideId: String,
        title: String,
        description: String,
        category: ExperienceType,
        pricePerPerson: Double,
        pricingUnit: PricingUnit,
        maxGroupSize: Int,
        locationName: String,
        tripLength: TripLength,
        packageDays: Int?,
        availableDays: [Weekday]
    ) async throws -> Listing {
        let newListing = Listing(
            id: UUID().uuidString,
            guideId: guideId,
            title: title,
            description: description,
            category: category,
            imageUrls: [],
            pricePerPerson: pricePerPerson,
            pricingUnit: pricingUnit,
            maxGroupSize: maxGroupSize,
            locationName: locationName,
            // Placeholder coordinates until a real geocoding/map picker step exists
            latitude: 0,
            longitude: 0,
            tripLength: tripLength,
            packageDays: packageDays,
            availableDays: availableDays,
            rating: 0,
            reviewCount: 0
        )

        let inserted: Listing = try await supabase
            .from("listings")
            .insert(newListing)
            .select()
            .single()
            .execute()
            .value

        listings.insert(inserted, at: 0)
        return inserted
    }

    // A plain [String: Any] dictionary isn't Encodable, and these fields
    // are different types, so a dedicated struct (same CodingKeys mapping
    // as Listing itself) is the clean way to PATCH just these columns.
    private struct ListingUpdate: Encodable {
        let title: String
        let description: String
        let category: ExperienceType
        let pricePerPerson: Double
        let pricingUnit: PricingUnit
        let maxGroupSize: Int
        let locationName: String
        let tripLength: TripLength
        let packageDays: Int?
        let availableDays: [Weekday]

        enum CodingKeys: String, CodingKey {
            case title, description, category
            case pricePerPerson = "price_per_person"
            case pricingUnit = "pricing_unit"
            case maxGroupSize = "max_group_size"
            case locationName = "location_name"
            case tripLength = "trip_length"
            case packageDays = "package_days"
            case availableDays = "available_days"
        }

        // The default synthesized Encodable for an Optional property uses
        // encodeIfPresent, which OMITS the key entirely when nil -- fine
        // for an insert, but wrong for this PATCH-style update: switching a
        // listing away from .multiDay needs to actually clear package_days
        // in Postgres, not just silently leave the old value sitting there.
        // Encoding an explicit null (via encodeNil) is what makes that happen.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            try container.encode(description, forKey: .description)
            try container.encode(category, forKey: .category)
            try container.encode(pricePerPerson, forKey: .pricePerPerson)
            try container.encode(pricingUnit, forKey: .pricingUnit)
            try container.encode(maxGroupSize, forKey: .maxGroupSize)
            try container.encode(locationName, forKey: .locationName)
            try container.encode(tripLength, forKey: .tripLength)
            if let packageDays {
                try container.encode(packageDays, forKey: .packageDays)
            } else {
                try container.encodeNil(forKey: .packageDays)
            }
            try container.encode(availableDays, forKey: .availableDays)
        }
    }

    // Guides edit listings from GuidzDashboardView -- this only ever
    // touches the listing row itself, never a booking. Existing bookings
    // (pending or otherwise) snapshot their own totalPrice/numberOfGuests
    // at the moment they were created, so an edit here can't retroactively
    // change what someone already booked -- it only affects the price/
    // details a *future* booking will see. That's what makes this safe to
    // do without any locking: there's no shared mutable state in the race.
    func updateListing(
        listingId: String,
        title: String,
        description: String,
        category: ExperienceType,
        pricePerPerson: Double,
        pricingUnit: PricingUnit,
        maxGroupSize: Int,
        locationName: String,
        tripLength: TripLength,
        packageDays: Int?,
        availableDays: [Weekday]
    ) async throws {
        let update = ListingUpdate(
            title: title,
            description: description,
            category: category,
            pricePerPerson: pricePerPerson,
            pricingUnit: pricingUnit,
            maxGroupSize: maxGroupSize,
            locationName: locationName,
            tripLength: tripLength,
            packageDays: packageDays,
            availableDays: availableDays
        )

        try await supabase
            .from("listings")
            .update(update)
            .eq("id", value: listingId)
            .execute()

        func applyEdits(to listing: inout Listing) {
            listing.title = title
            listing.description = description
            listing.category = category
            listing.pricePerPerson = pricePerPerson
            listing.pricingUnit = pricingUnit
            listing.maxGroupSize = maxGroupSize
            listing.locationName = locationName
            listing.tripLength = tripLength
            listing.packageDays = packageDays
            listing.availableDays = availableDays
        }

        if let index = listings.firstIndex(where: { $0.id == listingId }) {
            applyEdits(to: &listings[index])
        }
        // Only present here at all if the guide was already bookable as of
        // the last load -- editing details doesn't change that status, so
        // it's safe to mirror the same edits rather than re-fetch.
        if let index = bookableListings.firstIndex(where: { $0.id == listingId }) {
            applyEdits(to: &bookableListings[index])
        }
    }

    // Called after a listing's photos finish uploading to Storage --
    // separate from createListing since the listing needs to exist (and
    // have an id) before a photo can be uploaded into a path scoped to it.
    // imageUrls[0] is the cover photo shown on cards/Featured Guides;
    // ListingDetailView shows all of them in a swipeable gallery.
    func updateListingImages(listingId: String, imageUrls: [String]) async {
        do {
            try await supabase
                .from("listings")
                .update(["image_urls": imageUrls])
                .eq("id", value: listingId)
                .execute()
            if let index = listings.firstIndex(where: { $0.id == listingId }) {
                listings[index].imageUrls = imageUrls
            }
            if let index = bookableListings.firstIndex(where: { $0.id == listingId }) {
                bookableListings[index].imageUrls = imageUrls
            }
        } catch {
            print("Failed to update listing images for \(listingId): \(error)")
        }
    }
}
