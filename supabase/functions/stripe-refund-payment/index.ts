// Called when an explorer cancels a booking that's already been confirmed
// and charged (stripe-capture-payment already split the money between the
// guide's connected account and the platform's application fee, via the
// destination-charge setup in stripe-create-payment-intent). A plain
// refund would only pull money back out of the *platform's* own balance,
// leaving the guide quietly holding onto their payout -- reverse_transfer
// and refund_application_fee explicitly claw both of those back too, so
// the cost of the refund lands back where the money actually went instead
// of being eaten entirely by the platform.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { stripeRequest } from "../_shared/stripe.ts";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const explorerId = ctx.userClaims?.id;
    if (!explorerId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    try {
      const { bookingId } = (await req.json()) as { bookingId: string };
      if (!bookingId) {
        return Response.json({ error: "Missing bookingId" }, { status: 400 });
      }

      const { data: booking, error: bookingError } = await ctx.supabaseAdmin
        .from("bookings")
        .select("explorer_id, status, stripe_payment_intent_id")
        .eq("id", bookingId)
        .single();

      if (bookingError || !booking) {
        return Response.json({ error: "Booking not found" }, { status: 404 });
      }

      if (booking.explorer_id !== explorerId) {
        return Response.json({ error: "Not your booking" }, { status: 403 });
      }

      // Only a confirmed (captured/charged) booking has real money to
      // refund -- a still-pending one was only ever authorized, which is
      // what stripe-cancel-payment (a separate, guide-only decline path)
      // already handles by voiding the hold instead.
      if (booking.status !== "confirmed") {
        return Response.json({ error: "Booking is not confirmed" }, { status: 409 });
      }

      if (!booking.stripe_payment_intent_id) {
        return Response.json({ error: "No payment to refund" }, { status: 422 });
      }

      await stripeRequest("refunds", {
        payment_intent: booking.stripe_payment_intent_id,
        reverse_transfer: "true",
        refund_application_fee: "true",
      });

      // Same reasoning as every other payment function here: this is the
      // one place that actually knows the refund succeeded, so it commits
      // that to the booking row itself rather than trusting a follow-up
      // client call that might never arrive.
      const { error: updateError } = await ctx.supabaseAdmin
        .from("bookings")
        .update({ status: "cancelled" })
        .eq("id", bookingId);

      if (updateError) {
        console.error("Refunded payment but failed to update booking status:", updateError);
        return Response.json({ error: "Payment refunded, but failed to update booking" }, { status: 500 });
      }

      return Response.json({ refunded: true });
    } catch (error) {
      console.error("stripe-refund-payment failed:", error);
      return Response.json({ error: "Could not refund payment" }, { status: 500 });
    }
  }),
};
