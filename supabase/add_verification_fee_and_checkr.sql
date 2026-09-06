-- Real guide verification: a one-time fee (covers the Checkr background
-- check's own cost) charged to the platform's Stripe account, then a
-- Checkr candidate + invitation actually created. Columns needed to track
-- both sides of that.
alter table public.profiles
    add column if not exists checkr_candidate_id text;

alter table public.profiles
    add column if not exists checkr_report_id text;

alter table public.profiles
    add column if not exists verification_fee_paid_at timestamptz;

-- Security fix: rls_policies.sql's "Users can update their own profile"
-- policy has no column-level restriction, which means a real client could
-- currently call .update(["role": "guide", "verification_status":
-- "approved"]) directly against their own row and self-approve as a guide
-- with no background check, no fee, nothing -- the entire verification
-- pipeline is enforced only in the app's UI, not the database. Now that
-- guide-verification-submit/checkr-webhook are the only things meant to
-- ever flip these two columns (both run as service_role), lock everyone
-- else out of touching them: a normal client update silently keeps
-- whatever role/verification_status the row already had.
create or replace function public.protect_guide_verification_columns()
returns trigger
language plpgsql
security definer
as $$
begin
    if auth.role() <> 'service_role' then
        new.role := old.role;
        new.verification_status := old.verification_status;
    end if;
    return new;
end;
$$;

drop trigger if exists profiles_protect_verification on public.profiles;
create trigger profiles_protect_verification
    before update on public.profiles
    for each row
    execute function public.protect_guide_verification_columns();
