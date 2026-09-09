// Builds the ES256 JWT Apple's APNs HTTP/2 API requires on every request
// (one token per ~55 minutes, reused across every push -- not one per
// device) and does the actual send. Needs three Edge Function secrets,
// all from the Apple Developer account (Certificates, Identifiers &
// Profiles -> Keys -> a Key with Apple Push Notifications service (APNs)
// enabled): APNS_KEY (the exact contents of the downloaded .p8 file),
// APNS_KEY_ID, APNS_TEAM_ID. Set via:
//   supabase secrets set APNS_KEY="$(cat AuthKey_XXXXXXXXXX.p8)" APNS_KEY_ID=XXXXXXXXXX APNS_TEAM_ID=XXXXXXXXXX
// -- run that from a terminal, never paste the key contents into chat.

const APNS_TOPIC = "com.robertlong.truguidz1"; // must exactly match the app's bundle id

let cachedToken: { jwt: string; expiresAt: number } | null = null;

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importSigningKey(pem: string): Promise<CryptoKey> {
  const stripped = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(stripped), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

async function getSigningJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.jwt;
  }

  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const pem = Deno.env.get("APNS_KEY")!;

  const header = base64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const payload = base64url(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: now })));
  const signingInput = `${header}.${payload}`;

  const key = await importSigningKey(pem);
  // WebCrypto's ECDSA signature output is already raw r||s (IEEE P1363),
  // which is exactly what a JWS ES256 signature needs -- no DER
  // conversion step required, unlike some other ECDSA use cases.
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${base64url(new Uint8Array(signature))}`;
  cachedToken = { jwt, expiresAt: now + 50 * 60 };
  return jwt;
}

export interface PushPayload {
  title: string;
  body: string;
}

// Tries production APNs first, falls back to the sandbox host on a
// BadDeviceToken response -- a Simulator/TestFlight-internal/Xcode debug
// build registers a sandbox token, which production APNs always rejects
// outright, and there's no way to tell which kind of token it is without
// just trying.
export async function sendPush(deviceToken: string, payload: PushPayload): Promise<void> {
  const jwt = await getSigningJWT();
  const body = JSON.stringify({
    aps: { alert: { title: payload.title, body: payload.body }, sound: "default" },
  });

  async function post(host: string): Promise<Response> {
    return fetch(`https://${host}/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": APNS_TOPIC,
        "apns-push-type": "alert",
      },
      body,
    });
  }

  let response = await post("api.push.apple.com");
  if (response.status === 400) {
    const errorBody = await response.clone().json().catch(() => ({} as Record<string, unknown>));
    if (errorBody.reason === "BadDeviceToken") {
      response = await post("api.sandbox.push.apple.com");
    }
  }

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`APNs request failed (${response.status}): ${errorText}`);
  }
}
