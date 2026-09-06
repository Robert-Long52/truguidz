-- A guide physically can't run two trips at once. Checking-then-writing in
-- application code (Edge Function does a SELECT for conflicts, then an
-- UPDATE) is not enough on its own -- two confirmations can race through
-- that check at the same moment and both pass before either commits. The
-- only way to actually guarantee this is a constraint enforced by
-- Postgres itself: a GiST exclusion constraint, which the database checks
-- atomically as part of the write, the same way a unique constraint would.
create extension if not exists btree_gist;

-- Snapshotted onto the booking at creation time, same principle as
-- total_price/number_of_guests already being snapshots of the listing at
-- booking time (see EditListingView's comment on why that's safe) -- a
-- listing's trip_length changing later shouldn't retroactively change what
-- an existing booking blocks. For a single-day trip (morning/afternoon/
-- full_day) this equals date; for a multi-day package it's
-- date + package_days - 1.
alter table public.bookings add column if not exists end_date timestamptz;
update public.bookings set end_date = date where end_date is null;
alter table public.bookings alter column end_date set not null;

-- Postgres's built-in timestamptz -> date cast is STABLE, not IMMUTABLE
-- (its result depends on the session's TimeZone setting), and an index
-- expression requires IMMUTABLE. Pinning to UTC explicitly makes the
-- result genuinely deterministic regardless of session settings, which is
-- what actually justifies marking this immutable -- the standard,
-- widely-used workaround for building an exclusion constraint over a
-- timestamptz column.
create or replace function public.utc_date(ts timestamptz)
returns date
language sql
immutable
as $$
    select (ts at time zone 'UTC')::date;
$$;

-- Only applies to confirmed/completed bookings (a partial exclusion
-- constraint, via the WHERE clause) -- multiple explorers competitively
-- requesting the same day is fine and expected, a guide just can't have
-- two confirmed bookings whose date ranges overlap. '[]' makes both ends
-- of the range inclusive, which matters for a single-day booking: without
-- it, daterange(day, day) is an empty range that would never conflict
-- with anything.
alter table public.bookings drop constraint if exists bookings_no_overlapping_confirmed;
alter table public.bookings
    add constraint bookings_no_overlapping_confirmed
    exclude using gist (
        guide_id with =,
        daterange(public.utc_date(date), public.utc_date(end_date), '[]') with &&
    )
    where (status in ('confirmed', 'completed'));
