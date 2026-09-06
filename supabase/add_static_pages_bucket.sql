-- Home for small static HTML pages the app needs a real browser-facing
-- URL for (password reset landing page today, maybe others later) --
-- separate from listing-images since these aren't guide content, they're
-- app infrastructure. Public, upload-only-by-admin: no INSERT/UPDATE/
-- DELETE policy at all, since nothing client-side ever writes here --
-- only `supabase storage cp --linked` (an authenticated CLI/admin
-- context) does. See supabase_swift_gotchas memory for why Edge
-- Functions can't serve real text/html on the default *.supabase.co
-- domain -- Storage doesn't have that restriction, which is the whole
-- reason this bucket exists.

insert into storage.buckets (id, name, public)
values ('static-pages', 'static-pages', true)
on conflict (id) do nothing;

-- No policies needed: public bucket (public URL works with zero RLS,
-- same reasoning as listing-images), and no client-side writer.
