import { env } from "cloudflare:workers";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createApp } from "../src/worker";
import { signParams } from "../src/index.js";
import { ensureUser } from "../src/records";
import { cleanup } from "../src/media";
import { retryNotifications } from "../src/notifications";
import type { Bindings, Deps, Row } from "../src/types";

const NOW = 1800000000;
let keys: CryptoKeyPair, jwk: JsonWebKey, credentials: string;
let bindings: Bindings, deps: Deps, calls: string[];
let cloud: Row, fcmStatus: number;
const segment = (v: unknown) =>
  btoa(JSON.stringify(v))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
beforeAll(async () => {
  keys = (await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  )) as CryptoKeyPair;
  jwk = {
    ...((await crypto.subtle.exportKey("jwk", keys.publicKey)) as JsonWebKey),
    ...{ kid: "test-key" },
  };
  const raw = new Uint8Array(
    (await crypto.subtle.exportKey("pkcs8", keys.privateKey)) as ArrayBuffer,
  );
  credentials = JSON.stringify({
    project_id: "longevity-plate-beff9",
    client_email: "tests@example.iam.gserviceaccount.com",
    private_key: `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...raw))}\n-----END PRIVATE KEY-----`,
  });
});
beforeEach(() => {
  calls = [];
  fcmStatus = 200;
  cloud = {};
  bindings = {
    ...(env as unknown as Bindings),
    FIREBASE_PROJECT_ID: "longevity-plate-beff9",
    RATE_LIMIT: "1000",
    ADMIN_ORIGIN: "http://localhost:5173",
    CLOUDINARY_CLOUD_NAME: "test-cloud",
    CLOUDINARY_API_KEY: "key",
    CLOUDINARY_API_SECRET: "test-secret",
    FIREBASE_APP_ID: "1:1234:android:abcd",
    GOOGLE_SERVICE_ACCOUNT_JSON: credentials,
  };
  deps = {
    now: () => NOW,
    fetchKeys: async () => [jwk],
    fetch: async (url, init) => {
      const u = String(url);
      calls.push(u);
      if (u.includes("oauth2.googleapis.com"))
        return Response.json({ access_token: "test-oauth", expires_in: 3600 });
      if (u.includes("/resources/image/")) return Response.json(cloud);
      if (u.includes("/image/destroy")) return Response.json({ result: "ok" });
      if (u.includes("fcm.googleapis.com")) {
        const data = JSON.parse(String(init?.body)) as {
          message: { data: { targetUid: string } };
        };
        expect(data.message.data.targetUid).toBe("userA");
        return fcmStatus === 200
          ? Response.json({ name: "projects/test/messages/one" })
          : Response.json(
              {
                error:
                  fcmStatus === 404
                    ? { details: [{ errorCode: "UNREGISTERED" }] }
                    : { status: "UNAVAILABLE" },
              },
              { status: fcmStatus },
            );
      }
      if (u.endsWith("/reports"))
        return Response.json({
          reports: [{ name: "projects/1234/apps/test/reports/topIssues" }],
        });
      if (u.includes("/reports/topIssues"))
        return Response.json({
          groups: [
            {
              issue: { id: "issue-1", title: "Test SDK crash" },
              eventCount: 2,
            },
          ],
        });
      if (u.includes("/issues/"))
        return Response.json({
          id: "issue-1",
          title: "Test SDK crash",
          email: "redact@example.com",
        });
      if (u.includes("/events?"))
        return Response.json({
          events: [
            { id: "event-1", type: "FATAL", customKeys: { route: "/log" } },
          ],
        });
      return Response.json(
        { error: "unexpected-test-request" },
        { status: 500 },
      );
    },
  };
});
async function token(uid = "userA", claims: Row = {}, header: Row = {}) {
  const now = deps.now?.() ?? NOW;
  const h = segment({ alg: "RS256", kid: "test-key", ...header });
  const p = segment({
    aud: bindings.FIREBASE_PROJECT_ID,
    iss: `https://securetoken.google.com/${bindings.FIREBASE_PROJECT_ID}`,
    sub: uid,
    iat: now - 10,
    auth_time: now - 10,
    exp: now + 3600,
    ...claims,
  });
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    keys.privateKey,
    new TextEncoder().encode(`${h}.${p}`),
  );
  return `${h}.${p}.${btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")}`;
}
async function request(
  path: string,
  method = "GET",
  body?: unknown,
  uid: string | null = "userA",
  extra: Record<string, string> = {},
) {
  const headers: Record<string, string> = { ...extra };
  if (uid !== null) headers.Authorization = `Bearer ${await token(uid)}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const r = await createApp(deps).fetch(
    new Request(`https://api.test${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    }),
    bindings,
  );
  const data = (await r.json()) as Row;
  return { status: r.status, body: data, headers: r.headers };
}
const meal = { date: "2026-11-13", type: "lunch", description: "Cơm rau" };
const edit = (
  data: unknown = meal,
  baseVersion = 0,
  opId = crypto.randomUUID(),
) => ({ data, baseVersion, opId });
const rec = (r: { body: Row }) => r.body.record as Row;
async function admin() {
  await ensureUser(bindings.DB, "admin");
  await bindings.DB.prepare("INSERT INTO admin_users(uid) VALUES(?)")
    .bind("admin")
    .run();
}
async function register(
  uid = "userA",
  generation = 1,
  secret = "s".repeat(40),
) {
  return request(
    "/api/v1/devices/register",
    "POST",
    {
      installationId: "phone",
      installationSecret: secret,
      token: "fcm-registration-token-for-tests",
      generation,
      platform: "android",
      appVersion: "1.0",
    },
    uid,
  );
}
async function signPhoto() {
  await request("/api/v1/meals/meal-1", "PUT", edit());
  const result = await request("/api/v1/media/sign", "POST", {
    kind: "photo",
    mealId: "meal-1",
    contentHash: "a".repeat(64),
  });
  cloud = {
    public_id: result.body.publicId,
    version: 12,
    type: "authenticated",
    resource_type: "image",
    format: "jpg",
    bytes: 2048,
    width: 1200,
    height: 800,
  };
  return result.body;
}
async function receipt(ticket: Row) {
  return {
    publicId: ticket.publicId,
    version: "12",
    signature: await signParams(
      { public_id: ticket.publicId, version: "12" },
      "test-secret",
    ),
  };
}

describe("authentication and API boundaries", () => {
  it("unregister arriving before a delayed first register prevents reactivation", async () => {
    expect(
      (
        await request("/api/v1/devices/unregister", "POST", {
          installationId: "phone",
          installationSecret: "s".repeat(40),
          generation: 1,
        })
      ).status,
    ).toBe(200);
    expect((await register("userA", 1)).status).toBe(409);
    expect(
      (
        await bindings.DB.prepare(
          "SELECT active FROM device_tokens WHERE installation_id='phone'",
        ).first<Row>()
      )?.active,
    ).toBe(0);
    expect((await register("userA", 2)).status).toBe(200);
  });
  it("rejects stale expected meal revision before authorizing a photo", async () => {
    await request("/api/v1/meals/m1", "PUT", edit());
    await request(
      "/api/v1/meals/m1",
      "PUT",
      edit({ ...meal, description: "Other device" }, 1),
    );
    expect(
      (
        await request("/api/v1/media/sign", "POST", {
          kind: "photo",
          mealId: "m1",
          mealVersion: 1,
          contentHash: "c".repeat(64),
        })
      ).status,
    ).toBe(409);
    expect(
      (await bindings.DB.prepare("SELECT * FROM assets").all()).results,
    ).toHaveLength(0);
  });
  it("deleting a meal tombstones many pending uploads without one query per asset", async () => {
    await request("/api/v1/meals/m1", "PUT", edit());
    for (let n = 0; n < 30; n++)
      await request("/api/v1/media/sign", "POST", {
        kind: "photo",
        mealId: "m1",
        contentHash: n.toString(16).padStart(64, "0"),
      });
    const r = await request("/api/v1/meals/m1", "DELETE", edit({}, 1));
    expect(r.status).toBe(200);
    expect(
      (
        await bindings.DB.prepare(
          "SELECT COUNT(*) AS n FROM assets WHERE status='deleted'",
        ).first<Row>()
      )?.n,
    ).toBe(30);
    expect(
      (
        await bindings.DB.prepare(
          "SELECT COUNT(*) AS n FROM maintenance_jobs",
        ).first<Row>()
      )?.n,
    ).toBe(30);
  });
  it("public liveness exposes no provider credentials", async () => {
    const r = await request("/health", "GET", undefined, null);
    expect(r.status).toBe(200);
    expect(JSON.stringify(r.body)).not.toContain("test-secret");
  });
  it("requires a verified token", async () => {
    expect((await request("/api/v1/me", "GET", undefined, null)).status).toBe(
      401,
    );
  });
  it.each([
    { exp: NOW - 1 },
    { aud: "other" },
    { iss: "https://other" },
    { iat: NOW + 1000 },
    { auth_time: undefined },
    { exp: "9999999999" },
    { sub: "" },
  ])("rejects invalid claims %j", async (claims) => {
    const r = await createApp(deps).fetch(
      new Request("https://api.test/api/v1/me", {
        headers: { Authorization: `Bearer ${await token("userA", claims)}` },
      }),
      bindings,
    );
    expect(r.status).toBe(401);
  });
  it("rejects a forged signature and unknown signing key", async () => {
    for (const jwt of [
      `${await token()}x`,
      await token("userA", {}, { kid: "unknown" }),
    ]) {
      const r = await createApp(deps).fetch(
        new Request("https://api.test/api/v1/me", {
          headers: { Authorization: `Bearer ${jwt}` },
        }),
        bindings,
      );
      expect(r.status).toBe(401);
    }
  });
  it("does not let request payload elevate an admin role", async () => {
    expect((await request("/api/v1/admin/overview")).status).toBe(403);
    expect(
      (
        await request(
          "/api/v1/me/profile",
          "PUT",
          edit({
            displayName: "User",
            timezone: "Asia/Bangkok",
            isAdmin: true,
          }),
        )
      ).status,
    ).toBe(400);
  });
  it("enforces CORS including preflight", async () => {
    expect(
      (
        await request("/api/v1/me", "GET", undefined, "userA", {
          Origin: "https://evil.test",
        })
      ).status,
    ).toBe(403);
    const response = await createApp(deps).fetch(
      new Request("https://api.test/api/v1/me", {
        method: "OPTIONS",
        headers: { Origin: "http://localhost:5173" },
      }),
      bindings,
    );
    expect(response.status).toBe(204);
    expect(response.headers.get("Access-Control-Allow-Origin")).toBe(
      "http://localhost:5173",
    );
    const unauthorized = await request("/api/v1/me", "GET", undefined, null, {
      Origin: "http://localhost:5173",
    });
    expect(unauthorized.status).toBe(401);
    expect(unauthorized.headers.get("Access-Control-Allow-Origin")).toBe(
      "http://localhost:5173",
    );
  });
  it("bounds request bodies and list limits", async () => {
    expect(
      (
        await request(
          "/api/v1/meals/m1",
          "PUT",
          edit({ ...meal, description: "x".repeat(70000) }),
        )
      ).status,
    ).toBe(413);
    expect((await request("/api/v1/meals?limit=999")).status).toBe(400);
  });
  it("rate limits authenticated requests without exposing a token", async () => {
    bindings.RATE_LIMIT = "1";
    expect((await request("/api/v1/me")).status).toBe(200);
    const r = await request("/api/v1/me");
    expect(r.status).toBe(429);
    expect(JSON.stringify(r.body)).not.toContain("Bearer");
  });
  it("keeps private cache headers and request correlation IDs", async () => {
    const r = await request("/api/v1/me");
    expect(r.headers.get("Cache-Control")).toBe("no-store");
    expect(r.headers.get("X-Request-ID")).toBeTruthy();
  });
});
describe("D1 CRUD, revisions and synchronization", () => {
  it("stores validated meals, isolates UID and paginates", async () => {
    expect((await request("/api/v1/meals/m1", "PUT", edit())).status).toBe(200);
    await request("/api/v1/meals/m2", "PUT", edit());
    const list = await request("/api/v1/meals?limit=1");
    expect(list.body.items as Row[]).toHaveLength(1);
    expect(list.body.nextCursor).toBe("m1");
    expect(
      (await request("/api/v1/meals/m1", "GET", undefined, "userB")).status,
    ).toBe(404);
    expect(
      (await request("/api/v1/meals/m1", "PUT", edit(meal, 1), "userB")).status,
    ).toBe(404);
    expect(
      (await request("/api/v1/meals", "GET", undefined, "userB")).body
        .items as Row[],
    ).toHaveLength(0);
  });
  it("idempotent same-op retries do not create extra changes", async () => {
    const body = edit();
    const first = await request("/api/v1/meals/m1", "PUT", body);
    const repeat = await request("/api/v1/meals/m1", "PUT", body);
    expect(rec(first).version).toBe(1);
    expect(rec(repeat).version).toBe(1);
    const count = await bindings.DB.prepare(
      "SELECT count(*) AS total FROM changes",
    ).first<{ total: number }>();
    expect(count?.total).toBe(1);
    expect(
      (
        await request("/api/v1/meals/m1", "PUT", {
          ...body,
          data: { ...meal, description: "Changed" },
        })
      ).status,
    ).toBe(409);
  });
  it("rejects concurrent stale edits while preserving the winning version", async () => {
    await request("/api/v1/meals/m1", "PUT", edit());
    const results = await Promise.all([
      request(
        "/api/v1/meals/m1",
        "PUT",
        edit({ ...meal, description: "A" }, 1),
      ),
      request(
        "/api/v1/meals/m1",
        "PUT",
        edit({ ...meal, description: "B" }, 1),
      ),
    ]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 409]);
    expect(rec(await request("/api/v1/meals/m1")).version).toBe(2);
  });
  it("returns tombstones and a stable cursor for device-to-device pull", async () => {
    await request("/api/v1/meals/m1", "PUT", edit());
    const first = await request("/api/v1/sync/pull?cursor=0");
    const cursor = first.body.nextCursor;
    await request("/api/v1/meals/m1", "DELETE", edit({}, 1));
    expect((await request("/api/v1/meals/m1")).status).toBe(404);
    const next = await request(`/api/v1/sync/pull?cursor=${cursor}`);
    expect((next.body.items as Row[])[0].deletedAt).toBeTruthy();
  });
  it("push handles record conflicts independently, without trusting body uid", async () => {
    const r = await request("/api/v1/sync/push", "POST", {
      operations: [{ ...edit(), kind: "meal", id: "m1", deleted: false }],
    });
    expect(r.status).toBe(200);
    const bad = await request("/api/v1/sync/push", "POST", {
      uid: "userB",
      operations: [],
    });
    expect(bad.status).toBe(400);
  });
  it("validates dates, enums, descriptions and cannot inject SQL", async () => {
    for (const data of [
      { ...meal, date: "2026-02-31" },
      { ...meal, type: "invalid" },
      { ...meal, description: "" },
    ])
      expect(
        (await request("/api/v1/meals/m1", "PUT", edit(data))).status,
      ).toBe(400);
    const text = "x'); DROP TABLE users; --";
    expect(
      (
        await request(
          "/api/v1/meals/m1",
          "PUT",
          edit({ ...meal, description: text }),
        )
      ).status,
    ).toBe(200);
    expect(rec(await request("/api/v1/meals/m1")).data).toMatchObject({
      description: text,
    });
    expect(
      (
        await bindings.DB.prepare("SELECT count(*) AS total FROM users").first<{
          total: number;
        }>()
      )?.total,
    ).toBe(1);
  });
  it("supports profile, onboarding goals and weekly plan CRUD", async () => {
    expect(
      (
        await request(
          "/api/v1/me/profile",
          "PUT",
          edit({ displayName: "Test", timezone: "Asia/Bangkok" }),
        )
      ).status,
    ).toBe(200);
    expect(
      (await request("/api/v1/me/goals", "PUT", edit({ goals: ["logMeals"] })))
        .status,
    ).toBe(200);
    expect(rec(await request("/api/v1/me/goals")).data).toMatchObject({
      goals: ["logMeals"],
    });
    expect(
      (
        await request(
          "/api/v1/plans/2026-11-13_lunch",
          "PUT",
          edit({ date: meal.date, slot: "lunch", recipeId: "toast-egg" }),
        )
      ).status,
    ).toBe(200);
    expect(
      (await request("/api/v1/plans/2026-11-13_lunch", "DELETE", edit({}, 1)))
        .status,
    ).toBe(200);
  });
  it("database constraints prevent invalid asset ownership references", async () => {
    await expect(
      bindings.DB.prepare(
        "INSERT INTO assets(id,uid,kind,public_id,format,status,content_hash,expires_at,created_at,updated_at) VALUES('x','missing','photo','x','jpg','pending','x',0,'now','now')",
      ).run(),
    ).rejects.toThrow();
  });
});
describe("Cloudinary authorization and verified metadata", () => {
  it("signs a stable owner namespace and cannot access another UID", async () => {
    const ticket = await signPhoto();
    expect(ticket.publicId).toBe(`meal_photos/userA/meal-1/${"a".repeat(64)}`);
    const fields = ticket.fields as Record<string, string>;
    const { api_key, signature, ...params } = fields;
    expect(api_key).toBe("key");
    expect(signature).toBe(await signParams(params, "test-secret"));
    expect(
      (
        await request(
          `/api/v1/media/${ticket.assetId}/complete`,
          "POST",
          await receipt(ticket),
          "userB",
        )
      ).status,
    ).toBe(404);
  });
  it("confirms an actual provider asset and makes repeat confirmation idempotent", async () => {
    const ticket = await signPhoto();
    const body = await receipt(ticket);
    expect(
      (await request(`/api/v1/media/${ticket.assetId}/complete`, "POST", body))
        .status,
    ).toBe(200);
    expect(
      (await request(`/api/v1/media/${ticket.assetId}/complete`, "POST", body))
        .status,
    ).toBe(200);
    expect(calls.filter((c) => c.includes("/resources/image/"))).toHaveLength(
      1,
    );
    expect(rec(await request("/api/v1/meals/meal-1")).photoAsset).toMatchObject(
      { id: ticket.assetId, status: "ready" },
    );
    const link = await request(
      `/api/v1/media/${ticket.assetId}/url`,
      "POST",
      {},
    );
    expect(link.body.expiresAt).toBe(NOW + 900);
    expect(
      (
        await request(
          `/api/v1/media/${ticket.assetId}/url`,
          "POST",
          {},
          "userB",
        )
      ).status,
    ).toBe(404);
  });
  it("rejects a forged upload receipt before calling a provider", async () => {
    const ticket = await signPhoto();
    const r = await request(
      `/api/v1/media/${ticket.assetId}/complete`,
      "POST",
      { ...(await receipt(ticket)), signature: "0".repeat(40) },
    );
    expect(r.status).toBe(400);
    expect(calls).toHaveLength(0);
  });
  it("rejects oversized or wrong-format metadata and schedules safe cleanup", async () => {
    const ticket = await signPhoto();
    cloud.bytes = 6 * 1024 * 1024;
    expect(
      (
        await request(
          `/api/v1/media/${ticket.assetId}/complete`,
          "POST",
          await receipt(ticket),
        )
      ).status,
    ).toBe(400);
    const job = await bindings.DB.prepare(
      "SELECT run_after FROM maintenance_jobs",
    ).first<{ run_after: number }>();
    expect(job?.run_after).toBeGreaterThan(NOW + 3600);
    expect(
      (await request(`/api/v1/media/${ticket.assetId}/url`, "POST", {})).status,
    ).toBe(404);
  });
  it("does not let a deleted meal receive an attachment", async () => {
    const ticket = await signPhoto();
    await request("/api/v1/meals/meal-1", "DELETE", edit({}, 1));
    expect(
      (
        await request(
          `/api/v1/media/${ticket.assetId}/complete`,
          "POST",
          await receipt(ticket),
        )
      ).status,
    ).toBe(409);
  });
  it("expired upload sessions cannot be confirmed and errors preserve pending metadata", async () => {
    const ticket = await signPhoto();
    deps.now = () => NOW + 3601;
    expect(
      (
        await request(
          `/api/v1/media/${ticket.assetId}/complete`,
          "POST",
          await receipt(ticket),
        )
      ).status,
    ).toBe(409);
    const asset = await bindings.DB.prepare(
      "SELECT status FROM assets WHERE id=?",
    )
      .bind(ticket.assetId)
      .first<{ status: string }>();
    expect(asset?.status).toBe("pending");
  });
  it("supports authenticated PDF independently of a meal", async () => {
    const ticket = (
      await request("/api/v1/media/sign", "POST", {
        kind: "pdf",
        contentHash: "b".repeat(64),
      })
    ).body;
    expect((ticket.fields as Row).allowed_formats).toBe("pdf");
    expect(String(ticket.publicId)).toContain("reports/userA/");
  });
  it("reconciles a lost upload response using trusted provider metadata", async () => {
    const ticket = await signPhoto();
    const result = await request(
      `/api/v1/media/${ticket.assetId}/reconcile`,
      "POST",
      {},
    );
    expect(result.status).toBe(200);
    expect((result.body.meal as Row).version).toBe(2);
    const pull = await request("/api/v1/sync/pull");
    expect((pull.body.items as Row[]).at(-1)?.photoAsset).toMatchObject({
      id: ticket.assetId,
    });
  });
  it("does not silently attach a photo to a concurrently edited meal", async () => {
    const ticket = await signPhoto();
    await request(
      "/api/v1/meals/meal-1",
      "PUT",
      edit({ ...meal, description: "Other device edit" }, 1),
    );
    expect(
      (
        await request(
          `/api/v1/media/${ticket.assetId}/complete`,
          "POST",
          await receipt(ticket),
        )
      ).status,
    ).toBe(409);
    expect(rec(await request("/api/v1/meals/meal-1")).photoAsset).toBeNull();
  });
  it("keeps old PDF endpoints compatible", async () => {
    const r = await request("/reports/sign", "POST", {
      fileName: "meal-report-1762500000000.pdf",
    });
    expect(r.status).toBe(200);
    expect(r.body.publicId).toBe("reports/userA/meal-report-1762500000000");
  });
  it("cleanup only runs after signed-ticket replay window", async () => {
    const ticket = await signPhoto();
    await request(`/api/v1/media/${ticket.assetId}`, "DELETE");
    await cleanup(bindings, deps);
    expect(calls.some((c) => c.includes("/destroy"))).toBe(false);
    await cleanup(bindings, { ...deps, now: () => NOW + 4000 });
    expect(calls.some((c) => c.includes("/destroy"))).toBe(true);
  });
});
describe("device lifecycle and FCM outcomes", () => {
  it("registers and rotates tokens with installation proof", async () => {
    expect((await register()).status).toBe(200);
    expect((await register("userB", 2, "wrong".repeat(8))).status).toBe(403);
    expect((await register("userB", 2)).status).toBe(200);
    await request("/api/v1/devices/unregister", "POST", {
      installationId: "phone",
      installationSecret: "s".repeat(40),
      generation: 1,
    });
    const row = await bindings.DB.prepare(
      "SELECT uid,active FROM device_tokens",
    ).first<Row>();
    expect(row).toMatchObject({ uid: "userB", active: 1 });
  });
  it("only admins send, retries with the same request key do not duplicate", async () => {
    await register();
    await admin();
    const input = {
      targetUid: "userA",
      requestKey: "send-1",
      title: "Nhắc bữa ăn",
      body: "Mở nhật ký",
      route: "/log",
    };
    expect((await request("/api/v1/admin/push", "POST", input)).status).toBe(
      403,
    );
    const first = await request("/api/v1/admin/push", "POST", input, "admin");
    expect(first.status).toBe(201);
    expect((first.body.deliveries as Row[])[0].status).toBe("accepted");
    await request("/api/v1/admin/push", "POST", input, "admin");
    expect(calls.filter((c) => c.includes("fcm.googleapis.com"))).toHaveLength(
      1,
    );
    const history = await request("/api/v1/notifications");
    const notification = (history.body.items as Row[])[0];
    expect(
      (
        await request(
          `/api/v1/notifications/${notification.id}/open`,
          "POST",
          {},
        )
      ).status,
    ).toBe(200);
    expect(
      (
        await request(
          `/api/v1/notifications/${notification.id}/open`,
          "POST",
          {},
          "userB",
        )
      ).status,
    ).toBe(404);
  });
  it("invalid FCM tokens are deactivated, not marked delivered", async () => {
    await register();
    await admin();
    fcmStatus = 404;
    const r = await request(
      "/api/v1/admin/push",
      "POST",
      {
        targetUid: "userA",
        requestKey: "send-bad",
        title: "Test",
        body: "Test",
        route: "/log",
      },
      "admin",
    );
    expect((r.body.deliveries as Row[])[0]).toMatchObject({
      status: "failed",
      errorCode: "UNREGISTERED",
    });
    expect(
      (
        await bindings.DB.prepare(
          "SELECT active FROM device_tokens",
        ).first<Row>()
      )?.active,
    ).toBe(0);
  });
  it("known provider rejection retries with backoff and a finite attempt count", async () => {
    await register();
    await admin();
    fcmStatus = 503;
    const r = await request(
      "/api/v1/admin/push",
      "POST",
      {
        targetUid: "userA",
        requestKey: "send-retry",
        title: "Test",
        body: "Test",
        route: "/log",
      },
      "admin",
    );
    expect((r.body.deliveries as Row[])[0].status).toBe("retry");
    await retryNotifications(bindings, { ...deps, now: () => NOW + 31 });
    await retryNotifications(bindings, { ...deps, now: () => NOW + 100 });
    expect(
      await bindings.DB.prepare(
        "SELECT attempts,status FROM deliveries",
      ).first<Row>(),
    ).toMatchObject({ attempts: 3, status: "failed" });
  });
  it("rejects arbitrary routes and prevents token leakage in admin lists", async () => {
    await register();
    await admin();
    expect(
      (
        await request(
          "/api/v1/admin/push",
          "POST",
          {
            targetUid: "userA",
            requestKey: "bad-route",
            title: "Test",
            body: "Test",
            route: "https://evil.test",
          },
          "admin",
        )
      ).status,
    ).toBe(400);
    expect(
      JSON.stringify(
        (await request("/api/v1/admin/devices", "GET", undefined, "admin"))
          .body,
      ),
    ).not.toContain("fcm-registration-token-for-tests");
  });
});
describe("Admin and real-provider adapter contracts", () => {
  it("reads actual provider shapes, redacts PII and keeps provenance", async () => {
    await admin();
    const refresh = await request(
      "/api/v1/admin/crashlytics/refresh",
      "POST",
      {},
      "admin",
    );
    expect(refresh.status).toBe(200);
    expect(refresh.body.source).toBe("firebase-crashlytics");
    const cached = await request(
      "/api/v1/admin/crashlytics/issues",
      "GET",
      undefined,
      "admin",
    );
    expect(cached.body.fetchedAt).toBeTruthy();
    const detail = await request(
      "/api/v1/admin/crashlytics/issues/issue-1",
      "GET",
      undefined,
      "admin",
    );
    expect(JSON.stringify(detail.body)).not.toContain("redact@example.com");
    expect(detail.body.events).toMatchObject({ events: [{ type: "FATAL" }] });
    expect(
      (await request("/api/v1/admin/crashlytics/refresh", "POST", {}, "admin"))
        .status,
    ).toBe(429);
  });
  it("missing real credentials return a configuration error, never fake issues", async () => {
    await admin();
    bindings.GOOGLE_SERVICE_ACCOUNT_JSON = undefined;
    const r = await request(
      "/api/v1/admin/crashlytics/refresh",
      "POST",
      {},
      "admin",
    );
    expect(r.status).toBe(503);
    expect(
      (
        await request(
          "/api/v1/admin/crashlytics/issues",
          "GET",
          undefined,
          "admin",
        )
      ).body.payload,
    ).toBeNull();
  });
  it("Admin overview and search are paginated and server-authorized", async () => {
    await request("/api/v1/me");
    await admin();
    expect(
      (await request("/api/v1/admin/overview", "GET", undefined, "admin")).body
        .statistics,
    ).toMatchObject({ users: 2 });
    const search = await request(
      "/api/v1/admin/users?search=user&limit=1",
      "GET",
      undefined,
      "admin",
    );
    expect((search.body.items as Row[])[0].id).toBe("userA");
  });
});
