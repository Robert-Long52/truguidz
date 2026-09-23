-- Lets a guide black out individual days on top of their recurring
-- weekly schedule (available_days) -- a vacation, a maintenance day, a
-- personal commitment -- without having to change their weekly pattern
-- or deactivate the whole listing. Plain date[], same shape as
-- available_days being an array of weekdays; volume here is a guide
-- manually picking a handful of dates, not enough to warrant a separate
-- table.
alter table public.listings
    add column if not exists blocked_dates date[] not null default '{}';

-- Mirrors guide_has_confirmed_conflict's job (see
-- add_guide_conflict_check_function.sql) but for manually-blocked dates
-- instead of other confirmed bookings -- stripe-capture-payment checks
-- both before ever letting a guide confirm a pending request, so a guide
-- can't accidentally confirm a trip that lands on a day they'd already
-- blocked off. Whole-calendar-day comparison via utc_date(), same
-- reasoning as the confirmed-conflict check: raw timestamp comparison can
-- miss a same-day conflict when the two timestamps fall at different
-- times of day.
create or replace function public.listing_has_blocked_date_conflict(
    p_listing_id uuid,
    p_start_date timestamptz,
    p_end_date timestamptz
)
returns boolean
language sql
stable
as $$
    select exists (
        select 1
        from public.listings, unnest(blocked_dates) as blocked_day
        where id = p_listing_id
          and blocked_day between public.utc_date(p_start_date) and public.utc_date(p_end_date)
    );
$$;

grant execute on function public.listing_has_blocked_date_conflict to authenticated, service_role;
