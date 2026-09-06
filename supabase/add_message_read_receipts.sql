-- Lets a participant mark messages as read, without opening up the
-- ability to rewrite someone else's message content. RLS alone can't
-- express "only this column may change" -- that needs a trigger, same
-- pattern as profiles_protect_verification in add_verification_fee_and_checkr.sql.

grant update on public.messages to authenticated;

drop policy if exists "Participants can mark messages on their booking as read" on public.messages;
create policy "Participants can mark messages on their booking as read"
    on public.messages for update
    to authenticated
    using (
        exists (
            select 1 from public.bookings b
            where b.id = messages.booking_id
              and (b.explorer_id = auth.uid() or b.guide_id = auth.uid())
        )
    )
    with check (
        exists (
            select 1 from public.bookings b
            where b.id = messages.booking_id
              and (b.explorer_id = auth.uid() or b.guide_id = auth.uid())
        )
    );

create or replace function public.messages_protect_content()
returns trigger
language plpgsql
as $$
begin
    if auth.role() = 'service_role' then
        return new;
    end if;

    new.body := old.body;
    new.sender_id := old.sender_id;
    new.booking_id := old.booking_id;
    new.created_at := old.created_at;
    return new;
end;
$$;

drop trigger if exists messages_protect_content on public.messages;
create trigger messages_protect_content
    before update on public.messages
    for each row execute function public.messages_protect_content();
