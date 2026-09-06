-- Tracks whether a guide's Stripe Connect account can actually receive
-- payouts yet. Separate from stripe_connect_id existing -- an Express
-- account can be created but still have incomplete onboarding (no bank
-- account added, etc.), during which Stripe won't let it accept charges.
-- Named to match Stripe's own account field (charges_enabled) so it's
-- obvious what sets it: a future stripe-webhook function, on account.updated.
alter table public.profiles
    add column if not exists stripe_charges_enabled boolean not null default false;
