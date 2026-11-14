# Giới hạn và blocker thực tế

Ngày13/11/2026. Staging API40/40, Google Admin login user-confirmed, CPH2637 integration2/2, gallery→private JPEG thật, FCM ba trạng thái và crash mới→Admin đã đạt. ARTEMIS30lượt và phiên khám phá16.04phút đã lưu; RC đổi hành vi và khôi phục thực đã kiểm tra. Model mặc định ARTEMIS gặp503/quota; đã cấu hình model khả dụng riêng, không bật billing.

- Phân biệt evidence: unit/provider fixtures và Playwright component flow không chứng minh cloud; staging-api-smoke.json là API E2E dùng Firebase/Cloudinary/Crashlytics thật. staging-google-loader.json kiểm chứng CSP và real Google popup; người dùng xác nhận đăng nhập thật. API tests dùng controlled custom-token users, không thay Google OAuth UI.
- Integration_test đã chạy trên CPH2637. ARTEMIS có model key/device; đã chạy10 case ×3;16PASS/14FAIL theo quan sát và exploratory16.04phút. Không thay nhật ký ARTEMIS bằng kết quả flutter test.
- APK ARM64 debug nối staging đã cài/chạy trên CPH2637. Ca offline dùng HTTP failure có kiểm soát và SQLite close/open; không diễn giải thành kill tiến trình Android hoặc tắt Wi-Fi thật. Conflict kiểm tra hai client API, không gọi là hai điện thoại vật lý.
- Authenticated/private JPEG và PDF download đã kiểm tra account thật HTTP200; unsigned URL bị401. Quyền vẫn phải kiểm tra lại nếu đổi account hoặc delivery settings.
- Token logout khi offline chỉ là best effort tới server. Chặn xử lý targetUid sai ở app; OS notification tray vẫn cần policy và test. Push không chứa dữ liệu nhạy cảm.
- FCM accepted khác device delivered. Network timeout sau send được ghi unknown; không auto-resend vì không có exactly-once delivery guarantee của nhà cung cấp.
- Crashlytics API v1alpha có thể đổi. Crash mới từ CPH2637 đã khớp eventTime/device qua Admin; provider có độ trễ và quota riêng. Web chỉ hiển thị trường nguồn cung cấp.
- SQLite/app sandbox tách UID, chưa encryption at rest. Legacy SharedPreferences được giữ dự phòng. File local của bản đã xóa có thể còn để bảo toàn dữ liệu; cần retention/GC có kiểm chứng trước production lớn.
- Change log/tombstone/idempotency cache server chưa compact để bảo đảm client offline lâu vẫn đồng bộ; cần chính sách retention và cursor reset nếu triển khai lâu dài.
- Lịch sử notification client tải tối đa 50 bản gần nhất trong một lần reload; server hỗ trợ pagination. Local history giới hạn 100, trạng thái mở chưa có outbox riêng khi offline.
- Profile đồng bộ tên/timezone ban đầu; giao diện hiện vẫn hiển thị Google profile, chưa có màn sửa hồ sơ riêng. API read/update đã có.
- PDF API legacy giữ tương thích, file legacy không tự có metadata trong Admin mới. Backfill phải có kế hoạch kiểm chứng ownership.
- GitHub Actions43465913095 đã đạt cả backend-admin và flutter trên commitfb1afbd; các commit bổ sung tiếp tục được kiểm tra riêng.
- Báo cáo12trang và slide15trang mới ở output/pdf được cập nhật theo kiến trúc backend. File cũ ở thư mục parent là hồ sơ lịch sử.

Checklist gỡ blocker có trong TEST_PLAN.md và DEPLOYMENT_GUIDE.md. Chỉ nâng trạng thái VERIFIED_REAL sau khi lưu bằng chứng theo build/commit/device/time và kết quả quan sát được.

Ảnh Console còn thiếu theo rubric được liệt kê chính xác trong ASSIGNMENT_ACCEPTANCE.md. Không thay ảnh Console bằng API fixture hoặc ảnh dựng. Runner ARTEMIS khóa mặc định; --locked-app không phải sandbox và không dùng trên phone không giám sát.
