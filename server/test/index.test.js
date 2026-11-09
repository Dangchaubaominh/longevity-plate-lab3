import assert from 'node:assert/strict';
import { test } from 'node:test';

import { handle, signParams, verifyIdToken } from '../src/index.js';

const PROJECT = 'longevity-plate';
const NOW = 1_800_000_000;
const env = {
  FIREBASE_PROJECT_ID: PROJECT,
  CLOUDINARY_CLOUD_NAME: 'demo-cloud',
  CLOUDINARY_API_KEY: '1234',
  CLOUDINARY_API_SECRET: 'abcd',
};

// Cặp khóa thay cho khóa của Google để tự ký ID token trong test.
const keyPair = await crypto.subtle.generateKey(
  {
    name: 'RSASSA-PKCS1-v1_5',
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: 'SHA-256',
  },
  true,
  ['sign', 'verify'],
);
const jwk = {
  ...(await crypto.subtle.exportKey('jwk', keyPair.publicKey)),
  kid: 'test-key',
  alg: 'RS256',
  use: 'sig',
};
const deps = { now: () => NOW, fetchKeys: async () => [jwk] };

const segment = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');

async function makeToken(claims = {}, header = {}) {
  const head = segment({ alg: 'RS256', kid: 'test-key', ...header });
  const body = segment({
    aud: PROJECT,
    iss: `https://securetoken.google.com/${PROJECT}`,
    sub: 'uidA',
    iat: NOW - 10,
    auth_time: NOW - 10,
    exp: NOW + 3600,
    ...claims,
  });
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    keyPair.privateKey,
    new TextEncoder().encode(`${head}.${body}`),
  );
  return `${head}.${body}.${Buffer.from(signature).toString('base64url')}`;
}

function post(path, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  return new Request(`https://worker.test${path}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
}

async function call(path, body, token, environment = env) {
  const response = await handle(post(path, body, token), environment, deps);
  return { status: response.status, body: await response.json() };
}

test('chữ ký khớp ví dụ trong tài liệu Cloudinary', async () => {
  const signature = await signParams(
    {
      timestamp: '1315060510',
      public_id: 'sample_image',
      eager: 'w_400,h_300,c_pad|w_260,h_200,c_crop',
    },
    'abcd',
  );
  assert.equal(signature, 'bfd09f95f331f558cbd1320e67aa8d488770583e');
});

test('ký lệnh tải lên vào thư mục của uid trong token', async () => {
  const token = await makeToken();
  const { status, body } = await call(
    '/reports/sign',
    { fileName: 'meal-report-1762500000000.pdf' },
    token,
  );

  assert.equal(status, 200);
  assert.equal(body.publicId, 'reports/uidA/meal-report-1762500000000');
  assert.equal(body.uploadUrl, 'https://api.cloudinary.com/v1_1/demo-cloud/image/upload');
  const { api_key: apiKey, signature, ...signed } = body.fields;
  assert.deepEqual(signed, {
    allowed_formats: 'pdf',
    asset_folder: 'reports/uidA',
    overwrite: 'false',
    public_id: 'reports/uidA/meal-report-1762500000000',
    timestamp: String(NOW),
    type: 'authenticated',
  });
  assert.equal(apiKey, '1234');
  assert.equal(signature, await signParams(signed, 'abcd'));
});

test('từ chối tên tệp lạ', async () => {
  const token = await makeToken();
  for (const fileName of ['../uidB/meal-report-1.pdf', 'meal-report-1762500000000.exe', 42]) {
    const { status, body } = await call('/reports/sign', { fileName }, token);
    assert.equal(status, 400, `fileName ${fileName}`);
    assert.equal(body.error, 'invalid-file-name');
  }
});

test('cấp link có hạn dùng cho tệp của chính mình', async () => {
  const token = await makeToken();
  const publicId = 'reports/uidA/meal-report-1762500000000';
  const { status, body } = await call('/reports/url', { publicId }, token);

  assert.equal(status, 200);
  assert.equal(body.expiresAt, NOW + 15 * 60);
  const url = new URL(body.url);
  assert.equal(url.origin + url.pathname, 'https://api.cloudinary.com/v1_1/demo-cloud/image/download');
  const params = Object.fromEntries(url.searchParams);
  const { api_key: apiKey, signature, ...signed } = params;
  assert.deepEqual(signed, {
    expires_at: String(NOW + 15 * 60),
    format: 'pdf',
    public_id: publicId,
    timestamp: String(NOW),
    type: 'authenticated',
  });
  assert.equal(apiKey, '1234');
  assert.equal(signature, await signParams(signed, 'abcd'));
});

test('không cấp link cho tệp của uid khác', async () => {
  const token = await makeToken();
  const { status, body } = await call(
    '/reports/url',
    { publicId: 'reports/UidKhacDeKiemThu/meal-report-1700000000000' },
    token,
  );
  assert.equal(status, 403);
  assert.equal(body.error, 'forbidden');
});

test('từ chối publicId sai dạng', async () => {
  const token = await makeToken();
  for (const publicId of ['reports/uidA/../uidB/meal-report-1', 'other/uidA/meal-report-1762500000000']) {
    const { status } = await call('/reports/url', { publicId }, token);
    assert.equal(status, 400, publicId);
  }
});

test('thiếu hoặc sai token thì trả 401', async () => {
  const valid = await makeToken();
  const [head, body] = valid.split('.');
  const otherSignature = (await makeToken({ sub: 'uidB' })).split('.')[2];
  const cases = {
    'không có token': undefined,
    'token hỏng': 'abc',
    'sửa nội dung token': `${head}.${body}.${otherSignature}`,
    'sai dự án': await makeToken({ aud: 'other-project' }),
    'sai nơi cấp': await makeToken({ iss: 'https://example.com' }),
    'hết hạn': await makeToken({ exp: NOW - 1 }),
    'khóa lạ': await makeToken({}, { kid: 'unknown' }),
    'thuật toán khác': await makeToken({}, { alg: 'HS256' }),
    'thiếu iat': await makeToken({ iat: undefined }),
    'thiếu auth_time': await makeToken({ auth_time: undefined }),
    'nội dung là null': `${head}.${segment(null)}.${otherSignature}`,
    'header là null': `${segment(null)}.${body}.${otherSignature}`,
  };
  for (const [name, token] of Object.entries(cases)) {
    const { status } = await call('/reports/sign', { fileName: 'meal-report-1762500000000.pdf' }, token);
    assert.equal(status, 401, name);
  }
});

test('verifyIdToken trả về uid khi token hợp lệ', async () => {
  assert.equal(await verifyIdToken(await makeToken(), PROJECT, deps), 'uidA');
});

test('báo lỗi cấu hình khi thiếu biến môi trường', async () => {
  const token = await makeToken();
  const { CLOUDINARY_API_SECRET: _secret, ...missingSecret } = env;
  const { status, body } = await call(
    '/reports/sign',
    { fileName: 'meal-report-1762500000000.pdf' },
    token,
    missingSecret,
  );
  assert.equal(status, 500);
  assert.equal(body.error, 'server-not-configured');
});

test('đường dẫn lạ trả 404', async () => {
  const response = await handle(new Request('https://worker.test/'), env, deps);
  assert.equal(response.status, 404);
});
