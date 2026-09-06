// Stripe calls this directly (auth: 'none' -- it can't carry a Supabase
// session), so the ONLY thing standing between this endpoint and someone
// forging a fake "account.updated" event is verifying Stripe's signature
// ourselves. Stripe signs every webhook with a shared secret only Stripe
// and this function know; anyone who skips that check is trusting the
// internet to tell the truth about payments and account status.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

async function isValidStripeSignature(
  payload: string,
  header: string | null,
  secret: string,
): Promise<boolean> {
  if (!header) return false;

  const parts = Object.fromEntries(
    header.split(",").map((part) => part.split("=") as [string, string]),
  );
  const timestamp = parts["t"];
  const signature = parts["v1"];
  if (!timestamp || !signature) return false;

  // Stripe signs "<timestamp>.<raw request body>" -- has to be the exact
  // raw bytes, which is why we read the body as text once and reuse that
  // same string both for verification and (after) JSON.parse.
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${timestamp}.${payload}`),
  );
  const expected = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return expected === signature;
}

export default {
  fetch: withSupabase({ auth: "none" }, async (req, ctx) => {
    const payload = await req.text();
    const signatureHeader = req.headers.get("stripe-signature");

    if (!(await isValidStripeSignature(payload, signatureHeader, STRIPE_WEBHOOK_SECRET))) {
      return Response.json({ error: "Invalid signature" }, { status: 401 });
    }

    const event = JSON.parse(payload);

    if (event.type === "account.updated") {
      const account = event.data.object;

      const { error } = await ctx.supabaseAdmin
        .from("profiles")
        .update({ stripe_charges_enabled: account.charges_enabled === true })
        .eq("stripe_connect_id", account.id);

      if (error) {
        console.error("Failed to update stripe_charges_enabled:", error);
        return Response.json({ error: "Database update failed" }, { status: 500 });
      }
    }

    // Stripe expects a fast 2xx for every event type it sends, even ones
    // this function ignores -- otherwise it assumes delivery failed and
    // retries the same event repeatedly.
    return Response.json({ received: true });
  }),
};
