// Called by the app when a guide wants to connect a payout account. Creates
// a Stripe Express account for them the first time (stores the id on their
// profile via the admin client, bypassing RLS the same way handle_new_user
// does in Postgres), then always returns a fresh onboarding link -- Account
// Links expire quickly, so this is safe to call again if a guide re-opens
// the flow later.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { stripeRequest } from "../_shared/stripe.ts";

// Used to be the stripe-connect-return Edge Function -- confirmed live
// that Supabase's function gateway forces every function response to
// Content-Type: text/plain (plus a locked-down CSP) no matter what
// headers the function itself sets, so a guide finishing onboarding saw
// raw HTML source instead of the styled "you can close this tab" page.
// A plain static page on the same site as the privacy policy/support
// pages has no such restriction.
const CONNECT_RETURN_URL = "https://robert-long52.github.io/truguidz-legal/connect-return.html";

export default {
  fetch: withSupabase({ auth: "user" }, async (_req, ctx) => {
    const userId = ctx.userClaims?.id;
    if (!userId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    try {
      const { data: profile, error: profileError } = await ctx.supabaseAdmin
        .from("profiles")
        .select("role, stripe_connect_id, email")
        .eq("id", userId)
        .single();

      if (profileError || !profile) {
        return Response.json({ error: "Profile not found" }, { status: 404 });
      }

      if (profile.role !== "guide") {
        return Response.json({ error: "Only guides can connect a Stripe account" }, { status: 403 });
      }

      let accountId = profile.stripe_connect_id as string | null;

      if (!accountId) {
        const account = await stripeRequest("accounts", {
          type: "express",
          email: profile.email,
          "capabilities[card_payments][requested]": "true",
          "capabilities[transfers][requested]": "true",
        });
        accountId = account.id;

        const { error: updateError } = await ctx.supabaseAdmin
          .from("profiles")
          .update({ stripe_connect_id: accountId })
          .eq("id", userId);

        if (updateError) {
          return Response.json({ error: "Failed to save Stripe account id" }, { status: 500 });
        }
      }

      const accountLink = await stripeRequest("account_links", {
        account: accountId!,
        refresh_url: `${CONNECT_RETURN_URL}?status=refresh`,
        return_url: `${CONNECT_RETURN_URL}?status=complete`,
        type: "account_onboarding",
      });

      return Response.json({ url: accountLink.url });
    } catch (error) {
      console.error("stripe-connect-onboarding failed:", error);
      return Response.json({ error: "Could not create onboarding link" }, { status: 500 });
    }
  }),
};
