# Database schema

Nguồn chuẩn: `server/migrations/0001_core.sql`, `0002_asset_revision.sql`, `0003_record_creation.sql`. Dùng prepared statements và transaction/batch của D1.

| Bảng | Khóa và vai trò |
|---|---|
| users | UID PK, created/updated timestamps; tạo khi JWT hợp lệ gọi API |
| admin_users | UID PK/FK users, active; allowlist do chủ dự án quản lý ngoài API |
| records | PK(uid,kind,id), FK users; JSON nghiệp vụ, version, tombstone, last_op, created/updated |
| changes | seq tăng dần, FK record, UNIQUE(uid,op_id); lịch sử đồng bộ và tombstone |
| sync_operations | PK(uid,op_id), request_hash + cached result; idempotency |
| assets | ID PK, FK users, public_id UNIQUE; photo/pdf, owner, meal ID/revision, trạng thái, metadata, hạn upload |
| device_tokens | installation_id PK, token UNIQUE, FK users; installation proof hash, generation, active |
| campaigns | UUID PK, UNIQUE(actor_uid,request_key), FK actor và target; nội dung và hash |
| deliveries | UUID PK, UNIQUE(campaign_id,installation_id); kết quả API, attempts, opened_at |
| admin_audit_logs | ID tăng dần, actor/action/target/request/time; không chứa token hay body |
| crash_snapshots | app ID, source Firebase, JSON đã redaction, fetched_at |
| maintenance_jobs | asset FK, run_after, attempts, status; cleanup trì hoãn |
| rate_limits | PK(bucket,identity), bộ đếm phút; cron dọn bucket cũ |

`records.kind` là profile/goals/meal/plan. Profile/goals dùng ID `self`; meal có stable client ID; plan dùng `${date}_${slot}`. Các ô plan được nhóm thành tuần ở client theo ngày. Đây là cấu trúc tương đương user_profiles/meals/meal_goals/weekly_plan_items; không tạo bảng weekly header khi chưa có dữ liệu nghiệp vụ riêng.

`assets.meal_id` là quan hệ nghiệp vụ tới record kind meal có cùng UID; xác minh ở API và câu lệnh conditional update. Migration 0002 có unique partial index bảo đảm mỗi bữa chỉ có một ảnh ready. Các index khác hỗ trợ owner/kind, cursor, device active và lịch sử.

Mutation record dùng version nguyên dương. baseVersion=0 chỉ tạo; update/delete yêu cầu đúng phiên bản hiện tại. Batch ghi record, change và cached operation cùng transaction. Conflict không âm thầm thay đổi dữ liệu. Timestamp do server sinh, không dùng thời gian client để chọn bên thắng.

SQLite trên Flutter: `local_records`, `outbox`, `sync_meta`. Owner là một phần khóa record và điều kiện mọi truy vấn. Outbox có stable op_id, payload frozen, attempts, next_at, state, local_sequence. Database version 2 thêm photo_base_version để bảo vệ ảnh chờ upload khỏi thay đổi ở thiết bị khác.

Chạy local từ server: `npm run db:migrate`. Test Workers áp dụng tất cả migrations vào D1 local rồi kiểm tra FK, UNIQUE, idempotency, CRUD và tombstone. Remote migration chưa chạy; không dùng UUID zero của local binding để deploy.
