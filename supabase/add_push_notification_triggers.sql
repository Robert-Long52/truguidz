-- Wires the three events that actually send a push (new booking request,
-- booking confirmed/declined, new message) straight off the tables that
-- already change on those events, rather than adding "also call this
-- Edge Function" logic into every Swift call site that could create a
-- booking or send a message -- a trigger can't be forgotten by a future
-- code path the way remembering to call a notify-function manually can.
--
-- pg_net's http_post is fire-and-forget from the trigger's perspective
-- (it queues the request and returns immediately, checked via
-- net._http_response if you ever need to debug a delivery), so a slow or
-- failing push can never block or fail the actual booking/message write
-- that triggered it.
--
-- This project's app.settings.supabase_url / app.settings.service_role_key
-- GUCs (the usual pre-populated pattern for this on hosted Supabase) come
-- back null here, and even where they do exist, handing a trigger the full
-- service_role key just to call one endpoint is more access than "ask for
-- a push to be sent" actually needs -- a compromised trigger function
-- would get complete, RLS-bypassing database access as a side effect. This
-- uses a single-purpose secret stored in Vault instead (see the setup note
-- at the bottom of this file), sent as a custom header that
-- send-push-notification checks itself -- the Supabase URL isn't
-- sensitive (it's already public in the app itself), so that's just
-- hardcoded.
create extension if not exists pg_net;

create or replace function public.notify_push(
    p_user_id uuid,
    p_title text,
    p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_webhook_secret text;
begin
    select decrypted_secret into v_webhook_secret
    from vault.decrypted_secrets
    where name = 'push_webhook_secret';

    if v_webhook_secret is null then
        raise warning 'push_webhook_secret not set in Vault -- skipping push notification';
        return;
    end if;

    perform net.http_post(
        url := 'https://mxihqtkrnmkfodzrpfam.supabase.co/functions/v1/send-push-notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-webhook-secret', v_webhook_secret
        ),
        body := jsonb_build_object('userId', p_user_id, 'title', p_title, 'body', p_body)
    );
end;
$$;

-- 1. New booking request -> notify the guide.
create or replace function public.notify_new_booking_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_listing_title text;
begin
    if new.status = 'pending' then
        select title into v_listing_title from public.listings where id = new.listing_id;
        perform public.notify_push(
            new.guide_id,
            'New Booking Request',
            coalesce(v_listing_title, 'A trip') || ' -- ' || new.number_of_guests || ' guest(s) requested.'
        );
    end if;
    return new;
end;
$$;

drop trigger if exists bookings_notify_new_request on public.bookings;
create trigger bookings_notify_new_request
    after insert on public.bookings
    for each row
    execute function public.notify_new_booking_request();

-- 2. Booking confirmed/declined/cancelled -> notify the explorer.
create or replace function public.notify_booking_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_listing_title text;
begin
    if new.status is distinct from old.status and new.status in ('confirmed', 'cancelled') then
        select title into v_listing_title from public.listings where id = new.listing_id;
        perform public.notify_push(
            new.explorer_id,
            case new.status when 'confirmed' then 'Booking Confirmed' else 'Booking Update' end,
            coalesce(v_listing_title, 'Your trip') || (
                case new.status
                    when 'confirmed' then ' is confirmed!'
                    else ' was not confirmed. You have not been charged.'
                end
            )
        );
    end if;
    return new;
end;
$$;

drop trigger if exists bookings_notify_status_change on public.bookings;
create trigger bookings_notify_status_change
    after update on public.bookings
    for each row
    execute function public.notify_booking_status_change();

-- 3. New message -> notify whichever participant didn't send it.
create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_recipient_id uuid;
    v_sender_name text;
begin
    select
        case when new.sender_id = b.explorer_id then b.guide_id else b.explorer_id end
    into v_recipient_id
    from public.bookings b
    where b.id = new.booking_id;

    if v_recipient_id is not null then
        select name into v_sender_name from public.profiles where id = new.sender_id;
        perform public.notify_push(
            v_recipient_id,
            coalesce(v_sender_name, 'New message'),
            left(new.body, 120)
        );
    end if;
    return new;
end;
$$;

drop trigger if exists messages_notify_new_message on public.messages;
create trigger messages_notify_new_message
    after insert on public.messages
    for each row
    execute function public.notify_new_message();

-- ============================================================
-- One-time setup: the shared secret notify_push() reads above.
-- Generate your own value (never reuse an example) and run, with the
-- REAL value swapped in for <PASTE_YOUR_OWN_RANDOM_SECRET_HERE>:
--
--   select vault.create_secret('<PASTE_YOUR_OWN_RANDOM_SECRET_HERE>', 'push_webhook_secret');
--
-- Then set the exact same value as an Edge Function secret from a
-- terminal (never paste it into a chat):
--
--   supabase secrets set PUSH_WEBHOOK_SECRET="<the same value>"
--
-- If you ever need to rotate it, use vault.update_secret with the id
-- returned by create_secret, and re-run the supabase secrets set command
-- with the new value.
-- ============================================================
