# Tài liệu API thực tế (sau PR #4)

Phiên bản 0.2, 13/11/2026. Thay cho bản 0.1 (hợp đồng đặt ra trước khi code). PR #4 `feature/backend-admin-offline-sync` đã merge vào `main` và cài một kiến trúc khác hẳn bản 0.1 đã thống nhất: không phải REST đơn giản theo từng bữa ăn, mà là **đồng bộ bản ghi theo phiên bản (optimistic concurrency)** dùng chung cho mọi loại dữ liệu người dùng. Tài liệu này mô tả lại đúng những gì đang chạy trên `main`, đọc trực tiếp từ `server/src/*.ts`, `lib/services/sync/*.dart` và `server/test/api.spec.ts`.

## 0. Phạm vi và phân công

Vẫn chỉ phục vụ 3 workflow demo, nhưng cơ chế bên dưới đã đổi:

| Mã | Workflow | Cơ chế thật |
|---|---|---|
| WF-01 | Gửi lời nhắc ăn uống | Admin tạo "campaign" → mỗi thiết bị một "delivery" → FCM → app báo `opened` |
| WF-02 | Ghi nhận / xóa bữa ăn trong ngày | App ghi cục bộ vào SQLite (bảng `outbox`), đồng bộ nền lên `records` qua `/api/v1/sync/push` |
| WF-03 | Xuất báo cáo bữa ăn 7 ngày | App tạo PDF, ký tải lên Cloudinary qua `/api/v1/media/*`, không còn dùng `/reports/sign` |

Hệ thống thật còn làm nhiều hơn 3 workflow này (hồ sơ, mục tiêu, kế hoạch tuần, ảnh bữa ăn lên cloud, trang Admin xem thống kê/người dùng/audit log/Crashlytics). Tài liệu này mô tả đủ để vẽ ERD và kiến trúc đầy đủ (slide 09–16), nhưng phần workflow (slide 07, 17–20) vẫn chỉ xoáy vào 3 cái ở trên.

`lib/services/sync/sync_engine.dart` **chỉ gọi hai route chung** `/api/v1/sync/push` và `/api/v1/sync/pull` cho mọi loại dữ liệu (bữa ăn, kế hoạch, hồ sơ, mục tiêu) — không gọi trực tiếp `PUT/DELETE /api/v1/meals/{id}` dù route đó vẫn tồn tại trên server (dùng để test, hoặc cho ứng dụng khác gọi sau này).

## 1. Quy ước chung

- **Xác thực**: header `Authorization: Bearer <Firebase ID token>`. Server tự xác minh chữ ký RS256 bằng khóa công khai của Google (có cache theo `kid`), kiểm `issuer`, `audience`, `exp`/`iat`/`auth_time`. UID chỉ lấy từ token đã xác minh, body không có trường `uid`.
- **Giới hạn tốc độ**: 120 request/phút/UID (đếm theo phút trong bảng `rate_limits`), vượt thì trả 429 `rate_limited` (có thể thử lại).
- **CORS**: chỉ nhận cùng origin hoặc đúng `ADMIN_ORIGIN`.
- **Thân request**: tối đa 64 KiB, vượt trả 413 `body_too_large`. Mọi trường do client gửi được kiểm bằng Zod `.strict()` — thừa trường nào cũng bị từ chối.
- **Định dạng lỗi**:

  ```json
  { "error": { "code": "invalid_input", "message": "invalid_input", "requestId": "…", "retryable": false } }
  ```

- **Người dùng**: lần gọi đầu tiên có token hợp lệ, server tự thêm dòng vào `users` (`INSERT ... ON CONFLICT DO NOTHING`).
- **Admin**: route `/api/v1/admin/*` yêu cầu UID có mặt và `active = 1` trong `admin_users`, không thì trả 403 `admin_required`. Không có API nào tự cấp quyền Admin — phải tự chạy lệnh SQL (mục 10).

## 2. Business rule thật

| Mã | Quy tắc | Mã lỗi khi vi phạm |
|---|---|---|
| BR-01 | Mô tả bữa ăn 1–120 ký tự sau khi `trim` | Zod báo lỗi → 400 `invalid_input` |
| BR-02 | Loại bữa ∈ `breakfast, lunch, dinner, snack`; ngày `YYYY-MM-DD` phải là ngày có thật | 400 `invalid_input` |
| BR-03 | Mỗi lần ghi phải đúng `baseVersion` hiện tại của bản ghi (optimistic concurrency); sai thì **không** ghi đè | 409 `version_conflict` |
| BR-04 | Người dùng chỉ thấy, sửa, xóa đúng bản ghi/thiết bị/thông báo của chính mình (mọi câu SQL đều có `WHERE uid = ?`) | 404 `not_found` (không phân biệt "không có" và "của người khác") |
| BR-05 | Chỉ Admin đang `active` mới gọi được `/api/v1/admin/*` | 403 `admin_required` |
| BR-06 | Route đích của lời nhắc chỉ thuộc `/home`, `/log`, `/plan`, `/library`, `/notifications` (hoặc `/library/:id`, `/plan/recipe/:id`) | Zod báo lỗi → 400 `invalid_input` |
| BR-07 | Cùng Admin gửi lại cùng `requestKey` (hoặc cùng `opId` khi ghi bữa ăn) thì trả lại đúng kết quả cũ, không tạo thêm bản ghi hay gửi FCM lần hai | Trả lại kết quả cũ (200), hoặc 409 `idempotency_conflict` nếu nội dung gửi lại khác lần trước |
| BR-08 | Đánh dấu "đã mở" chỉ cập nhật `opened_at` nếu còn trống (`COALESCE`), gọi lại bao nhiêu lần cũng không đổi lần mở đầu tiên | Không có lỗi — idempotent |
| BR-09 | FCM báo token không còn hợp lệ (`UNREGISTERED`/`SENDER_ID_MISMATCH`) thì thiết bị chuyển `active = 0`, lần gửi sau không tính thiết bị đó | — |
| BR-10 | Chỉ xuất báo cáo khi 7 ngày gần nhất có ít nhất 1 bữa | App chặn trước khi gọi mạng (xem `ReportViewModel`) |
| BR-11 | Link tải ảnh/báo cáo hết hạn sau 15 phút (900 giây), ký bằng Cloudinary signed params, chỉ chủ sở hữu xin được link | 404 nếu không phải chủ |
| BR-12 | Một lời nhắc chỉ gửi tới tối đa 5 thiết bị đang hoạt động của một người | 400 `recipient_limit_exceeded` |
| BR-13 | Đăng ký lại thiết bị phải cùng `installationSecret` (server chỉ lưu hash) và `generation` không được lùi | 403 `invalid_installation_proof`, 409 `stale_device_registration` |

## 3. Database D1 (thật, `server/migrations/0001_core.sql` + `0002` + `0003`)

```sql
CREATE TABLE users (uid TEXT PRIMARY KEY, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);

CREATE TABLE admin_users (uid TEXT PRIMARY KEY REFERENCES users(uid), active INTEGER NOT NULL DEFAULT 1);

-- Một bảng dùng chung cho hồ sơ, mục tiêu, bữa ăn, kế hoạch tuần.
CREATE TABLE records (
  uid TEXT NOT NULL REFERENCES users(uid),
  kind TEXT NOT NULL CHECK(kind IN('profile','goals','meal','plan')),
  id TEXT NOT NULL,                 -- 'self' cho profile/goals; ID bữa ăn; '<ngày>_<buổi>' cho plan
  data_json TEXT NOT NULL CHECK(json_valid(data_json)),
  version INTEGER NOT NULL CHECK(version > 0),   -- tăng 1 mỗi lần sửa, dùng cho optimistic concurrency
  deleted_at TEXT,                  -- tombstone, không xóa dòng
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_op TEXT NOT NULL,            -- opId của lần ghi cuối, để nối với changes/sync_operations
  PRIMARY KEY(uid, kind, id)
);

-- Lịch sử thay đổi để thiết bị khác "pull" theo con trỏ tăng dần (seq).
CREATE TABLE changes (
  seq INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT NOT NULL, kind TEXT NOT NULL, id TEXT NOT NULL,
  version INTEGER NOT NULL, data_json TEXT NOT NULL, deleted_at TEXT, updated_at TEXT NOT NULL,
  op_id TEXT NOT NULL, UNIQUE(uid, op_id),
  FOREIGN KEY(uid, kind, id) REFERENCES records(uid, kind, id)
);

-- Cache kết quả theo opId: gọi lại cùng opId trả đúng kết quả cũ, không ghi lần hai.
CREATE TABLE sync_operations (
  uid TEXT NOT NULL REFERENCES users(uid), op_id TEXT NOT NULL, request_hash TEXT NOT NULL,
  result_json TEXT NOT NULL, created_at TEXT NOT NULL, PRIMARY KEY(uid, op_id)
);

-- Ảnh bữa ăn và PDF báo cáo, tải thẳng lên Cloudinary qua vé ký sẵn.
CREATE TABLE assets (
  id TEXT PRIMARY KEY, uid TEXT NOT NULL REFERENCES users(uid), kind TEXT NOT NULL CHECK(kind IN('photo','pdf')),
  meal_id TEXT, public_id TEXT NOT NULL UNIQUE, format TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN('pending','ready','rejected','deleted')),
  version TEXT, bytes INTEGER, width INTEGER, height INTEGER, content_hash TEXT NOT NULL,
  expires_at INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, meal_version INTEGER,
  UNIQUE(uid, id), UNIQUE(uid, kind, content_hash, meal_id)
);
-- Mỗi bữa chỉ có một ảnh "ready" tại một thời điểm (migration 0002).
CREATE UNIQUE INDEX one_ready_photo_per_meal ON assets(uid, meal_id) WHERE kind='photo' AND status='ready';

-- Thiết bị nhận FCM: chuyển quyền sở hữu cần đúng secret (server chỉ lưu hash) và generation tăng.
CREATE TABLE device_tokens (
  installation_id TEXT PRIMARY KEY, uid TEXT NOT NULL REFERENCES users(uid),
  token TEXT NOT NULL UNIQUE, secret_hash TEXT NOT NULL, generation INTEGER NOT NULL,
  active INTEGER NOT NULL, platform TEXT NOT NULL, app_version TEXT NOT NULL, updated_at TEXT NOT NULL
);

-- Một lượt Admin gửi lời nhắc.
CREATE TABLE campaigns (
  id TEXT PRIMARY KEY, actor_uid TEXT NOT NULL REFERENCES users(uid), target_uid TEXT NOT NULL REFERENCES users(uid),
  request_key TEXT NOT NULL, request_hash TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, route TEXT NOT NULL,
  status TEXT NOT NULL, created_at TEXT NOT NULL, UNIQUE(actor_uid, request_key)
);

-- Một lượt gửi tách theo từng thiết bị.
CREATE TABLE deliveries (
  id TEXT PRIMARY KEY, campaign_id TEXT NOT NULL REFERENCES campaigns(id), uid TEXT NOT NULL REFERENCES users(uid),
  installation_id TEXT NOT NULL, status TEXT NOT NULL, message_id TEXT, error_code TEXT,
  attempts INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER, opened_at TEXT, updated_at TEXT NOT NULL,
  UNIQUE(campaign_id, installation_id)
);

CREATE TABLE admin_audit_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, actor_uid TEXT NOT NULL, action TEXT NOT NULL, target_id TEXT NOT NULL, request_id TEXT NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE crash_snapshots (id INTEGER PRIMARY KEY AUTOINCREMENT, app_id TEXT NOT NULL, source TEXT NOT NULL, payload_json TEXT NOT NULL, fetched_at TEXT NOT NULL);
CREATE TABLE maintenance_jobs (id TEXT PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id), run_after INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'pending');
CREATE TABLE rate_limits (bucket INTEGER NOT NULL, identity TEXT NOT NULL, count INTEGER NOT NULL, PRIMARY KEY(bucket, identity));
```

Ghi chú quan trọng:

- `records` dùng chung cho 4 loại dữ liệu (`kind`), không phải một bảng `meals` riêng như bản 0.1. Muốn lấy bữa ăn thì lọc `kind = 'meal'`.
- Không xóa thật: `deleted_at` là tombstone, giữ dòng lại để các thiết bị khác đồng bộ biết đã xóa.
- `version` dùng cho optimistic concurrency: ghi đè phải gửi đúng `baseVersion` hiện tại, sai thì bị chặn (BR-03), không có khái niệm "server từ chối vĩnh viễn" như bản 0.1.
- `assets.meal_version` khóa một ảnh vào đúng phiên bản bữa ăn tại lúc xin tải lên — bữa ăn bị sửa ở thiết bị khác trong lúc đang tải ảnh thì ảnh đó bị từ chối khi xác nhận (409 `version_conflict`), tránh gắn nhầm ảnh.
- `device_tokens`: đổi thiết bị/đăng nhập lại phải cùng `installationSecret` (server chỉ so sánh hash SHA-256) và `generation` tăng dần — không chỉ dựa vào `fcmToken` như bản 0.1.

Quan hệ dùng cho ERD:

| Quan hệ | Bản số |
|---|---|
| users – records | 1 – 0..* |
| users – admin_users | 1 – 0..1 |
| users – device_tokens | 1 – 0..* |
| users – assets | 1 – 0..* |
| records(meal) – assets (ảnh) | 1 – 0..1 đang `ready` |
| admin_users – campaigns (người gửi) | 1 – 0..* |
| users – campaigns (người nhận) | 1 – 0..* |
| campaigns – deliveries | 1 – 1..* |
| device_tokens – deliveries | 1 – 0..* |
| records – changes | 1 – 0..* |

## 4. State machine

### Bữa ăn trên máy (nhãn hiện ở S04, `lib/views/meal_screens.dart`)

Nguồn: cột suy ra từ bảng `outbox` trong SQLite (`lib/services/sync/local_sync_store.dart`), không phải trạng thái lưu trên server.

| Trạng thái hiển thị | Khi nào |
|---|---|
| (không có nhãn) | Chưa bật đồng bộ (`API_BASE_URL` trống) — app chạy như Lab 3, chỉ lưu máy |
| "Đã lưu trên máy · chờ đồng bộ" | Vừa ghi/sửa/xóa, còn một dòng trong `outbox` ở trạng thái `pending` hoặc `inflight` |
| "Đã đồng bộ" | Không còn dòng nào trong `outbox` cho bản ghi này — server đã nhận |
| "Cần thử đồng bộ lại" | Dòng `outbox` chuyển `failed` (hết 3 lần thử) |
| "Có xung đột · mở Đồng bộ" | Server trả 409 `version_conflict` (bản ghi đã bị sửa ở thiết bị khác) — người dùng chọn giữ bản trên máy hay lấy bản trên server ở màn Đồng bộ |

Chuyển trạng thái của **bản ghi** (không phải outbox):

| Từ | Sự kiện | Đến |
|---|---|---|
| (chưa có) | Ghi lần đầu, `baseVersion = 0` | `version = 1` |
| version = v | Sửa đúng `baseVersion = v` | `version = v + 1` |
| version = v | Sửa sai `baseVersion` (đã đổi ở nơi khác) | **Từ chối**, trả 409 `version_conflict`, không đổi gì |
| bất kỳ | Xóa đúng `baseVersion` hiện tại | `deleted_at` được đặt, `version` vẫn tăng |
| đã `deleted_at` | Ghi lại | Coi như bản ghi mới (ứng dụng chưa tái sử dụng ID đã xóa cho bữa ăn, vì ID sinh từ thời điểm tạo) |

### Thông báo gửi tới một thiết bị (`deliveries.status`)

| Từ | Sự kiện | Đến |
|---|---|---|
| (chưa có) | Admin gửi, đủ điều kiện BR-05, BR-06, BR-07, BR-12 | `pending` |
| `pending`/`retry` | Bắt đầu gọi FCM (khóa bằng `UPDATE ... WHERE status IN(...)` để không gửi trùng) | `sending` |
| `sending` | FCM nhận, trả `message_id` | `accepted` |
| `sending` | FCM từ chối token (`UNREGISTERED`, `SENDER_ID_MISMATCH`) | `failed`, thiết bị chuyển `active = 0` |
| `sending` | Lỗi tạm thời (429/5xx), còn dưới 3 lần thử | `retry`, thử lại sau 30s × 2^lần |
| `sending` | Tiến trình bị ngắt giữa chừng (job nền phát hiện `sending` quá cũ) | `unknown` (không coi là thất bại hay thành công) |
| bất kỳ | Người dùng chạm thông báo | Không đổi `status`, chỉ đặt `opened_at` nếu còn trống (BR-08) |

## 5. API thật

Tiền tố `/api/v1`. Mọi route cần `Authorization: Bearer <token>` trừ `GET /health` và `GET /api/public/config`.

### 5.1. Đồng bộ chung — App Flutter chỉ gọi hai route này cho bữa ăn/kế hoạch/hồ sơ/mục tiêu

**`POST /sync/push`** — body `{ "operations": [ { opId, kind, id, baseVersion, deleted, data } ] }`, tối đa 5 operation một lần gọi.

- `kind` ∈ `profile | goals | meal | plan`. Với `meal`: `data = { date, type, description }` (không còn `createdAt` do client gửi — server tự đặt `created_at`/`updated_at`).
- Trả `{ "results": [ { opId, record } hoặc { opId, error: { code }, current } ] }` — mỗi operation có kết quả riêng, một cái lỗi không chặn các cái khác.
- `current` chỉ có khi lỗi là 409 `version_conflict`, chứa bản ghi mới nhất trên server để app tự quyết định (giữ máy hay lấy server).
- Cùng `opId` gọi lại với cùng nội dung → trả lại đúng kết quả cũ (BR-07). Cùng `opId` khác nội dung → lỗi `idempotency_conflict`.

**`GET /sync/pull?cursor=<seq>&limit=20`** — kéo các thay đổi (kể cả tombstone) có `seq > cursor`, tối đa 20 dòng một lần gọi, lặp cho tới khi `hasMore = false`.

### 5.2. Theo từng loại (REST, chủ yếu để test hoặc tích hợp khác — app Flutter không gọi trực tiếp)

`GET/PUT /me/profile`, `GET/PUT /me/goals`, `GET/PUT/DELETE /meals/{id}`, `GET /meals?from&to&cursor`, `GET/PUT/DELETE /plans/{id}`. `PUT`/`DELETE` nhận body `{ opId, baseVersion, data }`, xử lý qua đúng `applyOperation` như `/sync/push`.

### 5.3. Thiết bị

**`POST /devices/register`** — body `{ installationId, installationSecret, token, generation, platform, appVersion }`. `installationSecret` dài 32–100 ký tự, server chỉ lưu hash SHA-256. Đổi thiết bị/sinh lại secret phải tăng `generation`, không thì bị từ chối (BR-13). Cùng `token` đã gắn cho installation khác thì trả 409 `token_already_registered`.

**`POST /devices/unregister`** — body `{ installationId, installationSecret, generation }`, chuyển `active = 0`.

### 5.4. Thông báo (phía người nhận)

**`GET /notifications?limit&cursor`** — lịch sử thông báo của người gọi, có phân trang.

**`POST /notifications/{id}/open`** — đặt `opened_at` nếu còn trống, trả `{ "opened": true }`. 404 nếu không phải thông báo của người gọi.

### 5.5. Ảnh và PDF (`/media/*`, thay cho `/reports/sign`+`/reports/url` cũ)

**`POST /media/sign`** — body `{ kind: "photo"|"pdf", mealId?, mealVersion?, contentHash (SHA-256 64 hex), fileName? }`. Trả vé tải thẳng lên Cloudinary: `assetId`, `uploadUrl`, `fields` (có `signature` ký bằng secret Cloudinary, hạn 1 giờ). Ảnh gắn `mealId`+`mealVersion` thì bị từ chối nếu bữa đã đổi phiên bản từ lúc đó (409 `version_conflict`).

**`POST /media/{id}/reconcile`** (app chỉ cần endpoint này, không cần chữ ký Cloudinary gửi về) hoặc **`POST /media/{id}/complete`** (có chữ ký, dùng khi provider trả callback) — server tự hỏi Cloudinary xem tệp đã lên chưa, kiểm kích thước/định dạng, rồi chuyển `assets.status` sang `ready`. Ảnh thì tăng luôn `version` của bữa ăn liên quan.

**`POST /media/{id}/url`** — cấp link tải có hạn 15 phút (BR-11), chỉ chủ sở hữu xin được.

**`DELETE /media/{id}`** — tombstone, dọn trên Cloudinary bằng job nền (`maintenance_jobs`).

`POST /reports/sign` và `POST /reports/url` (route cũ từ Lab 3) vẫn được giữ chạy song song để không phá tương thích ngược, nhưng `ReportViewModel`/`ConnectedReportStorage` hiện tại gọi `/media/*` ở trên khi đã bật `API_BASE_URL`.

### 5.6. Admin (`/admin/*`, cần `admin_users.active = 1`)

| Route | Việc làm |
|---|---|
| `GET /admin/overview` | Đếm nhanh: số người dùng, bữa ăn, kế hoạch, thiết bị hoạt động, lượt gửi |
| `GET /admin/users?search&cursor` | Danh sách người dùng, tìm theo UID hoặc tên hiển thị, kèm số bữa/kế hoạch |
| `GET /admin/recipients` *(không có — xem `GET /admin/devices`)* | — |
| `GET /admin/devices?cursor` | Danh sách thiết bị đang đăng ký |
| `POST /admin/push` | Gửi lời nhắc — xem mục 6 |
| `GET /admin/push-jobs`, `GET /admin/push-jobs/{id}` | Lịch sử gửi và chi tiết từng lượt |
| `GET /admin/reports?cursor` | Danh sách PDF đã tạo (từ bảng `assets`) |
| `GET /admin/audit-logs?cursor` | Nhật ký thao tác Admin |
| `GET /admin/crashlytics/issues`, `POST /admin/crashlytics/refresh`, `GET /admin/crashlytics/issues/{id}` | Đọc Crashlytics thật qua Firebase API, có cache và giới hạn làm mới 1 phút/lần |

## 6. Gửi lời nhắc (WF-01 thật)

**`POST /admin/push`** — body:

```json
{ "requestKey": "…", "targetUid": "…", "title": "Nhắc ghi bữa tối", "body": "Bạn đã ăn tối chưa?", "route": "/log" }
```

1. Cùng `requestKey` gọi lại → trả lại lượt cũ, không tạo thêm, không gửi FCM lần hai (BR-07).
2. Lấy tối đa 6 thiết bị `active = 1` của `targetUid`; quá 5 thì từ chối (BR-12); không có thiết bị nào thì 409 `no_active_devices`.
3. Tạo 1 `campaign` + mỗi thiết bị 1 `delivery` (`pending`), rồi gọi FCM lần lượt cho từng `delivery`.

Payload gửi cho FCM:

```json
{
  "message": {
    "token": "<device_tokens.token>",
    "notification": { "title": "…", "body": "…" },
    "data": { "route": "/log", "notificationId": "<deliveries.id>", "targetUid": "<uid người nhận>" }
  }
}
```

App đọc `data.notificationId` để gọi `POST /notifications/{id}/open`, và `data.targetUid` để biết thông báo này của ai (quan trọng khi app đang ở nền và chưa chắc ai đang đăng nhập).

## 7. Workflow nối với API (thật)

**WF-01 · Gửi lời nhắc ăn uống**

1. Admin đăng nhập web (`AuthService` Firebase + check `admin_users` qua lần gọi `/me` hoặc `/admin/*` đầu tiên).
2. Admin chọn người nhận (`GET /admin/users`), soạn nội dung, xác nhận gửi (`POST /admin/push`).
3. Server tạo `campaign`+`deliveries`, gọi FCM, cập nhật `accepted`/`failed`/`retry`.
4. Điện thoại hiện thông báo (kể cả khi app đóng, qua background handler). Chạm vào: app mở route trong `data.route` (đã kiểm hợp lệ từ BR-06) và gọi `POST /notifications/{id}/open`.
5. Admin xem `GET /admin/push-jobs/{id}` thấy `openedAt`.

**WF-02 · Ghi nhận / xóa bữa ăn trong ngày**

1. Người dùng ghi/sửa/xóa bữa ở S05/S04. `MealRepository` ghi ngay vào SQLite cục bộ (bảng `local_records`) **trong cùng transaction** với một dòng `outbox` mới — không bao giờ mất một trong hai.
2. `SyncEngine` (chạy nền, không chặn UI) lấy từng dòng `outbox`, gửi `POST /sync/push` với đúng `opId`/`baseVersion` đã "đóng băng" lúc ghi.
3. Thành công: xóa dòng `outbox`, bản ghi hiện "Đã đồng bộ". Mất mạng/lỗi tạm thời: giữ `pending`, thử lại có backoff (tối đa 3 lần rồi chuyển `failed`). Xung đột phiên bản: chuyển `conflict`, người dùng tự chọn ở màn Đồng bộ.
4. `SyncEngine` còn định kỳ `GET /sync/pull` để nhận thay đổi từ thiết bị khác, kể cả tombstone.

**WF-03 · Xuất báo cáo bữa ăn 7 ngày**

1. App kiểm BR-10 (7 ngày gần nhất phải có ít nhất 1 bữa) — chặn trước khi gọi mạng.
2. Tạo PDF, gọi `POST /media/sign` (kind `pdf`) để xin vé tải thẳng lên Cloudinary.
3. Tải file lên thẳng Cloudinary bằng vé đó (app không đi qua Worker để truyền file).
4. Gọi `POST /media/{id}/reconcile` để server xác nhận với Cloudinary rồi chuyển `assets.status = ready`.
5. Gọi `POST /media/{id}/url` lấy link tải hạn 15 phút (BR-11).

## 8. Test đã có (không cần viết lại, chỉ cần biết để trích dẫn)

`server/test/api.spec.ts` (918 dòng, chạy bằng `npm test` trong `server/`), nhóm theo 4 `describe`:

| Nhóm | Ý chính | Liên quan |
|---|---|---|
| `authentication and API boundaries` | Token giả/không có/sai project đều 401; body/role không tự nâng quyền; CORS, rate limit, giới hạn độ dài | BR-04, BR-05 |
| `D1 CRUD, revisions and synchronization` | Lưu đúng, cách ly UID, phân trang; cùng `opId` gọi lại không tạo thêm; sửa sai `baseVersion` bị chặn; `pull` trả tombstone và con trỏ ổn định; kiểm dữ liệu chặn SQL injection | BR-01, BR-02, BR-03, BR-07 |
| `Cloudinary authorization and verified metadata` | Vé ký theo đúng chủ sở hữu; xác nhận lặp lại vẫn idempotent; từ chối biên lai giả; từ chối sai kích thước/định dạng; không gắn ảnh vào bữa đã xóa hoặc đang sửa ở nơi khác | BR-11 |
| `device lifecycle and FCM outcomes` | Đăng ký/xoay token cần đúng bằng chứng thiết bị; chỉ Admin được gửi, gửi lại cùng `requestKey` không trùng; token hỏng bị vô hiệu chứ không tính là đã gửi; route lạ bị chặn | BR-05, BR-06, BR-07, BR-09, BR-12, BR-13 |

Phía app: `test/backend_api_test.dart` (gọi API, làm mới token khi 401, timeout), `test/sync_engine_test.dart` (lên lịch gửi, mất mạng, mất phản hồi không gửi trùng), `test/sync_store_test.dart` (SQLite thật: transaction, khôi phục sau khởi động lại, tách theo UID, con trỏ, xung đột, tombstone), `test/notification_owner_test.dart` (chỉ chủ thông báo mới báo "đã mở" được).

## 9. Thiết lập cần để bật kết nối thật

1. `--dart-define=API_BASE_URL=<url Worker>` lúc build (khác tên biến `REPORT_API_URL` ở bản 0.1). Thiếu biến này thì app chạy hoàn toàn cục bộ như Lab 3.
2. Secret Cloudinary (3 cái, giữ như cũ) và `GOOGLE_SERVICE_ACCOUNT_JSON` cho FCM + Crashlytics, đặt bằng `npx wrangler secret put`, không đưa vào Git.
3. Cấp quyền Admin: đăng nhập một lần để có dòng `users`, rồi:

   ```bash
   npx wrangler d1 execute <tên-db> --remote --command "INSERT INTO admin_users (uid, active) VALUES ('<UID>', 1)"
   ```

4. `FIREBASE_APP_ID` + quyền đọc Crashlytics (nếu muốn dùng mục Crashlytics trên Admin — ngoài phạm vi 3 workflow chính).
