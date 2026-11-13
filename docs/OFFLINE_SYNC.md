# Đồng bộ khi mất mạng

Nguồn chuẩn khi bật API_BASE_URL là SQLite. Mọi thao tác nghiệp vụ phải đi qua repository/LocalSyncStore. Legacy SharedPreferences chỉ được đọc trong migration một lần theo UID, không xóa dữ liệu nguồn.

Record local: owner, kind/id, data, server_version, local_sequence, tombstone, asset ID, photo_base_version, conflict. Outbox: op_id ngẫu nhiên ổn định, payload, baseVersion, state/attempts/backoff. Cùng một transaction ghi record và outbox; test trigger lỗi chứng minh rollback cả hai.

Operation chưa gửi có thể coalesce. Khi bắt đầu gửi, payload/opId/baseVersion được freeze. Mất response vẫn gửi lại đúng operation đó. Sửa tiếp tạo operation mới, chờ operation trước; chỉ ack của thao tác chính mình mới được rebase operation chưa freeze theo version trả về. Pull không tự rebase conflict để ghi đè người khác.

Chu kỳ: pull → push từng operation (tối đa 30/lượt) → upload ảnh của meal đã ack → pull. Giữ dữ liệu local đang chờ khi nhận record remote. Cursor và các record kéo được ghi cùng SQLite transaction. Tombstones không bị quên khi client nghỉ nhiều ngày; server hiện chưa compact history.

Đổi UID: xóa cache RAM, dùng điều kiện UID cho từng API/truy vấn, kiểm tra lại owner sau await. Data/outbox cũ còn trong sandbox theo UID. Initial route chờ khôi phục cache; lỗi mạng vẫn có dữ liệu đã lưu. Lifecycle resume và thao tác local kích hoạt sync; không polling liên tục khi không có thay đổi. Account → Đồng bộ có trạng thái và thử lại thủ công.

Retry mutation tối đa 3 lần, backoff tăng, lỗi terminal chuyển failed; conflict tách riêng. Pull/network cycle thất bại tự động dừng sau 3 lần; người dùng retry/reset sau đó. Ảnh có bộ đếm bền tối đa 3, kể cả thiếu file; retry chủ động mới mở lại. Không đánh dấu SYNCED cho bữa có ảnh còn chờ.

Xung đột business trả current record. Người dùng chọn giữ local (opId mới, baseVersion hiện tại) hoặc dùng server (bỏ operation xung đột). Photo base revision được lưu trước khi pull khác-device làm đổi version; upload stale bị chặn. Màn Đồng bộ có lựa chọn ảnh riêng. Nếu record đã bị xóa ở server, cần đồng bộ tombstone; không tự hồi sinh bằng timestamp client.

Tests: sync_store_test.dart (SQLite thật, rollback/restart/migration/owner/cursor/conflict/tombstone/photo), sync_engine_test.dart (repo→engine, offline/reconnect/lost response/no duplicate), backend_api_test.dart (401 refresh/logout/timeout). Hai thiết bị thật, ứng dụng bị OS kill và camera native cần checklist staging; không suy ra từ unit tests.
