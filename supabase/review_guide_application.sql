-- Manual review helper for the interim (pre-Checkr) verification path.
-- Run the SELECT first to see who's waiting and where their ID photo
-- lives, go look at it in the Supabase dashboard under
-- Storage > guide-documents > {their id}/id-document.jpg, then run
-- whichever UPDATE matches your decision.

select id, name, email, phone_number, bio, years_experience, id_document_path, created_at
from public.profiles
where role = 'guide' and verification_status = 'pending'
order by created_at asc;

-- Approve (edit the email, then run):
-- update public.profiles
-- set verification_status = 'approved'
-- where email = 'guide@example.com'
-- returning id, email, verification_status;

-- Reject (edit the email, then run):
-- update public.profiles
-- set verification_status = 'rejected'
-- where email = 'guide@example.com'
-- returning id, email, verification_status;
