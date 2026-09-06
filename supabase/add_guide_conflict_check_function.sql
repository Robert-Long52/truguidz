-- stripe-capture-payment's upfront conflict check (before ever touching
-- Stripe) needs to use the *exact* same overlap semantics as the
-- bookings_no_overlapping_confirmed exclusion constraint -- whole calendar
-- days via utc_date(), not raw timestamp comparison. Confirmed this
-- matters for real, not just in theory: a naive `.lte()/.gte()` comparison
-- of the raw date/end_date columns in the Edge Function missed a same-day
-- conflict where the two bookings' timestamps happened to fall at
-- different times of day (e.g. noon vs. 8:30pm) -- they don't overlap as
-- raw instants, but they're still the same calendar day, which is what
-- actually matters (a guide can't split one day between two trips). A
-- shared RPC function is what guarantees the pre-check and the constraint
-- can never quietly disagree with each other.
create or replace function public.guide_has_confirmed_conflict(
    p_guide_id uuid,
    p_start_date timestamptz,
    p_end_date timestamptz,
    p_exclude_booking_id uuid default null
)
returns boolean
language sql
stable
as $$
    select exists (
        select 1 from public.bookings
        where guide_id = p_guide_id
          and status in ('confirmed', 'completed')
          and (p_exclude_booking_id is null or id != p_exclude_booking_id)
          and daterange(public.utc_date(date), public.utc_date(end_date), '[]')
              && daterange(public.utc_date(p_start_date), public.utc_date(p_end_date), '[]')
    );
$$;

grant execute on function public.guide_has_confirmed_conflict to authenticated, service_role;
