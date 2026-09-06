-- The client-side blackout calendar (BookingRequestView.blockedDates) was
-- built to read straight off BookingStore.bookings, which is loaded via a
-- plain `select()` on the bookings table -- but that table's own SELECT
-- policy ("Bookings are visible to the explorer or guide involved") only
-- lets a caller see rows where they're the explorer *or* the guide. A
-- different explorer browsing to book this guide can never see the
-- guide's other customers' confirmed bookings through that query at all,
-- so the blackout calendar silently showed nothing blocked for anyone
-- except whichever single account happened to have made every test
-- booking. This is a SECURITY DEFINER function specifically so it can see
-- across that RLS boundary -- but it only ever returns the day range,
-- nothing else (no explorer identity, price, guest count), which is the
-- minimum someone needs to know "is this day taken" without leaking
-- anything about who booked it or for how much.
create or replace function public.guide_confirmed_date_ranges(p_guide_id uuid)
returns table (start_date timestamptz, end_date timestamptz)
language sql
stable
security definer
set search_path = public
as $$
    select date, end_date
    from public.bookings
    where guide_id = p_guide_id
      and status in ('confirmed', 'completed');
$$;

grant execute on function public.guide_confirmed_date_ranges to authenticated;
