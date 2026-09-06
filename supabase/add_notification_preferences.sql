-- Notification preference storage -- no push (APNs) infrastructure exists
-- yet to actually deliver anything, but the preferences themselves are
-- real and persisted, ready for whenever push gets wired up.
alter table public.profiles
    add column if not exists notify_booking_updates boolean not null default true;

alter table public.profiles
    add column if not exists notify_promotions boolean not null default false;
