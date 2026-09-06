-- Creates the bucket listing photos live in, plus RLS policies on
-- storage.objects (Supabase's Storage RLS works exactly like table RLS --
-- same auth.uid() checks, just against file paths instead of columns).
--
-- Path convention: listing-images/{guideId}/{listingId}/photo.jpg
-- storage.foldername(name) splits the path into an array, so
-- (storage.foldername(name))[1] is the guideId segment -- that's what lets
-- a policy check "is this guide uploading into their own folder."

insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true)
on conflict (id) do nothing;

-- No SELECT policy: the bucket is public, so individual files are already
-- servable via their public URL without RLS. A broad SELECT policy here
-- would instead let clients *list/enumerate* every file in the bucket via
-- the Storage API -- more exposure than intended, and not something
-- AsyncImage loading a known URL ever needed anyway.
drop policy if exists "Listing images are publicly readable" on storage.objects;

drop policy if exists "Guides can upload their own listing images" on storage.objects;
create policy "Guides can upload their own listing images"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'listing-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Guides can update their own listing images" on storage.objects;
create policy "Guides can update their own listing images"
    on storage.objects for update
    to authenticated
    using (
        bucket_id = 'listing-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Guides can delete their own listing images" on storage.objects;
create policy "Guides can delete their own listing images"
    on storage.objects for delete
    to authenticated
    using (
        bucket_id = 'listing-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
