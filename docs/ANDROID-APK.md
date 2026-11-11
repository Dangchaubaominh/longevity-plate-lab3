# APK chạy trên điện thoại Android

> Sau khi pull main `12c60ae`, PDF Firebase dùng Cloudinary/Cloudflare Worker. Build bằng `.\scripts\build-android.ps1 -Firebase -ReportApiUrl https://<worker-url>`. Các APK và kết quả 53 test ghi dưới đây thuộc lần build trước, chưa chứa code vừa hòa nhập; xem `server/README.md` để cấu hình Worker cùng project `longevity-plate-beff9`.

Bản đã build: `artifacts/android/longevity-plate-offline.apk` (khoảng 66,4 MB), Android 7.0/API 24 trở lên. Xem `build-evidence/VALIDATION.md` để biết kết quả kiểm tra và giới hạn.

Bản Firebase đã build thành công ngày 11/11/2026: `artifacts/android/longevity-plate-firebase.apk` (62,1 MB), dùng project `longevity-plate-beff9`. Analyze và 53 test đạt; APK đã kiểm tra chữ ký. Xem `build-evidence/FIREBASE_VALIDATION.md`. Chưa kiểm tra các dịch vụ cloud trên điện thoại thật.

## Hai chế độ

- **Offline trên thiết bị:** dùng hồ sơ local, ghi bữa, đổi mục tiêu, tìm/đọc bài, lên kế hoạch, lưu PDF thật bằng bộ chọn tệp Android. Dữ liệu giữ trong SharedPreferences sau khi đóng app. Xóa dữ liệu hoặc gỡ app sẽ mất nhật ký; PDF đã lưu ra ngoài vẫn còn.
- **Firebase:** Google Sign-In, upload Storage, FCM, Analytics, Crashlytics và Remote Config dùng các adapter trong `lib/services/firebase/`. Cần cấu hình project thật theo `SETUP-FIREBASE.md`. Không lấy APK offline làm bằng chứng đã tích hợp Firebase thật.

## Build APK offline

Chạy `./scripts/build-android.ps1` trong PowerShell để kiểm tra và build tự động. Script chép APK và SHA-256 vào `artifacts/android/`. Thêm `-Firebase` khi đã có cấu hình project thật; thêm `-SkipChecks` nếu vừa chạy kiểm tra trên cùng bản mã và chỉ cần build lại.

Script dùng cache Gradle `.gradle-local` trên cùng ổ với dự án để tránh làm đầy ổ C khi R8 chạy. Cache dependency `caches/modules-2` phải là thư mục thật; script từ chối junction/symlink. Không ghép một phần cache qua junction giữa hai ổ đĩa: cache này đã gây lỗi Kotlin DSL `Cannot access class KotlinAndroidProjectExtension` và `Unresolved reference JvmTarget`. Với bản clone mới, Gradle tự tải cache đầy đủ vào ổ dự án. Với cache cũ có junction, dừng Gradle, đổi tên junction và chép đầy đủ cache gốc vào `caches/modules-2`, hoặc dùng một cache mới để Gradle tải lại. Script đặt Kotlin compiler chạy trong tiến trình Gradle cho cả included build, rồi khôi phục biến môi trường khi kết thúc.

Nếu log R8 báo không thể tạo/xóa thư mục `transforms`, kiểm tra dung lượng ổ chứa cache trước khi đổi mã nguồn. Lần sửa ngày 11/11/2026 phát hiện ổ C chỉ còn khoảng 247 MB. Nên giữ vài GB trống cho cache, tệp tạm và build Android.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=USE_LOCAL_SERVICES=true
```

Kết quả Flutter: `build/app/outputs/flutter-apk/app-release.apk`.

Lần build đầu có thể phải tải Gradle, NDK và các Android SDK Platform còn thiếu. Dự án giới hạn Gradle heap 1536 MB, tối đa một worker và Kotlin chạy trong tiến trình Gradle để phù hợp máy 6-8 GB RAM. Không tăng heap lên 8 GB trên máy ít RAM. Nếu lỗi cache `transforms`, xem log build và kiểm tra quyền/không gian thư mục Gradle trước khi chạy lại; không cần xóa source hay dữ liệu app.

Module Android dùng `android/app/build.gradle` (Groovy). Bản offline không chạy Java R8/resource shrinking để giảm tải máy build, vẫn dùng Dart release AOT. Bản Firebase giữ bước thu gọn native.

Toolchain hiện tại là Flutter 3.47+, AGP 9.1, Kotlin 2.4 và Java target 17. `android.builtInKotlin=true` bật Kotlin của AGP; khai báo Kotlin `apply false` trong settings chỉ ghim phiên bản compiler thay cho Kotlin 2.2.10 mặc định của AGP 9.1, không áp dụng plugin Kotlin Android riêng. Giữ `android.newDsl=false` để tương thích các plugin còn dùng DSL cũ; cảnh báo deprecation này không làm build thất bại. Tham khảo [hướng dẫn Flutter](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).

App có nhãn **OFFLINE** phía trên, nút **Tiếp tục offline**, không hiện hồ sơ Google giả. Khi xuất PDF, chọn vị trí trong hộp thoại Android và bấm Lưu. Sau đó có thể mở bằng trình đọc PDF cài trên điện thoại. Nếu chưa có trình đọc, vẫn có thể tìm tệp trong ứng dụng Files/Tệp.

S11 > Khu vực trình diễn có các lỗi giả lập một lần, bật/tắt món gợi ý và đổi số bài hiển thị. S12 có nút tạo tin mẫu và chạm vào để mở thư viện. Các thao tác này không gửi tin FCM, không sửa Remote Config trên Console và không gửi crash lên Firebase. Các tùy chỉnh trình diễn reset khi khởi động lại app.

## Cài lên điện thoại

1. Chuyển APK sang điện thoại bằng cáp USB hoặc nơi lưu trữ của bạn.
2. Mở APK trên điện thoại. Nếu Android hỏi, cho phép ứng dụng Tệp/trình duyệt đang dùng cài app từ nguồn này.
3. Bấm Cài đặt rồi mở Longevity Plate.
4. Bắt đầu > Tiếp tục offline > chọn mục tiêu > Hoàn tất.
5. Thử Nhật ký > Thêm bữa, Thư viện > đọc bài > Lập kế hoạch, Nhật ký > Xuất PDF.

Hoặc bật USB debugging, kết nối cáp, chấp nhận hộp thoại RSA trên điện thoại rồi dùng:

```powershell
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

APK hiện dùng khóa debug để ký bản lab theo cấu hình sẵn của dự án. Cập nhật đè cần cùng khóa ký. Nếu chữ ký bản cũ khác, giữ lại dữ liệu cần thiết trước khi gỡ bản cũ.

## Firebase project riêng của nhóm/cá nhân

Bạn có thể tạo project riêng, không cần dùng project bạn cùng nhóm đã tạo. Tuy nhiên dữ liệu/cấu hình project cũ không tự chuyển sang project mới.

1. Mở https://console.firebase.google.com/ > tạo project mới và bật Analytics.
2. Đăng ký Android package `com.longevityplate.longevity_plate`.
3. Trong thư mục repo, chạy `firebase login`, sau đó:

```powershell
flutterfire configure --project=<PROJECT_ID_MOI> --platforms=android --android-package-name=com.longevityplate.longevity_plate
```

4. Hoàn thiện Google Services/Crashlytics Gradle plugins theo `SETUP-FIREBASE.md`; thêm SHA-1/SHA-256 của khóa ký đang dùng, bật Google provider và tải cấu hình mới.
5. Bật/cấu hình các dịch vụ, deploy Storage rules và publish hai tham số Remote Config theo tài liệu setup.
6. Build lại **không có** `USE_LOCAL_SERVICES=true`:

```powershell
flutter build apk --release
```

7. Chạy trên điện thoại thật, đối chiếu Console và lưu bằng chứng. Nếu chưa cấu hình, bản mặc định hiện lỗi thiết lập và nút vào offline, không âm thầm giả làm đã kết nối Firebase.

Không chia sẻ mật khẩu Google, service-account key hoặc keystore trong chat/GitHub. Firebase client config không thay được security rules. Web Admin/backend là hạng mục riêng, chưa được triển khai trong bản bổ sung mobile này.
