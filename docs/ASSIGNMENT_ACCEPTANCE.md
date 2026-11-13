# Đối chiếu Lab3 và yêu cầu backend

Nguồn: PRM393_Lab3_Preparation_Guide_v5_ToiUu.pdf, 25 trang; bổ sung của giảng viên trong hội thoại: Cloudinary/S3 thay Storage được phép, chấm trên điện thoại thật, Admin dùng web riêng để xem crash, người dùng tự quay video. Yêu cầu triển khai backend theo Backendtast.docx.

| Guide | Tiêu chí | Code/tài liệu/bằng chứng local | Nghiệm thu thật còn cần |
|---|---|---|---|
| p1–4 | 3 flow Lab2, MVVM, loading/data/empty/error | Provider VM, repositories, architecture.md/design-traceability.md, test/flows_test.dart | Điện thoại và ảnh màn các flow |
| p5–7 | Google login/cancel/logout/guard/Users Console | FirebaseAuthService, Session VM, router, auth_and_guard_test.dart | Auth Console và sign-in/cancel/offline thật |
| p8–10 | Tạo PDF, progress, reports/UID, quyền owner, lỗi mạng | ReportBuilder, media API và compatibility PDF, storage.rules có sẵn, Workers/Flutter tests | Cloudinary authenticated PDF delivery và thử A/B thật |
| p11–13 | FCM Android13+, 3 trạng thái, lịch sử/deep link/deny | MessagingService, owner queue, devices/notifications API, Admin confirm, FCM_SETUP.md | Foreground/background/terminated và Console send trên device |
| p14–16 | ≥7 event, plan, DebugView, không PII | analytics-plan.md, service events và tests, evidence/analysis được giữ | Đối chiếu event DebugView của build cuối và từng flow |
| p17–19 | handled error + crash, UID/custom key | FirebaseCrashService, demo confirm, route key; actual REST adapter Admin | SDK issue/event Firebase và web Admin sau crash thật |
| p20–22 | ≥2 Remote Config, defaults/cache, before/after | max_knowledge_results, suggested_recipes_enabled; widget tests | Console publish và UI trước/sau không rebuild |
| p23 | ≥10 ARTEMIS case ×3, native Android/error, exploratory15–30m | docs/test-cases.md, scripts/artemis-lab3.ps1, công cụ official đã chuẩn bị | Chưa chạy ARTEMIS với model key + device; cần logs/success quan sát được |
| p24 | AI PR review ≥5 findings/≥2 nhóm/≥3 fixes có trace | docs/code-review.md và hồ sơ review trước đây | Đối chiếu PR/commit thực tế khi chốt nộp |
| p25 | GitHub, report8–12p, slides12–15p, video5–10m | Repo và PDF/slide đã tồn tại ở output/pdf trước backend | Cập nhật tài liệu theo nghiệm thu cuối; người dùng tự quay video |

## Backendtast.docx

| Phase | Đã triển khai | Ranh giới kiểm chứng |
|---|---|---|
| P0 | Audit, config, safe checks, staging deploy, secrets, domain, Admin allowlist | Cloud cấu hình xong; device/model ARTEMIS vẫn cần người dùng |
| P1 | Hono TS, D1, Firebase JWT, Admin allowlist, profile/goals/meals/plans CRUD, pagination/errors/OpenAPI | D1 local + real Firebase JWT/remote D1 CRUD/owner checks đã pass |
| P2 | Signed photo/PDF, complete/reconcile, metadata/owner, revision/unique attachment, cleanup | Cloudinary provider15/15 và remote Worker upload/download/A-B pass |
| P3 | Registration proof/generation, token refresh/logout, FCM HTTP v1, campaigns/history/retry | Tests pass, real FCM validate_only pass; phone delivery cần thật |
| P4 | React Admin, role guard, responsive, users/devices/push/history/PDF/audit/Crashlytics | User xác nhận Google dashboard; CSP regression4/4; actual Crashlytics4 nhóm + issue/events pass |
| P5 | SQLite migration, transactional outbox, durable retry, cursor/tombstones/conflicts, photo cache, MVVM | Flutter102/102, analyze sạch, APK nối staging; đa thiết bị/camera còn cần ADB |
| P6 | Automated tests, CI YAML, security scan, documentation, staging integration_test | Local169 cases; API E2E cloud40/40; CI remote sẽ xác nhận sau push |

Không đánh dấu toàn Assignment DONE chỉ từ local tests. Các điều kiện chưa có evidence phải giữ BLOCKED_REAL_VERIFICATION, đúng chỉ dẫn Backendtast.docx. Không đưa claim hoàn tất chưa kiểm chứng vào slide/PDF.
