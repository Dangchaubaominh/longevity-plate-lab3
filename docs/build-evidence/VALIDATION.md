# Xác minh bản Android offline

## File cài đặt

- File: `artifacts/android/longevity-plate-offline.apk`
- Kích thước: 69.604.902 byte (khoảng 66,4 MiB).
- SHA-256: `2D7EB94128FF808B1AB1023D3E46311106C5644EABE647A5EB5F63B2124B813B`
- Package: `com.longevityplate.longevity_plate`.
- Version: `1.0.0`, versionCode `1`.
- Android tối thiểu: API 24 (Android 7.0). Target/compile: API 36.
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- Chữ ký: APK Signature Scheme v2 hợp lệ, một signer Android Debug (khóa ký lab).
- ZIP CRC: không có entry lỗi. Có Android Manifest, ba tệp DEX, AOT `libapp.so` cho ba ABI và tài nguyên Flutter.

## Kiểm tra đã chạy

1. `flutter analyze --no-pub`: không có issues. Log `flutter-analyze.txt`.
2. `flutter test --no-pub --reporter expanded`: 53/53 pass. Log `flutter-test.txt`.
3. `flutter build apk --release --no-pub --dart-define=USE_LOCAL_SERVICES=true -v`: BUILD SUCCESSFUL, exit 0. Log `flutter-build-apk-final.txt`.
4. Android `apksigner verify --verbose --print-certs`: Verifies, v2 true. Log `apk-signature.txt`.
5. Android `aapt2 dump badging` và `dump xmltree`: package/version/ABI, minSdkVersion 24, targetSdkVersion 36. Log `apk-metadata.txt` và thông tin xác minh ở trên.
6. `git diff --check`: không có lỗi whitespace.

## Môi trường và sửa cấu hình build

Flutter 3.47.2 stable, Dart 3.13.2, Gradle 9.3.1, AGP 9.1.0, JDK 25 từ Android Studio. NDK 28.2.13676358 và SDK Platforms 34/35 đã được cài khi build.

Máy có khoảng 6 GB RAM. Đã giảm Gradle heap từ 8 GB xuống 1536 MB, một worker và Kotlin in-process. Dùng cache riêng `.gradle-local` trên D để tránh lỗi cache transforms trên C. Module app dùng Gradle Groovy tương đương để tránh lỗi Kotlin DSL legacy khi biên dịch cấu hình. Bản offline bỏ Java R8/resource shrinking nhưng Dart vẫn là release AOT; bản Firebase giữ cấu hình thu gọn native. Các lần build bị lỗi trước đó được giữ ở `../tmp/android-build-attempts` tính từ repo.

## Giới hạn bằng chứng

Không có điện thoại Android kết nối khi kiểm tra ADB. Chưa cài hoặc chạy APK trên thiết bị thật, nên chưa xác minh trực tiếp bộ chọn tệp Android và mở PDF bằng ứng dụng ngoài. Hai kiểm thử lưu/hủy PDF hiện kiểm tra MethodChannel bằng mock; biên dịch Android và kiểm tra chữ ký không thay cho kiểm thử thiết bị.

Bản APK dùng hồ sơ offline, không có đăng nhập Google/FCM/Crashlytics/Storage thật. Không dùng kết quả này làm bằng chứng đã hoàn thành tích hợp Firebase hoặc ARTEMIS. Cần cấu hình Firebase project riêng, build bản Firebase rồi chạy trên điện thoại thật để chấm Lab 3. Web Admin/backend không thuộc bản bổ sung mobile này.
