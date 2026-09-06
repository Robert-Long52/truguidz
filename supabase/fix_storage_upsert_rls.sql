-- Real bug, found through hands-on debugging, not theoretical: uploading
-- with upsert:true (used by both StorageService.uploadListingImage and
-- uploadGuideVerificationDocument) was failing with "new row violates
-- row-level security policy" -- for BOTH buckets, including the
-- already-shipped listing-images one, whenever the upload targeted a path
-- that already had a row (i.e. any actual re-upload/overwrite; a
-- brand-new path was fine, which is why this went unnoticed until now).
--
-- Root cause: Postgres RLS requires SELECT-level visibility into a row
-- before UPDATE/DELETE can act on it (to evaluate the UPDATE policy's
-- USING clause against the existing row at all) -- a permissive UPDATE
-- policy alone is not sufficient if there's no SELECT policy granting
-- that visibility. Both buckets deliberately had no SELECT policy (to
-- avoid letting clients enumerate bucket contents) -- upsert's internal
-- INSERT ... ON CONFLICT DO UPDATE path needs to "see" the conflicting
-- row to update it, and with zero SELECT visibility, it silently found
-- nothing to update and Postgres reported it as an RLS violation.
--
-- Fix: add a SELECT policy scoped to the uploader's own folder for both
-- buckets. This is NOT the same exposure the "no SELECT policy" comments
-- elsewhere warn about -- those warn against a *broad*
-- `using (bucket_id = '...')` policy with no owner scoping, which lets
-- any authenticated user enumerate every file in the bucket. Scoping to
-- `(storage.foldername(name))[1] = auth.uid()::text` only ever lets a
-- user see their own uploads, which is required for upsert against your
-- own file to work at all, and leaks nothing about other users' files.
create policy "Guides can view their own verification documents"
    on storage.objects for select
    to authenticated
    using (bucket_id = 'guide-documents' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Guides can view their own listing images"
    on storage.objects for select
    to authenticated
    using (bucket_id = 'listing-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- Also make the guide-documents UPDATE policy's WITH CHECK explicit
-- (previously relied on the USING-only default) -- harmless either way,
-- but keeping both buckets' policies in the same explicit shape.
drop policy if exists "Guides can replace their own verification documents" on storage.objects;
create policy "Guides can replace their own verification documents"
    on storage.objects for update
    to authenticated
    using (bucket_id = 'guide-documents' and (storage.foldername(name))[1] = auth.uid()::text)
    with check (bucket_id = 'guide-documents' and (storage.foldername(name))[1] = auth.uid()::text);
