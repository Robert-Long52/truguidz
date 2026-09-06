-- Liability waiver / ToS acceptance tracking. Real legal text still needs
-- to come from a lawyer -- this is the tracking mechanism, wired up now
-- with clearly-marked placeholder copy so it's ready to go the moment
-- real text exists (see LiabilityWaiverView.swift).
--
-- Deliberately just two columns on profiles rather than a separate
-- versioned-acceptance-history table -- simplest thing that works for a
-- single current waiver. A history table is easy to add later if this
-- ever needs to track acceptance of multiple distinct documents
-- (e.g. a separate guide agreement vs. explorer liability waiver) or a
-- real audit trail of every version someone has accepted over time.
--
-- No RLS/trigger changes needed: the existing "Users can update their own
-- profile" policy already allows a user to set these two columns on their
-- own row (they're not gated like role/verification_status are).
alter table public.profiles
    add column if not exists waiver_accepted_at timestamptz;

alter table public.profiles
    add column if not exists waiver_version text;
