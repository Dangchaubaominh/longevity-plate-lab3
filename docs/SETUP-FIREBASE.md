# Cấu hình Firebase và chạy trên Android

Các bước này cần tài khoản Google của bạn nên phải tự thực hiện. Dùng tài khoản kiểm thử riêng, không dùng tài khoản cá nhân chính.

## 1. Cài công cụ

1. Android Studio, gồm Android SDK, Platform Tools và một emulator có Google Play. Google Sign-In và FCM cần Google Play Services.
2. JDK đi kèm Android Studio là đủ, Flutter tự tìm thấy. Kiểm tra bằng `flutter doctor`.
3. Thêm `C:\src\flutter\bin` vào PATH, hoặc đường dẫn Flutter trên máy bạn. Các lệnh dưới đây và FlutterFire CLI đều cần `flutter` và `dart` trong PATH.
4. Firebase CLI: <https://firebase.google.com/docs/cli>
5. FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

Build lần đầu mất khoảng 15 phút vì Gradle tự tải NDK, CMake và các Android SDK Platform còn thiếu. Có thể thử build trước khi cấu hình Firebase:

```bash
flutter run --dart-define=USE_FAKE_SERVICES=true
```

Nếu `flutter doctor` báo thiếu `cmdline-tools`, cài "Android SDK Command-line Tools" trong SDK Manager của Android Studio rồi chạy `flutter doctor --android-licenses`.

## 2. Tạo dự án và kết nối app

1. Đăng nhập:

```bash
firebase login
```

2. Tạo dự án tại <https://console.firebase.google.com>, bật Google Analytics khi được hỏi.
3. Trong thư mục app, chạy lệnh sau. Lệnh này tạo `android/app/google-services.json` và ghi đè `lib/firebase_options.dart`:

```bash
flutterfire configure --platforms=android --android-package-name=com.longevityplate.longevity_plate
```

4. Kiểm tra plugin Gradle. `android/settings.gradle.kts` phải có `com.google.gms.google-services` và `com.google.firebase.crashlytics`, `android/app/build.gradle.kts` phải áp dụng cả hai. Nếu lệnh trên chưa thêm, hãy tự thêm theo <https://firebase.google.com/docs/android/setup> và chọn phiên bản tương thích với AGP 9.1.

## 3. Đăng nhập Google

1. Console, Authentication, Sign-in method, bật Google.
2. Lấy SHA-1 và SHA-256 của khóa debug. Mỗi máy có một khóa debug riêng, nên mỗi thành viên nhóm đều phải thêm SHA của máy mình. `gradlew` chỉ có sau lần build Android đầu tiên và cần `JAVA_HOME`. Trong PowerShell:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
cd android; .\gradlew.bat :app:signingReport
```

Lấy các giá trị ở mục `Variant: debug`.

3. Console, Project settings, app Android, thêm hai giá trị SHA.
4. Chạy lại `flutterfire configure` để lấy `google-services.json` mới. Tệp này phải có OAuth client của web, vì `google_sign_in` đọc `default_web_client_id` từ đó.

Nếu thiếu SHA hoặc tệp cũ, màn đăng nhập báo "Đăng nhập Google chưa được cấu hình đúng cho bản cài này".

## 4. Cloud Storage

1. Nâng dự án lên gói Blaze. [Từ 03/02/2026](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024), dự án ở gói Spark không truy cập được bucket nào. Blaze cần tài khoản thanh toán nhưng vẫn có hạn mức miễn phí.
2. Đặt cảnh báo ngân sách trên Google Cloud Console.
3. Console, Storage, Get started. Chọn vùng `US-CENTRAL1`, `US-EAST1` hoặc `US-WEST1` để dùng được hạn mức Always Free.
4. Triển khai rules từ repo:

```bash
firebase deploy --only storage
```

## 5. Remote Config

Console, Remote Config, tạo hai tham số rồi Publish:

| Tham số | Kiểu | Giá trị thử |
|---|---|---|
| `max_knowledge_results` | Number | 1 |
| `suggested_recipes_enabled` | Boolean | false |

## 6. Chạy app

```bash
flutter run
```

Xem trước giao diện không cần Firebase:

```bash
flutter run -d chrome --dart-define=USE_FAKE_SERVICES=true
```

## 7. Kiểm tra từng dịch vụ

| Dịch vụ | Cách kiểm tra |
|---|---|
| Auth | Đăng nhập, hủy, tắt mạng rồi đăng nhập, đăng xuất. Xem người dùng ở Authentication, Users |
| Storage | S04, Xuất báo cáo PDF. Xem tệp ở `reports/<uid>/`. S11, thử đọc báo cáo của UID khác phải bị từ chối. Tắt mạng rồi xuất báo cáo |
| FCM | S11, sao chép token. Console, Messaging, gửi thử với token này ở 3 trạng thái app, kèm custom data `route`, ví dụ `/library/who-diverse`. Trên Android 13+ thử từ chối quyền |
| Analytics | Làm theo [analytics-plan.md](analytics-plan.md) với DebugView |
| Crashlytics | S11, ghi lỗi non-fatal rồi gây crash thử nghiệm. Mở lại app để báo cáo được gửi đi |
| Remote Config | Đổi giá trị trên Console, Publish. Xem S08, S06 và giá trị ở S11. Tắt mạng rồi mở lại app |

## Khóa bí mật

Theo tài liệu Firebase, `google-services.json` và `firebase_options.dart` là cấu hình phía client, không phải khóa bí mật. Quyền truy cập do rules và Auth kiểm soát. Nên giới hạn API key theo package và SHA trên Google Cloud Console.

Tuyệt đối không commit service account, keystore, `key.properties`, `.env` hoặc khóa API của ARTEMIS. Các mẫu này đã có trong `.gitignore`.
