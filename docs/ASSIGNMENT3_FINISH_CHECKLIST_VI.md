# Hoàn thiện Assignment 3 - thứ tự thực hiện

> Checklist lịch sử trước khi triển khai backend. Trạng thái và hướng dẫn hiện hành: [ASSIGNMENT_ACCEPTANCE.md](ASSIGNMENT_ACCEPTANCE.md), [FINAL_IMPLEMENTATION_REPORT.md](FINAL_IMPLEMENTATION_REPORT.md), [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md).

Đối chiếu guide PRM393 Lab3 v5 và mã nguồn ngày 13/11/2026. Mục tiêu nộp gồm GitHub, báo cáo PDF 8-12 trang, slide PDF 12-15 trang và video 5-10 phút. Người dùng tự quay video.

## 1. Phân biệt các cấu hình

| Thông tin | Công dụng | Nơi cấu hình |
|---|---|---|
| Cloudinary Cloud name / API key / API secret | Lưu tệp và ký upload | Cloudflare Worker secrets; không đặt API secret trong Flutter |
| URL Worker `https://...workers.dev` | Địa chỉ app gọi `/reports/sign`, `/reports/url` | `REPORT_API_URL` khi build/run |
| Firebase project | Đăng nhập, FCM, Analytics, Crashlytics, Remote Config | Android config, firebase_options.dart và Worker phải khớp |
| API key mô hình AI | ARTEMIS đọc màn hình và thực hiện kiểm thử | Wizard ARTEMIS, lưu local trong thư mục artifacts được Git bỏ qua |
| ADB IP:port / device ID | Kết nối điện thoại thật | Wireless debugging hoặc USB |

Cloudinary API key không thay cho API key mô hình AI của ARTEMIS. Có tài khoản Cloudinary cũng chưa có nghĩa Worker đang deploy đã được cấu hình đúng.

## 2. Hoàn tất cloud trước khi đóng băng APK

Trong `server/`, cấu hình các secret bằng prompt của Wrangler, không dán secret vào chat:

```powershell
npm ci
npx wrangler login
npx wrangler secret put CLOUDINARY_CLOUD_NAME
npx wrangler secret put CLOUDINARY_API_KEY
npx wrangler secret put CLOUDINARY_API_SECRET
npx wrangler deploy
```

- Kiểm tra `FIREBASE_PROJECT_ID` trong wrangler.toml trùng project của app; working tree hiện là `longevity-plate-beff9`.
- Ghi lại URL Worker được in sau deploy. Nếu đã có Worker của nhóm, kiểm tra nó trước khi thay cấu hình hoặc deploy đè.
- Trong Cloudinary, bật khả năng delivery PDF/ZIP nếu tài khoản đang chặn PDF.
- Nghiệm thu: xuất PDF, thấy trạng thái tải và URL, mở được PDF, thấy asset tại `reports/<uid>/`, tài khoản khác không xin được link, mất mạng có thông báo và Thử lại.
- Ảnh bữa ăn hiện lưu local. Upload ảnh lên Cloudinary là tính năng mở rộng theo kế hoạch riêng; guide yêu cầu ít nhất một tệp như PDF, không bắt buộc dùng ảnh để thay thế luồng PDF.

## 3. Build bản dùng để nghiệm thu trên điện thoại thật

```powershell
flutter devices
```

Đặt URL thực tế của Worker vào tham số sau:

```powershell
.\scripts\build-android.ps1 -Firebase -ReportApiUrl https://<worker-url>
```

Test debug có thể dùng `flutter run -d "<device-id>" --dart-define=REPORT_API_URL=https://<worker-url>`. Ghi lại commit, version app, thiết bị, ngày chạy và SHA-256 của APK được dùng để chấm. Không đổi code giữa các vòng ARTEMIS rồi gộp kết quả như cùng một bản.

## 4. Kiểm thử cloud và thu bằng chứng

| Nhóm | Ca chính và ca lỗi | Bằng chứng |
|---|---|---|
| Auth | Google Sign-In; hủy; mất mạng; logout; chặn màn bảo vệ; tách A/B | App trước/sau login, Firebase Authentication Users |
| Cloudinary thay Storage | PDF thành công; quyền UID; upload/mở link thất bại khi mất mạng | Tiến độ/URL/PDF và Cloudinary Media Library, request bị từ chối |
| FCM | Foreground; background; terminated; chạm mở đúng route; từ chối quyền | Thiết bị, token lưu riêng, thông báo và lịch sử trong app |
| Analytics | Thực hiện các event trong analytics-plan.md; tắt/bật mạng; không gửi PII | DebugView từng event và tham số, đối chiếu với luồng F01-F03 |
| Crashlytics | Một lỗi thực tế được xử lý; nút crash có xác nhận; mở lại app gửi báo cáo | Fatal/non-fatal, user ID và custom key route trên Firebase |
| Remote Config | Hai tham số đổi hành vi; thử offline/cache/default | Console và app trước/sau, cùng APK |

Không dùng Android Force stop để thay cho mọi tình huống terminated FCM: sau Force stop từ Settings, app cần được mở lại mới nhận tin bình thường. Tài khoản test và khóa phải được giữ riêng; ảnh đưa vào tài liệu che token, email và thông tin nhạy cảm.

Yêu cầu bổ sung của giảng viên qua người dùng: Admin dùng web xem kết quả, team Dev xem Firebase. Cần kiểm tra/triển khai web Admin và kết nối dữ liệu có phân quyền riêng; không gọi một trang Flutter web giả lập hoặc ảnh Console tĩnh là dashboard Admin đã hoạt động. Đây là hạng mục độc lập với ARTEMIS.

## 5. Cài và cấu hình ARTEMIS

Source chính thức được đặt riêng tại `D:\PRM393\Lab3\tools\artemis`. Không commit source công cụ vào repo Flutter. Bản tải ngày 13/11/2026: `351ca8422f7b5b54e80a9c1ce03a222e02415b6b`.

Môi trường đã cài Python 3.12.13 và ARTEMIS 1.0 theo lockfile; CLI `--version` chạy thành công. scrcpy 5.0.1 portable đặt trong `tools/scrcpy/scrcpy-win64-v5.0.1`; file tải từ release Genymobile chính thức đã đối chiếu SHA-256 `b12a2c4ee8be317422451fc7dcf8ee20a71b5ea7ef9ad73ddd825a25316227a5`. Đây là công cụ xem màn hình/replay; chưa phải bằng chứng đã chạy test thiết bị.

Cài dependency từ lockfile nếu cần dựng lại:

```powershell
cd D:\PRM393\Lab3\tools\artemis
$env:UV_CACHE_DIR = 'D:\PRM393\Lab3\tools\.uv-cache'
$env:UV_PYTHON_INSTALL_DIR = 'D:\PRM393\Lab3\tools\.python'
uv sync --locked --no-dev --python 3.12
```

Từ thư mục app, dùng wrapper đã chuẩn bị:

```powershell
.\scripts\artemis-lab3.ps1 -Mode init
.\scripts\artemis-lab3.ps1 -Mode doctor
.\scripts\artemis-lab3.ps1 -Mode ui
```

- `init`: tự chọn nhà cung cấp AI và nhập key vào prompt ẩn. Không gửi key qua chat. Xác nhận model của profile đang dùng có quyền truy cập với tài khoản đã chọn.
- Khi wizard hỏi IDE để auto-install MCP, chọn `8 - Skip for now` nếu chỉ chạy qua giao diện web. Không cần thay cấu hình Codex/IDE toàn cục để nghiệm thu bằng ARTEMIS UI.
- `.env`, trạng thái và traces được đặt trong `artifacts/artemis-runtime`, đã bị Git bỏ qua bởi `/artifacts/`.
- Wrapper thêm Android platform-tools và scrcpy portable vào PATH cho tiến trình và khôi phục môi trường khi kết thúc; không sửa cấu hình MCP toàn cục.
- Wrapper tắt tự cài Accessibility Helper. Khi chạy trên điện thoại cá nhân, chỉ cài/bật helper hoặc UIAutomator theo quy trình đã xem rõ quyền cần cấp.
- Dùng tài khoản Google test trên điện thoại. ARTEMIS gửi dữ liệu màn hình/tác vụ cho nhà cung cấp AI đã cấu hình; tránh mở ứng dụng/tài khoản cá nhân khi chạy.
- Chọn đúng thiết bị thật trong UI, chạy một ca đơn giản và xem replay/log trước khi chạy cả bộ.

## 6. Chạy ARTEMIS theo guide

Bộ 12 ca AR-01 đến AR-12 đã có trong `docs/test-cases.md`: F01-F03, validation, hủy bản nháp, thay món, tìm kiếm, quyền Android, mở trình duyệt ngoài, retry và logout.

1. Chốt điều kiện đầu cho từng ca: user nào, đã onboarding chưa, trạng thái quyền thông báo, dữ liệu/kế hoạch có sẵn.
2. Bổ sung dữ liệu kiểm thử duy nhất cho mỗi lần chạy để phân biệt bản ghi mới/cũ.
3. Chạy mỗi ca 3 lần, tổng 36 lượt cho bộ 12 ca.
4. Lưu trace ID, thiết bị, version/commit, timestamp, screenshot cuối, log và lỗi ở từng lượt.
5. Đối chiếu kết quả quan sát được với kỳ vọng. `SUCCESS` của agent không tự động tính là PASS.
6. Tính tỷ lệ từng ca = số lượt đạt / 3. Giữ lịch sử FAIL, lỗi tìm được và lần chạy lại sau sửa.
7. Chạy thêm một phiên khám phá 15-30 phút, ghi thời gian thực tế, màn đã đi qua, lỗi và cách xử lý.

Ba vòng `flutter test` đã đạt 75/75 mỗi vòng (225 lượt test Flutter) trong `artifacts/lab3-final-verification`. Đây là kiểm thử Flutter với dependency giả lập, không phải 36 lượt ARTEMIS hoặc bằng chứng cloud thật.

## 7. Chốt AI Review, GitHub và tài liệu

- Đối chiếu `docs/code-review.md`: ít nhất 5 phát hiện thuộc 2 nhóm, có vị trí code, quyết định và lý do; ít nhất 3 phát hiện được sửa với commit. Repo hiện có hồ sơ review PR #1 và các commit truy vết; cập nhật khi sửa code mới.
- Cập nhật architecture.md, design-traceability.md và analytics-plan.md theo đúng source chốt. Không dùng bản audit lịch sử trước pull để mô tả source mới.
- Nộp source/README trên GitHub, commit/tag bản chốt, hướng dẫn build và vị trí bằng chứng. Không đưa secret lên GitHub.
- Báo cáo PDF 8-12 trang: mục tiêu, F01-F03, MVVM, dịch vụ, bảo mật, test/ARTEMIS, review, kết luận có dẫn chứng.
- Slide PDF 12-15 trang: giải thích nguyên lý, luồng token/chữ ký, vị trí code, thay đổi Remote Config, kết quả test và minh chứng.
- Video 5-10 phút do người dùng quay bằng APK chốt: F01-F03, PDF, FCM, Analytics, Crashlytics, Remote Config, Admin web và phần kiểm thử.

## 8. Việc cần cung cấp để tiếp tục nghiệm thu

1. URL Worker đang dùng, hoặc cấu hình secret trực tiếp trong tài khoản Cloudflare của bạn.
2. Nhà cung cấp API mô hình cho ARTEMIS; nhập key trong wizard local.
3. Điện thoại kết nối USB hoặc Wireless debugging; nếu wireless, cung cấp IP:port đang hiển thị ở mục kết nối.
4. Nếu nhóm đã có web Admin, cung cấp URL/source để tích hợp và nghiệm thu cùng app.

Nguồn chính thức: https://github.com/google/artemis ; https://cloudinary.com/documentation/authentication_signatures ; https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages .
