# Implementation audit

Ngày 13/11/2026. Source baseline `56bce85`, nhánh feature/meal-photo-local-cloudinary-plan. Yêu cầu triển khai từ Backendtast.docx; không thay đổi cấu hình Firebase riêng longevity-plate-beff9.

## Có thể tái sử dụng

- Flutter MVVM/Provider/GoRouter, 3 luồng Lab2, 12 màn, adapter Firebase và PDF.
- Worker JavaScript hiện có: xác minh JWT Google, signed upload PDF và private download, 10 test Node.
- Ảnh JPEG local theo UID, chụp/gallery/lost result, retry và idempotent meal ID.
- Test Flutter đạt 75/75 ở ba vòng trước triển khai; logs artifacts/lab3-final-verification. Các vòng này không kiểm chứng backend mới.
- Hồ sơ AI review PR1 và source/test cho Auth/FCM/RC/Analytics/Crashlytics.

## Khoảng trống

- Chưa có D1/schema/migration, CRUD cloud, sync cursor, outbox giao dịch, API admin hoặc web Admin.
- Worker mới có hai route PDF; chưa có authorization Admin, CORS/rate limit chung hoặc metadata asset.
- FCM chưa đăng ký token/rotation/logout với server; chưa có API gửi từ Admin.
- Crashlytics SDK có code; backend runtime đọc Firebase chưa có.
- SharedPreferences nghiệp vụ cần migration an toàn vào cache/outbox transaction khi bật API.
- Chưa có CI toàn hệ thống, Playwright, Workers/D1 integration test hoặc OpenAPI.

## P0 và ranh giới

ARTEMIS 1.0/Python3.12/scrcpy đã cài tại tools; doctor thiếu model key và điện thoại. Không có Worker URL, Cloudflare/D1 binding remote, Cloudinary secrets hay Google server credential trong cấu hình dự án hiện tại. Firebase CLI có quyền đọc project beff9, nhưng quyền CLI không tự trở thành credential hợp lệ cho production Worker. Không deploy production, bật billing, thay IAM hoặc gửi tin hàng loạt. Tiếp tục local implementation và test providers có dependency injection.

## Cách triển khai

Giữ hai route PDF cũ, bổ sung Hono/TypeScript và D1; SQL prepared statements, UID từ JWT đã xác minh, Admin allowlist server-side. Mọi live verification có bằng chứng riêng. Secrets nhập local hoặc Wrangler secrets, không qua chat/Git.
