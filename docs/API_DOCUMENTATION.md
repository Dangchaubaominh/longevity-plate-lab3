# API và tích hợp

Đặc tả máy đọc: [openapi.json](openapi.json), sinh lại bằng `cd server; npm run openapi` từ Zod schemas. Base nghiệp vụ `/api/v1`; mọi route cần `Authorization: Bearer <Firebase ID token>` trừ `/health` và `/api/public/config`.

| Method/route | Hành vi |
|---|---|
| GET /me | UID và quyền Admin thực tế |
| GET/PUT /me/profile, /me/goals | Đọc/tạo/cập nhật record self |
| GET /meals, /plans | Danh sách của owner; from/to/cursor/limit |
| GET/PUT/DELETE /meals/:id, /plans/:id | CRUD theo stable ID; delete tạo tombstone |
| POST /sync/push | Tối đa 5 operation; kết quả riêng từng operation |
| GET /sync/pull | cursor số nguyên, limit≤20, items/nextCursor/hasMore |
| POST /media/sign | Cấp ticket cho photo hoặc PDF của owner |
| POST /media/:id/complete | Xác minh receipt signature và Cloudinary metadata |
| POST /media/:id/reconcile | Phục hồi kết quả qua Admin API Cloudinary |
| GET/DELETE /media/:id | Metadata / tombstone asset |
| POST /media/:id/url | URL download có hạn 15 phút |
| GET /files | Metadata tệp của người gọi |
| POST /devices/register, /devices/unregister | Registration token + installation proof + generation |
| GET /notifications; POST /notifications/:id/open | Lịch sử owner; xác nhận mở |
| GET /admin/overview, /users, /devices, /reports, /audit-logs | Thống kê, tìm kiếm/phân trang và metadata Admin |
| POST /admin/push | Campaign có requestKey ổn định, target UID, preview do web thực hiện |
| GET /admin/push-jobs, /push-jobs/:id | Lịch sử và kết quả theo thiết bị |
| GET /admin/crashlytics/issues | Snapshot Firebase gần nhất và fetchedAt |
| POST /admin/crashlytics/refresh | Đọc dữ liệu thật, cooldown 60 giây |
| GET /admin/crashlytics/issues/:id | Issue và tối đa 5 event Firebase |

Ví dụ PUT `/meals/meal_001`:

```json
{"opId":"operation_001","baseVersion":0,"data":{"date":"2026-11-13","type":"lunch","description":"Cơm rau"}}
```

Trả `{record:{id,kind,data,version,deletedAt,createdAt,updatedAt}}`. Gửi lại cùng opId/body nhận cùng kết quả; cùng opId nhưng body khác trả conflict. Để update dùng opId mới và baseVersion từ record đã đọc. DELETE vẫn gửi body Mutation, data có thể `{}`.

Sync push: `{operations:[{opId,kind,id,baseVersion,deleted,data}]}`. HTTP 200 chứa `results`; mỗi phần có record hoặc error.code/current. Client phải xét từng phần. Không tự retry conflict bằng baseVersion mới khi người dùng chưa chọn bản muốn giữ.

Pagination danh sách dùng cursor theo ID, limit 1–50, nextCursor=null khi hết; sync dùng seq để không bỏ thay đổi/tombstone. Search users là substring, max 80 ký tự. Date phải là ngày ISO hợp lệ ở payload. Profile tên≤80; meal description 1–120; goals thuộc ba enum; recipeId thuộc catalog hiện hành.

Lỗi mới: `{error:{code,message,requestId,retryable}}`. HTTP 400 input, 401 token, 403 Admin/origin, 404 không tồn tại hoặc khác owner, 409 revision/idempotency, 413 body quá 64KiB, 429 rate/cooldown, 502/503/504 provider. Lỗi không chứa credential. Client refresh ID token đúng một lần khi 401.

Hai route legacy `/reports/sign`, `/reports/url` giữ request/response và error string trước đây; metadata PDF legacy không tự xuất hiện trong bảng assets mới. Không tự migrate các file cũ không có bằng chứng owner/provider.
