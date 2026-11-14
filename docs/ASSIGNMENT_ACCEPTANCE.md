# Lab3 - đối chiếu cuối ngày 14/11/2026

Nguồn: guide PRM393 v5,25 trang; Cloudinary thay Storage theo giảng viên; chấm trên CPH2637 thật; Admin dùng web. Video5–10phút do người dùng tự quay.

| Guide | Kết quả hiện tại | Bằng chứng |
|---|---|---|
| p1–4 | Ba flow, MVVM/Provider, loading/data/empty/error | architecture.md, design-traceability.md;169 automated cases; device/ARTEMIS |
| p5–7 Auth | Google login/logout/guard thực trên phone; cancel/error unit tests | AR01×3; auth_and_guard_test.dart; Firebase tokens thật. Ảnh Users Console thuộc phần cần chụp thêm bên dưới |
| p8–10 Storage | Cloudinary authenticated JPEG/PDF, ownerA/B, signed URL/progress/error | Provider15/15; staging40/40; gallery thật; native PDF14925bytes200; firebase/storage.rules trong repo |
| p11–13 FCM | Android permission; foreground/background/terminated; history/deep link | DEVICE_ACCEPTANCE.md; openedAt thực và screenshots/logs |
| p14–16 Analytics |17 events có plan, không PII;8 ảnh DebugView có sẵn | analytics-plan.md; evidence/analysis; ảnh còn thiếu được liệt kê riêng |
| p17–19 Crash | Native crash và non-fatal thật; UID/route custom keys trong service; Web đọc issue/event | Event15:11:28Z trên CPH2637; Admin API HTTP200;5groups; ảnh Console cần bổ sung |
| p20–22 RC |2keys, defaults/cache, realtime đổi hành vi và khôi phục không rebuild | Library còn1bài và planner ẩn/hiện gợi ý thật; v4→v5; EXPLORATORY_SESSION.md |
| p23 ARTEMIS |10case×3lượt;36attempts;16/30PASS,14FAIL theo quan sát | ARTEMIS_CASES.md; ARTEMIS_RESULTS.md; session IDs/image hashes; raw log/DB/images private |
| p23 Explore | Phiên giám sát16.04phút,5kiểm tra, không video | EXPLORATORY_SESSION.md; exploratory-summary.json |
| p24 AI review |10findings/6nhóm; accept/adjust/reject;6commit sửa truy vết | code-review.md; PR1 và commit anchors |
| p25 Nộp | Báo cáo12trang;slide15trang;nhánh GitHub riêng | output/pdf/*Final_20261114.pdf; video người dùng tự quay |

## Phần còn thiếu theo đúng rubric, ngoài video

Chức năng và API đã có, nhưng chưa đủ ảnh Console cho toàn bộ checklist. Không ghi các mục dưới đây là hoàn tất bằng ảnh API thay thế:

1. Authentication → Users và ảnh trước/sau đăng nhập theo project hiện tại.
2. Analytics DebugView: đã có8ảnh `login`, `meal_add_start`, `meal_save_failed`, `meal_saved`, `plan_from_article`, `plan_slot_saved`, `recipe_view`, `select_content`. Cần ảnh cho9event còn lại trong analytics-plan: logout, tutorial_begin, tutorial_complete, meal_draft_discarded, article_search, plan_save_failed, report_exported, report_export_failed, notification_opened.
3. Crashlytics Console: fatal/non-fatal, UserID và custom key route; Web Admin ảnh dashboard/crash detail. Crash thật đã xác minh qua REST, ảnh Console là yêu cầu bằng chứng riêng.
4. Remote Config Console:2tham số/publish; app trước/sau đã có ảnh thật. Thử offline defaults ở test fixtures; không gọi đó là ngắt mạng điện thoại thực.
5. Cloudinary Media Library: asset JPEG/PDF authenticated và đường dẫn reports/UID (không chụp secret). Upload/download/owner thật đã đạt.

Computer Use đã dừng do không xác định được URL trình duyệt đủ chắc để kiểm tra chính sách. Không tiếp tục input trình duyệt trong lượt này. Giữ checklist để người vận hành bổ sung ảnh Console bằng phiên đã đăng nhập, không tạo ảnh giả.

Không cần nâng cấp package hoặc đổi Expo. APK staging hiện tại phù hợp các kiểm tra; code app không thay đổi sau bản APK đã nghiệm thu. Backend dùng Workers/HonoTS+D1; Cloudinary chỉ giữ media; Firebase phục vụ Auth/FCM/Analytics/Crashlytics/RC.

<!-- ARTEMIS_REMEDIATION_START -->
## Remediation thực tế 06:59:29 14/11/26

Baseline giữ **16/30 PASS, 14 FAIL**. Campaign `remediation_20261114` chạy lại riêng 14 lượt FAIL: **12/14 PASS đã xác minh**, 26 attempts được giữ. Tổng hợp kế thừa 16 PASS baseline: **28/30 (93.33%)**, còn 2 lượt chưa đạt xác nhận. Đây không phải 30 lượt chạy mới.

Chi tiết và giới hạn: [ARTEMIS_REMEDIATION_STATUS.md](ARTEMIS_REMEDIATION_STATUS.md). Ba lượt AR13 đều có người dùng tự chọn ảnh fixture. Tác nhân báo PASS cả ba; R3 có ảnh popup, R1/R2 còn thiếu ảnh popup trong trace và giữ PENDING_REVIEW. Người dùng yêu cầu dừng đối chiếu, không chạy thêm. Kết quả báo về tổng hợp 30/30; bằng chứng đầy đủ xác nhận 28/30. Model, sessions và bằng chứng có trong hồ sơ.
<!-- ARTEMIS_REMEDIATION_END -->
