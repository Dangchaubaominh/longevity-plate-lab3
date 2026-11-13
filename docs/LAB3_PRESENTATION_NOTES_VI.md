# Thuyết minh 15 slide Lab3

## 1. Longevity Plate PRM393 · Lab 3

Giới thiệu ứng dụng nhật ký và kế hoạch bữa ăn. Báo cáo tập trung cách hoạt động và vị trí code của Google Auth, Cloudinary, FCM, Analytics, Crashlytics và Remote Config. Ứng dụng Flutter chạy trên CPH2637 Android16; Admin dùng web riêng. Cloudinary thay Firebase Storage theo hướng dẫn của giảng viên.

## 2. Ba flow xuyên suốt ứng dụng

F01: đăng nhập Google, chọn mục tiêu, vào Home; có hủy, logout và guard. F02: chọn loại bữa, chụp/chọn ảnh, nhập món, lưu vào SQLite trước rồi đồng bộ. F03: đọc kiến thức, mở công thức, chọn ngày/bữa, thêm vào kế hoạch; thay món có xác nhận. ViewModel quản lý loading/data/empty/error, View không tự gọi API.

## 3. Kiến trúc hiện tại

Flutter giữ Provider/MVVM và GoRouter. SQLite là nguồn dữ liệu cục bộ có transaction và outbox. Worker xác minh Firebase ID token, lấy UID từ claims, gọi D1 và provider. Cloudinary giữ JPEG/PDF; D1 giữ dữ liệu nghiệp vụ và metadata. Admin React đăng nhập Firebase nhưng quyền được quyết định ở server. Analytics, Crashlytics và Remote Config dùng SDK Firebase trực tiếp trên app.

## 4. Google login và Firebase ID token

Google OAuth xác nhận tài khoản. Firebase Auth phát hành ID token có chữ ký, app xin token từ SDK trước khi gọi API. Worker kiểm tra RS256, kid, issuer, audience, expiry và subject; không tin UID do client tự gửi. Nếu HTTP401, client thử refresh token đúng một lần. Token đăng nhập và token FCM có mục đích khác nhau. Nguồn: https://firebase.google.com/docs/auth/admin/verify-id-tokens

## 5. Ảnh bữa ăn và PDF trên Cloudinary

Camera/gallery tạo ảnh local, chuẩn hóa JPEG. Sau khi meal đã có revision server, client xin ticket có mealId, mealVersion và SHA256. Secret ký chỉ ở Worker. Client upload trực tiếp Cloudinary rồi xác nhận receipt; Worker kiểm tra metadata provider và owner trước khi gắn ảnh vào bữa. PDF dùng cùng cơ chế asset và authenticated download. Signed download trong dự án có hạn15phút. Nguồn: https://cloudinary.com/documentation/upload_images và https://cloudinary.com/documentation/upload_parameters

## 6. Lưu trước trên SQLite, đồng bộ sau

Một transaction ghi bản ghi và outbox, tránh trường hợp UI báo đã lưu nhưng mất yêu cầu đồng bộ. Operation có opId ổn định và baseVersion. Server lưu kết quả idempotency; retry cùng operation không tạo thêm record. Cursor lấy các thay đổi, tombstone truyền trạng thái xóa. Hai phía sửa cùng revision tạo conflict để người dùng chọn giữ local hoặc server. Test offline kiểm tra lỗi HTTP có kiểm soát, không cần ngắt ADB Wi-Fi.

## 7. FCM token là địa chỉ của app instance

Firebase Messaging SDK lấy registration token từ FCM cho một app instance trong project. Token có thể đổi khi cài lại, khôi phục hoặc SDK refresh. SDK quản lý token trên thiết bị; app lấy token để đăng ký với backend, lắng nghe tokenRefresh và gắn lại theo UID hiện tại. Installation proof/generation ngăn registration đến trễ gán lại cho tài khoản cũ. Token FCM không phải Firebase ID token, không dùng làm quyền truy cập API. Nguồn: https://firebase.google.com/docs/cloud-messaging/flutter/get-started

## 8. Admin gửi push; app nhận và mở đúng màn

Admin gửi yêu cầu có targetUid/title/body/route và requestKey sau preview/confirm. Worker lấy token của UID đích, dùng OAuth service account gọi FCM HTTPv1. Accepted nghĩa là FCM nhận yêu cầu, không chứng minh máy đã hiển thị. App foreground dùng onMessage và SnackBar; background dùng onMessageOpenedApp; terminated dùng getInitialMessage rồi route sau restore. openedAt được ghi khi người dùng mở. CPH2637 đã kiểm tra cả ba trạng thái. Nguồn: https://firebase.google.com/docs/cloud-messaging/send/v1-api

## 9. Analytics đo hành vi, tách khỏi kết quả lưu

Mỗi sự kiện có điểm phát và tham số nghiệp vụ, ví dụ meal_saved chỉ phát sau khi lưu thành công. Không đưa email, tên món tự nhập hoặc token vào event parameters. ResilientAnalyticsService chặn lỗi telemetry làm hỏng luồng chính. Khi không có mạng, SDK có thể hoãn gửi; cần quan sát DebugView khi có mạng trở lại. Evidence Analytics trước backend được giữ theo ngày, không gán cho build mới. Nguồn: https://firebase.google.com/docs/analytics/debugview

## 10. Crash thật từ app; Admin xem trên web

Nút Gây crash thử nghiệm hiện hộp xác nhận, sau đó SDK crash native. Android ghi FirebaseCrashlyticsTestCrash lúc22:11:28 ngày13/11. Mở lại app để SDK gửi. Worker dùng service account có Crashlytics Viewer, gọi REST v1alpha reports/issues/events, lưu snapshot có source/fetchedAt. Admin xem dữ liệu này trên web; Dev có thể dùng Firebase Console. Event mới khớp CPH2637/Android16/app1.0.0. Nguồn: https://firebase.google.com/docs/reference/crashlytics/rest

## 11. Remote Config thay hành vi không cần build lại

Ứng dụng đặt defaults trước, fetchAndActivate để lấy cấu hình, và nghe onConfigUpdated để activate cập nhật realtime. max_knowledge_results giới hạn số bài; suggested_recipes_enabled hiện/ẩn khu vực món gợi ý. Mất mạng thì giữ cache hoặc defaults. Remote Config là cấu hình phía client, không phải nơi giữ secret hay thay kiểm tra quyền server. Nguồn: https://firebase.google.com/docs/remote-config/flutter/get-started

## 12. Web chỉ phục vụ Admin

React/TypeScript/Vite sử dụng Firebase Auth cho Google login. API kiểm tra Admin allowlist ở server ở mọi route admin, không dựa vào việc ẩn nút trên web. Các màn gồm overview, users, devices, push/history, PDF metadata, audit và Crashlytics. Lỗi auth/internal-error ban đầu do CSP chặn Google loader đã được sửa với allowlist domain cụ thể và regression browser test. Người dùng đã đăng nhập dashboard thật.

## 13. Bằng chứng kiểm thử theo từng lớp

169 ca automated gồm102Flutter,55backend,8Admin component và4browser; không coi fixtures là cloud thật. Smoke provider Cloudinary15/15 và staging API40/40 dùng dịch vụ thật. Integration chạy trên CPH2637; FCM ba trạng thái và crash mới được đối chiếu trên thiết bị/API. GitHub Actions43465913095 đạt hai job. ARTEMIS có30lượt/36attempts,16PASS và14FAIL theo ảnh/UI/cloud, không theo SUCCESS. Sự cố AR13 mở sai package đã được dừng; chạy không giám sát bị khóa. Phiên khám phá thủ công ghi riêng, không tính thành lượt ARTEMIS.

## 14. AI review: kiểm chứng rồi quyết định

Review gốc của PR#1 ghi10 findings thuộc6nhóm, có chấp nhận/điều chỉnh/bác bỏ. Các ví dụ: telemetry gây báo sai kết quả lưu được sửa ở service; UserID Crashlytics được xóa khi logout; initialMessage lỗi là non-fatal; JSON token null và thiếuiat bị401. Có6commit sửa trong vòngreviewgốc; backendmới tiếp tục sửa queue notification theo UID/event và thêmregression. Số dòngtham chiếu theo commitreview749183d, khôngphảiheadmới.

## 15. Kịch bản trình diễn và giải thích

Video do nhóm tự quay5–10phút. Trình diễn trên máy thật: Googlelogin, ghi bữa cóảnh, kiến thức→kế hoạch; Adminsendpush→tapđúngmàn; crashbutton→mởlại→Adminrefresh. Giải thích token nào dùng ởđâu, serverkiểmtraownerthếnào, vìsaoretrykhôngtạotrùng, môhìnhMVC/MVVMphânlớpthếnào. NộpGitHub,báocáoPDF8–12trang,slidePDF12–15trangvàvideo.
