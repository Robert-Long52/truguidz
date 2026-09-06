-- One-time fix for two CHECK constraints that didn't match the Swift
-- enums' actual rawValues (schema.sql and auth_trigger.sql have already
-- been corrected in the repo -- this brings the live database in line
-- with those files). Safe to run more than once.
--
-- Order matters: drop the old constraints BEFORE updating data to the new
-- values (otherwise the UPDATE itself gets rejected by the still-active
-- old constraint), then add the corrected constraints back once the data
-- already matches them.

alter table public.listings
    drop constraint if exists listings_category_check;
alter table public.profiles
    drop constraint if exists profiles_verification_status_check;

update public.profiles set verification_status = 'notStarted' where verification_status = 'not_started';
update public.listings set category = 'Trail Riding' where category = 'trailRiding';

alter table public.listings
    add constraint listings_category_check
    check (category in ('hunting', 'fishing', 'hiking', 'Trail Riding'));

alter table public.profiles
    add constraint profiles_verification_status_check
    check (verification_status in ('notStarted', 'pending', 'approved', 'rejected'));

-- Re-apply the trigger function with the corrected default value.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, name, email, role, verification_status)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'name', 'New User'),
        new.email,
        'explorer',
        'notStarted'
    );
    return new;
end;
$$;
