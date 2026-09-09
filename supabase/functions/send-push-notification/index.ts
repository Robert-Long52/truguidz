// Called by database triggers (see add_push_notification_triggers.sql)
// right after a booking is requested, a booking's status changes, or a
// new message is sent -- never called directly by the app. The platform's
// own verify_jwt gate (config.toml) is what actually protects this: a
// trigger authenticates with the project's service_role key (a real,
// validly-signed JWT for this project, available to Postgres via the
// built-in app.settings.service_role_key -- see the trigger SQL), so a
// stranger without that key can't reach this at all.
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
