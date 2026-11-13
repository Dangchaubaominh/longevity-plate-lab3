import { Hono } from "hono";
import { signParams } from "./index.js";
import {
  ApiError,
  boundedJson,
  digest,
  need,
  nowIso,
  type AppEnv,
  type Ctx,
  type Deps,
  type Row,
} from "./types";
import { sign, complete } from "./schemas";
import { cloudAsset, providerJson } from "./providers";
import { record } from "./records";

export function mediaRoutes(deps: Deps) {
  const app = new Hono<AppEnv>();
  app.post("/sign", async (c) => {
    const input = sign.parse(await boundedJson(c.req.raw));
    const uid = c.get("uid");
    const db = c.env.DB;
    let mealVersion: number | null = null;
    if (input.kind === "photo") {
      const meal = input.mealId
        ? await db
            .prepare(
              "SELECT version FROM records WHERE uid=? AND kind='meal' AND id=? AND deleted_at IS NULL",
            )
            .bind(uid, input.mealId)
            .first<{ version: number }>()
        : null;
      if (!meal) throw new ApiError(404, "meal_not_found");
      mealVersion = meal.version;
      if (input.mealVersion !== undefined && input.mealVersion !== meal.version)
        throw new ApiError(409, "version_conflict");
    }
    const mealId = input.mealId ?? "report";
    const id = await digest(
      `${uid}:${input.kind}:${mealId}:${input.contentHash}`,
    );
    const publicId =
      input.kind === "photo"
        ? `meal_photos/${uid}/${mealId}/${input.contentHash}`
        : `reports/${uid}/asset-${id}`;
    const time = deps.now?.() ?? Math.floor(Date.now() / 1000);
    const format = input.kind === "photo" ? "jpg" : "pdf";
    // Validate provider configuration before persisting an upload authorization.
    const cloud = need(c.env.CLOUDINARY_CLOUD_NAME);
    const secret = need(c.env.CLOUDINARY_API_SECRET);
    const apiKey = need(c.env.CLOUDINARY_API_KEY);
    const previous = await db
      .prepare("SELECT status FROM assets WHERE id=? AND uid=?")
      .bind(id, uid)
      .first<Row>();
    if (previous?.status === "deleted" || previous?.status === "rejected")
      throw new ApiError(409, "asset_tombstoned");
    await db.batch([
      db
        .prepare(
          `INSERT INTO assets(id,uid,kind,meal_id,public_id,format,status,content_hash,expires_at,created_at,updated_at,meal_version) VALUES(?,?,?,?,?,?,'pending',?,?,?,?,?)
    ON CONFLICT(id) DO UPDATE SET expires_at=excluded.expires_at,meal_version=excluded.meal_version WHERE assets.status='pending'`,
        )
        .bind(
          id,
          uid,
          input.kind,
          input.mealId ?? null,
          publicId,
          format,
          input.contentHash,
          time + 3600,
          nowIso(),
          nowIso(),
          mealVersion,
        ),
      db
        .prepare(
          `INSERT INTO maintenance_jobs(id,asset_id,run_after) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET status='pending',run_after=excluded.run_after WHERE EXISTS(SELECT 1 FROM assets WHERE id=excluded.asset_id AND status='pending')`,
        )
        .bind(id, id, time + 3660),
    ]);
    const params = {
      allowed_formats: format,
      asset_folder: `${input.kind === "photo" ? "meal_photos" : "reports"}/${uid}`,
      overwrite: "false",
      public_id: publicId,
      timestamp: String(time),
      type: "authenticated",
    };
    return c.json({
      assetId: id,
      publicId,
      expiresAt: time + 3600,
      uploadUrl: `https://api.cloudinary.com/v1_1/${cloud}/image/upload`,
      fields: {
        ...params,
        api_key: apiKey,
        signature: await signParams(params, secret),
      },
    });
  });
  app.post("/:id/complete", async (c) =>
    confirmAsset(c, deps, complete.parse(await boundedJson(c.req.raw))),
  );
  app.post("/:id/reconcile", async (c) => confirmAsset(c, deps));
  async function confirmAsset(
    c: Ctx,
    deps: Deps,
    receipt?: { publicId: string; version: string; signature: string },
  ) {
    const uid = c.get("uid");
    const asset = await c.env.DB.prepare(
      "SELECT * FROM assets WHERE id=? AND uid=?",
    )
      .bind(c.req.param("id"), uid)
      .first<Row>();
    if (!asset) throw new ApiError(404, "not_found");
    if (asset.status === "deleted" || asset.status === "rejected")
      throw new ApiError(409, "asset_tombstoned");
    if (receipt) {
      if (receipt.publicId !== asset.public_id)
        throw new ApiError(403, "asset_owner_mismatch");
      const expected = await signParams(
        { public_id: receipt.publicId, version: receipt.version },
        need(c.env.CLOUDINARY_API_SECRET),
      );
      if (!constantEqual(expected, receipt.signature))
        throw new ApiError(400, "invalid_upload_receipt");
    }
    if (asset.status === "ready") {
      if (receipt && receipt.version !== String(asset.version))
        throw new ApiError(409, "asset_version_conflict");
      const meal = asset.meal_id
        ? await c.env.DB.prepare(
            "SELECT * FROM records WHERE uid=? AND kind='meal' AND id=?",
          )
            .bind(uid, asset.meal_id)
            .first<Row>()
        : null;
      return c.json({
        asset: publicAsset(asset),
        meal: meal ? record(meal) : null,
      });
    }
    if (Number(asset.expires_at) < (deps.now?.() ?? Date.now() / 1000))
      throw new ApiError(409, "upload_session_expired");
    let actual: Row;
    try {
      actual = await cloudAsset(c.env, String(asset.public_id), deps);
    } catch (e) {
      if (e instanceof ApiError && e.code === "provider_http_404")
        throw new ApiError(404, "asset_not_uploaded");
      throw e;
    }
    const version = String(actual.version);
    if (
      actual.public_id !== asset.public_id ||
      (receipt && version !== receipt.version) ||
      !/^\d+$/.test(version) ||
      actual.type !== "authenticated" ||
      actual.resource_type !== "image"
    )
      throw new ApiError(400, "asset_metadata_mismatch");
    const size = Number(actual.bytes);
    const max = asset.kind === "photo" ? 5 * 1024 * 1024 : 10 * 1024 * 1024;
    if (
      !Number.isSafeInteger(size) ||
      size < 1 ||
      size > max ||
      actual.format !== asset.format
    ) {
      await c.env.DB.batch([
        c.env.DB.prepare(
          "UPDATE assets SET status='rejected',updated_at=? WHERE id=? AND uid=?",
        ).bind(nowIso(), asset.id, uid),
        c.env.DB.prepare(
          "INSERT INTO maintenance_jobs(id,asset_id,run_after) VALUES(?,?,?) ON CONFLICT(id) DO NOTHING",
        ).bind(asset.id, asset.id, Number(asset.expires_at) + 60),
      ]);
      throw new ApiError(400, "asset_policy_violation");
    }
    const statements: D1PreparedStatement[] = [];
    const opId = `asset-${String(asset.id)}-${version}`;
    if (asset.kind === "photo") {
      const meal = await c.env.DB.prepare(
        "SELECT version FROM records WHERE uid=? AND kind='meal' AND id=? AND deleted_at IS NULL",
      )
        .bind(uid, asset.meal_id)
        .first<{ version: number }>();
      if (!meal) throw new ApiError(409, "meal_deleted");
      if (meal.version !== asset.meal_version)
        throw new ApiError(409, "version_conflict");
      statements.push(
        c.env.DB.prepare(
          "UPDATE assets SET status='deleted',updated_at=? WHERE uid=? AND meal_id=? AND kind='photo' AND status='ready' AND id<>? AND EXISTS(SELECT 1 FROM records WHERE uid=? AND kind='meal' AND id=? AND version=? AND deleted_at IS NULL)",
        ).bind(
          nowIso(),
          uid,
          asset.meal_id,
          asset.id,
          uid,
          asset.meal_id,
          asset.meal_version,
        ),
        c.env.DB.prepare(
          "UPDATE maintenance_jobs SET status='pending',run_after=MAX(run_after,?) WHERE asset_id IN(SELECT id FROM assets WHERE uid=? AND meal_id=? AND status='deleted')",
        ).bind(Date.now() / 1000 + 3600, uid, asset.meal_id),
      );
    }
    statements.push(
      c.env.DB.prepare(
        `UPDATE assets SET status='ready',version=?,bytes=?,width=?,height=?,updated_at=? WHERE id=? AND uid=? AND status='pending' AND (kind='pdf' OR EXISTS(SELECT 1 FROM records WHERE records.uid=assets.uid AND records.kind='meal' AND records.id=assets.meal_id AND records.version=assets.meal_version AND records.deleted_at IS NULL))`,
      ).bind(
        version,
        size,
        Number(actual.width) || null,
        Number(actual.height) || null,
        nowIso(),
        asset.id,
        uid,
      ),
    );
    if (asset.kind === "photo")
      statements.push(
        c.env.DB.prepare(
          "UPDATE records SET version=version+1,last_op=?,updated_at=? WHERE uid=? AND kind='meal' AND id=? AND version=? AND EXISTS(SELECT 1 FROM assets WHERE id=? AND status='ready')",
        ).bind(
          opId,
          nowIso(),
          uid,
          asset.meal_id,
          asset.meal_version,
          asset.id,
        ),
        c.env.DB.prepare(
          "INSERT INTO changes(uid,kind,id,version,data_json,deleted_at,updated_at,op_id) SELECT uid,kind,id,version,data_json,deleted_at,updated_at,last_op FROM records WHERE uid=? AND kind='meal' AND id=? AND last_op=? ON CONFLICT(uid,op_id) DO NOTHING",
        ).bind(uid, asset.meal_id, opId),
      );
    statements.push(
      c.env.DB.prepare(
        "UPDATE maintenance_jobs SET status='done' WHERE id=? AND EXISTS(SELECT 1 FROM assets WHERE id=? AND status='ready')",
      ).bind(asset.id, asset.id),
    );
    await c.env.DB.batch(statements);
    const saved = await c.env.DB.prepare(
      "SELECT * FROM assets WHERE id=? AND uid=?",
    )
      .bind(asset.id, uid)
      .first<Row>();
    if (saved?.status !== "ready") throw new ApiError(409, "version_conflict");
    const meal = asset.meal_id
      ? await c.env.DB.prepare(
          "SELECT * FROM records WHERE uid=? AND kind='meal' AND id=?",
        )
          .bind(uid, asset.meal_id)
          .first<Row>()
      : null;
    return c.json({
      asset: publicAsset(saved),
      meal: meal ? record(meal) : null,
    });
  }
  app.get("/:id", async (c) => {
    const asset = await c.env.DB.prepare(
      "SELECT * FROM assets WHERE id=? AND uid=?",
    )
      .bind(c.req.param("id"), c.get("uid"))
      .first<Row>();
    if (!asset || asset.status === "deleted")
      throw new ApiError(404, "not_found");
    return c.json({ asset: publicAsset(asset) });
  });
  app.post("/:id/url", async (c) => {
    const asset = await c.env.DB.prepare(
      "SELECT * FROM assets WHERE id=? AND uid=? AND status='ready'",
    )
      .bind(c.req.param("id"), c.get("uid"))
      .first<Row>();
    if (!asset) throw new ApiError(404, "not_found");
    const now = deps.now?.() ?? Math.floor(Date.now() / 1000);
    const params = {
      expires_at: String(now + 900),
      format: String(asset.format),
      public_id: String(asset.public_id),
      timestamp: String(now),
      type: "authenticated",
    };
    const query = new URLSearchParams({
      ...params,
      api_key: need(c.env.CLOUDINARY_API_KEY),
      signature: await signParams(params, need(c.env.CLOUDINARY_API_SECRET)),
    });
    return c.json({
      url: `https://api.cloudinary.com/v1_1/${need(c.env.CLOUDINARY_CLOUD_NAME)}/image/download?${query}`,
      expiresAt: now + 900,
    });
  });
  app.delete("/:id", async (c) => {
    const uid = c.get("uid");
    const asset = await c.env.DB.prepare(
      "SELECT * FROM assets WHERE id=? AND uid=?",
    )
      .bind(c.req.param("id"), uid)
      .first<Row>();
    if (!asset) throw new ApiError(404, "not_found");
    await c.env.DB.batch([
      c.env.DB.prepare(
        "UPDATE assets SET status='deleted',updated_at=? WHERE id=? AND uid=?",
      ).bind(nowIso(), asset.id, uid),
      c.env.DB.prepare(
        "INSERT INTO maintenance_jobs(id,asset_id,run_after) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET status='pending',run_after=MAX(run_after,excluded.run_after)",
      ).bind(
        asset.id,
        asset.id,
        Math.max(Number(asset.expires_at) + 60, Date.now() / 1000),
      ),
    ]);
    return c.json({ deleted: true });
  });
  return app;
}
export function publicAsset(a: Row) {
  return {
    id: a.id,
    kind: a.kind,
    mealId: a.meal_id,
    publicId: a.public_id,
    status: a.status,
    version: a.version,
    bytes: a.bytes,
    width: a.width,
    height: a.height,
    format: a.format,
  };
}
function constantEqual(a: string, b: string) {
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++)
    diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  return diff === 0;
}
export async function cleanup(env: AppEnv["Bindings"], deps: Deps) {
  const now = deps.now?.() ?? Math.floor(Date.now() / 1000);
  const jobs = await env.DB.prepare(
    "SELECT j.id,a.public_id FROM maintenance_jobs j JOIN assets a ON a.id=j.asset_id WHERE j.status='pending' AND a.status<>'ready' AND j.run_after<=? AND j.attempts<3 LIMIT 3",
  )
    .bind(now)
    .all<Row>();
  for (const job of jobs.results) {
    try {
      const params = {
        public_id: String(job.public_id),
        timestamp: String(now),
        type: "authenticated",
        invalidate: "true",
      };
      const body = new URLSearchParams({
        ...params,
        api_key: need(env.CLOUDINARY_API_KEY),
        signature: await signParams(params, need(env.CLOUDINARY_API_SECRET)),
      });
      const result = await providerJson(
        `https://api.cloudinary.com/v1_1/${need(env.CLOUDINARY_CLOUD_NAME)}/image/destroy`,
        {
          method: "POST",
          body: body.toString(),
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
        },
        deps,
      );
      if (result.result !== "ok" && result.result !== "not found")
        throw new Error();
      await env.DB.prepare(
        "UPDATE maintenance_jobs SET status='done' WHERE id=?",
      )
        .bind(job.id)
        .run();
    } catch {
      await env.DB.prepare(
        "UPDATE maintenance_jobs SET attempts=attempts+1,run_after=? WHERE id=?",
      )
        .bind(now + 300, job.id)
        .run();
    }
  }
  await env.DB.prepare("DELETE FROM rate_limits WHERE bucket<?")
    .bind(Math.floor(now / 60) - 10)
    .run();
}
