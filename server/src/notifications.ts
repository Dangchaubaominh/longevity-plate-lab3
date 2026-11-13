import { Hono } from "hono";
import {
  ApiError,
  boundedJson,
  digest,
  nowIso,
  type AppEnv,
  type Bindings,
  type Deps,
  type Row,
} from "./types";
import { campaign, device, unregister } from "./schemas";
import { googleAccessToken, providerJson } from "./providers";
import { audit } from "./records";

export function deviceRoutes() {
  const app = new Hono<AppEnv>();
  app.post("/register", async (c) => {
    const input = device.parse(await boundedJson(c.req.raw));
    const uid = c.get("uid");
    const hash = await digest(input.installationSecret);
    const old = await c.env.DB.prepare(
      "SELECT * FROM device_tokens WHERE installation_id=?",
    )
      .bind(input.installationId)
      .first<Row>();
    if (old && old.secret_hash !== hash)
      throw new ApiError(403, "invalid_installation_proof");
    if (old && Number(old.generation) > input.generation)
      throw new ApiError(409, "stale_device_registration");
    if (
      old &&
      Number(old.generation) === input.generation &&
      (old.uid !== uid || old.token !== input.token || old.active !== 1)
    )
      throw new ApiError(409, "stale_device_registration");
    const collision = await c.env.DB.prepare(
      "SELECT installation_id FROM device_tokens WHERE token=? AND installation_id<>?",
    )
      .bind(input.token, input.installationId)
      .first();
    if (collision) throw new ApiError(409, "token_already_registered");
    const saved = await c.env.DB.prepare(
      `INSERT INTO device_tokens(installation_id,uid,token,secret_hash,generation,active,platform,app_version,updated_at) VALUES(?,?,?,?,?,1,?,?,?)
   ON CONFLICT(installation_id) DO UPDATE SET uid=excluded.uid,token=excluded.token,generation=excluded.generation,active=1,platform=excluded.platform,app_version=excluded.app_version,updated_at=excluded.updated_at WHERE device_tokens.secret_hash=excluded.secret_hash AND (device_tokens.generation<excluded.generation OR (device_tokens.generation=excluded.generation AND device_tokens.active=1 AND device_tokens.uid=excluded.uid AND device_tokens.token=excluded.token))`,
    )
      .bind(
        input.installationId,
        uid,
        input.token,
        hash,
        input.generation,
        input.platform,
        input.appVersion,
        nowIso(),
      )
      .run();
    if (!saved.meta.changes)
      throw new ApiError(409, "stale_device_registration");
    return c.json({ registered: true });
  });
  app.post("/unregister", async (c) => {
    const input = unregister.parse(await boundedJson(c.req.raw));
    await c.env.DB.prepare(
      `INSERT INTO device_tokens(installation_id,uid,token,secret_hash,generation,active,platform,app_version,updated_at) VALUES(?,?,?,?,?,0,'android','',?) ON CONFLICT(installation_id) DO UPDATE SET active=0,updated_at=excluded.updated_at WHERE device_tokens.uid=excluded.uid AND device_tokens.generation=excluded.generation AND device_tokens.secret_hash=excluded.secret_hash`,
    )
      .bind(
        input.installationId,
        c.get("uid"),
        "inactive:" + crypto.randomUUID(),
        await digest(input.installationSecret),
        input.generation,
        nowIso(),
      )
      .run();
    return c.json({ unregistered: true });
  });
  return app;
}
export function pushAdminRoutes(deps: Deps) {
  const app = new Hono<AppEnv>();
  app.get("/devices", async (c) => {
    const limit = pageSize(c.req.query("limit"));
    const cursor = c.req.query("cursor") ?? "";
    const rows = await c.env.DB.prepare(
      "SELECT installation_id AS installationId,uid,platform,app_version AS appVersion,active,updated_at AS updatedAt FROM device_tokens WHERE installation_id>? ORDER BY installation_id LIMIT ?",
    )
      .bind(cursor, limit + 1)
      .all<Row>();
    return c.json(page(rows.results, limit, "installationId"));
  });
  app.post("/push", async (c) => {
    const input = campaign.parse(await boundedJson(c.req.raw));
    const actor = c.get("uid");
    const db = c.env.DB;
    const hash = await digest(JSON.stringify(input));
    const previous = await db
      .prepare("SELECT * FROM campaigns WHERE actor_uid=? AND request_key=?")
      .bind(actor, input.requestKey)
      .first<Row>();
    if (previous) {
      if (previous.request_hash !== hash)
        throw new ApiError(409, "idempotency_conflict");
      return c.json(await campaignResult(db, String(previous.id)));
    }
    // Fail before creating an attempted campaign when server credentials are absent.
    await googleAccessToken(
      c.env,
      "https://www.googleapis.com/auth/firebase.messaging",
      deps,
    );
    const devices = await db
      .prepare("SELECT * FROM device_tokens WHERE uid=? AND active=1 LIMIT 6")
      .bind(input.targetUid)
      .all<Row>();
    if (!devices.results.length) throw new ApiError(409, "no_active_devices");
    if (devices.results.length > 5)
      throw new ApiError(400, "recipient_limit_exceeded");
    const id = crypto.randomUUID();
    const created = await db
      .prepare(
        "INSERT INTO campaigns(id,actor_uid,target_uid,request_key,request_hash,title,body,route,status,created_at) VALUES(?,?,?,?,?,?,?,?,'processing',?) ON CONFLICT(actor_uid,request_key) DO NOTHING",
      )
      .bind(
        id,
        actor,
        input.targetUid,
        input.requestKey,
        hash,
        input.title,
        input.body,
        input.route,
        nowIso(),
      )
      .run();
    if (created.meta.changes === 0) {
      const existing = await db
        .prepare(
          "SELECT id,request_hash FROM campaigns WHERE actor_uid=? AND request_key=?",
        )
        .bind(actor, input.requestKey)
        .first<Row>();
      if (existing?.request_hash !== hash)
        throw new ApiError(409, "idempotency_conflict");
      return c.json(await campaignResult(db, String(existing.id)));
    }
    const statements = devices.results.map((d) =>
      db
        .prepare(
          "INSERT INTO deliveries(id,campaign_id,uid,installation_id,status,updated_at) VALUES(?,?,?,?,'pending',?)",
        )
        .bind(
          crypto.randomUUID(),
          id,
          input.targetUid,
          d.installation_id,
          nowIso(),
        ),
    );
    await db.batch(statements);
    await audit(db, actor, "push.send", id, c.get("requestId"));
    const deliveries = await db
      .prepare("SELECT id FROM deliveries WHERE campaign_id=?")
      .bind(id)
      .all<Row>();
    for (const delivery of deliveries.results)
      await sendDelivery(c.env, String(delivery.id), deps);
    await db
      .prepare("UPDATE campaigns SET status='processed' WHERE id=?")
      .bind(id)
      .run();
    return c.json(await campaignResult(db, id), 201);
  });
  app.get("/push-jobs", async (c) => {
    const limit = pageSize(c.req.query("limit"));
    const cursor = c.req.query("cursor") ?? "";
    const rows = await c.env.DB.prepare(
      "SELECT id,target_uid AS targetUid,title,body,route,status,created_at AS createdAt FROM campaigns WHERE id>? ORDER BY id LIMIT ?",
    )
      .bind(cursor, limit + 1)
      .all<Row>();
    return c.json(page(rows.results, limit));
  });
  app.get("/push-jobs/:id", async (c) => {
    const result = await campaignResult(c.env.DB, c.req.param("id"));
    if (!result.campaign) throw new ApiError(404, "not_found");
    return c.json(result);
  });
  return app;
}
export async function campaignResult(db: D1Database, id: string) {
  const campaign = await db
    .prepare(
      "SELECT id,title,body,route,status,created_at AS createdAt,target_uid AS targetUid FROM campaigns WHERE id=?",
    )
    .bind(id)
    .first();
  const deliveries = await db
    .prepare(
      "SELECT id,installation_id AS installationId,status,message_id AS messageId,error_code AS errorCode,attempts,opened_at AS openedAt FROM deliveries WHERE campaign_id=?",
    )
    .bind(id)
    .all();
  return { campaign, deliveries: deliveries.results };
}
export async function sendDelivery(env: Bindings, id: string, deps: Deps) {
  const row = await env.DB.prepare(
    `SELECT d.*,c.title,c.body,c.route,t.token,t.active,t.uid AS device_uid FROM deliveries d JOIN campaigns c ON c.id=d.campaign_id LEFT JOIN device_tokens t ON t.installation_id=d.installation_id WHERE d.id=?`,
  )
    .bind(id)
    .first<Row>();
  if (!row || !["pending", "retry"].includes(String(row.status))) return;
  const lease = await env.DB.prepare(
    "UPDATE deliveries SET status='sending',attempts=attempts+1,updated_at=? WHERE id=? AND status IN('pending','retry')",
  )
    .bind(nowIso(), id)
    .run();
  if (!lease.meta.changes) return;
  let status = "failed",
    messageId: string | null = null,
    error: string | null = null,
    next: number | null = null;
  try {
    if (row.active !== 1 || row.device_uid !== row.uid)
      throw new ApiError(409, "device_inactive");
    const token = await googleAccessToken(
      env,
      "https://www.googleapis.com/auth/firebase.messaging",
      deps,
    );
    const result = await providerJson(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: row.token,
            notification: { title: row.title, body: row.body },
            data: { route: row.route, notificationId: id, targetUid: row.uid },
          },
        }),
      },
      deps,
    );
    if (typeof result.name !== "string")
      throw new ApiError(504, "provider_result_unknown");
    status = "accepted";
    messageId = result.name;
  } catch (e) {
    const failure =
      e instanceof ApiError ? e : new ApiError(504, "provider_result_unknown");
    error = failure.providerCode ?? failure.code;
    if (
      failure.providerCode === "UNREGISTERED" ||
      failure.providerCode === "SENDER_ID_MISMATCH"
    )
      await env.DB.prepare(
        "UPDATE device_tokens SET active=0 WHERE installation_id=? AND uid=? AND token=?",
      )
        .bind(row.installation_id, row.uid, row.token)
        .run();
    else if (failure.retryable && Number(row.attempts) < 2) {
      status = "retry";
      next =
        (deps.now?.() ?? Math.floor(Date.now() / 1000)) +
        30 * Math.pow(2, Number(row.attempts));
    } else if (failure.code === "provider_result_unknown") status = "unknown";
  }
  await env.DB.prepare(
    "UPDATE deliveries SET status=?,message_id=?,error_code=?,next_attempt=?,updated_at=? WHERE id=?",
  )
    .bind(status, messageId, error, next, nowIso(), id)
    .run();
}
export async function retryNotifications(env: Bindings, deps: Deps) {
  const now = deps.now?.() ?? Math.floor(Date.now() / 1000);
  const jobs = await env.DB.prepare(
    "SELECT id FROM deliveries WHERE status='retry' AND next_attempt<=? AND attempts<3 LIMIT 3",
  )
    .bind(now)
    .all<Row>();
  for (const job of jobs.results) await sendDelivery(env, String(job.id), deps);
  // A process interruption after send cannot safely be interpreted as a rejection.
  await env.DB.prepare(
    "UPDATE deliveries SET status='unknown',error_code='interrupted_send' WHERE status='sending' AND updated_at<?",
  )
    .bind(new Date(Date.now() - 300000).toISOString())
    .run();
}
export function pageSize(value: string | undefined) {
  const n = value === undefined ? 20 : Number(value);
  if (!Number.isInteger(n) || n < 1 || n > 50)
    throw new ApiError(400, "invalid_limit");
  return n;
}
export function page(rows: Row[], limit: number, key = "id") {
  const more = rows.length > limit;
  const items = rows.slice(0, limit);
  return { items, nextCursor: more ? String(items.at(-1)![key]) : null };
}
