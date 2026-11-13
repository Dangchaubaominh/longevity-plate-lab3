# Kế hoạch kiểm thử và bằng chứng

## Mục tiêu

100% các ranh giới bắt buộc trong Backendtast.docx có ca kiểm thử hoặc checklist thật; mục tiêu bao phủ dòng Flutter ≥60% cho bộ test hiện tại, báo cáo số đo thực, không sửa assertion để đạt số. Backend/Admin báo số case và phạm vi; chưa dùng phần trăm dòng khi không có collector phù hợp Workers. Automated local PASS và VERIFIED_REAL là hai trạng thái khác nhau.

## Local tự động

| Lớp | Lệnh | Phạm vi |
|---|---|---|
| Backend legacy | npm run test:legacy | 10 case PDF signing/owner/JWT compatibility |
| Workers + D1 | npm test (server) | JWT RSA thật với test key; real D1 migrations/constraints/CRUD/cursor/transaction; provider HTTP fixtures |
| Security | npm run security; npm audit --audit-level=high | Pattern credentials và dependency advisories; không thay pentest |
| Flutter | flutter analyze; flutter test --coverage | Unit/widget/navigation/layout/PDF/photo/repository/SQLite/VM/sync/owner/timeout |
| Admin components | npm run lint; npm run typecheck; npm test; npm run build | RTL/Vitest: auth role, loading/error/empty/users/form/confirm/crash/logout |
| Browser | npm run test:e2e (admin) | Playwright Chromium, desktop/mobile, real browser với HTTP/auth fixtures; không phải live-backend E2E |
| Bundles | npm run build (server); flutter build apk --debug | Worker dry-run gồm Admin assets, Android compile |

Không cần production secrets cho CI; test JWT/provider fixtures chỉ được inject bằng createApp test factory. Không có production env bỏ qua auth. CI tạo artifacts Playwright và Flutter coverage, không continue-on-error.

## Real acceptance cần cấu hình

1. Auth: login Google, cancel, offline login, logout, route guard, users Console; đúng SHA/project.
2. A/B: A tạo meal/PDF, B đọc/sửa/confirm/link bằng ID của A phải thất bại; thường user gọi Admin 403.
3. Meal/photo: chụp camera Android, chọn gallery, hủy picker, lost-result nếu OS kill; lưu offline, mở lại app, bật mạng, đúng một record/attachment; cloud authenticated và PDF download thật.
4. Hai máy: cùng UID tải meal/plan; sửa cùng revision → conflict; chọn local/server; xóa offline rồi sync; attachment đổi/không tự hồi sinh file đã xóa.
5. FCM: foreground/background/terminated, deny permission, token refresh/logout/account switch; kết quả accepted và opened phân biệt.
6. Crash: một lỗi đã xử lý và một crash có xác nhận; mở lại SDK upload; Firebase + Admin issue/event thật, timestamps/keys/version.
7. Analytics: DebugView ít nhất 7 event đúng analytics-plan.md, không PII. Evidence cũ được giữ riêng, không thay bằng logs test giả.
8. Remote Config: hai tham số, trước/sau và offline defaults, không build lại.
9. ARTEMIS: 10 case docs/test-cases.md, mỗi case 3 lần, Android native interaction và nhánh lỗi; exploratory 15–30 phút, xác minh UI/giá trị quan sát được.

Mỗi evidence ghi time, commit/build, device/Android, UID đã che, API request ID, expectation/observed result, command/exit status. Không đưa private key, JWT, FCM token vào Git. Không tuyên bố giao nhận thật từ mock HTTP. Khi chưa đủ device/credential: BLOCKED_REAL_VERIFICATION và tiếp tục các phần local.
