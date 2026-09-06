// Called by the app when a guide taps "Decline" on a pending booking.
// Releases the card authorization from stripe-create-payment-intent --
// nothing was ever actually charged, so there's nothing to refund, just an
// authorization hold to let go of.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { stripeRequest } from "../_shared/stripe.ts";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const guideId = ctx.userClaims?.id;
    if (!guideId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    try {
      const { bookingId } = (await req.json()) as { bookingId: string };
      if (!bookingId) {
        return Response.json({ error: "Missing bookingId" }, { status: 400 });
      }

      const { data: booking, error: bookingError } = await ctx.supabaseAdmin
        .from("bookings")
        .select("guide_id, status, stripe_payment_intent_id")
        .eq("id", bookingId)
        .single();

      if (bookingError || !booking) {
        return Response.json({ error: "Booking not found" }, { status: 404 });
      }

      if (booking.guide_id !== guideId) {
        return Response.json({ error: "Not your booking" }, { status: 403 });
      }

      if (booking.status !== "pending") {
        return Response.json({ error: "Booking is not pending" }, { status: 409 });
      }

      if (booking.stripe_payment_intent_id) {
        await stripeRequest(`payment_intents/${booking.stripe_payment_intent_id}/cancel`);
      }

      const { error: updateError } = await ctx.supabaseAdmin
        .from("bookings")
        .update({ status: "cancelled" })
        .eq("id", bookingId);

      if (updateError) {
        console.error("Cancelled payment but failed to update booking status:", updateError);
        return Response.json({ error: "Payment cancelled, but failed to update booking" }, { status: 500 });
      }

      return Response.json({ cancelled: true });
    } catch (error) {
      console.error("stripe-cancel-payment failed:", error);
      return Response.json({ error: "Could not cancel payment" }, { status: 500 });
    }
  }),
};
