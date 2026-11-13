import { Hono } from "hono";
import { ZodError, z } from "zod";
import { handle as legacyHandle, verifyIdToken } from "./index.js";
import {
  ApiError,
  boundedJson,
  nowIso,
  type AppEnv,
  type Ctx,
  type Deps,
  type Row,
} from "./types";
import { applyOperation, audit, ensureUser, record } from "./records";
import { push } from "./schemas";
import { cleanup, mediaRoutes, publicAsset } from "./media";
import {
  deviceRoutes,
  page,
  pageSize,
  pushAdminRoutes,
  retryNotifications,
} from "./notifications";
import { crashRequest } from "./providers";

const mutation = z
  .object({
    data: z.unknown(),
    baseVersion: z.number().int().min(0),
    opId: z.string().regex(/^[a-zA-Z0-9_.-]{1,160}$/),
  })
  .strict();
export function createApp(deps: Deps = {}) {
  const app = new Hono<AppEnv>();
  app.use("*", async (c, next) => {
    c.set("requestId", crypto.randomUUID());
    const origin = c.req.header("Origin");
    const sameOrigin = new URL(c.req.url).origin;
    if (origin && origin !== sameOrigin && origin !== c.env.ADMIN_ORIGIN)
      throw new ApiError(403, "origin_not_allowed");
    if (origin) {
      c.header("Access-Control-Allow-Origin", origin);
      c.header("Vary", "Origin");
    }
    c.header("Access-Control-Allow-Headers", "Authorization, Content-Type");
    c.header("Access-Control-Allow-Methods", "GET, PUT, POST, DELETE, OPTIONS");
    c.header("Cache-Control", "no-store");
    c.header("X-Content-Type-Options", "nosniff");
    c.header("X-Request-ID", c.get("requestId"));
    if (c.req.method === "OPTIONS") return c.body(null, 204);
    if (c.req.path === "/health" || c.req.path === "/api/public/config")
      return next();
    if (!c.req.path.startsWith("/api/") && !c.req.path.startsWith("/reports/"))
      return next();
    if (!c.env.DB || !c.env.FIREBASE_PROJECT_ID)
      throw new ApiError(503, "backend_not_configured");
    const bearer = /^Bearer (\S+)$/.exec(c.req.header("Authorization") ?? "");
    if (!bearer) throw new ApiError(401, "unauthenticated");
    let uid: string;
    try {
      uid = await verifyIdToken(bearer[1], c.env.FIREBASE_PROJECT_ID, {
        now: deps.now,
        fetchKeys: deps.fetchKeys,
      });
    } catch {
      throw new ApiError(401, "invalid_token");
    }
    if (!/^[a-zA-Z0-9_-]{1,128}$/.test(uid))
      throw new ApiError(401, "unsupported_uid");
    c.set("uid", uid);
    const bucket = Math.floor((deps.now?.() ?? Date.now() / 1000) / 60);
    const counter = await c.env.DB.prepare(
      "INSERT INTO rate_limits(bucket,identity,count) VALUES(?,?,1) ON CONFLICT(bucket,identity) DO UPDATE SET count=count+1 RETURNING count",
    )
      .bind(bucket, uid)
      .first<{ count: number }>();
    if ((counter?.count ?? 0) > Number(c.env.RATE_LIMIT ?? 120))
      throw new ApiError(429, "rate_limited", true);
    await ensureUser(c.env.DB, uid);
    if (c.req.path.startsWith("/api/v1/admin")) {
      const admin = await c.env.DB.prepare(
        "SELECT uid FROM admin_users WHERE uid=? AND active=1",
      )
        .bind(uid)
        .first();
      if (!admin) throw new ApiError(403, "admin_required");
    }
    await next();
  });
  app.onError((error, c) => {
    const failure =
      error instanceof ApiError
        ? error
        : error instanceof ZodError
          ? new ApiError(400, "invalid_input")
          : new ApiError(500, "internal_error");
    // Never log request bodies, Authorization headers or provider credentials.
    if (failure.status === 500)
      console.error(
        JSON.stringify({
          requestId: c.get("requestId"),
          code: "internal_error",
        }),
      );
    return new Response(
      JSON.stringify({
        error: {
          code: failure.code,
          message: failure.code,
          requestId: c.get("requestId"),
          retryable: failure.retryable,
        },
      }),
      {
        status: failure.status,
        headers: {
          ...Object.fromEntries(c.res.headers),
          "Content-Type": "application/json",
          "Cache-Control": "no-store",
          "X-Request-ID": c.get("requestId"),
        },
      },
    );
  });
  app.get("/health", (c) =>
    c.json({ status: "ok", service: "longevity-plate-api", apiVersion: 1 }),
  );
  app.get("/api/public/config", (c) => {
    let data: unknown;
    try {
      data = JSON.parse(c.env.FIREBASE_WEB_CONFIG ?? "{}");
    } catch {
      throw new ApiError(503, "web_auth_not_configured");
    }
    const config = z
      .object({
        apiKey: z.string().min(1),
        appId: z.string().min(1),
        projectId: z.literal(c.env.FIREBASE_PROJECT_ID),
        authDomain: z.string().min(1),
        messagingSenderId: z.string().optional(),
      })
      .safeParse(data);
    if (!config.success) throw new ApiError(503, "web_auth_not_configured");
    return c.json({ firebase: config.data });
  });
  app.all("/reports/*", (c) => legacyHandle(c.req.raw, c.env, deps));
  app.get("/api/v1/me", async (c) => {
    const admin = await c.env.DB.prepare(
      "SELECT uid FROM admin_users WHERE uid=? AND active=1",
    )
      .bind(c.get("uid"))
      .first();
    return c.json({ uid: c.get("uid"), isAdmin: !!admin });
  });
  for (const [path, kind] of [
    ["me/profile", "profile"],
    ["me/goals", "goals"],
  ] as const) {
    app.get(`/api/v1/${path}`, async (c) =>
      c.json({ record: await getRecord(c, kind, "self") }),
    );
    app.put(`/api/v1/${path}`, async (c) => {
      const body = mutation.parse(await boundedJson(c.req.raw));
      return c.json({
        record: await applyOperation(c.env.DB, c.get("uid"), {
          ...body,
          kind,
          id: "self",
          deleted: false,
        }),
      });
    });
  }
  for (const [path, kind] of [
    ["meals", "meal"],
    ["plans", "plan"],
  ] as const) {
    app.get(`/api/v1/${path}`, async (c) => {
      const limit = pageSize(c.req.query("limit"));
      const cursor = c.req.query("cursor") ?? "";
      const from = c.req.query("from") ?? "0000-01-01",
        to = c.req.query("to") ?? "9999-12-31";
      if (
        !/^\d{4}-\d{2}-\d{2}$/.test(from) ||
        !/^\d{4}-\d{2}-\d{2}$/.test(to) ||
        from > to
      )
        throw new ApiError(400, "invalid_date_range");
      const rows = await c.env.DB.prepare(
        "SELECT * FROM records WHERE uid=? AND kind=? AND deleted_at IS NULL AND id>? AND json_extract(data_json,'$.date') BETWEEN ? AND ? ORDER BY id LIMIT ?",
      )
        .bind(c.get("uid"), kind, cursor, from, to, limit + 1)
        .all<Row>();
      const result = page(rows.results, limit);
      return c.json({
        ...result,
        items: await Promise.all(
          result.items.map((row) => enrich(c, record(row))),
        ),
      });
    });
    app.get(`/api/v1/${path}/:id`, async (c) =>
      c.json({ record: await getRecord(c, kind, c.req.param("id")) }),
    );
    app.put(`/api/v1/${path}/:id`, async (c) => {
      const body = mutation.parse(await boundedJson(c.req.raw));
      return c.json({
        record: await applyOperation(c.env.DB, c.get("uid"), {
          ...body,
          kind,
          id: c.req.param("id"),
          deleted: false,
        }),
      });
    });
    app.delete(`/api/v1/${path}/:id`, async (c) => {
      const body = mutation.parse(await boundedJson(c.req.raw));
      const id = c.req.param("id");
      const result = await applyOperation(c.env.DB, c.get("uid"), {
        ...body,
        kind,
        id,
        deleted: true,
      });
      if (kind === "meal") await tombstoneMealAssets(c, id);
      return c.json({ record: result });
    });
  }
  app.post("/api/v1/sync/push", async (c) => {
    const body = push.parse(await boundedJson(c.req.raw));
    const results: Row[] = [];
    for (const op of body.operations) {
      try {
        const saved = await applyOperation(c.env.DB, c.get("uid"), op);
        if (op.deleted && op.kind === "meal")
          await tombstoneMealAssets(c, op.id);
        results.push({ opId: op.opId, record: saved });
      } catch (e) {
        if (!(e instanceof ApiError || e instanceof ZodError)) throw e;
        const current =
          e instanceof ApiError && e.status === 409
            ? await c.env.DB.prepare(
                "SELECT * FROM records WHERE uid=? AND kind=? AND id=?",
              )
                .bind(c.get("uid"), op.kind, op.id)
                .first<Row>()
            : null;
        results.push({
          opId: op.opId,
          error: { code: e instanceof ApiError ? e.code : "invalid_input" },
          current: current ? await enrich(c, record(current)) : null,
        });
      }
    }
    return c.json({ results });
  });
  app.get("/api/v1/sync/pull", async (c) => {
    const cursor = Number(c.req.query("cursor") ?? 0);
    const limit = Math.min(pageSize(c.req.query("limit")), 20);
    if (!Number.isSafeInteger(cursor) || cursor < 0)
      throw new ApiError(400, "invalid_cursor");
    const rows = await c.env.DB.prepare(
      "SELECT changes.*,records.created_at FROM changes JOIN records ON records.uid=changes.uid AND records.kind=changes.kind AND records.id=changes.id WHERE changes.uid=? AND changes.seq>? ORDER BY changes.seq LIMIT ?",
    )
      .bind(c.get("uid"), cursor, limit + 1)
      .all<Row>();
    const items = rows.results.slice(0, limit);
    return c.json({
      items: await Promise.all(items.map((row) => enrich(c, record(row)))),
      nextCursor: items.at(-1)?.seq ?? cursor,
      hasMore: rows.results.length > limit,
    });
  });
  app.route("/api/v1/media", mediaRoutes(deps));
  app.route("/api/v1/devices", deviceRoutes());
  app.get("/api/v1/files", async (c) => {
    const limit = pageSize(c.req.query("limit"));
    const rows = await c.env.DB.prepare(
      "SELECT * FROM assets WHERE uid=? AND status<>'deleted' AND id>? ORDER BY id LIMIT ?",
    )
      .bind(c.get("uid"), c.req.query("cursor") ?? "", limit + 1)
      .all<Row>();
    const result = page(rows.results, limit);
    return c.json({ ...result, items: result.items.map(publicAsset) });
  });
  app.get("/api/v1/notifications", async (c) => {
    const limit = pageSize(c.req.query("limit"));
    const rows = await c.env.DB.prepare(
      `SELECT d.id,c.title,c.body,c.route,d.status,d.opened_at AS openedAt,d.updated_at AS receivedAt FROM deliveries d JOIN campaigns c ON c.id=d.campaign_id WHERE d.uid=? AND d.id>? ORDER BY d.id LIMIT ?`,
    )
      .bind(c.get("uid"), c.req.query("cursor") ?? "", limit + 1)
      .all<Row>();
    return c.json(page(rows.results, limit));
  });
  app.post("/api/v1/notifications/:id/open", async (c) => {
    const result = await c.env.DB.prepare(
      "UPDATE deliveries SET opened_at=COALESCE(opened_at,?) WHERE id=? AND uid=?",
    )
      .bind(nowIso(), c.req.param("id"), c.get("uid"))
      .run();
    if (!result.meta.changes) throw new ApiError(404, "not_found");
    return c.json({ opened: true });
  });
  app.route("/api/v1/admin", pushAdminRoutes(deps));
  app.get("/api/v1/admin/overview", async (c) => {
    const result = await c.env.DB.prepare(
      `SELECT (SELECT count(*) FROM users) AS users,(SELECT count(*) FROM records WHERE kind='meal' AND deleted_at IS NULL) AS meals,(SELECT count(*) FROM records WHERE kind='plan' AND deleted_at IS NULL) AS plans,(SELECT count(*) FROM device_tokens WHERE active=1) AS devices,(SELECT count(*) FROM campaigns) AS campaigns`,
    ).first();
    return c.json({ statistics: result });
  });
  app.get("/api/v1/admin/users", async (c) => {
    const limit = pageSize(c.req.query("limit"));
    const search = (c.req.query("search") ?? "").slice(0, 80);
    const rows = await c.env.DB.prepare(
      `SELECT u.uid AS id,u.created_at AS createdAt,json_extract(r.data_json,'$.displayName') AS displayName,(SELECT COUNT(*) FROM records m WHERE m.uid=u.uid AND m.kind='meal' AND m.deleted_at IS NULL) AS mealCount,(SELECT COUNT(*) FROM records p WHERE p.uid=u.uid AND p.kind='plan' AND p.deleted_at IS NULL) AS planCount FROM users u LEFT JOIN records r ON r.uid=u.uid AND r.kind='profile' AND r.id='self' WHERE u.uid>? AND (u.uid LIKE ? OR json_extract(r.data_json,'$.displayName') LIKE ?) ORDER BY u.uid LIMIT ?`,
    )
      .bind(
        c.req.query("cursor") ?? "",
        `%${search}%`,
        `%${search}%`,
        limit + 1,
      )
      .all<Row>();
    return c.json(page(rows.results, limit));
  });
  app.get("/api/v1/admin/reports", async (c) => {
    const limit = pageSize(c.req.query("limit"));
    const rows = await c.env.DB.prepare(
      "SELECT id,uid,public_id AS publicId,status,bytes,created_at AS createdAt FROM assets WHERE kind='pdf' AND id>? ORDER BY id LIMIT ?",
    )
      .bind(c.req.query("cursor") ?? "", limit + 1)
      .all<Row>();
    await audit(
      c.env.DB,
      c.get("uid"),
      "reports.list",
      "pdf",
      c.get("requestId"),
    );
    return c.json(page(rows.results, limit));
  });
  app.get("/api/v1/admin/audit-logs", async (c) => {
    const limit = pageSize(c.req.query("limit"));
    const cursor = Number(c.req.query("cursor") ?? 0);
    if (!Number.isSafeInteger(cursor) || cursor < 0)
      throw new ApiError(400, "invalid_cursor");
    const rows = await c.env.DB.prepare(
      "SELECT id,actor_uid AS actorUid,action,target_id AS targetId,created_at AS createdAt FROM admin_audit_logs WHERE id>? ORDER BY id LIMIT ?",
    )
      .bind(cursor, limit + 1)
      .all<Row>();
    return c.json(page(rows.results, limit));
  });
  app.get("/api/v1/admin/crashlytics/issues", async (c) => {
    const snapshot = await c.env.DB.prepare(
      "SELECT * FROM crash_snapshots WHERE app_id=? ORDER BY id DESC LIMIT 1",
    )
      .bind(c.env.FIREBASE_APP_ID ?? "")
      .first<Row>();
    if (!snapshot)
      return c.json({
        source: "firebase-crashlytics",
        fetchedAt: null,
        payload: null,
      });
    return c.json({
      source: snapshot.source,
      fetchedAt: snapshot.fetched_at,
      payload: JSON.parse(String(snapshot.payload_json)) as unknown,
    });
  });
  app.post("/api/v1/admin/crashlytics/refresh", async (c) => {
    const previous = await c.env.DB.prepare(
      "SELECT fetched_at FROM crash_snapshots ORDER BY id DESC LIMIT 1",
    ).first<Row>();
    if (
      previous &&
      Date.now() - Date.parse(String(previous.fetched_at)) < 60000
    )
      throw new ApiError(429, "refresh_cooldown", true);
    const list = await crashRequest(c.env, "reports", deps);
    const reports = Array.isArray(list.reports) ? list.reports : [];
    const report = reports.find(
      (r: unknown) =>
        typeof r === "object" &&
        r !== null &&
        String((r as Row).name).endsWith("/topIssues"),
    ) as Row | undefined;
    if (!report) throw new ApiError(502, "crash_report_not_available");
    const payload = await crashRequest(
      c.env,
      "reports/topIssues?pageSize=20",
      deps,
    );
    const fetchedAt = nowIso();
    await c.env.DB.prepare(
      "INSERT INTO crash_snapshots(app_id,source,payload_json,fetched_at) VALUES(?,'firebase-crashlytics',?,?)",
    )
      .bind(c.env.FIREBASE_APP_ID, JSON.stringify(redact(payload)), fetchedAt)
      .run();
    await audit(
      c.env.DB,
      c.get("uid"),
      "crashlytics.refresh",
      "topIssues",
      c.get("requestId"),
    );
    return c.json({
      source: "firebase-crashlytics",
      fetchedAt,
      payload: redact(payload),
    });
  });
  app.get("/api/v1/admin/crashlytics/issues/:id", async (c) => {
    const id = c.req.param("id");
    if (!/^[a-zA-Z0-9_-]{1,120}$/.test(id))
      throw new ApiError(400, "invalid_issue_id");
    const issue = await crashRequest(c.env, `issues/${id}`, deps);
    const events = await crashRequest(
      c.env,
      `events?pageSize=5&filter.issue.id=${encodeURIComponent(id)}`,
      deps,
    );
    await audit(
      c.env.DB,
      c.get("uid"),
      "crashlytics.issue",
      id,
      c.get("requestId"),
    );
    return c.json({
      source: "firebase-crashlytics",
      issue: redact(issue),
      events: redact(events),
    });
  });
  app.notFound((c) => {
    if (c.req.path.startsWith("/api/") || c.req.path.startsWith("/reports/"))
      throw new ApiError(404, "not_found");
    if (c.env.ASSETS) return c.env.ASSETS.fetch(c.req.raw);
    throw new ApiError(404, "not_found");
  });
  return app;
}
async function getRecord(c: Ctx, kind: string, id: string) {
  const row = await c.env.DB.prepare(
    "SELECT * FROM records WHERE uid=? AND kind=? AND id=? AND deleted_at IS NULL",
  )
    .bind(c.get("uid"), kind, id)
    .first<Row>();
  if (!row) throw new ApiError(404, "not_found");
  return enrich(c, record(row));
}
async function enrich(c: Ctx, item: Row) {
  if (item.kind !== "meal" || item.deletedAt) return item;
  const asset = await c.env.DB.prepare(
    "SELECT * FROM assets WHERE uid=? AND meal_id=? AND kind='photo' AND status='ready' ORDER BY updated_at DESC LIMIT 1",
  )
    .bind(c.get("uid"), item.id)
    .first<Row>();
  return { ...item, photoAsset: asset ? publicAsset(asset) : null };
}
async function tombstoneMealAssets(c: Ctx, mealId: string) {
  await c.env.DB.batch([
    c.env.DB.prepare(
      "INSERT INTO maintenance_jobs(id,asset_id,run_after) SELECT id,id,MAX(expires_at+60,?) FROM assets WHERE uid=? AND meal_id=? AND status IN('pending','ready') ON CONFLICT(id) DO UPDATE SET status='pending',run_after=MAX(run_after,excluded.run_after)",
    ).bind(Math.floor(Date.now() / 1000), c.get("uid"), mealId),
    c.env.DB.prepare(
      "UPDATE assets SET status='deleted',updated_at=? WHERE uid=? AND meal_id=? AND status IN('pending','ready')",
    ).bind(nowIso(), c.get("uid"), mealId),
  ]);
}
function redact(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value)
        .filter(([k]) => !/(email|token|private.?key|secret)/i.test(k))
        .map(([k, v]) => [k, redact(v)]),
    );
  if (typeof value === "string")
    return value
      .replace(/Bearer\s+\S+/gi, "[REDACTED]")
      .replace(
        /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,
        "[REDACTED]",
      );
  return value;
}
const app = createApp();
export default {
  fetch: app.fetch,
  async scheduled(_event: ScheduledEvent, env: AppEnv["Bindings"]) {
    await cleanup(env, {});
    await retryNotifications(env, {});
  },
};
