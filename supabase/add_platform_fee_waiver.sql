-- Lets an admin waive TruGuidz's platform fee for a specific guide (e.g.
-- an early guide helping test the platform before it's seen a real
-- season of bookings). stripe-create-payment-intent checks this on every
-- new booking and skips application_fee_amount entirely when it's set --
-- Stripe's own processing cut still comes out, nothing else does.
alter table public.profiles
    add column if not exists platform_fee_waived boolean not null default false;

-- Same trust gap add_verification_fee_and_checkr.sql's
-- protect_guide_verification_columns trigger closed for role/
-- verification_status: rls_policies.sql's "Users can update their own
-- profile" policy has no column-level restriction, so without this a
-- guide could set their own fee waiver with a raw PATCH against their own
-- row. This is money, so it doesn't get to ride on "the app UI never
-- exposes it." Only a service_role caller (this is only ever flipped by
-- hand via the SQL editor -- see the example below) can change it;
-- anyone else's update silently keeps whatever the row already had.
create or replace function public.protect_platform_fee_waived()
returns trigger
language plpgsql
security definer
as $$
begin
    if auth.role() <> 'service_role' then
        new.platform_fee_waived := old.platform_fee_waived;
    end if;
    return new;
end;
$$;

drop trigger if exists profiles_protect_fee_waiver on public.profiles;
create trigger profiles_protect_fee_waiver
    before update on public.profiles
    for each row
    execute function public.protect_platform_fee_waived();

-- Example: run this by hand in the Supabase SQL editor (Studio) once a
-- guide's account exists, to waive their fee. Swap in the real email.
--
-- update public.profiles
-- set platform_fee_waived = true
-- where email = 'jason@example.com';
