// Shared by every function that talks to Stripe's REST API directly (no
// Stripe SDK needed for this -- it's plain form-encoded HTTP). Functions
// starting with an underscore aren't deployed as their own endpoint;
// Supabase just skips them, which is what makes this importable from
// sibling functions via a relative path.
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;

export async function stripeRequest(
  path: string,
  body: Record<string, string> = {},
): Promise<any> {
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams(body),
  });
  const json = await response.json();
  if (!response.ok) {
    throw new Error(json.error?.message ?? `Stripe request to ${path} failed`);
  }
  return json;
}

// Read-only counterpart to stripeRequest -- used to re-verify a
// PaymentIntent's actual status server-side rather than trusting whatever
// the client claims happened.
export async function stripeGet(path: string): Promise<any> {
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method: "GET",
    headers: { Authorization: `Bearer ${STRIPE_SECRET_KEY}` },
  });
  const json = await response.json();
  if (!response.ok) {
    throw new Error(json.error?.message ?? `Stripe GET ${path} failed`);
  }
  return json;
}
