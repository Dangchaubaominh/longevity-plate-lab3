// Controlled live provider test. Deletes only randomly named fixtures created
// by this invocation, never existing user assets. Outputs no keys or signed URLs.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { parseEnv } from "node:util";
import { signParams } from "../src/index.js";
const config = parseEnv(readFileSync(process.argv[2] ?? ".dev.vars", "utf8"));
mkdirSync("../artifacts/backend-implementation", { recursive: true });
const cloud = config.CLOUDINARY_CLOUD_NAME,
  key = config.CLOUDINARY_API_KEY,
  secret = config.CLOUDINARY_API_SECRET;
if (!cloud || !key || !secret)
  throw new Error("Cloudinary configuration missing (values hidden)");
const base = `https://api.cloudinary.com/v1_1/${encodeURIComponent(cloud)}`;
const report = {
  time: new Date().toISOString(),
  source: "live-cloudinary",
  checks: [],
};
const pending = [];
const fixtureOwner = `verification_${randomUUID().replaceAll("-", "")}`;
const check = (name, pass, status) => {
  report.checks.push({ name, pass, status });
  console.log(
    `${name}: ${pass ? "PASS" : "FAIL"}${status === undefined ? "" : ` (HTTP ${status})`}`,
  );
};
const request = (url, init = {}) =>
  fetch(url, { ...init, signal: AbortSignal.timeout(20000) });
function pdf() {
  const chunks = ["%PDF-1.4\n"];
  const offsets = [0];
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> /Contents 4 0 R >>",
    "<< /Length 0 >>\nstream\n\nendstream",
  ];
  for (let i = 0; i < objects.length; i++) {
    offsets.push(Buffer.byteLength(chunks.join("")));
    chunks.push(`${i + 1} 0 obj\n${objects[i]}\nendobj\n`);
  }
  const xref = Buffer.byteLength(chunks.join(""));
  chunks.push(
    `xref\n0 5\n0000000000 65535 f \n${offsets
      .slice(1)
      .map((n) => `${String(n).padStart(10, "0")} 00000 n \n`)
      .join(
        "",
      )}trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`,
  );
  return Buffer.from(chunks.join(""));
}
try {
  const ping = await request(`${base}/ping`, {
    headers: {
      Authorization: `Basic ${Buffer.from(`${key}:${secret}`).toString("base64")}`,
    },
  });
  check("credential_ping", ping.ok, ping.status);
  if (!ping.ok) {
    const body = await ping.json().catch(() => ({}));
    const message = String(body.error?.message ?? "").toLowerCase();
    report.providerError = /unknown api key/.test(message)
      ? "unknown_api_key"
      : /invalid.*secret|invalid.*credential|invalid.*signature/.test(message)
        ? "invalid_credential"
        : /cloud.*not.*found/.test(message)
          ? "cloud_not_found"
          : "provider_auth_rejected";
    console.log(`Provider category: ${report.providerError} (details hidden)`);
  }
  if (!ping.ok)
    throw new Error("Provider credential/reachability check failed");
  for (const [kind, format, bytes] of [
    [
      "photo",
      "jpg",
      readFileSync(new URL("../test/fixtures/smoke.jpg", import.meta.url)),
    ],
    ["pdf", "pdf", pdf()],
  ]) {
    const publicId = `${kind === "photo" ? "meal_photos" : "reports"}/${fixtureOwner}/smoke-${kind}`;
    const params = {
      allowed_formats: format,
      asset_folder: `${kind === "photo" ? "meal_photos" : "reports"}/${fixtureOwner}`,
      overwrite: "false",
      public_id: publicId,
      timestamp: String(Math.floor(Date.now() / 1000)),
      type: "authenticated",
    };
    const fields = {
      ...params,
      api_key: key,
      signature: await signParams(params, secret),
    };
    const form = new FormData();
    for (const [k, v] of Object.entries(fields)) form.set(k, v);
    form.set(
      "file",
      new Blob([bytes], {
        type: kind === "photo" ? "image/jpeg" : "application/pdf",
      }),
      `fixture.${format}`,
    );
    pending.push(publicId);
    const upload = await request(`${base}/image/upload`, {
      method: "POST",
      body: form,
    });
    const result = await upload.json();
    check(`${kind}_signed_upload`, upload.ok, upload.status);
    if (!upload.ok) continue;
    check(
      `${kind}_authenticated_metadata`,
      result.public_id === publicId &&
        result.type === "authenticated" &&
        result.format === format &&
        result.bytes === bytes.length,
    );
    const receipt = await signParams(
      { public_id: publicId, version: String(result.version) },
      secret,
    );
    check(`${kind}_receipt_signature`, receipt === result.signature);
    const metadata = await request(
      `${base}/resources/image/authenticated/${encodeURIComponent(publicId)}`,
      {
        headers: {
          Authorization: `Basic ${Buffer.from(`${key}:${secret}`).toString("base64")}`,
        },
      },
    );
    check(`${kind}_admin_metadata`, metadata.ok, metadata.status);
    const download = {
      expires_at: String(Math.floor(Date.now() / 1000) + 900),
      format,
      public_id: publicId,
      timestamp: String(Math.floor(Date.now() / 1000)),
      type: "authenticated",
    };
    const url = new URL(`${base}/image/download`);
    url.search = new URLSearchParams({
      ...download,
      api_key: key,
      signature: await signParams(download, secret),
    }).toString();
    const response = await request(url);
    const data = await response.arrayBuffer();
    check(
      `${kind}_private_download`,
      response.ok && data.byteLength > 0,
      response.status,
    );
    const unsigned = await request(
      `https://res.cloudinary.com/${encodeURIComponent(cloud)}/image/authenticated/v${result.version}/${publicId}.${format}`,
    );
    check(
      `${kind}_unsigned_denied`,
      [401, 403, 404].includes(unsigned.status),
      unsigned.status,
    );
  }
} catch {
  check("provider_request_completed", false);
} finally {
  for (const publicId of pending) {
    if (!publicId.includes(`/${fixtureOwner}/smoke-`))
      throw new Error("Fixture cleanup guard rejected target");
    try {
      const params = {
        public_id: publicId,
        type: "authenticated",
        timestamp: String(Math.floor(Date.now() / 1000)),
      };
      const response = await request(`${base}/image/destroy`, {
        method: "POST",
        body: new URLSearchParams({
          ...params,
          api_key: key,
          signature: await signParams(params, secret),
        }),
      });
      const data = await response.json();
      check(
        `${publicId.endsWith("photo") ? "photo" : "pdf"}_fixture_cleanup`,
        response.ok && ["ok", "not found"].includes(data.result),
        response.status,
      );
    } catch {
      check("fixture_cleanup", false);
    }
  }
  writeFileSync(
    "../artifacts/backend-implementation/cloudinary-live.json",
    JSON.stringify(report, null, 2) + "\n",
  );
}
if (report.checks.some((c) => !c.pass)) process.exitCode = 1;
