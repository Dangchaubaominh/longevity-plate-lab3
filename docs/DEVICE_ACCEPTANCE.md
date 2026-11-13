# Nghiệm thu thiết bị thật — 13/11/2026

Thiết bị OPPO CPH2637, Android 16/API36, ARM64, ADB qua Wi-Fi. Bản debug nối Worker staging; không xóa dữ liệu app. APK SHA256: `1B1AB859CB85FB377F289055F18F1E30D0254B8DF1E2FC37594582A0F13C6C86`.

| Ca | Quan sát thực tế | Kết quả |
|---|---|---|
| Cài APK | `adb install -r` trả Success; Google sign-in và màn Home hoạt động | PASS |
| Integration native | `flutter test integration_test/staging_flow_test.dart -d <device> --dart-define=API_BASE_URL=<staging>` chạy 1/1 trên điện thoại | PASS |
| Meal/photo cloud | Firebase session thật → SQLite/outbox → D1 meal → chuẩn hóa JPEG → Cloudinary → tải ảnh riêng tư → xóa fixture bằng tombstone | PASS |
| Gallery native → cloud | Mở Android photo picker, người dùng chọn ảnh; lưu bữa `LAB3_GALLERY_DEVICE_20261113`, D1version2 có asset; private JPEG download HTTP200,228597bytes | PASS |
| SQLite recovery / retry / conflict | Native test `offline_recovery_test.dart`1/1: HTTP failure có kiểm soát, transaction/outbox trên SQLite Android, close/open database giữ opId/ảnh; nối API thật→đúng1record/asset; client thứ hai sửa revision→conflict; chọn server đúng dữ liệu; cleanup fixture | PASS |
| Android notification permission | Quan sát banner quyền đang tắt, bấm Bật thông báo → Android hiện hộp thoại → Allow; server nhận device registration | PASS |
| FCM foreground | Tin “Lab3 foreground” hiện trong S12 và SnackBar trên điện thoại | PASS |
| FCM background | Home để app ở nền → gửi riêng tài khoản thử → thấy notification Android → chạm mở Nhật ký; API có openedAt `2026-11-13T15:05:19.527Z` | PASS |
| FCM terminated | Kết thúc tiến trình bằng quyền run-as của bản debug; xác nhận pid rỗng trước gửi, không force-stop → notification Android đến → chạm mở Nhật ký; openedAt `2026-11-13T15:06:05.973Z` | PASS |
| Non-fatal SDK | Bấm Ghi lỗi non-fatal trên app; số event của nhóm demo tăng từ1 lên2 trên Firebase REST | PASS |
| Crash SDK → Admin | Bấm Gây crash thử nghiệm → xác nhận Gây crash → Android ghi FirebaseCrashlyticsTestCrash lúc22:11:28; mở lại app. Admin refresh phát hiện nhóm mới `ece9690113b884780b157ecd849ebd37`; detail/events trả eventTime `2026-11-13T15:11:28Z`, device CPH2637, Android16, app1.0.0 | PASS |
| Remote Config realtime | Publish2keys: version1=3/true; native UI ghi3/true; version2=1/false→native UI đổi1/false; version3 trở về3/true→native UI đổi đúng. Không rebuild APK giữa ba phiên bản | PASS |

Raw evidence nằm trong thư mục Git-ignored `artifacts/backend-implementation/`: `device-integration.txt`, `device-fcm-foreground.png`, `device-fcm-background-opened.json`, `device-fcm-terminated-opened.json`. Không công khai token, tài khoản khác trên thiết bị hoặc signed URL.

Hai integration tests đạt trên CPH2637. Ca offline dùng lỗi HTTP có kiểm soát và close/open database, không tuyên bố ngắt Wi-Fi hoặc kill tiến trình Android. Gallery đã thử native với ảnh người dùng chọn; camera capture là ca riêng. Không tính `accepted` của FCM là bằng chứng nhận tin nếu chưa quan sát trên điện thoại. Raw evidence: `device-offline-integration.txt`, `device-gallery-proof.json`, `device-native-crash.txt`, `device-crash-refresh.json`, `device-crash-detail.json` (private; không publish token/tài khoản khác).

## Bổ sung khám phá có giám sát14/11

16.04phút/5kiểm tra; xem EXPLORATORY_SESSION.md. Camera native mở rồi hủy; không ghi nhận camera capture/upload. Hai validation nhìn thấy trong ảnh thực dù hierarchy thiếu text. Hủy thay món giữ recipe/revision1 ở D1. Native PDF14925bytes HTTP200; RCv4=1/false thực sự giảm list còn1bài và ẩn gợi ý; v5=3/true khôi phục gợi ý. Không rebuild APK.
