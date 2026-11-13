# Báo cáo triển khai Longevity Plate backend và Admin

Ngày 13/11/2026. Triển khai theo Backendtast.docx và đối chiếu guide Lab3 25 trang. Firebase project giữ nguyên `longevity-plate-beff9`.

## Kết quả sử dụng được

- **Admin/API staging:** https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev . Google login đã được người dùng xác nhận; chỉ UID của tài khoản được chỉ định có quyền Admin.
- **APK:** artifacts/backend-implementation/longevity-plate-staging-arm64.apk, ARM64 debug, nối trực tiếp staging; SHA256 cùng thư mục. Không chứa Cloudinary secret hay service-account key.
- **API E2E thật:** 40/40 checks. Firebase-issued ID tokens, remote D1, profile/goals/meal/plan, owner isolation, idempotency/revision, cursor/tombstone, JPEG/PDF upload/confirm/private download, FCM validate_only và Crashlytics issue/events.
- **Automated local:** 102 Flutter +55 backend +8 Admin RTL +4 browser =169 cases đạt. Flutter analyze không có issue; line coverage81.27% (3246/3994).
- **Cloudinary:** 15/15 kiểm tra provider thật, bao gồm unsigned denial và cleanup. **Crashlytics:** đọc4 nhóm sự cố thật và actual issue/events từ Firebase; không chèn sample production.

## Những gì đã thay đổi

Worker JavaScript PDF cũ được giữ tương thích, bổ sung Hono/TypeScript, D1 migrations và API versioned. JWT xác minh chữ ký/claims/key rotation; owner từ token, Admin allowlist server-side, CORS chặt, rate limit, payload validation và errors có request ID. OpenAPI có34 paths/41 operations và kiểm tra cấu trúc.

Cloudinary dùng authenticated assets, signed ticket/receipt, provider metadata verification, owner/revision, một ready photo/bữa, reconcile khi mất response và cleanup trì hoãn. File và báo cáo cũ không bị tự xóa hoặc backfill không kiểm chứng.

Flutter giữ Provider/MVVM/GoRouter, thêm SQLite cache/outbox transaction, migration theo UID giữ SharedPreferences backup, stable IDs/frozen operations, retry/backoff, cursor, tombstone, conflict choice và photo base revision. Có màn trạng thái đồng bộ; camera/gallery/local cache tiếp tục hoạt động.

FCM có token registration proof/generation, tuần tự hóa refresh, logout tombstone chống registration đến trễ, campaigns/deliveries/idempotency/retry và opened status. Admin form có preview/confirm. Accepted và delivered được phân biệt.

Admin React/TS/Vite có dashboard, users/activity counts/search/pagination, devices, notifications/history, PDF metadata, audit và actual Crashlytics. Lỗi thực CSP chặn Google loader đã được sửa, có regression test và kiểm tra Google popup trên staging.

## Ma trận nghiệm thu

| Component | Code | Automated tests | Real verification | Status |
|---|---|---|---|---|
| Backend | Hono TS/module APIs |45 Workers/D1 +10 legacy | Staging E2E40/40 | VERIFIED_REAL |
| Database | D1 migrations0001–0003 | Constraints/transaction/CRUD | Remote staging CRUD/cursor/tombstone | VERIFIED_REAL |
| Authentication | Firebase JWT + Admin allowlist | Bad claims/signature/owner/role | Firebase tokens thật; Google Admin login user-confirmed | VERIFIED_REAL |
| Cloudinary/PDF | Signed/authenticated media | Signature/metadata/owner/retry | Provider15/15 + staging upload/download/A-B | VERIFIED_REAL |
| FCM | HTTPv1/token/jobs/history | Success/error/retry/generation | CPH2637 nhận foreground/background/terminated; openedAt và route đúng | VERIFIED_REAL |
| Crashlytics | Actual REST v1alpha adapter | Fixtures/errors/redaction | Nút crash CPH2637 → nhóm fatal mới/event đúng timestamp/device; tổng5 nhóm | VERIFIED_REAL |
| Flutter Sync | SQLite transactional outbox/MVVM |102 Flutter cases, analyze sạch | CPH2637 integration2/2: online media; controlled HTTP failure/native SQLite reopen/idempotent retry/real second-client conflict | VERIFIED_REAL trong phạm vi kiểm thử |
| Admin Web | React/TS/Vite |8 RTL +4 browser | Google login user-confirmed; real loader/CSP check | VERIFIED_REAL |
| CI | GitHub Actions, no prod secrets | backend-admin và flutter cùng đạt | [Run43449611839](https://github.com/Dangchaubaominh/longevity-plate-lab3/actions/runs/43449611839), commit9215cf9 | TEST_PASSED |
| ARTEMIS | Environment + plan/scripts | Doctor ready, thiết bị và model key có sẵn | Đang chạy; model mặc định gặp503, thử model khả dụng | IN_PROGRESS |

## Deploy và bảo vệ dữ liệu

Dùng Worker staging và database riêng, không deploy đè production hoặc nâng billing. Secrets đưa qua stdin của Wrangler. Runtime service account chỉ được bổ sung Crashlytics Viewer sau câu trả lời cho phép của người dùng; các IAM bindings khác được giữ. Domain staging được thêm vào Firebase authorized domains. Test accounts/assets có UUID riêng và đã cleanup.

Public example được làm sạch; `.dev.vars`, private-backup, logs/artifacts và APK không nằm trong commit source. Báo cáo bằng chứng tóm tắt nằm trong docs/build-evidence/backend-implementation-summary.json; raw logs ở artifacts/backend-implementation/.

## Điều kiện còn phụ thuộc người dùng

Điện thoại đã kết nối; APK, integration_test, FCM ba trạng thái và crash→Firebase/Admin đã đạt (DEVICE_ACCEPTANCE.md). Tiếp tục camera/gallery và ARTEMIS theo rubric. Đa thiết bị cần thiết bị thứ hai; tests A/B API đã kiểm tra owner isolation. Người dùng tự quay video theo phân công.

Hướng dẫn: DEPLOYMENT_GUIDE.md, TEST_PLAN.md, ADMIN_GUIDE.md, FCM_SETUP.md, CRASHLYTICS_INTEGRATION.md, ASSIGNMENT_ACCEPTANCE.md. Giới hạn sản phẩm còn lại và phạm vi evidence được ghi trong KNOWN_LIMITATIONS.md.
