# Giới hạn và blocker thực tế

Ngày 13/11/2026. Backend/Admin staging vượt40/40 kiểm tra cloud thật; Google Admin login được người dùng xác nhận. CPH2637 đã kết nối, integration native1/1 và FCM ba trạng thái đã đạt. Đang hoàn tất crash/camera và ARTEMIS; model mặc định có lỗi503 từ provider.

- Phân biệt evidence: unit/provider fixtures và Playwright component flow không chứng minh cloud; staging-api-smoke.json là API E2E dùng Firebase/Cloudinary/Crashlytics thật. staging-google-loader.json kiểm chứng CSP và real Google popup; người dùng xác nhận đăng nhập thật. API tests dùng controlled custom-token users, không thay Google OAuth UI.
- Integration_test đã chạy trên CPH2637. ARTEMIS có model key/device; đang chạy10 case ×3 và exploratory15–30 phút. Không thay nhật ký ARTEMIS bằng kết quả flutter test.
- APK ARM64 debug đã nhúng URL staging, build thành công. Chưa được coi là nghiệm thu hardware khi chưa cài/chạy trên điện thoại.
- Authenticated/private JPEG và PDF download đã kiểm tra account thật HTTP200; unsigned URL bị401. Quyền vẫn phải kiểm tra lại nếu đổi account hoặc delivery settings.
- Token logout khi offline chỉ là best effort tới server. Chặn xử lý targetUid sai ở app; OS notification tray vẫn cần policy và test. Push không chứa dữ liệu nhạy cảm.
- FCM accepted khác device delivered. Network timeout sau send được ghi unknown; không auto-resend vì không có exactly-once delivery guarantee của nhà cung cấp.
- Crashlytics API v1alpha có thể đổi. Quyền đọc đã được cấp sau phê duyệt và request thật đã trả issue/events; độ trễ của crash mới và quota project vẫn cần quan sát khi demo trên thiết bị. Web chỉ hiển thị trường nguồn cung cấp.
- SQLite/app sandbox tách UID, chưa encryption at rest. Legacy SharedPreferences được giữ dự phòng. File local của bản đã xóa có thể còn để bảo toàn dữ liệu; cần retention/GC có kiểm chứng trước production lớn.
- Change log/tombstone/idempotency cache server chưa compact để bảo đảm client offline lâu vẫn đồng bộ; cần chính sách retention và cursor reset nếu triển khai lâu dài.
- Lịch sử notification client tải tối đa 50 bản gần nhất trong một lần reload; server hỗ trợ pagination. Local history giới hạn 100, trạng thái mở chưa có outbox riêng khi offline.
- Profile đồng bộ tên/timezone ban đầu; giao diện hiện vẫn hiển thị Google profile, chưa có màn sửa hồ sơ riêng. API read/update đã có.
- PDF API legacy giữ tương thích, file legacy không tự có metadata trong Admin mới. Backfill phải có kế hoạch kiểm chứng ownership.
- CI đã viết và lệnh tương ứng chạy local; workflow trên GitHub chỉ được xác nhận sau push/run thực. Không tuyên bố CI remote xanh khi chưa chạy.
- PDF báo cáo/slide đã có trước lượt triển khai này có thể mô tả kiến trúc local cũ; cần cập nhật sau nghiệm thu và không sử dụng như bằng chứng runtime backend mới.

Checklist gỡ blocker có trong TEST_PLAN.md và DEPLOYMENT_GUIDE.md. Chỉ nâng trạng thái VERIFIED_REAL sau khi lưu bằng chứng theo build/commit/device/time và kết quả quan sát được.
