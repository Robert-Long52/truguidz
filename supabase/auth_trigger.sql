-- Auto-creates a public.profiles row the instant someone signs up via
-- Supabase Auth. Without this, auth.users would have an account with no
-- matching profile, and every join against profiles would come up empty.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer      -- runs as the function owner, not the caller
set search_path = public  -- pins name resolution so it can't be hijacked
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

-- auth.users is a table Supabase owns, but you're still allowed to attach
-- your own trigger to it -- this is the one official hook point for
-- "do something when a user signs up."
create trigger on_auth_user_created
    after insert on auth.users
    for each row
    execute function public.handle_new_user();
