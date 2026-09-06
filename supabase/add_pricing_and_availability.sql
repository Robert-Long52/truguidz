-- Lets guides price a listing as per-person, per-hour, per-day, or a flat
-- rate for the whole trip regardless of group size, and choose which
-- days-of-week / time-of-day slots they actually run it.
--
-- price_per_person itself is left named as-is -- it's really just "price"
-- now, but every already-tested display site and the live Stripe
-- payment-intent Edge Function key off that column name, and a rename
-- buys nothing functional.
alter table public.listings
    add column if not exists pricing_unit text not null default 'per_person'
        check (pricing_unit in ('per_person', 'per_hour', 'per_day', 'flat_rate'));

-- Weekday ints, 0 = Sunday .. 6 = Saturday, matching Swift's Weekday enum.
alter table public.listings
    add column if not exists available_days integer[] not null default '{0,1,2,3,4,5,6}';

alter table public.listings
    add column if not exists available_time_slots text[] not null default '{morning,afternoon,full_day}';
