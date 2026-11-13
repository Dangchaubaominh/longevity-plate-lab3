import type { Context } from "hono";

export interface Bindings {
  DB: D1Database;
  FIREBASE_PROJECT_ID: string;
  ADMIN_ORIGIN?: string;
  CLOUDINARY_CLOUD_NAME?: string;
  CLOUDINARY_API_KEY?: string;
  CLOUDINARY_API_SECRET?: string;
  GOOGLE_SERVICE_ACCOUNT_JSON?: string;
  FIREBASE_APP_ID?: string;
  FIREBASE_WEB_CONFIG?: string;
  RATE_LIMIT?: string;
  ASSETS?: Fetcher;
}
export type AppEnv = {
  Bindings: Bindings;
  Variables: { uid: string; requestId: string };
};
export type Ctx = Context<AppEnv>;
export interface Deps {
  fetch?: typeof fetch;
  now?: () => number;
  fetchKeys?: () => Promise<JsonWebKey[]>;
}
export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    public retryable = false,
    public providerCode?: string,
  ) {
    super(code);
  }
}
export type Row = Record<string, unknown>;
export const nowIso = () => new Date().toISOString();
export function need(value: string | undefined): string {
  if (!value) throw new ApiError(503, "provider_not_configured");
  return value;
}
export async function boundedJson(
  request: Request,
  max = 65536,
): Promise<unknown> {
  const reader = request.body?.getReader();
  if (!reader) throw new ApiError(400, "invalid_json");
  const chunks: Uint8Array[] = [];
  let length = 0;
  while (true) {
    const part = await reader.read();
    if (part.done) break;
    length += part.value.length;
    if (length > max) {
      await reader.cancel();
      throw new ApiError(413, "body_too_large");
    }
    chunks.push(part.value);
  }
  const bytes = new Uint8Array(length);
  let start = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, start);
    start += chunk.length;
  }
  try {
    return JSON.parse(new TextDecoder().decode(bytes)) as unknown;
  } catch {
    throw new ApiError(400, "invalid_json");
  }
}
export async function digest(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(bytes)]
    .map((n) => n.toString(16).padStart(2, "0"))
    .join("");
}
