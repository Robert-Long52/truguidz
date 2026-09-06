-- Row Level Security for TruGuidz.
--
-- Two layers are at work here, and both are required:
--   1. GRANT   -- can this Postgres role touch the table at all
--   2. POLICY  -- given access, which rows specifically
-- Supabase's dashboard-created tables get default GRANTs automatically;
-- tables created via raw SQL (like schema.sql) don't, which is why the
-- earlier anon-key test got "permission denied" instead of an empty result.
--
-- Safe to run this whole file more than once: GRANT and ENABLE ROW LEVEL
-- SECURITY are no-ops if already applied, and every CREATE POLICY is
-- preceded by a DROP POLICY IF EXISTS.

-- =========================================================
-- profiles
-- =========================================================
alter table public.profiles enable row level security;

grant select, update on public.profiles to authenticated;
-- No insert grant: profiles rows are only ever created by the
-- handle_new_user trigger (supabase/auth_trigger.sql), which runs as
-- SECURITY DEFINER and bypasses RLS/grants entirely by design.

drop policy if exists "Profiles are viewable by logged-in users" on public.profiles;
create policy "Profiles are viewable by logged-in users"
    on public.profiles for select
    to authenticated
    using (true);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
    on public.profiles for update
    to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- =========================================================
-- listings
-- =========================================================
alter table public.listings enable row level security;

grant select on public.listings to anon, authenticated;
grant insert, update, delete on public.listings to authenticated;

drop policy if exists "Listings are public" on public.listings;
create policy "Listings are public"
    on public.listings for select
    to anon, authenticated
    using (true);

drop policy if exists "Approved guides can create their own listings" on public.listings;
create policy "Approved guides can create their own listings"
    on public.listings for insert
    to authenticated
    with check (
        guide_id = auth.uid()
        and exists (
            select 1 from public.profiles
            where id = auth.uid()
              and role = 'guide'
              and verification_status = 'approved'
        )
    );

drop policy if exists "Guides can update their own listings" on public.listings;
create policy "Guides can update their own listings"
    on public.listings for update
    to authenticated
    using (guide_id = auth.uid())
    with check (guide_id = auth.uid());

drop policy if exists "Guides can delete their own listings" on public.listings;
create policy "Guides can delete their own listings"
    on public.listings for delete
    to authenticated
    using (guide_id = auth.uid());

-- =========================================================
-- bookings
-- =========================================================
alter table public.bookings enable row level security;

grant select, insert, update on public.bookings to authenticated;

drop policy if exists "Bookings are visible to the explorer or guide involved" on public.bookings;
create policy "Bookings are visible to the explorer or guide involved"
    on public.bookings for select
    to authenticated
    using (auth.uid() = explorer_id or auth.uid() = guide_id);

drop policy if exists "Explorers can create their own bookings" on public.bookings;
create policy "Explorers can create their own bookings"
    on public.bookings for insert
    to authenticated
    with check (auth.uid() = explorer_id);

-- Deliberately permissive on which status transitions are allowed --
-- either party involved can update the row (covers explorer cancelling,
-- guide confirming/declining). Enforcing the exact state machine
-- (e.g. only a guide can move pending -> confirmed) would need a trigger
-- comparing OLD vs NEW status; worth adding later, not required for MVP.
drop policy if exists "Explorer or guide can update a booking they're part of" on public.bookings;
create policy "Explorer or guide can update a booking they're part of"
    on public.bookings for update
    to authenticated
    using (auth.uid() = explorer_id or auth.uid() = guide_id)
    with check (auth.uid() = explorer_id or auth.uid() = guide_id);

-- =========================================================
-- reviews
-- =========================================================
alter table public.reviews enable row level security;

grant select on public.reviews to anon, authenticated;
grant insert on public.reviews to authenticated;

drop policy if exists "Reviews are public" on public.reviews;
create policy "Reviews are public"
    on public.reviews for select
    to anon, authenticated
    using (true);

-- Note: the reviews_require_completed_booking trigger (schema.sql) only
-- checks that the booking is completed -- it doesn't check that the
-- reviewer actually owns that booking. This policy closes that gap.
drop policy if exists "Explorers can review their own completed bookings" on public.reviews;
create policy "Explorers can review their own completed bookings"
    on public.reviews for insert
    to authenticated
    with check (
        explorer_id = auth.uid()
        and exists (
            select 1 from public.bookings
            where id = booking_id and explorer_id = auth.uid()
        )
    );

-- =========================================================
-- messages
-- =========================================================
alter table public.messages enable row level security;

grant select, insert on public.messages to authenticated;

drop policy if exists "Messages are visible to the explorer or guide on that booking" on public.messages;
create policy "Messages are visible to the explorer or guide on that booking"
    on public.messages for select
    to authenticated
    using (
        exists (
            select 1 from public.bookings b
            where b.id = messages.booking_id
              and (b.explorer_id = auth.uid() or b.guide_id = auth.uid())
        )
    );

-- The actual "no contact info before payment" enforcement: a message can
-- only be inserted if its booking has moved past 'pending'.
drop policy if exists "Only participants on a confirmed booking can message" on public.messages;
create policy "Only participants on a confirmed booking can message"
    on public.messages for insert
    to authenticated
    with check (
        sender_id = auth.uid()
        and exists (
            select 1 from public.bookings b
            where b.id = booking_id
              and b.status in ('confirmed', 'completed')
              and (b.explorer_id = auth.uid() or b.guide_id = auth.uid())
        )
    );
