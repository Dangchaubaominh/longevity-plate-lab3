# Longevity Plate

App Flutter cho Lab 3: ghi nhận bữa ăn, lên kế hoạch tuần và đọc kiến thức ăn uống, xây dựng từ thiết kế Lab 2. App dùng 5 dịch vụ Firebase, còn phần lưu tệp dùng Cloudinary thay cho Cloud Storage vì Cloud Storage cần gói Blaze. Giảng viên đã cho phép thay thế này.

Nội dung trong app là minh họa, không phải tư vấn y tế.

Backend/Admin và đồng bộ mới nằm ở nhánh `feature/backend-admin-offline-sync`. Bản Firebase trước khi thêm backend được lưu tại tag [`lab3-evidence`](https://github.com/Dangchaubaominh/longevity-plate-lab3/tree/lab3-evidence).

## Cài và dùng thử

Cần điện thoại Android có Google Play và một tài khoản Google.

1. Lấy tệp APK từ nhóm hoặc từ mục Releases của repo, nếu nhóm đã đăng.
2. Mở tệp trên điện thoại và cho phép cài từ nguồn này. Play Protect có thể cảnh báo vì app không đến từ Play Store.
3. Mở app, bấm **Bắt đầu**, chọn **Tiếp tục với Google**.
4. Chọn ít nhất một mục tiêu rồi bấm **Hoàn tất**.

| Tab hoặc màn | Việc làm được |
|---|---|
| Hôm nay | Xem tổng quan trong ngày, ghi nhanh bữa ăn |
| Nhật ký | Thêm bữa ăn, xem theo ngày, xuất báo cáo PDF 7 ngày gần nhất |
| Kế hoạch | Xếp món vào từng bữa trong tuần |
| Kiến thức | Tìm và đọc bài viết, lập kế hoạch từ bài đang đọc |
| Biểu tượng chuông | Xem lịch sử thông báo, bật quyền thông báo |
| Biểu tượng tài khoản | Đổi mục tiêu, đăng xuất, mở Khu vực trình diễn |

Lưu ý khi dùng:

- Khi build với `API_BASE_URL`, dữ liệu lưu SQLite trước rồi đồng bộ qua Worker/D1 và Cloudinary. Không có define này thì giữ chế độ local/PDF cũ. Backend mới cần nghiệm thu staging theo hướng dẫn bên dưới.
- Xuất báo cáo cần có mạng. Link tải báo cáo hết hạn sau 15 phút, sau đó phải xuất lại.
- Khu vực trình diễn chỉ để kiểm thử: các lỗi ở đó là giả lập, còn nút "Gây crash thử nghiệm" sẽ đóng app thật.

## Chia sẻ cho người khác

| Người nhận | Cần làm |
|---|---|
| Người dùng thử | Gửi tệp APK. Chỉ gửi trong nhóm và cho giảng viên, vì mọi lượt xuất báo cáo đều dùng hạn mức miễn phí của Cloudinary |
| Thành viên chạy mã nguồn | Clone nhánh `feature/lab3-firebase`, rồi thêm SHA của khóa debug trên máy mình vào Firebase theo [docs/SETUP-FIREBASE.md](docs/SETUP-FIREBASE.md). Thiếu SHA thì đăng nhập Google báo lỗi cấu hình |
| Giảng viên xem Firebase | Firebase Console, Project settings, Users and permissions, thêm email với quyền Viewer |

Không chia sẻ API Secret của Cloudinary, tài khoản Cloudflare hay mật khẩu tài khoản kiểm thử. Ảnh minh chứng phải che email, UID và FCM token.

## Chạy nhanh

**Cài lên điện thoại Android:** xem [docs/ANDROID-APK.md](docs/ANDROID-APK.md). Bản offline giữ phiên local, có đủ ba luồng và lưu PDF thật vào thư mục do người dùng chọn trên điện thoại. Firebase thật cần cấu hình riêng.

Xem giao diện với dịch vụ giả lập, không cần Firebase:

```bash
flutter pub get
```

```bash
flutter run -d chrome --dart-define=USE_FAKE_SERVICES=true
```

Chạy test:

```bash
flutter test
```

Chạy với Firebase thật trên Android: làm theo [docs/SETUP-FIREBASE.md](docs/SETUP-FIREBASE.md). Nếu chưa cấu hình, app hiện màn hướng dẫn thay vì crash.

## Tính năng

- 3 luồng của Lab 2 trên 9 màn, kèm trạng thái tải, rỗng và lỗi
- 3 màn thêm cho Lab 3: Đăng nhập, Tài khoản, Thông báo
- Đăng nhập Google, chặn truy cập, tách dữ liệu theo tài khoản
- Xuất báo cáo PDF 7 ngày và tải lên Cloudinary qua server báo cáo, có tiến độ
- Thông báo FCM ở 3 trạng thái app, có lịch sử trong app
- Analytics với 17 sự kiện, Crashlytics với lỗi non-fatal và custom key
- Remote Config điều khiển số bài ở thư viện và mục món gợi ý
- Khu vực trình diễn ở màn Tài khoản để giả lập lỗi và kiểm thử

## Tài liệu

| Tài liệu | Nội dung |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Kiến trúc MVVM, quyết định thiết kế, chu kỳ Remote Config |
| [docs/analytics-plan.md](docs/analytics-plan.md) | Danh sách sự kiện và câu hỏi sản phẩm |
| [docs/design-traceability.md](docs/design-traceability.md) | Đối chiếu màn hình và khác biệt so với Lab 2 |
| [docs/SETUP-FIREBASE.md](docs/SETUP-FIREBASE.md) | Cấu hình Firebase, cách kiểm tra từng dịch vụ |
| [docs/test-cases.md](docs/test-cases.md) | Test tự động, ca thủ công, ca ARTEMIS, danh sách bằng chứng |
| [docs/code-review.md](docs/code-review.md) | Kết quả AI Code Review, quyết định cho từng phát hiện và commit sửa |
| [server/README.md](server/README.md) | Server báo cáo trên Cloudflare Workers, giữ vai trò của storage.rules |

## Backend và Admin mới

Web Admin/API staging: [Mở Longevity Plate Admin](https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev). Google login được bảo vệ bằng allowlist server; thông tin triển khai và phạm vi nghiệm thu nằm trong [báo cáo triển khai](docs/FINAL_IMPLEMENTATION_REPORT.md).

Worker TypeScript/Hono, Cloudflare D1, Cloudinary authenticated ảnh/PDF, FCM HTTP v1, Web Admin React và adapter Crashlytics REST. Flutter giữ MVVM, thêm transactional outbox SQLite, retry/idempotency và xử lý xung đột.

- Bắt đầu: [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md).
- Kiến trúc/API: [SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md), [OpenAPI](docs/openapi.json).
- Nghiệm thu: [TEST_PLAN.md](docs/TEST_PLAN.md), [ASSIGNMENT_ACCEPTANCE.md](docs/ASSIGNMENT_ACCEPTANCE.md).
- Tiến độ và giới hạn thực: [IMPLEMENTATION_PROGRESS.md](docs/IMPLEMENTATION_PROGRESS.md), [KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md).

Local tests không thay thế nghiệm thu Google/Cloudinary/FCM/Crashlytics trên điện thoại thật. Không đưa secret vào Git hoặc chat.
