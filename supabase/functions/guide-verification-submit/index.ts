// Called once the verification fee PaymentIntent succeeds (or is skipped
// entirely -- see guide-verification-fee-intent's feeRequired:false branch,
// which is what's actually active right now while the fee is waived).
// Writes the guide application to the profile via service_role -- the
// profiles_protect_verification trigger (see
// add_verification_fee_and_checkr.sql) means only service_role can flip
// role/verification_status at all, so this function is the only path that
// can turn someone into a pending guide.
//
// No real Checkr call yet: the platform's own Checkr business
// credentialing isn't done, so for now this is manual review instead --
// an admin looks at id_document_path directly via the Supabase dashboard's
// Storage browser and flips verification_status by hand (see
// promote_test_guide.sql). Swapping in real Checkr later means adding a
// candidate-creation call here; nothing about this function's shape needs
// to change for that.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { stripeGet } from "../_shared/stripe.ts";

interface RequestBody {
  paymentIntentId?: string;
  phoneNumber: string;
  yearsExperience: number;
  bio: string;
  idDocumentPath: string;
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const userId = ctx.userClaims?.id;
    if (!userId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    try {
      const { paymentIntentId, phoneNumber, yearsExperience, bio, idDocumentPath } =
        (await req.json()) as RequestBody;

      if (!phoneNumber || !bio || !idDocumentPath) {
        return Response.json({ error: "Missing required fields" }, { status: 400 });
      }

      let feePaidAt: string | null = null;

      // Only exercised once the fee is turned back on -- never trust the
      // client's word that it paid, re-check the PaymentIntent itself.
      if (paymentIntentId) {
        const paymentIntent = await stripeGet(`payment_intents/${paymentIntentId}`);
        if (paymentIntent.status !== "succeeded" || paymentIntent.metadata?.applicant_id !== userId) {
          return Response.json({ error: "Payment could not be verified" }, { status: 402 });
        }
        feePaidAt = new Date().toISOString();
      }

      const { error } = await ctx.supabaseAdmin
        .from("profiles")
        .update({
          role: "guide",
          verification_status: "pending",
          phone_number: phoneNumber,
          years_experience: yearsExperience,
          bio,
          id_document_path: idDocumentPath,
          ...(feePaidAt ? { verification_fee_paid_at: feePaidAt } : {}),
        })
        .eq("id", userId);

      if (error) {
        console.error("Failed to save guide application:", error);
        return Response.json({ error: "Could not save application" }, { status: 500 });
      }

      return Response.json({ success: true });
    } catch (error) {
      console.error("guide-verification-submit failed:", error);
      return Response.json({ error: "Could not submit application" }, { status: 500 });
    }
  }),
};
