// Called by database triggers (see add_push_notification_triggers.sql)
// right after a booking is requested, a booking's status changes, or a
// new message is sent -- never called directly by the app.
//
// verify_jwt is off for this function (config.toml) since the caller is a
// Postgres trigger, not a logged-in user with a real JWT. What actually
// gates this instead is a single-purpose shared secret (PUSH_WEBHOOK_SECRET)
// that only this function and the trigger's Vault entry know -- deliberately
// NOT the project's service_role key. A trigger only ever needs to do one
// thing here (ask for a push to be sent); handing it the full service_role
// key just to authenticate that would mean a compromised trigger function
// gets complete, RLS-bypassing database access as a side effect, which is a
// wildly bigger blast radius than this one call actually needs.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { sendPush } from "../_shared/apns.ts";

interface RequestBody {
  userId: string;
  title: string;
  body: string;
}

export default {
  fetch: withSupabase({ auth: "none" }, async (req, ctx) => {
    try {
      const expectedSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
      if (!expectedSecret || req.headers.get("x-webhook-secret") !== expectedSecret) {
        return Response.json({ error: "Unauthorized" }, { status: 401 });
      }

      const { userId, title, body } = (await req.json()) as RequestBody;
      if (!userId || !title || !body) {
        return Response.json({ error: "Missing userId/title/body" }, { status: 400 });
      }

      const { data: profile, error } = await ctx.supabaseAdmin
        .from("profiles")
        .select("device_push_token, notify_booking_updates")
        .eq("id", userId)
        .single();

      // Not an error -- most calls here are for a user who hasn't granted
      // notification permission (or hasn't opened the app since this
      // shipped, or opted out) yet. The trigger that called this doesn't
      // need to know or care either way.
      if (error || !profile?.device_push_token) {
        return Response.json({ sent: false, reason: "No device token on file" });
      }
      if (profile.notify_booking_updates === false) {
        return Response.json({ sent: false, reason: "Notifications disabled by user" });
      }

      await sendPush(profile.device_push_token, { title, body });
      return Response.json({ sent: true });
    } catch (error) {
      console.error("send-push-notification failed:", error);
      return Response.json({ error: "Could not send notification" }, { status: 500 });
    }
  }),
};
