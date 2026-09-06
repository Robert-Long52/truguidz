-- Replaces the "guide picks several available time slots" model with
-- "one listing is exactly one trip length" -- a guide who wants to offer
-- both a morning hunt and a full-day hunt makes two listings instead of
-- one listing an explorer has to pick a slot on. Also adds multi-day
-- packages, which the old available_time_slots model had no way to
-- express at all.
alter table public.listings
    add column if not exists trip_length text not null default 'full_day'
        check (trip_length in ('morning', 'afternoon', 'full_day', 'multi_day'));

alter table public.listings
    add column if not exists package_days integer check (package_days is null or package_days >= 2);

alter table public.listings
    drop column if exists available_time_slots;
