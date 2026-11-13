import { writeFileSync } from "node:fs";
import { z } from "zod";
import * as s from "../src/schemas.ts";
const schemas = {};
for (const name of [
  "meal",
  "profile",
  "goals",
  "plan",
  "operation",
  "push",
  "device",
  "unregister",
  "sign",
  "complete",
  "campaign",
]) {
  const schema = z.toJSONSchema(s[name]);
  delete schema.$schema;
  schemas[name] = schema;
}
schemas.Record = {
  type: "object",
  required: ["id", "kind", "data", "version", "updatedAt"],
  properties: {
    id: { type: "string" },
    kind: { enum: ["meal", "plan", "goals", "profile"] },
    data: { type: "object" },
    version: { type: "integer", minimum: 1 },
    deletedAt: { type: ["string", "null"] },
    createdAt: { type: ["string", "null"] },
    updatedAt: { type: "string" },
    photoAsset: {
      anyOf: [{ $ref: "#/components/schemas/Asset" }, { type: "null" }],
    },
  },
};
schemas.Asset = {
  type: "object",
  properties: {
    id: { type: "string" },
    kind: { enum: ["photo", "pdf"] },
    status: { enum: ["pending", "ready", "rejected", "deleted"] },
    bytes: { type: ["integer", "null"] },
    publicId: { type: "string" },
    version: { type: ["string", "null"] },
  },
};
schemas.Error = {
  type: "object",
  required: ["error"],
  properties: {
    error: {
      type: "object",
      required: ["code", "requestId", "retryable"],
      properties: {
        code: { type: "string" },
        message: { type: "string" },
        requestId: { type: "string" },
        retryable: { type: "boolean" },
      },
    },
  },
};
schemas.Mutation = {
  type: "object",
  additionalProperties: false,
  required: ["opId", "baseVersion", "data"],
  properties: {
    opId: { type: "string", pattern: "^[a-zA-Z0-9_.-]{1,160}$" },
    baseVersion: { type: "integer", minimum: 0 },
    data: { type: "object" },
  },
};
const ref = (n) => ({ $ref: `#/components/schemas/${n}` });
const record = {
  type: "object",
  required: ["record"],
  properties: { record: ref("Record") },
};
const paged = {
  type: "object",
  required: ["items", "nextCursor"],
  properties: {
    items: { type: "array", items: { type: "object" } },
    nextCursor: { type: ["string", "null"] },
  },
};
const paths = {};
function add(
  path,
  method,
  summary,
  {
    input,
    output = { type: "object" },
    publicRoute = false,
    admin = false,
    pagination = false,
  } = {},
) {
  const parameters = [...path.matchAll(/\{([^}]+)\}/g)].map((m) => ({
    name: m[1],
    in: "path",
    required: true,
    schema: { type: "string" },
  }));
  if (pagination)
    parameters.push(
      { name: "cursor", in: "query", schema: { type: "string" } },
      {
        name: "limit",
        in: "query",
        schema: {
          type: "integer",
          minimum: 1,
          maximum: path.includes("sync/pull") ? 20 : 50,
          default: 20,
        },
      },
    );
  const op = {
    operationId: method + "_" + path.replace(/[^a-zA-Z0-9]+/g, "_"),
    summary,
    description: admin
      ? "Requires active server-side admin_users allowlist."
      : publicRoute
        ? "Public endpoint."
        : "Owner is derived from the verified Firebase ID token.",
    security: publicRoute ? [] : [{ FirebaseIdToken: [] }],
    parameters,
    responses: {
      200: {
        description: "Success",
        content: { "application/json": { schema: output } },
      },
      ...Object.fromEntries(
        [
          "400",
          "401",
          "403",
          "404",
          "409",
          "413",
          "429",
          "500",
          "502",
          "503",
          "504",
        ].map((code) => [
          code,
          {
            description:
              "Validation, authorization, conflict, limit or provider error.",
            content: { "application/json": { schema: ref("Error") } },
          },
        ]),
      ),
    },
  };
  if (path === "/api/v1/admin/push" && method === "post")
    op.responses[201] = {
      description: "Campaign created and processed",
      content: { "application/json": { schema: output } },
    };
  if (input)
    op.requestBody = {
      required: true,
      content: {
        "application/json": {
          schema: typeof input === "string" ? ref(input) : input,
        },
      },
    };
  (paths[path] ??= {})[method] = op;
}
add("/health", "get", "Process health (does not verify providers)", {
  publicRoute: true,
});
add("/api/public/config", "get", "Public Firebase web SDK configuration", {
  publicRoute: true,
});
add("/api/v1/me", "get", "Current UID and server-evaluated admin role");
for (const [path, kind] of [
  ["profile", "profile"],
  ["goals", "goals"],
]) {
  add(`/api/v1/me/${path}`, "get", `Read ${kind}`, { output: record });
  add(`/api/v1/me/${path}`, "put", `Create/update ${kind}`, {
    input: {
      ...schemas.Mutation,
      properties: { ...schemas.Mutation.properties, data: ref(kind) },
    },
    output: record,
  });
}
for (const [path, kind] of [
  ["meals", "meal"],
  ["plans", "plan"],
]) {
  add(`/api/v1/${path}`, "get", `List owned ${path}`, {
    pagination: true,
    output: {
      ...paged,
      properties: {
        ...paged.properties,
        items: { type: "array", items: ref("Record") },
      },
    },
  });
  paths[`/api/v1/${path}`].get.parameters.push(
    ...["from", "to"].map((name) => ({
      name,
      in: "query",
      schema: { type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$" },
    })),
  );
  add(`/api/v1/${path}/{id}`, "get", `Read owned ${kind}`, { output: record });
  add(`/api/v1/${path}/{id}`, "put", `Create/update owned ${kind}`, {
    input: {
      ...schemas.Mutation,
      properties: { ...schemas.Mutation.properties, data: ref(kind) },
    },
    output: record,
  });
  add(`/api/v1/${path}/{id}`, "delete", `Soft-delete owned ${kind}`, {
    input: "Mutation",
    output: record,
  });
}
const syncResult = {
  type: "object",
  required: ["opId"],
  properties: {
    opId: { type: "string" },
    record: ref("Record"),
    error: { type: "object", properties: { code: { type: "string" } } },
    current: { anyOf: [ref("Record"), { type: "null" }] },
  },
};
add(
  "/api/v1/sync/push",
  "post",
  "Apply up to 5 revisioned idempotent operations",
  {
    input: "push",
    output: {
      type: "object",
      required: ["results"],
      properties: { results: { type: "array", items: syncResult } },
    },
  },
);
add("/api/v1/sync/pull", "get", "Read cursor changes and tombstones", {
  pagination: true,
  output: {
    type: "object",
    required: ["items", "nextCursor", "hasMore"],
    properties: {
      items: { type: "array", items: ref("Record") },
      nextCursor: { type: "integer" },
      hasMore: { type: "boolean" },
    },
  },
});
add(
  "/api/v1/media/sign",
  "post",
  "Authorize an owned authenticated Cloudinary upload",
  {
    input: "sign",
    output: {
      type: "object",
      required: ["assetId", "publicId", "expiresAt", "uploadUrl", "fields"],
      properties: {
        assetId: { type: "string" },
        publicId: { type: "string" },
        expiresAt: { type: "integer" },
        uploadUrl: { type: "string", format: "uri" },
        fields: { type: "object", additionalProperties: { type: "string" } },
      },
    },
  },
);
add(
  "/api/v1/media/{id}/complete",
  "post",
  "Verify signed receipt and provider metadata",
  { input: "complete" },
);
add(
  "/api/v1/media/{id}/reconcile",
  "post",
  "Recover upload result using trusted provider metadata",
  { input: { type: "object" } },
);
add("/api/v1/media/{id}", "get", "Read owned ready file metadata");
add(
  "/api/v1/media/{id}",
  "delete",
  "Tombstone owned asset and schedule cleanup",
);
add("/api/v1/media/{id}/url", "post", "Create a 15-minute owned download URL", {
  input: { type: "object" },
  output: {
    type: "object",
    properties: {
      url: { type: "string", format: "uri" },
      expiresAt: { type: "integer" },
    },
  },
});
add("/api/v1/files", "get", "List owned file metadata", {
  pagination: true,
  output: paged,
});
add(
  "/api/v1/devices/register",
  "post",
  "Register/rotate token with installation proof and generation",
  { input: "device" },
);
add(
  "/api/v1/devices/unregister",
  "post",
  "Deactivate this owner/generation only",
  { input: "unregister" },
);
add(
  "/api/v1/notifications",
  "get",
  "Read own notification requests (accepted does not mean delivered)",
  { pagination: true, output: paged },
);
add(
  "/api/v1/notifications/{id}/open",
  "post",
  "Record first opening by the owner",
  { input: { type: "object" } },
);
for (const resource of [
  "overview",
  "users",
  "devices",
  "push-jobs",
  "reports",
  "audit-logs",
  "crashlytics/issues",
])
  add(`/api/v1/admin/${resource}`, "get", `Admin: ${resource}`, {
    admin: true,
    pagination: !["overview", "crashlytics/issues"].includes(resource),
    output: ["overview", "crashlytics/issues"].includes(resource)
      ? { type: "object" }
      : paged,
  });
paths["/api/v1/admin/users"].get.parameters.push({
  name: "search",
  in: "query",
  schema: { type: "string", maxLength: 80 },
});
add(
  "/api/v1/admin/push",
  "post",
  "Create idempotent campaign; FCM accepted is not device delivery",
  { admin: true, input: "campaign" },
);
add(
  "/api/v1/admin/push-jobs/{id}",
  "get",
  "Admin campaign and per-device results",
  { admin: true },
);
add(
  "/api/v1/admin/crashlytics/refresh",
  "post",
  "Fetch actual Firebase topIssues; cache with provenance",
  { admin: true, input: { type: "object" } },
);
add(
  "/api/v1/admin/crashlytics/issues/{id}",
  "get",
  "Actual Firebase issue and latest 5 related events",
  { admin: true },
);
add(
  "/reports/sign",
  "post",
  "Legacy PDF authorization (compatibility contract)",
  {
    input: {
      type: "object",
      required: ["fileName"],
      properties: {
        fileName: { type: "string", pattern: "^meal-report-\\d{10,16}\\.pdf$" },
      },
    },
  },
);
add(
  "/reports/url",
  "post",
  "Legacy PDF private link (legacy errors use string error)",
  {
    input: {
      type: "object",
      required: ["publicId"],
      properties: { publicId: { type: "string" } },
    },
  },
);
writeFileSync(
  "../docs/openapi.json",
  JSON.stringify(
    {
      openapi: "3.1.1",
      info: {
        title: "Longevity Plate Lab3 API",
        version: "1.0.0",
        description:
          "D1 owner-scoped API. Provider calls need server secrets. Sync errors are per-operation in HTTP 200. Legacy /reports routes retain original error schema.",
      },
      servers: [{ url: "http://localhost:8787", description: "Local Worker" }],
      paths,
      components: {
        securitySchemes: {
          FirebaseIdToken: {
            type: "http",
            scheme: "bearer",
            bearerFormat: "Firebase ID token",
          },
        },
        schemas,
      },
    },
    null,
    2,
  ) + "\n",
);
console.log(
  `Generated ${Object.keys(paths).length} paths and ${Object.keys(schemas).length} schemas.`,
);
