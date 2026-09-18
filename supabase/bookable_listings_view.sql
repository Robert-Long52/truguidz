-- The Explore-facing subset of listings: active + the guide has finished
-- Stripe Connect onboarding (see ListingStore.bookableListings for why
-- this exists as a separate view rather than a client-side filter).
--
-- This view was originally created directly in the Studio SQL editor and
-- was never actually checked into a file here -- which is exactly how it
-- went stale: add_listing_blocked_dates.sql added blocked_dates to the
-- listings table, but nothing updated this view's explicit column list to
-- include it, since it doesn't use `select *`. Every row read through
-- this view then failed to decode as a Listing at all (blockedDates has
-- no way to default itself in during Decodable synthesis just because the
-- Swift property has a default value -- a missing key is a hard decode
-- error unless the property is Optional), which silently emptied
-- ListingStore.listings for everyone, not just the affected listing --
-- loadListings() loads `listings` and `bookable_listings` together and
-- fails as a single unit if either one throws.
--
-- Whenever a new column is added to `listings` that Listing.swift needs
-- to decode, it has to be added to this file's column list too, or this
-- breaks again the same way. (Listing.swift also now falls back to a
-- default instead of hard-failing on a missing blocked_dates specifically
-- -- see its custom init(from:) -- but that's a safety net for this one
-- field, not a reason to skip updating this list for other fields.)
create or replace view public.bookable_listings as
select
    l.id,
    l.guide_id,
    l.title,
    l.description,
    l.category,
    l.image_urls,
    l.price_per_person,
    l.max_group_size,
    l.location_name,
    l.latitude,
    l.longitude,
    l.rating,
    l.review_count,
    l.created_at,
    l.pricing_unit,
    l.available_days,
    l.trip_length,
    l.package_days,
    l.is_active,
    l.blocked_dates
from listings l
join profiles p on p.id = l.guide_id
where l.is_active = true and p.stripe_charges_enabled = true;
