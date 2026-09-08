-- TruGuidz database schema (draft)
--
-- Maps directly onto the Swift models in truguidz1/Models/:
--   User.swift     -> profiles
--   Listing.swift  -> listings
--   Booking.swift  -> bookings
--   (new)          -> reviews      (Listing.rating/reviewCount are derived from this)
--   Message.swift  -> messages     (booking-scoped only, see note below)
--
-- Design choice: "enums" below are `text` + CHECK constraint, not native
-- Postgres ENUM types. A CHECK constraint is just as strict, but adding a
-- new allowed value later is a plain `ALTER TABLE ... DROP/ADD CONSTRAINT`
-- instead of the more awkward `ALTER TYPE ... ADD VALUE`.

-- =========================================================
-- 1. profiles
--    One row per account, keyed 1:1 to Supabase's built-in auth.users.
--    auth.users holds the login credentials (email/password, managed by
--    Supabase Auth); profiles holds everything app-specific about that
--    person. This split is the standard Supabase pattern -- you never
--    put custom app columns directly on auth.users.
-- =========================================================
create table public.profiles (
    id                   uuid primary key references auth.users (id) on delete cascade,
    name                 text not null,
    email                text not null,
    profile_image_url    text,
    role                 text not null default 'explorer'
                         check (role in ('explorer', 'guide')),

    -- Guide-only fields -- left null for explorers, same as the Swift model
    verification_status  text not null default 'notStarted'
                         check (verification_status in ('notStarted', 'pending', 'approved', 'rejected')),
    bio                  text,
    years_experience     integer,
    stripe_connect_id    text,
    stripe_charges_enabled boolean not null default false, -- see add_stripe_status.sql

    -- See add_verification_fee_and_checkr.sql -- the real Checkr
    -- background-check pipeline, added after this file was first written.
    checkr_candidate_id     text,
    checkr_report_id        text,
    verification_fee_paid_at timestamptz,
    -- See add_id_document_and_storage.sql -- interim manual review path
    -- while Checkr is blocked on the platform's own business credentialing.
    id_document_path       text,
    -- See add_waiver_acceptance.sql -- liability waiver / ToS acceptance.
    waiver_accepted_at      timestamptz,
    waiver_version          text,
    -- See add_notification_preferences.sql
    notify_booking_updates  boolean not null default true,
    notify_promotions       boolean not null default false,

    -- See add_platform_fee_waiver.sql -- an admin-only override for
    -- individual guides (e.g. early guides helping test the platform).
    -- Never settable by the guide themselves; see rls_policies.sql.
    platform_fee_waived    boolean not null default false,

    phone_number         text,
    created_at           timestamptz not null default now()
);

comment on table public.profiles is 'App-specific profile data for every account, 1:1 with auth.users.';

-- =========================================================
-- 2. listings
-- =========================================================
create table public.listings (
    id                 uuid primary key default gen_random_uuid(),
    guide_id           uuid not null references public.profiles (id) on delete cascade,

    title              text not null,
    description        text not null,
    category           text not null
                       check (category in ('hunting', 'fishing', 'hiking', 'Trail Riding')),
    image_urls         text[] not null default '{}',

    price_per_person   numeric(10, 2) not null check (price_per_person >= 0),
    -- See add_pricing_and_availability.sql -- added after this file was first written.
    pricing_unit        text not null default 'per_person'
                         check (pricing_unit in ('per_person', 'per_hour', 'per_day', 'flat_rate')),
    max_group_size     integer not null check (max_group_size > 0),
    location_name      text not null,
    latitude           double precision,
    longitude          double precision,
    available_days       integer[] not null default '{0,1,2,3,4,5,6}',
    -- See add_trip_length.sql -- one listing is always exactly one trip
    -- length; replaced an earlier available_time_slots[] multi-select.
    trip_length          text not null default 'full_day'
                         check (trip_length in ('morning', 'afternoon', 'full_day', 'multi_day')),
    package_days         integer check (package_days is null or package_days >= 2),

    -- Kept in sync from the reviews table by the trigger below --
    -- never written to directly by the app.
    rating             numeric(2, 1) not null default 0,
    review_count       integer not null default 0,

    created_at         timestamptz not null default now()
);

create index listings_guide_id_idx on public.listings (guide_id);

-- =========================================================
-- 3. bookings
-- =========================================================
create table public.bookings (
    id                        uuid primary key default gen_random_uuid(),
    listing_id                uuid not null references public.listings (id),
    explorer_id               uuid not null references public.profiles (id),
    guide_id                  uuid not null references public.profiles (id),

    date                      timestamptz not null,
    -- Snapshotted at booking time from the listing's trip_length/
    -- package_days (see add_booking_conflict_prevention.sql) -- equals
    -- `date` for a single-day trip, or date + package_days - 1 for a
    -- multi-day package. Exists so a listing's trip_length changing later
    -- can't retroactively change what an existing booking blocks.
    end_date                  timestamptz not null,
    number_of_guests          integer not null check (number_of_guests > 0),
    total_price               numeric(10, 2) not null check (total_price >= 0),

    status                    text not null default 'pending'
                              check (status in ('pending', 'confirmed', 'completed', 'cancelled')),
    created_at                timestamptz not null default now(),

    -- Populated once Stripe payment is captured (see BookingStore.confirmBooking)
    stripe_payment_intent_id  text
);

create index bookings_listing_id_idx on public.bookings (listing_id);
create index bookings_explorer_id_idx on public.bookings (explorer_id);
create index bookings_guide_id_idx on public.bookings (guide_id);

-- A guide can't have two overlapping confirmed/completed bookings -- see
-- add_booking_conflict_prevention.sql for the GiST exclusion constraint
-- that enforces this atomically at the database level (a plain
-- check-then-write in application code has its own race window; this
-- doesn't). Multiple pending requests for the same day are still fine.

-- =========================================================
-- 4. reviews
--    One review per completed booking. listings.rating/review_count are
--    derived from this table by the trigger below, not set by hand.
-- =========================================================
create table public.reviews (
    id           uuid primary key default gen_random_uuid(),
    booking_id   uuid not null unique references public.bookings (id) on delete cascade,
    listing_id   uuid not null references public.listings (id),
    explorer_id  uuid not null references public.profiles (id),

    rating       integer not null check (rating between 1 and 5),
    comment      text,
    created_at   timestamptz not null default now()
);

create index reviews_listing_id_idx on public.reviews (listing_id);

-- Guardrail: a review can only be left for a booking that was confirmed
-- and whose trip date/time has already passed. This is a data-integrity
-- rule (belongs on the table itself), separate from RLS (which separately
-- enforces *who* can insert one). Gating on `date < now()` rather than a
-- 'completed' status because nothing in the app ever sets that status --
-- confirmed bookings just stay 'confirmed' -- so this is the only rule
-- that's actually reachable.
create or replace function public.enforce_review_after_completion()
returns trigger
language plpgsql
as $$
declare
    booking_status text;
    booking_date timestamptz;
begin
    select status, date into booking_status, booking_date
    from public.bookings where id = new.booking_id;

    if booking_status not in ('confirmed', 'completed') then
        raise exception 'Cannot review a booking that was never confirmed';
    end if;

    if booking_date >= now() then
        raise exception 'Cannot review a trip that hasn''t happened yet';
    end if;

    return new;
end;
$$;

create trigger reviews_require_completed_booking
    before insert on public.reviews
    for each row
    execute function public.enforce_review_after_completion();

-- Keep listings.rating / review_count in sync whenever a review is
-- inserted, updated, or deleted.
create or replace function public.sync_listing_rating()
returns trigger
language plpgsql
as $$
declare
    target_listing_id uuid := coalesce(new.listing_id, old.listing_id);
begin
    update public.listings
    set rating = coalesce((select round(avg(rating), 1) from public.reviews where listing_id = target_listing_id), 0),
        review_count = (select count(*) from public.reviews where listing_id = target_listing_id)
    where id = target_listing_id;
    return null;
end;
$$;

create trigger reviews_sync_listing_rating
    after insert or update or delete on public.reviews
    for each row
    execute function public.sync_listing_rating();

-- =========================================================
-- 5. messages
--    Booking-scoped only, on purpose: explorers and guides can only
--    message once a booking exists, so a guide can't hand out contact
--    info and get booked off-platform to dodge fees. RLS (a later phase)
--    will additionally require the booking to be 'confirmed' before any
--    row can be inserted -- this table just holds the shape.
-- =========================================================
create table public.messages (
    id          uuid primary key default gen_random_uuid(),
    booking_id  uuid not null references public.bookings (id) on delete cascade,
    sender_id   uuid not null references public.profiles (id),

    body        text not null,
    created_at  timestamptz not null default now(),
    read_at     timestamptz
);

create index messages_booking_id_idx on public.messages (booking_id);
