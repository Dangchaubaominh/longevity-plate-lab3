# Longevity Plate

App Flutter cho Lab 3: ghi nhận bữa ăn, lên kế hoạch tuần và đọc kiến thức ăn uống, xây dựng từ thiết kế Lab 2 và kết hợp 6 dịch vụ Firebase.

Nội dung trong app là minh họa, không phải tư vấn y tế.

## Chạy nhanh

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
- Xuất báo cáo PDF 7 ngày và tải lên Cloud Storage, có tiến độ
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
| [firebase/storage.rules](firebase/storage.rules) | Quy tắc bảo mật Cloud Storage |
