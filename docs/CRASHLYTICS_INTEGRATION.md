# Crashlytics runtime cho Admin

Nguồn API chính thức được kiểm tra ngày 13/11/2026:

- [REST v1alpha](https://firebase.google.com/docs/reference/crashlytics/rest)
- [reports.list](https://firebase.google.com/docs/reference/crashlytics/rest/v1alpha/projects.apps.reports/list)
- [reports.get](https://firebase.google.com/docs/reference/crashlytics/rest/v1alpha/projects.apps.reports/get)
- [events.list](https://firebase.google.com/docs/reference/crashlytics/rest/v1alpha/projects.apps.events/list)

Adapter runtime nằm trong providers.ts/worker.ts, không phụ thuộc Firebase MCP của coding agent. OAuth scope cloud-platform; service account phải được quyền đọc Crashlytics theo chính sách project. Code không tự cấp quyền. FIREBASE_APP_ID là app Android thực, dạng `1:<projectNumber>:android:<id>`; project number được lấy từ app ID. GOOGLE_SERVICE_ACCOUNT_JSON phải có project_id khớp Firebase project hiện dùng.

Luồng Admin: server allowlist → reports.list → tìm báo cáo topIssues → reports.get với pageSize=20 → redaction → snapshot D1 có source/fetchedAt. GET snapshot không bịa dữ liệu khi trống. Refresh có cooldown 60 giây. Xem issue gọi issues.get và events.list (pageSize=5, filter.issue.id). Web hiển thị loại lỗi khi nguồn có, issue và JSON chi tiết gồm event/version/platform/stacktrace/custom keys nếu API trả.

Không tạo crash record từ thao tác bấm nút. Nút demo Flutter thật gọi FirebaseCrashlytics.instance.crash(); SDK phải ghi nhận và upload sau app mở lại. Lỗi nghiệp vụ được catch vẫn recordError non-fatal và UI hiển thị lỗi. Session gắn UID và custom route key; logout đặt UID null.

Nghiệm thu staging: đăng nhập tài khoản kiểm thử trên điện thoại, mở khu vực trình diễn và xác nhận nút crash; mở lại app để SDK gửi, chờ Firebase tiếp nhận; Dev kiểm tra Console; Admin mở web → Crashlytics → Làm mới → issue → event. Đối chiếu timestamp, app version, fatal/non-fatal, key và UID đã che. Chụp evidence ở cả Console và web. Không crash trong sử dụng thường ngày hoặc giả kết quả nếu dữ liệu chưa tới.

Đã kiểm chứng thật ngày13/11/2026: REST API, Reader role được user cho phép, staging refresh/detail/events HTTP200. Bấm nút trên APK mới gây native crash lúc22:11:28; mở lại app, refresh22:16 có nhóm fatal mới `ece9690113b884780b157ecd849ebd37` (tổng5 nhóm). Event API khớp `2026-11-13T15:11:28Z`, CPH2637/Android16/app1.0.0; non-fatal demo cũng tăng event. Evidence: DEVICE_ACCEPTANCE.md và raw `device-crash-detail.json`. Không tạo sự cố giả trong D1. Refresh cooldown/page size là giới hạn ứng dụng, không phải cam kết quota nhà cung cấp; v1alpha có thể đổi.
