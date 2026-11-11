# Kiểm tra bản Android Firebase — 11/11/2026

## Lỗi đã xử lý

- Log người dùng: `flutter analyze` và 53 test đạt, nhưng build Firebase lỗi Kotlin DSL trong `google_sign_in_android`.
- Cache Gradle trên D trước đó ghép `modules-2` qua junction tới C. Cache Kotlin DSL mới không đọc đúng classpath. Đã thay dependency cache bằng thư mục thật trên D và tạo lại cache Kotlin DSL/accessors.
- Khi đối chiếu bằng cache mặc định C, build qua được Kotlin nhưng R8 lỗi tạo/xóa thư mục `transforms`. Kiểm tra thực tế thấy C chỉ còn khoảng 247 MB. Script chuyển cache build sang D, nơi còn hàng chục GB trống.
- AGP 9.1 dùng built-in Kotlin (`android.builtInKotlin=true`). Settings ghim compiler Kotlin 2.4.0 bằng khai báo `apply false`, thay cho bản mặc định 2.2.10 thấp hơn mức Flutter 3.47 hỗ trợ. Không áp dụng plugin Kotlin Android riêng trong app.
- Script từ chối `modules-2` dạng junction/symlink và chạy Kotlin compiler trong tiến trình Gradle; khôi phục biến môi trường khi kết thúc.

## Kết quả kiểm tra

- `flutter analyze`: **No issues found**.
- `flutter test`: **53 test đạt**. Xem `firebase-checks-verification.txt`.
- `assembleRelease`: **thành công**, exit code 0; Flutter báo `Built ... app-release.apk (62.1MB)`. Xem `firebase-build-verification.txt`. Lần tạo lại cache và chạy đủ R8/Android Lint mất khoảng 16 phút 42 giây.
- R8 đã tạo mapping cho bản Firebase; không tắt bước thu gọn mã.
- APK native mới: 65.069.334 byte; `apksigner verify` đạt, chữ ký v2 hợp lệ. Xem `firebase-apk-signature.txt`.
- APK trong `artifacts/android/longevity-plate-firebase.apk` khớp SHA-256 với cả hai đầu ra APK của Gradle/Flutter: `088DA5E8F3ACC1874AE7C2825CD91442D7D7097267F12BD1EE016BA0588DFBDB`.
- Package `com.longevityplate.longevity_plate`, phiên bản 1.0.0 (code 1), min SDK 24, target SDK 36. Xem `firebase-apk-metadata.txt`.
- SHA-1 khóa ký `912ad1810374e6ee30971434eed427e89fa6b98f` khớp OAuth Android client trong `google-services.json`.
- Cấu hình Dart và Android cùng project `longevity-plate-beff9`.
- `git diff --check` và kiểm tra cú pháp PowerShell đạt.

## Chạy lại

Trong thư mục gốc ứng dụng:

```powershell
.\scripts\build-android.ps1 -Firebase
```

Nếu vừa kiểm tra cùng bản mã và chỉ cần build lại, thêm `-SkipChecks`. APK thành công được script sao chép vào `artifacts/android/longevity-plate-firebase.apk` cùng tệp SHA-256.

## Phạm vi chưa xác minh

ADB chưa thấy điện thoại kết nối. Các kiểm tra trên không thay thế việc chạy trên thiết bị thật và đối chiếu Firebase Console: Google Sign-In, upload và rules, FCM ba trạng thái, Analytics, crash/non-fatal và Remote Config. Các cảnh báo deprecation từ thư viện hoặc thông báo có phiên bản package mới không được tính là lỗi Dart.
