-- Interim manual-verification path: a guide applicant uploads a photo ID
-- instead of going through Checkr (blocked on the platform's own business
-- credentialing, not something to hold up guide applications on). An admin
-- reviews the uploaded document directly via the Supabase dashboard's
-- Storage browser (which uses a privileged login, not the app's RLS) and
-- flips verification_status by hand, the same way promote_test_guide.sql
-- already does. Swapping in real Checkr later only means adding a
-- candidate-creation call inside guide-verification-submit -- this storage
-- path and column don't need to change.
alter table public.profiles
    add column if not exists id_document_path text;

-- Unlike listing-images, this bucket is NOT public -- these are photo IDs.
-- No SELECT policy at all: nobody should be able to read these back
-- through the API, including the uploader. Only a dashboard login
-- (service_role-equivalent) or the Storage browser can see the actual
-- files.
insert into storage.buckets (id, name, public)
values ('guide-documents', 'guide-documents', false)
on conflict (id) do nothing;

drop policy if exists "Guides can upload their own verification documents" on storage.objects;
create policy "Guides can upload their own verification documents"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'guide-documents'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Guides can replace their own verification documents" on storage.objects;
create policy "Guides can replace their own verification documents"
    on storage.objects for update
    to authenticated
    using (
        bucket_id = 'guide-documents'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
