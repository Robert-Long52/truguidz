// Called when someone submits the guide application, before anything else
// happens -- this charges a flat fee that covers the cost of actually
// running a Checkr background check (guide-verification-submit only fires
// after this PaymentIntent succeeds). Unlike the booking payment flow,
// there's no Connect destination here: this fee is the platform's own
// cost to cover, not a payout to anyone, so it's a plain charge straight
// to the platform's Stripe account and captures immediately -- there's no
// "decision" later that would need to release an authorization hold.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { stripeRequest } from "../_shared/stripe.ts";

// A Supabase secret, not a hardcoded constant, specifically so the fee can
// be changed (or eventually waived) with `supabase secrets set` alone --
// no redeploy. Defaults to $35 if unset. Stripe won't create a $0
// PaymentIntent at all, so waiving the fee later needs the feeRequired:
// false branch below, not just setting this to "0" -- that's already
// wired up on both ends (see GuideApplicationView.swift) even though
// nothing sets it to 0 today.
const feeCentsRaw = Deno.env.get("GUIDE_VERIFICATION_FEE_CENTS");
const GUIDE_VERIFICATION_FEE_CENTS = feeCentsRaw ? parseInt(feeCentsRaw, 10) : 3500;

export default {
  fetch: withSupabase({ auth: "user" }, async (_req, ctx) => {
    const userId = ctx.userClaims?.id;
    if (!userId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    try {
      const { data: profile, error: profileError } = await ctx.supabaseAdmin
        .from("profiles")
        .select("role, verification_status, email")
        .eq("id", userId)
        .single();

      if (profileError || !profile) {
        return Response.json({ error: "Profile not found" }, { status: 404 });
      }

      if (profile.role === "guide" && profile.verification_status === "approved") {
        return Response.json({ error: "You're already an approved guide" }, { status: 409 });
      }

      if (GUIDE_VERIFICATION_FEE_CENTS <= 0) {
        return Response.json({ feeRequired: false });
      }

      const paymentIntent = await stripeRequest("payment_intents", {
        amount: String(GUIDE_VERIFICATION_FEE_CENTS),
        currency: "usd",
        "payment_method_types[]": "card",
        // Both shown on Stripe's dashboard/receipt -- the point is that this
        // reads as a real, itemized business expense (a background check
        // required to work as a guide), not a vague unexplained charge, in
        // case whoever's paying it wants to keep it for their own taxes.
        description: "TruGuidz Guide Verification & Background Check Fee",
        receipt_email: profile.email,
        "metadata[applicant_id]": userId,
        "metadata[purpose]": "guide_verification_fee",
      });

      return Response.json({
        feeRequired: true,
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      });
    } catch (error) {
      console.error("guide-verification-fee-intent failed:", error);
      return Response.json({ error: "Could not create payment" }, { status: 500 });
    }
  }),
};
