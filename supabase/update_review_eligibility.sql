-- The original trigger gated reviews on status = 'completed' -- but
-- nothing in the app has ever actually set a booking to 'completed'
-- (confirmed bookings just stay 'confirmed' forever), which would have
-- made reviews permanently unreachable. The user's actual requirement is
-- simpler and more directly correct anyway: a review should be allowed
-- once the trip itself has happened, i.e. its date/time has passed --
-- not dependent on a status flag nothing sets. `date` is a timestamptz,
-- so this comparison already accounts for time of day, not just the
-- calendar date (even though the booking flow doesn't yet let an
-- explorer pick a specific start *time* -- see BookingRequestView, whose
-- DatePicker is date-only. Whatever time the underlying Date happens to
-- carry is what's compared against here).
create or replace function public.enforce_review_after_completion()
returns trigger
language plpgsql
as $$
declare
    booking_status text;
    booking_date timestamptz;
begin
    select status, date into booking_status, booking_date
    from public.bookings where id = new.booking_id;

    if booking_status not in ('confirmed', 'completed') then
        raise exception 'Cannot review a booking that was never confirmed';
    end if;

    if booking_date >= now() then
        raise exception 'Cannot review a trip that hasn''t happened yet';
    end if;

    return new;
end;
$$;
