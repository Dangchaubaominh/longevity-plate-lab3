# Kết quả kiểm thử triển khai backend

Ngày 13/11/2026, Windows, Flutter 3.47.2/Dart 3.13.2, Node 22.22.3. Source phát triển từ 56bce85. Unit/CI tests không cần secret; các live smoke tests riêng đọc secret local để gọi dịch vụ thật, chỉ tạo fixture có UUID và cleanup.

| Kiểm tra | Kết quả | Bằng chứng |
|---|---|---|
| Fresh npm ci server/Admin | PASS; cả hai npm audit 0 vulnerabilities | Đã chạy từ lockfile; không npm audit fix --force |
| Backend lint/typecheck | PASS, strict + noUnused | npm run lint/typecheck |
| Node PDF compatibility | 10/10 PASS | artifacts/backend-implementation/backend-tests.txt |
| Workers/D1 | 45/45 PASS | Cùng log; DB local thật, Firebase RSA test key và HTTP provider fixtures |
| Migrations D1 local | PASS: 0001–0003, lần cuối no pending | npm run db:migrate |
| OpenAPI | PASS: 34 paths, 41 operations, 15 schemas; refs/security/params | npm run openapi; structural checker, không thay runtime test |
| Secret pattern scan | PASS | npm run security; .dev.vars/backup bị Git bỏ qua |
| Admin lint/typecheck/build | PASS | Vite build tạo dist, không chứa test harness |
| Admin RTL/Vitest | 8/8 PASS | artifacts/backend-implementation/admin-tests.txt |
| Playwright Chromium | 4/4 PASS, gồm CSP regression | Real browser; component API/auth fixtures và policy enforcement |
| Flutter full regression | 102/102 PASS | artifacts/backend-implementation/flutter-tests.txt |
| Flutter analyzer | No issues found | artifacts/backend-implementation/flutter-analyze.txt |
| Flutter line coverage | 3246/3994 = 81.27% | coverage/lcov.info; coverage-summary.json |
| Worker bundle/deploy | PASS dry-run và staging deploy thật | ASSETS + remote D1; latest CSP fix deployed |
| Android staging APK | PASS, ARM64 debug với API_BASE_URL thật | android-staging-build.txt; longevity-plate-staging-arm64.apk + SHA256 |
| Cloudinary thật | 15/15 PASS: upload/receipt/metadata/private download/unsigned denial/cleanup | artifacts/backend-implementation/cloudinary-live.json |
| Firebase apps config | VERIFIED_REAL metadata read bằng CLI | Android/Web app đã có cùng project; public config điền local |
| Staging remote E2E | 40/40 PASS với Firebase ID token thật, D1, JPEG/PDF và owner isolation | artifacts/backend-implementation/staging-api-smoke.json |
| Web Google loader/CSP | PASS HTTP200 script, accounts.google.com popup, zero Google CSP blocks | staging-google-loader.json; người dùng xác nhận dashboard |
| FCM provider | PASS validate_only HTTP200, không gửi tới thiết bị | Staging real-provider report; không coi là delivered |
| Crashlytics live | PASS, 4 nhóm sự cố thật và actual issue/events | Staging report; runtime Reader role đã được user phê duyệt |
| Device staging integration | PASS 1/1 trên CPH2637 Android16 | device-integration.txt; Firebase/D1/Cloudinary/private image/tombstone thật |
| Device durable offline/retry/conflict | PASS 1/1 trên CPH2637 | device-offline-integration.txt; HTTP failure có kiểm soát, SQLite close/open, cloud retry idempotent và second-client revision conflict |
| Native gallery photo | PASS | Người dùng chọn trong photo picker; D1version2/asset; private JPEG228597bytes HTTP200 |
| Device FCM | PASS foreground/background/terminated | SnackBar/history, Android notification và openedAt; xem DEVICE_ACCEPTANCE.md |
| Device crash/non-fatal → Admin | PASS | Nhóm fatal mới/eventTime15:11:28Z khớp CPH2637/Android16; non-fatal event tăng |
| GitHub Actions | PASS backend-admin + flutter | Run43465913095, commitfb1afbd, hai job success |
| ARTEMIS |30runs,36attempts;16PASS/14FAIL theo quan sát | ARTEMIS_RESULTS.md; không lấy agent SUCCESS làm PASS |
| Supervised exploratory |16.04min;5kiểm tra | EXPLORATORY_SESSION.md; native PDF200/14925bytes; RC đổi hành vi; camera cancel; replacement cancel |

Các lỗi tìm thấy và đã sửa: fetch bị mất browser context; timeout chưa bao trọn send; queue sync tự kích hoạt lại thừa; ảnh bị thay/xóa từ thiết bị khác; thiếu revision cho ảnh chưa upload; queue notification lẫn owner; mất deep link trong restore/onboarding; token registration/logout đến server sai thứ tự. Tests regression bao phủ các trường hợp này.

Ví dụ cấu hình public có giá trị giống credential đã được chuyển sang bản backup private bị Git bỏ qua, example nộp chỉ còn biến rỗng. Không có credential được in vào kết quả. GitHub CI đã chạy trên nhánh riêng và hai job đều success; không merge main.

Lịch sử lỗi: Cloudinary 401 được giải quyết khi chuyển sang đúng backup; Web SDK key/JSON quoting đã sửa; bật Crashlytics API và thêm Reader sau phê duyệt để xử lý403; một lượt staging bị lỗi network giữa flow và đã cleanup, lượt ổn định cuối đạt40/40. CSP lỗi thật trên Google popup đã được user báo, sửa, thêm regression test và xác minh trên host. Không cộng mocked/local tests thành evidence giao nhận FCM hoặc đa thiết bị thật.
