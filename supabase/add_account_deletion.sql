-- Account deletion needs to be safe against real relational data.
-- bookings/messages/reviews all reference profiles.id with ON DELETE NO
-- ACTION (by design -- a booking's own history has to survive even if
-- the other party's account later changes), and profiles.id itself
-- cascades from auth.users. That combination means directly deleting the
-- auth.users row would fail with a foreign-key violation for any account
-- that's ever booked, messaged, or reviewed -- which is nearly every real
-- account. So this is a soft-delete: anonymize the profile in place,
-- deactivate any listings so they stop appearing to explorers, and
-- separately revoke login via Supabase Auth's ban mechanism (no row
-- deletion involved, so none of the FK constraints ever come into play).
alter table public.profiles add column if not exists deleted_at timestamptz;
alter table public.listings add column if not exists is_active boolean not null default true;
