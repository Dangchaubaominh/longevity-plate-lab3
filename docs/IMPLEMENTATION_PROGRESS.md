# Implementation progress

Theo Backendtast.docx. Trạng thái: NOT_STARTED, IN_PROGRESS, CODE_COMPLETE, TEST_PASSED, VERIFIED_REAL, BLOCKED, DONE. BLOCKED_REAL_VERIFICATION là nhãn chi tiết của BLOCKED, không phải PASS.

| Phase | Scope | Status | Evidence/blocker |
|---|---|---|---|
| Audit | Baseline source/config/tests | DONE | IMPLEMENTATION_AUDIT.md |
| P0 | Real provider configuration | VERIFIED_REAL | Staging deployed; Firebase/Cloudinary secrets configured; IAM Viewer added only after explicit approval |
| P1 | Hono API, D1, auth, CRUD, sync | VERIFIED_REAL | 55 automated backend cases; real staging Firebase JWT/CRUD/ownership/cursor/tombstone checks |
| P2 | Authenticated photo/PDF assets | VERIFIED_REAL | 15 provider checks + real Worker upload/confirm/private download/A-B isolation; fixtures cleaned |
| P3 | Device registration, FCM, history | VERIFIED_REAL | CPH2637 foreground/background/terminated received; tapped notification opens log and records openedAt |
| P4 | Admin web and Crashlytics adapter | VERIFIED_REAL | User confirmed Google dashboard login; CSP regression fixed; real Crashlytics returns 4 groups and issue/events |
| P5 | Flutter API, durable offline sync | VERIFIED_REAL | 102 Flutter tests; analyzer clean; real CPH2637 staging integration1/1 passed, including JPEG upload/private download/tombstone |
| P6 | Tests, CI, documentation, acceptance | IN_PROGRESS | 169 local automated cases, 40/40 real staging checks; finishing report/GitHub CI; ARTEMIS needs device/model access |

Production/cloud/device execution must not be marked DONE based only on mock tests. Progress and commands are updated after each phase.

## Kết quả hiện tại - 13/11/2026

- Admin/API: https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev . Staging D1 riêng, migrations 0001–0003 đã áp dụng, không deploy đè production.
- Real staging: 40/40 checks trong artifacts/backend-implementation/staging-api-smoke.json, gồm Firebase-issued ID tokens của hai test users, owner isolation, revision/idempotency, ảnh/PDF, sync và Crashlytics issue/event thật. Test users/assets đã cleanup. FCM chỉ validate_only, không ghi nhận là delivered.
- Flutter: 102/102, line coverage 3246/3994 = 81.27%, flutter analyze No issues. Backend 10 Node +45 Workers/D1; Admin 8 RTL; browser 4 Playwright.
- Google login production: lỗi CSP script-src self đã sửa bằng allowlist apis.google.com/www.gstatic.com, không dùng unsafe-eval. Test browser thực tải Google script HTTP200, mở popup accounts.google.com, 0 CSP Google blocks; người dùng xác nhận vào dashboard.
- Cloudinary: cấu hình .dev.vars ban đầu 401; dùng đúng private-backup theo yêu cầu người dùng đã đạt upload/private delivery JPEG/PDF thật. Public example được làm sạch, secret/backup không vào Git.
- Web SDK key trong backup khác SDK config Firebase hiện hành: đã dùng lại cấu hình chính thức đúng Web app. JSON dotenv được chuẩn hóa, Worker được reload.
- Crashlytics: đã bật REST API; sau khi người dùng đồng ý mới cấp roles/firebasecrashlytics.viewer cho runtime service account. Đã đọc 4 nhóm sự cố và actual issue/events từ staging.
- APK: artifacts/backend-implementation/longevity-plate-staging-arm64.apk, nối staging thật. Không coi compile thành công là đã nghiệm thu trên điện thoại.

Điện thoại đã kết nối, integration_test1/1, FCM ba trạng thái và crash button→Firebase/Admin đã đạt. GitHub Actions43449611839 hai job success trên commit9215cf9. Phần tiếp tục: camera/gallery; ARTEMIS10 case ×3 và exploratory.
