import Foundation
import Supabase

// One shared client for the whole app -- auth, database queries, and
// (later) storage all go through this same instance. The anon key is safe
// to ship in the app itself; it's Row Level Security policies on the
// database side, not secrecy of this key, that actually protect data.
//
// flowType: .implicit -- the SDK defaults to .pkce, but confirmed directly
// (curl-ing the real /recover -> /verify redirect chain for a real test
// account) that Supabase's password-recovery email link always redirects
// with tokens in the URL fragment (#access_token=...&type=recovery), the
// classic implicit-grant shape, never a PKCE ?code=. With the default PKCE
// setting, session(from:) rejected that real link outright as "not a valid
// PKCE flow URL" before ever getting a chance to use it -- silently, since
// nothing else in this app uses signInWithOAuth/PKCE-specific flows, so
// there's no downside to matching what the server actually sends.
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://mxihqtkrnmkfodzrpfam.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14aWhxdGtybm1rZm9kenJwZmFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3OTQwMjcsImV4cCI6MjEwMTM3MDAyN30.5c9jxO77CS3jbmznojOy7nVHLPuVuYXU28fkzhv_FTU",
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(flowType: .implicit)
    )
)
