update public.profiles
set role = 'guide', verification_status = 'approved'
where email = 'longrobert759@gmail.com'
returning id, email, role, verification_status;
