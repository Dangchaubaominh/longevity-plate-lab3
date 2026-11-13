// Server báo cáo PDF, chạy trên Cloudflare Workers.
//
// Firebase Storage cần gói Blaze nên app lưu báo cáo trên Cloudinary. Cloudinary
// không biết ai đang đăng nhập Firebase, nên server này giữ vai trò của
// storage.rules: kiểm tra ID token Firebase, chỉ ký lệnh tải lên vào
// reports/<uid>/ của chính người đó và chỉ cấp link có hạn dùng cho chủ tệp.
// Khóa bí mật Cloudinary chỉ nằm ở đây, không có trong app hay trên GitHub.

const GOOGLE_KEYS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const UID = /^[A-Za-z0-9]{1,128}$/;
const FILE_NAME = /^meal-report-\d{10,16}\.pdf$/;
const PUBLIC_ID = /^reports\/([A-Za-z0-9]{1,128})\/meal-report-\d{10,16}$/;
const LINK_TTL_SECONDS = 15 * 60;
const CLOCK_SKEW_SECONDS = 5 * 60;

export class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

export default {
  fetch: (request, env) => handle(request, env),
};

/** `deps` chỉ dùng trong test để cố định giờ và khóa ký token. */
export async function handle(request, env, deps = {}) {
  try {
    const { pathname } = new URL(request.url);
    if (request.method === 'POST' && pathname === '/reports/sign') {
      return json(await signUpload(request, env, deps));
    }
    if (request.method === 'POST' && pathname === '/reports/url') {
      return json(await createDownloadLink(request, env, deps));
    }
    throw new HttpError(404, 'not-found');
  } catch (error) {
    if (error instanceof HttpError) return json({ error: error.code }, error.status);
    console.error(error);
    return json({ error: 'internal' }, 500);
  }
}

/** Ký lệnh tải lên. Thư mục lấy từ token, không tin uid do app gửi lên. */
async function signUpload(request, env, deps) {
  const config = readConfig(env);
  const uid = await authenticate(request, config.projectId, deps);
  const { fileName } = await readBody(request);
  if (typeof fileName !== 'string' || !FILE_NAME.test(fileName)) {
    throw new HttpError(400, 'invalid-file-name');
  }
  const publicId = `reports/${uid}/${fileName.slice(0, -'.pdf'.length)}`;
  const params = {
    // Cloudinary đọc nội dung tệp và từ chối nếu không phải PDF.
    allowed_formats: 'pdf',
    asset_folder: `reports/${uid}`,
    overwrite: 'false',
    public_id: publicId,
    timestamp: String(nowSeconds(deps)),
    // Tệp authenticated chỉ mở được bằng link có chữ ký do server cấp.
    type: 'authenticated',
  };
  const signature = await signParams(params, config.apiSecret);
  return {
    publicId,
    uploadUrl: `https://api.cloudinary.com/v1_1/${config.cloudName}/image/upload`,
    fields: { ...params, api_key: config.apiKey, signature },
  };
}

/** Cấp link tải có hạn dùng, chỉ cho tệp nằm trong thư mục của chính người gọi. */
async function createDownloadLink(request, env, deps) {
  const config = readConfig(env);
  const uid = await authenticate(request, config.projectId, deps);
  const { publicId } = await readBody(request);
  const match = typeof publicId === 'string' ? PUBLIC_ID.exec(publicId) : null;
  if (!match) throw new HttpError(400, 'invalid-public-id');
  if (match[1] !== uid) throw new HttpError(403, 'forbidden');

  const now = nowSeconds(deps);
  const params = {
    expires_at: String(now + LINK_TTL_SECONDS),
    format: 'pdf',
    public_id: publicId,
    timestamp: String(now),
    type: 'authenticated',
  };
  const signature = await signParams(params, config.apiSecret);
  const query = new URLSearchParams({ ...params, api_key: config.apiKey, signature });
  return {
    url: `https://api.cloudinary.com/v1_1/${config.cloudName}/image/download?${query}`,
    expiresAt: now + LINK_TTL_SECONDS,
  };
}

/** Chữ ký theo tài liệu Cloudinary: sắp xếp tham số, nối khóa bí mật, băm SHA-1. */
export async function signParams(params, apiSecret) {
  const payload = Object.keys(params)
    .sort()
    .map((key) => `${key}=${params[key]}`)
    .join('&');
  const digest = await crypto.subtle.digest(
    'SHA-1',
    new TextEncoder().encode(payload + apiSecret),
  );
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** Kiểm tra ID token Firebase theo tài liệu "Verify ID tokens using a third-party JWT library". */
export async function verifyIdToken(token, projectId, deps = {}) {
  let header;
  let payload;
  let signature;
  const parts = token.split('.');
  try {
    if (parts.length !== 3) throw new Error('malformed');
    header = JSON.parse(new TextDecoder().decode(base64UrlToBytes(parts[0])));
    payload = JSON.parse(new TextDecoder().decode(base64UrlToBytes(parts[1])));
    signature = base64UrlToBytes(parts[2]);
  } catch {
    throw new HttpError(401, 'invalid-token');
  }

  const now = nowSeconds(deps);
  if (
    header === null ||
    typeof header !== 'object' ||
    payload === null ||
    typeof payload !== 'object' ||
    // Tài liệu Firebase yêu cầu iat và auth_time ở quá khứ, nên phải có mặt.
    typeof payload.iat !== 'number' ||
    typeof payload.auth_time !== 'number' ||
    typeof payload.exp !== 'number' ||
    !Number.isFinite(payload.exp) ||
    !Number.isFinite(payload.iat) ||
    !Number.isFinite(payload.auth_time) ||
    header.alg !== 'RS256' ||
    typeof header.kid !== 'string' ||
    payload.aud !== projectId ||
    payload.iss !== `https://securetoken.google.com/${projectId}` ||
    typeof payload.sub !== 'string' ||
    payload.sub.length === 0 ||
    payload.sub.length > 128 ||
    payload.iat > now + CLOCK_SKEW_SECONDS ||
    payload.auth_time > now + CLOCK_SKEW_SECONDS
  ) {
    throw new HttpError(401, 'invalid-token');
  }
  if (!(payload.exp > now)) throw new HttpError(401, 'token-expired');

  let keys = await (deps.fetchKeys ?? fetchGoogleKeys)();
  let jwk = keys.find((key) => key.kid === header.kid);
  if (!jwk && !deps.fetchKeys) {
    cachedUntil = 0;
    keys = await fetchGoogleKeys();
    jwk = keys.find((key) => key.kid === header.kid);
  }
  if (!jwk) throw new HttpError(401, 'invalid-token');
  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    signature,
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new HttpError(401, 'invalid-token');
  return payload.sub;
}

async function authenticate(request, projectId, deps) {
  const match = /^Bearer (\S+)$/.exec(request.headers.get('Authorization') ?? '');
  if (!match) throw new HttpError(401, 'missing-token');
  const uid = await verifyIdToken(match[1], projectId, deps);
  if (!UID.test(uid)) throw new HttpError(400, 'unsupported-uid');
  return uid;
}

let cachedKeys = null;
let cachedUntil = 0;

/** Khóa công khai Google dùng ký ID token, giữ lại theo Cache-Control. */
async function fetchGoogleKeys() {
  if (cachedKeys && Date.now() < cachedUntil) return cachedKeys;
  const response = await fetch(GOOGLE_KEYS_URL);
  if (!response.ok) throw new Error(`Google keys: ${response.status}`);
  const { keys } = await response.json();
  const maxAge = /max-age=(\d+)/.exec(response.headers.get('Cache-Control') ?? '');
  cachedKeys = keys;
  cachedUntil = Date.now() + (maxAge ? Number(maxAge[1]) : 3600) * 1000;
  return keys;
}

function readConfig(env) {
  const config = {
    projectId: env.FIREBASE_PROJECT_ID,
    cloudName: env.CLOUDINARY_CLOUD_NAME,
    apiKey: env.CLOUDINARY_API_KEY,
    apiSecret: env.CLOUDINARY_API_SECRET,
  };
  if (Object.values(config).some((value) => !value)) {
    throw new HttpError(500, 'server-not-configured');
  }
  return config;
}

async function readBody(request) {
  try {
    const body = await request.json();
    return body !== null && typeof body === 'object' ? body : {};
  } catch {
    throw new HttpError(400, 'invalid-json');
  }
}

function base64UrlToBytes(value) {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

function nowSeconds(deps) {
  return deps.now?.() ?? Math.floor(Date.now() / 1000);
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
