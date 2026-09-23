-- Splits a booking's headcount into adults/children instead of one plain
-- "number of guests" -- kids still count toward the listing's max group
-- size and toward per-person pricing exactly like an adult would (no
-- separate child pricing was asked for), this is purely so a guide can see
-- the actual makeup of who's showing up. number_of_guests stays the
-- authoritative total (= number_of_adults + number_of_children) so every
-- existing capacity check and pricing calculation keeps working untouched.
--
-- Nullable, not defaulted to 0/0 -- a booking made before this shipped has
-- no real adults/children breakdown to backfill (only the total survives),
-- and the client treats null here as "show the plain guest count" rather
-- than fabricating a 100%-adults split that was never actually asked.
alter table public.bookings
    add column if not exists number_of_adults integer;
alter table public.bookings
    add column if not exists number_of_children integer;

alter table public.bookings drop constraint if exists bookings_headcount_matches_total;
alter table public.bookings
    add constraint bookings_headcount_matches_total
    check (
        number_of_adults is null
        or number_of_children is null
        or number_of_adults + number_of_children = number_of_guests
    );
