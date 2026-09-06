// Stripe redirects the guide's browser here after they finish (or bail out
// of) the hosted Connect onboarding flow. There's no app to hand off to
// automatically (no custom URL scheme configured yet), so this is just a
// static page telling them to go back to TruGuidz by hand.
//
// Deliberately NOT using withSupabase here (confirmed live: it forces
// every response to Content-Type: text/plain plus a `default-src 'none';
// sandbox` CSP, no matter what headers the handler itself sets --
// presumably a safe-by-default guard against a JSON API accidentally
// serving exploitable HTML. That's the right default for the rest of
// these functions, which only ever return JSON, but this one specifically
// needs to serve a real styled page, and this route never touches auth or
// the database anyway (nothing here needs what withSupabase provides), so
// bypassing it entirely is a plain Deno.serve with no downside.
Deno.serve((req) => {
  const status = new URL(req.url).searchParams.get("status") ?? "complete";

  const message =
    status === "refresh"
      ? "That link expired before you finished. Open TruGuidz and tap Connect with Stripe again to get a new one."
      : "You can close this tab and return to TruGuidz.";

  const html = `<!doctype html>
<html>
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
  <body style="font-family: -apple-system, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 24px; text-align: center; background: #F3F5F0; color: #1C231D;">
    <p style="max-width: 320px; font-size: 17px;">${message}</p>
  </body>
</html>`;

  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } });
});
