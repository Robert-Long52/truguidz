// Called by the app when a guide taps "Confirm" on a pending booking.
// The card was already authorized back when the explorer requested the
// booking (stripe-create-payment-intent) -- this is the moment that
// authorization actually turns into a real charge, split between the
// guide's connected account and the platform fee.
//
// This is also the moment a guide could accidentally double-book
// themselves -- two explorers can competitively request the same day, and
// nothing should stop that, but only one of those requests should ever be
// allowed to actually become a confirmed, charged booking. A cheap
// upfront check covers the common case; the real guarantee is the
// database's own GiST exclusion constraint (bookings_no_overlapping_confirmed,
// see add_booking_conflict_prevention.sql), which is checked atomically as
// part of the UPDATE below and can't be raced the way a check-then-write
// in this code could be.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { stripeRequest } from "../_shared/stripe.ts";

const EXCLUSION_VIOLATION = "23P01";

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
        .select("guide_id, listing_id, status, date, end_date, stripe_payment_intent_id")
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

      if (!booking.stripe_payment_intent_id) {
        return Response.json({ error: "No payment to capture" }, { status: 422 });
      }

      // Cheap upfront check -- catches the common case (someone else's
      // request for an overlapping day already got confirmed) before ever
      // touching Stripe, so the explorer isn't charged just to be
      // immediately refunded. Doesn't need to be perfectly race-free on
      // its own; the exclusion constraint below is what actually
      // guarantees correctness. Uses the same RPC the constraint's logic
      // mirrors (whole-calendar-day overlap, not raw timestamp comparison)
      // rather than reimplementing it here -- a from-scratch version of
      // this check using plain .lte()/.gte() on the raw columns really did
      // miss a same-day conflict where the two bookings' timestamps landed
      // at different times of day, confirmed while testing this.
      const { data: hasConflict, error: conflictError } = await ctx.supabaseAdmin.rpc(
        "guide_has_confirmed_conflict",
        {
          p_guide_id: guideId,
          p_start_date: booking.date,
          p_end_date: booking.end_date,
          p_exclude_booking_id: bookingId,
        },
      );

      if (conflictError) {
        console.error("Failed to check for booking conflicts:", conflictError);
        return Response.json({ error: "Could not verify availability" }, { status: 500 });
      }

      if (hasConflict) {
        return Response.json(
          { error: "You already have a confirmed trip that overlaps this date." },
          { status: 409 },
        );
      }

      // Same idea as the confirmed-conflict check above, but against days
      // the guide manually blocked off on this listing (see
      // add_listing_blocked_dates.sql) rather than another booking. A
      // guide can still change their mind and confirm anyway by first
      // unblocking the date on the listing -- this only stops confirming
      // straight past a block by accident.
      const { data: blockedConflict, error: blockedError } = await ctx.supabaseAdmin.rpc(
        "listing_has_blocked_date_conflict",
        {
          p_listing_id: booking.listing_id,
          p_start_date: booking.date,
          p_end_date: booking.end_date,
        },
      );

      if (blockedError) {
        console.error("Failed to check for blocked-date conflicts:", blockedError);
        return Response.json({ error: "Could not verify availability" }, { status: 500 });
      }

      if (blockedConflict) {
        return Response.json(
          { error: "This date is blocked on your calendar. Unblock it on the listing first if you want to confirm this trip." },
          { status: 409 },
        );
      }

      await stripeRequest(`payment_intents/${booking.stripe_payment_intent_id}/capture`);

      // This function is the one thing that actually knows the capture
      // succeeded -- committing that to the booking row here (rather than
      // trusting the client to do it in a follow-up call) means the two
      // can never drift apart if the client loses network right after.
      const { error: updateError } = await ctx.supabaseAdmin
        .from("bookings")
        .update({ status: "confirmed" })
        .eq("id", bookingId);

      if (updateError) {
        // The rare true race: another confirmation for an overlapping day
        // slipped in between the check above and this update, and the
        // database's exclusion constraint caught it. The card was already
        // captured, so refund it immediately rather than leaving an
        // explorer charged for a trip that can now never happen -- same
        // reverse_transfer/refund_application_fee logic as
        // stripe-refund-payment, since money already moved to the guide's
        // connected account and the platform's fee.
        if (updateError.code === EXCLUSION_VIOLATION) {
          try {
            await stripeRequest("refunds", {
              payment_intent: booking.stripe_payment_intent_id,
              reverse_transfer: "true",
              refund_application_fee: "true",
            });
          } catch (refundError) {
            console.error(
              "Booking conflict AND compensating refund failed -- needs manual follow-up:",
              bookingId,
              refundError,
            );
          }
          await ctx.supabaseAdmin.from("bookings").update({ status: "cancelled" }).eq("id", bookingId);
          return Response.json(
            { error: "This date was just booked by someone else. You have not been charged." },
            { status: 409 },
          );
        }

        console.error("Captured payment but failed to update booking status:", updateError);
        return Response.json({ error: "Payment captured, but failed to update booking" }, { status: 500 });
      }

      return Response.json({ captured: true });
    } catch (error) {
      console.error("stripe-capture-payment failed:", error);
      return Response.json({ error: "Could not capture payment" }, { status: 500 });
    }
  }),
};
