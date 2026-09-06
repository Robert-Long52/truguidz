// Called by the app the moment an explorer submits a booking request --
// this is the ONLY point in the whole flow where the explorer is actually
// present to authorize a card, so it's also the only point where a
// PaymentIntent can be created. capture_method: "manual" means the card is
// authorized (funds held) now but not actually charged until a guide
// confirms (stripe-capture-payment) or released if they decline
// (stripe-cancel-payment).
//
// Price is computed here from the listing, never trusted from the client --
// an explorer controlling their own request body could otherwise pay
// whatever amount they wanted for someone else's trip.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { stripeRequest } from "../_shared/stripe.ts";

const PLATFORM_FEE_RATE = 0.10;

interface RequestBody {
  listingId: string;
  numberOfGuests: number;
  hours?: number;
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const explorerId = ctx.userClaims?.id;
    if (!explorerId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    try {
      const { listingId, numberOfGuests, hours } = (await req.json()) as RequestBody;
      if (!listingId || !numberOfGuests || numberOfGuests < 1) {
        return Response.json({ error: "Missing or invalid listingId/numberOfGuests" }, { status: 400 });
      }

      const { data: listing, error: listingError } = await ctx.supabaseAdmin
        .from("listings")
        .select("guide_id, price_per_person, pricing_unit, max_group_size, trip_length, package_days")
        .eq("id", listingId)
        .single();

      if (listingError || !listing) {
        return Response.json({ error: "Listing not found" }, { status: 404 });
      }

      if (numberOfGuests > listing.max_group_size) {
        return Response.json({ error: "Too many guests for this listing" }, { status: 400 });
      }

      // Mirrors Listing.totalPrice(numberOfGuests:hours:) on the client --
      // this is the version that actually determines what gets charged,
      // the client-side one is only for showing an estimate before payment.
      const packageDayCount = listing.trip_length === "multi_day" ? Math.max(listing.package_days ?? 1, 1) : 1;

      let amount: number;
      switch (listing.pricing_unit) {
        case "per_hour": {
          const requestedHours = hours && hours > 0 ? hours : 1;
          if (requestedHours > 24) {
            return Response.json({ error: "Invalid hours" }, { status: 400 });
          }
          amount = listing.price_per_person * requestedHours;
          break;
        }
        case "per_day":
          amount = listing.price_per_person * packageDayCount;
          break;
        case "flat_rate":
          amount = listing.price_per_person;
          break;
        case "per_person":
        default:
          amount = listing.price_per_person * numberOfGuests;
          break;
      }

      const { data: guide, error: guideError } = await ctx.supabaseAdmin
        .from("profiles")
        .select("stripe_connect_id, stripe_charges_enabled")
        .eq("id", listing.guide_id)
        .single();

      if (guideError || !guide?.stripe_connect_id || !guide.stripe_charges_enabled) {
        return Response.json(
          { error: "This guide isn't set up to accept payments yet" },
          { status: 422 },
        );
      }

      const totalCents = Math.round(amount * 100);
      const applicationFeeCents = Math.round(totalCents * PLATFORM_FEE_RATE);

      const paymentIntent = await stripeRequest("payment_intents", {
        amount: String(totalCents),
        currency: "usd",
        capture_method: "manual",
        "payment_method_types[]": "card",
        "transfer_data[destination]": guide.stripe_connect_id,
        application_fee_amount: String(applicationFeeCents),
        "metadata[listing_id]": listingId,
        "metadata[explorer_id]": explorerId,
        "metadata[guide_id]": listing.guide_id,
      });

      return Response.json({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        totalPrice: totalCents / 100,
      });
    } catch (error) {
      console.error("stripe-create-payment-intent failed:", error);
      return Response.json({ error: "Could not create payment" }, { status: 500 });
    }
  }),
};
