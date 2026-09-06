-- service_role bypasses RLS by design (it has the BYPASSRLS attribute), but
-- that's a separate layer from table-level GRANTs -- same two-layer model
-- as anon/authenticated in rls_policies.sql. Tables created via raw SQL
-- don't get service_role's usual blanket access automatically, which is
-- exactly what stripe-connect-onboarding just hit: ctx.supabaseAdmin
-- correctly bypassed RLS, but still got "permission denied" at the GRANT
-- layer underneath it.
grant select, insert, update, delete on public.profiles to service_role;
grant select, insert, update, delete on public.listings to service_role;
grant select, insert, update, delete on public.bookings to service_role;
grant select, insert, update, delete on public.reviews to service_role;
grant select, insert, update, delete on public.messages to service_role;

-- So this doesn't need rediscovering every time a new table gets added.
alter default privileges in schema public grant select, insert, update, delete on tables to service_role;
