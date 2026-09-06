// Apple App Store Review Guideline 5.1.1(v) requires that any app
// supporting account creation also let a user delete their account
// entirely within the app -- not just via an emailed request. This is
// that flow.
//
// This can't be a simple `delete from profiles` or a call to Supabase
// Auth's admin delete-user endpoint: bookings/messages/reviews all
// reference profiles.id with ON DELETE NO ACTION (deliberately, so a
// booking's own history survives even if the other party's account later
// changes), and profiles.id itself cascades from auth.users. Deleting the
// auth.users row would cascade into profiles, which would then
// immediately hit those NO ACTION constraints and roll the whole thing
// back -- for almost any account that's ever booked, messaged, or
// reviewed, i.e. nearly every real account.
//
// So instead: anonymize the profile in place, deactivate any listings so
// they stop being bookable, remove the ID document from storage if one
// exists, and separately revoke sign-in via Supabase Auth's ban
// mechanism -- no row deletion involved, so none of those FK constraints
// ever come into play.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const userId = ctx.userClaims?.id;
    if (!userId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    try {
      const { data: profile, error: fetchError } = await ctx.supabaseAdmin
        .from("profiles")
        .select("id_document_path")
        .eq("id", userId)
        .single();

      if (fetchError || !profile) {
        return Response.json({ error: "Could not find your account" }, { status: 404 });
      }

      if (profile.id_document_path) {
        await ctx.supabaseAdmin.storage.from("guide-documents").remove([profile.id_document_path]);
      }

      // Hiding a guide's listings from the Explore feed, not deleting
      // them -- a hard delete would hit the same NO ACTION problem via
      // bookings.listing_id for any listing that's ever been booked.
      await ctx.supabaseAdmin
        .from("listings")
        .update({ is_active: false })
        .eq("guide_id", userId);

      const { error: updateError } = await ctx.supabaseAdmin
        .from("profiles")
        .update({
          name: "Deleted User",
          email: `deleted-${userId}@truguidz.deleted`,
          phone_number: null,
          bio: null,
          years_experience: null,
          profile_image_url: null,
          id_document_path: null,
          stripe_connect_id: null,
          checkr_candidate_id: null,
          checkr_report_id: null,
          deleted_at: new Date().toISOString(),
        })
        .eq("id", userId);

      if (updateError) {
        console.error("Failed to anonymize profile:", updateError);
        return Response.json({ error: "Could not delete your account" }, { status: 500 });
      }

      const { error: banError } = await ctx.supabaseAdmin.auth.admin.updateUserById(userId, {
        ban_duration: "876000h",
      });

      if (banError) {
        console.error("Failed to ban user after anonymizing profile:", banError);
        return Response.json(
          { error: "Your data was removed, but we couldn't fully disable sign-in. Contact support." },
          { status: 500 },
        );
      }

      return Response.json({ success: true });
    } catch (error) {
      console.error("delete-account failed:", error);
      return Response.json({ error: "Could not delete your account" }, { status: 500 });
    }
  }),
};
