# Thuyết minh slide kết hợp báo cáo

Guide yêu cầu PDF12–15trang, không quy định template/font/thứ tự. Bản này15trang, nội dung liên kết với báo cáo12trang. Speaker notes giữ chi tiết nguyên lý, code và giới hạn bằng chứng; không tạo ảnh Console giả.

## 1. Longevity Plate

Báo cáo: Trang1.

Bài báo cáo PRM393 Lab3 của ứng dụng nhật ký và kế hoạch bữa ăn. Trọng tâm là ba luồng đã hiện thực và cách các dịch vụ phối hợp. Mobile Flutter chạy trên OPPO CPH2637 Android16; Admin dùng Web riêng. Cloudinary thay Firebase Storage theo hướng dẫn bổ sung của giảng viên. Ảnh bìa là asset thương hiệu của dự án, không phải ảnh nghiệm thu.

## 2. Mục tiêu và ba luồng sử dụng

Báo cáo: Trang1–2.

F01: Google login, chọn mục tiêu, về Home. F02: chọn ngày và loại bữa, ảnh, mô tả rồi lưu. F03: đọc kiến thức, mở công thức và đưa vào kế hoạch. Các nhánh hủy, dữ liệu rỗng, validation và lỗi tải được quản lý trong ViewModel. Ảnh bên phải là Home thật trên CPH2637; các món công thức có nhãn minh họa, không đưa ra chẩn đoán hoặc điểm sức khỏe. Source: docs/design-traceability.md; lib/app/router.dart.

## 3. Kiến trúc MVVM + Provider

Báo cáo: Trang2–3.

MVVM: View chỉ hiển thị và phát thao tác; ViewModel quản lý loading/data/empty/error; repository và service xử lý dữ liệu/SDK. Provider cấp dependency; GoRouter bảo vệ route. SQLite native lưu local_records/outbox/sync_meta theo UID. API Worker Hono/TypeScript xác minh Firebase JWT, ownership, revision, Admin allowlist. D1 lưu dữ liệu và metadata. Cloudinary giữ file authenticated. Firebase Auth/FCM/Analytics/Crashlytics/Remote Config có vai trò riêng. Source: docs/SYSTEM_ARCHITECTURE.md; lib/app/app_services.dart; server/src/worker.ts.

## 4. F01  Đăng nhập và bảo vệ dữ liệu

Báo cáo: Trang4.

Google OAuth trả credential cho Firebase Auth. SDK quản lý phiên và ID token; BackendApi gắn Authorization Bearer vào request. Worker kiểm tra chữ ký RS256, issuer, audience, expiry và subject rồi lấy UID từ token. Token hết hạn được refresh đúng một lần khi401. Không tin UID tự khai trong form/query. Hủy login giữ màn đăng nhập và thông báo; logout xóa trạng thái UID hiện tại, dừng xử lý notification của owner cũ và route guard chặn dữ liệu. User thường gọi Admin API bị403. Sources: lib/services/firebase/firebase_auth_service.dart; lib/viewmodels/session_view_model.dart; lib/services/sync/backend_api.dart; server/src/providers.ts; https://firebase.google.com/docs/auth/admin/verify-id-tokens

## 5. F02  Lưu một bữa ăn có ảnh

Báo cáo: Trang2,5–6.

Người dùng chọn ngày không vượt quá hôm nay, loại bữa bắt buộc, tên món tối đa120ký tự; ảnh tùy chọn camera/gallery. Photo picker native sao chép ảnh vào app sandbox, tránh mất file tạm. AddMealViewModel validation trước submit; transaction ghi meal và outbox. Sync tạo record có revision trên D1 rồi upload photo theo base revision. D1version2 của bữa LAB3_GALLERY_DEVICE_20261113 có ready asset; JPEG private tải200/228597bytes. Camera đã mở/hủy; không suy ra camera capture/upload từ ca cancel. Mất mạng hoặc lỗi HTTP giữ dữ liệu local và cho retry. Sources: lib/views/meal_screens.dart; lib/viewmodels/add_meal_view_model.dart; device_meal_photo_service.dart; docs/DEVICE_ACCEPTANCE.md.

## 6. Cloudinary  Ảnh và PDF theo chủ sở hữu

Báo cáo: Trang5.

Luồng media: client gửi hash/kind cùng mealId/revision nếu là photo; Worker xác minh Firebase token và owner rồi cấp signed ticket. Client upload trực tiếp Cloudinary, không giữ API Secret. Worker complete/reconcile kiểm tra receipt và metadata provider trước ready asset. PDF được ReportBuilder tạo từ nhật ký7ngày, ConnectedReportStorage upload với progress rồi xin owner URL có thời hạn15phút. Path reports/UID nằm phía provider. Giới hạn app: JPEG5MiB, PDF10MiB. Provider15/15 và staging40/40 gồm A/B owner isolation, unsigned denial và cleanup. PDF native200/14925bytes/1trang; không công khai signed URL. Firebase/storage.rules là phương án tham chiếu không deploy. Sources: server/src/media.ts; lib/services/sync/connected_storage.dart; https://cloudinary.com/documentation/upload_images

## 7. Đồng bộ khi mất kết nối và xung đột

Báo cáo: Trang6.

Một transaction lưu local record+outbox. Mỗi operation giữ opId và frozen payload; retry dùng lại chính operation. Server idempotency cache trả lại kết quả cũ. baseVersion chống ghi đè bản mới; hai client sửa cùngrevision thì chọn local/server rõ ràng. Cursor lấy thay đổi tăng dần; tombstone truyền xóa để không hồi sinh dữ liệu. Thử trên CPH2637 dùng HTTP failure có kiểm soát và close/open SQLite, không ngắt Wi-Fi hoặc kill OS process. Sau nối dịch vụ thật, đúng1record/asset; API client thứ hai tạo revision conflict và chọn server. Sources: local_sync_store.dart; sync_engine.dart; server/src/records.ts; integration_test/offline_recovery_test.dart.

## 8. F03  Kiến thức đến kế hoạch tuần

Báo cáo: Trang2,6.

Luồng S08→S09→S06→S07→S06. Tìm kiếm không dấu và empty state là nhánh thư viện; nguồn WHO mở browser Android rồi Back về bài. Chọn công thức đặt ngày/bữa rồi thêm vào kế hoạch. Món gợi ý chỉ hiển thị công thức đầu; muốn chọn món khác đi qua Chọn món. Khi slot đã có recipe khác, dialog Thay thế món hiện tại? yêu cầu xác nhận. Phiên khám phá chọn Bánh mì và trứng vào20/11 breakfast đang có Cơm rau củ và đậu; Hủy giữ recipe rice-veg-beans version1 tại D1. Ảnh dialog bên phải là bằng chứng native; minh họa toast bên trái là asset công thức. Sources: plan_screens.dart; planner_view_model.dart; recipe_view_model.dart; EXPLORATORY_SESSION.md.

## 9. FCM  Token và đường đi của thông báo

Báo cáo: Trang7.

Firebase Messaging SDK lấy registration token do FCM cấp cho app instance trong project. SDK quản lý token/cache; client gọi getToken, onTokenRefresh và đăng ký với Worker theoUID/installation/generation. Token có thể đổi sau cài lại hoặc SDK refresh; logout hủy liên kết, registration proof/generation ngăn request cũ gắn sang account khác. Firebase ID token dùng Authorization API, FCM token dùng làm đích gửi, không tự cấp quyền đọc dữ liệu. Admin xác nhận gửi, Worker lấy token active và OAuth service account gọi FCM HTTPv1; cloud secret không nằm ở client. Sources: firebase_messaging_service.dart; SyncEngine.registerDevice; server/src/notifications.ts; https://firebase.google.com/docs/cloud-messaging/flutter/get-started; https://firebase.google.com/docs/cloud-messaging/send/v1-api

## 10. FCM  Nhận tin ở ba trạng thái Android

Báo cáo: Trang7.

Foreground: onMessage hiện SnackBar và lưu S12. Background: notification Android tới, chạm dùng onMessageOpenedApp mở /log. Terminated: tiến trình own debug kết thúc, xác minh PIDrỗng; getInitialMessage mở đúng route sau session restore. Không dùng force-stop để suy raterminated. openedAt thực lần nền15:05:19.527Z, lần terminated15:06:05.973Z ngày13/11. Android16 xin quyền notification; khi bịtắt app hướng dẫn bật và không coi registration là delivery. Token invalid bịvôhiệuhóa; timeout không rõ kết quả không tựresend vôhạn. Image: device-fcm-foreground.png, native message history. Sources: DEVICE_ACCEPTANCE.md; notifications_view_model.dart; FCM_SETUP.md.

## 11. Analytics  Đo từng bước của ba flow

Báo cáo: Trang8.

Kế hoạch17events ở docs/analytics-plan.md được viết theo baflow; tên khuyến nghị login/select_content, tùy chỉnh snake_case. meal_saved chỉ phát sau lưu thành công; duration_ms đo thời gian nghiệp vụ. Params String/int, không email, tên món tự nhập, queryraw hoặc token. UserID là FirebaseUID, đặt sau login và xóa logout. ResilientAnalyticsService bắt lỗi đo lường để không biến bữa đã lưu thành thất bại rồi retrytrùng. 8ảnh DebugView có sẵn trước campaignbackend; ảnh bên phải là meal_saved/duration_ms, không mô tả là screenshotbuildcuối. Các event không có screenshot đầy đủ được ghi riêng ASSIGNMENT_ACCEPTANCE.md; không thay bằng unit logs. Sources: firebase_analytics_service.dart; service_interfaces.dart; https://firebase.google.com/docs/analytics/debugview

## 12. Crashlytics  App phát sinh, Admin xem trên Web

Báo cáo: Trang9.

Crashlytics phân biệt hai trường hợp. Lỗi đã xử lý được ghi non-fatal và giao diện vẫn cho người dùng thử lại. Nút crash trong khu vực Demo có hộp xác nhận rồi gọi FirebaseCrashlytics.instance.crash(), làm tiến trình Android dừng thật. Sau khi mở lại, SDK gửi dữ liệu; Firebase có thời gian xử lý riêng. User ID và custom key route bổ sung ngữ cảnh; logout xóa liên kết tài khoản cũ.
Sự cố mới có eventTime2026-11-13T15:11:28Z, khớp CPH2637/Android16/app1.0.0. Worker dùng OAuth với service account có Crashlytics Viewer để đọc reports/issues/events qua RESTv1alpha. Web Admin đọc snapshot có source và fetchedAt, không tự tạo crash record từ sự kiện bấm nút. Dev có thể xem Firebase Console; Admin dùng Web riêng. Bảng trên slide là dữ liệu REST đã đối chiếu, không phải ảnh chụp Console. Code: firebase_crash_service.dart, account_screen.dart, server/src/providers.ts và worker.ts. Nguồn: https://firebase.google.com/docs/reference/crashlytics/rest

## 13. Remote Config  Đổi hành vi không rebuild

Báo cáo: Trang8.

Ứng dụng đặt defaults trước khi tải cấu hình: max_knowledge_results=3 và suggested_recipes_enabled=true. fetchAndActivate lấy và kích hoạt cấu hình; onConfigUpdated hỗ trợ cập nhật realtime. Khi fetch lỗi hoặc mất mạng, ứng dụng giữ giá trị đã activate/cache, hoặc defaults khi chưa có giá trị từ server.
Trong phiên khám phá, templatev4=1/false làm thư viện chỉ còn một bài và khu vực Món gợi ý biến mất. Templatev5=3/true khôi phục giá trị và khu vực gợi ý trong cùng APK. Hai ảnh trên slide là trạng tháifalse và trạng tháitrue đã khôi phục; chúng được cắt bỏ thanh hệ thống, không đổi nội dung UI. Remote Config không lưu secret và không thay thế quyền server. Code: firebase_remote_config_service.dart và RemoteConfigKeys trong service_interfaces.dart. Bằng chứng: EXPLORATORY_SESSION.md. Nguồn: https://firebase.google.com/docs/remote-config/flutter/get-started

## 14. Kiểm thử  Phân biệt test local và cloud thật

Báo cáo: Trang10–11.

169 kiểm tra tự động gồm102Flutter,55backend,8Admin RTL và4Playwright. Đây là kiểm tra local/fixtures, được phân biệt với15/15 kiểm tra Cloudinary provider thật và40/40 kiểm tra API staging dùng Firebase, D1, media và Crashlytics thật. Hai integration tests chạy trên CPH2637 kiểm tra luồng ảnh online, lỗi HTTP có kiểm soát, SQLite close/open, retry và revision conflict. Không diễn giải thành ngắt Wi-Fi hoặc kill tiến trình Android.
ARTEMIS official chạy10ca, mỗi ca3lượt, giữ36attempts gồm retry. Đối chiếu ảnh/UI/cloud cho16PASS và14FAIL, tương đương53,33%. Các false positive gồm chuỗi chỉ xuất hiện ở clipboard bàn phím, thiếu hộp xác nhận hoặc chọn sai fixture. Một lượt đi sang package khác đã bị dừng và runner không giám sát bị khóa. Phiên khám phá16,04phút/5kiểm tra ghi riêng, không cộng thành lượt ARTEMIS. Tham chiếu: TEST_RESULTS.md, ARTEMIS_RESULTS.md, EXPLORATORY_SESSION.md. GitHub Actions43476254884 trên commitd35f44d đạt cả hai job.

## 15. AI Code Review và kết luận

Báo cáo: Trang12.

Vòng review PR1 tại commit749183d dùng Claude Code, công cụ tương đương theo guidep24. Hồ sơ có10findings thuộc6nhóm, ghi quyết định chấp nhận, điều chỉnh hoặc bác bỏ và lý do. Sáu commit sửa gốc được truy vết trong docs/code-review.md; bảng trên slide chọn các ví dụ tiêu biểu.
CR01/05 được điều chỉnh tại service để lỗi Analytics không biến thao tác lưu thành thất bại. CR03 xóa Crashlytics UID khi logout; CR04 ghi lỗi initialMessage là non-fatal. CR07/08 sửa kiểm tra JWT; CR10 dùng chung logic tìm nội dung. CR09 bị bác bỏ vì vẫn cần phản ánh quyền thay đổi trong Settings. Queue CR02 lịch sử được xử lý tiếp ở9215cf9, không phải giới hạn chưa sửa của bản hiện tại.
Kết luận: ba flow chạy trên Android thật; Worker kiểm tra owner; đồng bộ local-first có retry/revision và bằng chứng vận hành. Hồ sơ nộp gồm GitHub, báo cáo12trang, slide15trang và video5–10phút do nhóm tự quay. Các ảnh Console còn thiếu được ghi riêng ở ASSIGNMENT_ACCEPTANCE.md; không suy ra toàn bộ rubric đã đủ. Nguồn: https://github.com/Dangchaubaominh/longevity-plate-lab3/pull/1
