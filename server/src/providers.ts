import { z } from "zod";
import { ApiError, need, type Bindings, type Deps, type Row } from "./types";

export async function providerJson(
  url: string,
  init: RequestInit,
  deps: Deps,
): Promise<Row> {
  let response: Response;
  try {
    response = await (deps.fetch ?? fetch)(url, {
      ...init,
      signal: AbortSignal.timeout(20000),
    });
  } catch {
    throw new ApiError(504, "provider_result_unknown", false);
  }
  if (!response.ok) {
    const retryable = response.status === 429 || response.status >= 500;
    let providerCode: string | undefined;
    try {
      const body = (await response.json()) as {
        error?: { details?: { errorCode?: string }[] };
      };
      const value = body.error?.details?.find((d) => d.errorCode)?.errorCode;
      if (value && ["UNREGISTERED", "SENDER_ID_MISMATCH"].includes(value))
        providerCode = value;
    } catch {
      /* Only expose a small allowlist of provider error codes. */
    }
    throw new ApiError(
      retryable ? 503 : 502,
      `provider_http_${response.status}`,
      retryable,
      providerCode,
    );
  }
  try {
    const data: unknown = await response.json();
    if (!data || typeof data !== "object" || Array.isArray(data))
      throw new Error();
    return data as Row;
  } catch {
    throw new ApiError(502, "invalid_provider_response");
  }
}
const credentialSchema = z.object({
  project_id: z.string(),
  client_email: z.string().email(),
  private_key: z.string().min(50),
});
const tokenCache = new Map<string, { token: string; until: number }>();
function base64(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}
export async function googleAccessToken(
  env: Bindings,
  scope: string,
  deps: Deps,
) {
  let credentials: z.infer<typeof credentialSchema>;
  try {
    credentials = credentialSchema.parse(
      JSON.parse(need(env.GOOGLE_SERVICE_ACCOUNT_JSON)),
    );
  } catch {
    throw new ApiError(503, "google_credential_not_configured");
  }
  if (credentials.project_id !== env.FIREBASE_PROJECT_ID)
    throw new ApiError(503, "google_project_mismatch");
  const now = deps.now?.() ?? Math.floor(Date.now() / 1000);
  const key = `${credentials.client_email}:${scope}`;
  const cached = tokenCache.get(key);
  if (cached && cached.until > now + 60) return cached.token;
  const segment = (value: unknown) =>
    base64(new TextEncoder().encode(JSON.stringify(value)));
  const head = segment({ alg: "RS256", typ: "JWT" });
  const payload = segment({
    iss: credentials.client_email,
    scope,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  });
  let signingKey: CryptoKey;
  try {
    const raw = atob(
      credentials.private_key
        .replace(/-----[^-]+-----/g, "")
        .replace(/\s/g, ""),
    );
    signingKey = await crypto.subtle.importKey(
      "pkcs8",
      Uint8Array.from(raw, (c) => c.charCodeAt(0)),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );
  } catch {
    throw new ApiError(503, "invalid_google_credential");
  }
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    signingKey,
    new TextEncoder().encode(`${head}.${payload}`),
  );
  const data = await providerJson(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: `${head}.${payload}.${base64(new Uint8Array(sig))}`,
      }).toString(),
    },
    deps,
  );
  if (typeof data.access_token !== "string")
    throw new ApiError(502, "invalid_oauth_response");
  tokenCache.set(key, {
    token: data.access_token,
    until: now + Math.min(Number(data.expires_in) || 300, 3600),
  });
  return data.access_token;
}
export async function crashRequest(env: Bindings, suffix: string, deps: Deps) {
  const appId = need(env.FIREBASE_APP_ID);
  if (!/^1:\d+:(android|ios):[a-zA-Z0-9]+$/.test(appId))
    throw new ApiError(503, "invalid_firebase_app_id");
  const projectNumber = appId.split(":")[1];
  const token = await googleAccessToken(
    env,
    "https://www.googleapis.com/auth/cloud-platform",
    deps,
  );
  return providerJson(
    `https://firebasecrashlytics.googleapis.com/v1alpha/projects/${projectNumber}/apps/${appId}/${suffix}`,
    { headers: { Authorization: `Bearer ${token}` } },
    deps,
  );
}
export async function cloudAsset(env: Bindings, publicId: string, deps: Deps) {
  const cloud = need(env.CLOUDINARY_CLOUD_NAME);
  return providerJson(
    `https://api.cloudinary.com/v1_1/${encodeURIComponent(cloud)}/resources/image/authenticated/${encodeURIComponent(publicId)}`,
    {
      headers: {
        Authorization: `Basic ${btoa(`${need(env.CLOUDINARY_API_KEY)}:${need(env.CLOUDINARY_API_SECRET)}`)}`,
      },
    },
    deps,
  );
}
