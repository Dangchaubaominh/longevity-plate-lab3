# Nghiệm thu thiết bị thật — 13/11/2026

Thiết bị OPPO CPH2637, Android 16/API36, ARM64, ADB qua Wi-Fi. Bản debug nối Worker staging; không xóa dữ liệu app. APK SHA256: `1B1AB859CB85FB377F289055F18F1E30D0254B8DF1E2FC37594582A0F13C6C86`.

| Ca | Quan sát thực tế | Kết quả |
|---|---|---|
| Cài APK | `adb install -r` trả Success; Google sign-in và màn Home hoạt động | PASS |
| Integration native | `flutter test integration_test/staging_flow_test.dart -d <device> --dart-define=API_BASE_URL=<staging>` chạy 1/1 trên điện thoại | PASS |
| Meal/photo cloud | Firebase session thật → SQLite/outbox → D1 meal → chuẩn hóa JPEG → Cloudinary → tải ảnh riêng tư → xóa fixture bằng tombstone | PASS |
| Android notification permission | Quan sát banner quyền đang tắt, bấm Bật thông báo → Android hiện hộp thoại → Allow; server nhận device registration | PASS |
| FCM foreground | Tin “Lab3 foreground” hiện trong S12 và SnackBar trên điện thoại | PASS |
| FCM background | Home để app ở nền → gửi riêng tài khoản thử → thấy notification Android → chạm mở Nhật ký; API có openedAt `2026-11-13T15:05:19.527Z` | PASS |
| FCM terminated | Kết thúc tiến trình bằng quyền run-as của bản debug; xác nhận pid rỗng trước gửi, không force-stop → notification Android đến → chạm mở Nhật ký; openedAt `2026-11-13T15:06:05.973Z` | PASS |

Raw evidence nằm trong thư mục Git-ignored `artifacts/backend-implementation/`: `device-integration.txt`, `device-fcm-foreground.png`, `device-fcm-background-opened.json`, `device-fcm-terminated-opened.json`. Không công khai token, tài khoản khác trên thiết bị hoặc signed URL.

Integration test dùng fixture ảnh của repository để xác minh chuỗi native/cloud, không thay thế việc kiểm thử camera vật lý. Nút crash, camera/gallery và ARTEMIS được ghi thêm sau từng lần chạy. Không tính `accepted` của FCM là bằng chứng nhận tin nếu chưa quan sát trên điện thoại.
