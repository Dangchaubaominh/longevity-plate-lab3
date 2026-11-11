# Hướng dẫn nghiệm thu 6 nhóm Firebase của Longevity Plate

> **Lưu ý sau pull main `12c60ae`:** các mục nghiệm thu Firebase Storage dưới đây thuộc phiên bản trước. PDF hiện dùng Cloudinary qua Cloudflare Worker; xem `server/README.md` và `docs/SETUP-FIREBASE.md` cho cấu hình và kiểm thử mới. Khi build Firebase, truyền `-ReportApiUrl https://<worker-url>` cho `scripts/build-android.ps1`. Project client và Worker local hiện là `longevity-plate-beff9`; chưa deploy thay đổi này lên cloud.

Ngày đối chiếu mã: 11/11/2026. Đây là kịch bản kiểm thử, chưa phải biên bản xác nhận các dịch vụ cloud đã đạt. Chỉ điền PASS sau khi chạy trên điện thoại thật và có bằng chứng.

**0. Chuẩn bị và cách ghi kết quả**

1. Mở Firebase Console, chọn project đang có trong `lib/firebase_options.dart` và `android/app/google-services.json`. Cấu hình được kiểm tra trước đây là `longevity-plate-beff9`; nếu nhóm đã đổi project, đối chiếu lại.
2. Cài `artifacts/android/longevity-plate-firebase.apk` lên điện thoại Android có Google Play Services. Nếu vừa đổi mã/config, build lại bằng `.\scripts\build-android.ps1 -Firebase` trước khi cài.
3. App phải có đăng nhập Google; không có nhãn OFFLINE hay thông báo dùng dịch vụ giả lập. Không chọn “Tiếp tục offline” khi nghiệm thu cloud.
4. Chuẩn bị hai tài khoản Google kiểm thử A/B, mạng Wi-Fi hoặc dữ liệu di động, và máy tính mở Console.
5. Hoàn tất đăng nhập, chọn mục tiêu; thêm ít nhất hai bữa vào nhật ký. Giữ tên món đơn giản để dễ nhận ra trong PDF.
6. Trong app, bấm biểu tượng tài khoản ở đầu màn → kéo xuống → mở “Khu vực trình diễn”. Biểu tượng chuông mở lịch sử thông báo.
7. Mỗi ca lưu: mã ca, thời gian, model điện thoại/Android, phiên bản APK/commit, tài khoản A/B, thao tác, kết quả mong đợi/thực tế, PASS/FAIL/BLOCKED, ảnh/video/log.

Mẫu biên bản:

| Mã ca | Thời điểm | Thao tác | Mong đợi | Thực tế | Kết quả | Tệp bằng chứng |
|---|---|---|---|---|---|---|
| AUTH-01 | Chưa chạy | Đăng nhập A | Có UID trên Authentication | Chưa ghi nhận | NOT RUN | |

Đặt bằng chứng vào một thư mục theo đợt, ví dụ `docs/evidence/device-2026-11-11/`, với các nhóm `01-auth`, `02-storage`, `03-fcm`, `04-analytics`, `05-crashlytics`, `06-remote-config`. Không ghi PASS theo kết quả test giả lập hoặc chỉ theo việc build APK thành công.

**1. Authentication — đăng nhập Google, phiên đăng nhập và cô lập tài khoản**

Điều kiện: Authentication → Sign-in method/Providers đã bật Google; OAuth client và SHA của đúng khóa ký APK đã được khai báo.

| Mã | Thao tác trên thiết bị | Kết quả cần thấy |
|---|---|---|
| AUTH-01 | Đăng nhập Google bằng A, hoàn tất chọn mục tiêu | App vào Hôm nay; Tài khoản hiện đúng A; Console → Authentication → Users có A và UID tương ứng |
| AUTH-02 | Đăng xuất; bấm đăng nhập rồi hủy bộ chọn Google | App ở màn đăng nhập, nút dùng lại được; không tự vào màn cần đăng nhập |
| AUTH-03 | Đăng nhập A, đóng/mở app | Giữ phiên hợp lệ và trở lại đúng luồng; không bắt chọn mục tiêu lần đầu lại nếu A đã hoàn tất |
| AUTH-04 | Đăng xuất khi còn mạng; tắt cả Wi-Fi/dữ liệu di động; thử đăng nhập mới; sau đó bật mạng thử lại | Nếu không hoàn tất đăng nhập, app có thông báo phù hợp và thử lại được; không treo/crash. Một phiên đã được SDK lưu vẫn có thể tồn tại khi mất mạng, nên phải ghi rõ trạng thái bắt đầu |
| AUTH-05 | A thêm bữa dễ nhận ra → đăng xuất → B đăng nhập → xem Nhật ký/Mục tiêu/Kế hoạch → quay lại A | B không thấy dữ liệu riêng của A; quay lại A vẫn thấy dữ liệu A theo chính sách lưu local hiện tại |

Bằng chứng: màn tài khoản A/B, UID trong Console, video hủy đăng nhập và thử lại, nhật ký phân tách A/B.

Giải thích khi báo cáo: Google Sign-In lấy Google ID token; `FirebaseAuth.signInWithCredential` tạo phiên Firebase. UID là định danh Firebase dùng trong đường dẫn Storage và gắn ngữ cảnh telemetry. Nhật ký, mục tiêu và kế hoạch hiện lưu bằng SharedPreferences theo UID; không có bước lưu các bữa vào Firestore trong bản mã này.

Mã cần chỉ: `lib/services/firebase/firebase_auth_service.dart`, `lib/viewmodels/session_view_model.dart`, `lib/services/repositories.dart`.

**2. Upload/Storage — PDF thật, tiến độ, lỗi mạng và rules theo UID**

Adapter hiện tại dùng Firebase Storage. Cloud Storage yêu cầu project Blaze; nếu Console chặn ở bước này thì ghi BLOCKED. Cloudinary/S3 được giảng viên cho thay thế, nhưng cần adapter và kiểm thử thực tế tương ứng trước khi đánh dấu đã đạt.

Trước khi thử upload, mở Storage → Rules và đối chiếu `firebase/storage.rules`. Nếu dùng CLI, chạy trong thư mục repo:

```powershell
firebase deploy --only storage --project longevity-plate-beff9
```

Chỉ dùng Project ID trên nếu đó vẫn là project nhóm đang nghiệm thu.

| Mã | Thao tác | Kết quả cần thấy |
|---|---|---|
| UP-01 | Đăng nhập A → Nhật ký → Xuất báo cáo PDF → “Tạo và tải lên” | Có trạng thái tạo PDF, tải lên/tiến độ, sau đó thông báo thành công và URL |
| UP-02 | Bấm “Mở báo cáo”; đối chiếu Storage → Files | PDF mở được, tiếng Việt đọc được, có đúng dữ liệu 7 ngày; file thật nằm tại `reports/<UID_A>/meal-report-<timestamp>.pdf` |
| UP-03 | Tắt Wi-Fi và dữ liệu di động trước khi upload; bật mạng rồi bấm “Thử lại” | Hiện lỗi phù hợp, không báo thành công giả, không bị khóa nút; thử lại thành công. SDK hiện retry upload tối đa khoảng 30 giây, operation tối đa khoảng 15 giây; tổng thao tác có thể dài hơn |
| UP-04 | Tài khoản → Khu vực trình diễn → “Thử đọc báo cáo của UID khác” | Hiện bị từ chối với `unauthorized`; `object-not-found` đơn thuần không được ghi là PASS quyền truy cập |
| UP-05 | Rules Playground/Simulator: thử đọc đúng đường dẫn file A đã tạo, lần lượt bằng UID_A, UID_B và không đăng nhập | A được phép; B và người chưa đăng nhập bị từ chối |
| UP-06 | Tài khoản → bật “Lỗi tải báo cáo lên (S04)” → xuất PDF → thử lại | Nhánh lỗi và phục hồi hoạt động. Ghi rõ đây là lỗi được chèn một lần, không thay UP-03/UP-05 |

Trong Rules Playground chọn thao tác đọc/get và điền UID mô phỏng ở phần authenticated. Với rules hiện tại, chỉ chủ UID được đọc/tạo PDF dưới 5 MB; update/delete chưa được cho phép. Có thể bổ sung kiểm thử MIME sai và dung lượng quá giới hạn bằng môi trường test phù hợp.

Nút thử có sẵn đang đọc một đường dẫn UID khác cố định với tên file không tồn tại. Bằng chứng mạnh hơn là UP-05 đối chiếu đường dẫn file thật và ba danh tính. Không dùng việc mở URL download có token trong trình duyệt làm bằng chứng rằng rules đang cho mọi UID đọc: đây là đường truy cập theo URL có token, khác phép đọc qua SDK có danh tính.

File PDF nhỏ có thể nhảy nhanh lên 100%; không tự kết luận tiến độ bị lỗi. Quay màn hình từ trước khi bấm upload, hoặc thử trên mạng chậm nếu cần quan sát rõ.

Mã cần chỉ: `lib/viewmodels/report_view_model.dart`, `lib/services/report_builder.dart`, `lib/services/firebase/firebase_storage_service.dart`, `firebase/storage.rules`.

**3. FCM — token, nhận ở ba trạng thái, điều hướng và lịch sử**

1. Cho phép thông báo trên Android 13+. Nếu trước đó từ chối nhiều lần, vào Cài đặt Android → Ứng dụng → Longevity Plate → Thông báo để bật lại.
2. Trong app: Tài khoản → Khu vực trình diễn → Cloud Messaging → “Sao chép token”. Dùng token của chính bản cài đang thử; lấy lại sau khi cài lại/xóa dữ liệu nếu cần.
3. Firebase Console → Messaging/Cloud Messaging → tạo thông báo Firebase Notification → nhập tiêu đề và nội dung → “Send test message/Test on device” → dán registration token → gửi tới thiết bị test.
4. Gửi ba tin có tiêu đề riêng: `LAB3-FG-01`, `LAB3-BG-01`, `LAB3-TERM-01`; tránh nhầm các tin gửi nhiều lần.

| Mã | Trạng thái trước khi gửi | Kết quả cần thấy |
|---|---|---|
| FCM-01 | App đang mở, đã đăng nhập | Có SnackBar trong app với nút “Xem”; tin có trong lịch sử. App hiện không tạo notification tray riêng cho foreground |
| FCM-02 | Nhấn Home để app ở nền | Có thông báo hệ thống; chạm thông báo mở app và ghi lịch sử/đã đọc |
| FCM-03 | App đã được mở/đăng nhập trước đó, sau đó kết thúc process mà không Force stop | Có thông báo hệ thống; chạm để mở app từ đầu và xử lý tin ban đầu |
| FCM-04 | Tắt quyền thông báo trong Cài đặt Android rồi mở lại màn Thông báo | UI báo “Thông báo đang tắt”, app vẫn dùng được; không yêu cầu phải có notification tray khi quyền bị tắt |
| FCM-05 | Gửi thêm Custom data `route=/library/who-diverse` trong composer hỗ trợ trường này hoặc qua sender có Admin SDK/HTTP v1 | Chạm “Xem”/notification mở đúng chi tiết bài viết |
| FCM-06 | Gửi Custom data `route=/khong-ton-tai` | App chuyển an toàn về lịch sử `/notifications`, không crash hoặc mở route tùy ý |
| FCM-07 | Nhận/chạm tin → mở lịch sử → đóng/mở lại app | Lịch sử còn, trạng thái đọc hợp lý; chạm một tin không tạo bản ghi trùng cùng message ID |

Để làm FCM-03 có kiểm soát, nhấn Home trước rồi dùng ADB:

```powershell
adb shell am kill com.longevityplate.longevity_plate
```

Không dùng `am force-stop` hoặc nút “Buộc dừng” để tạo ca terminated: Android yêu cầu mở app lại sau force-stop để nhận tin bình thường. Một số hãng hạn chế app nền; ghi model và thiết lập tiết kiệm pin nếu có khác biệt.

Nếu test token cơ bản mở lịch sử thay vì bài viết, kiểm tra payload có `data.route` hay không. Khi không có `route`, mã app chủ động mở `/notifications`. Trong Notifications composer, trường Custom data nằm ở Advanced/Additional options; nếu hộp Send test message của Console không mang theo trường này, chỉ ghi nhận ca nhận tin cơ bản và dùng sender có payload được kiểm soát cho ca deep link. Không đánh dấu deep link đạt chỉ vì tin tới thiết bị.

Payload minh họa cho sender HTTP v1, không phải nội dung dán vào ô notification body:

```json
{
  "message": {
    "token": "TOKEN_CUA_DIEN_THOAI_TEST",
    "notification": { "title": "LAB3-ROUTE-01", "body": "Mo bai kien thuc" },
    "data": { "route": "/library/who-diverse" }
  }
}
```

Giải thích: bản app hiện dùng registration token từ `FirebaseMessaging.getToken()`. SDK/FCM cấp và quản lý token cho một app instance; nó khác UID và có thể thay đổi. App đang lấy token để hiển thị/sao chép, chưa có backend lưu token hoặc luồng đồng bộ `onTokenRefresh` trong adapter này. Khi dùng Console, Console gửi yêu cầu tới FCM thay cho server của nhóm. Nếu dùng server riêng, server xác thực với FCM bằng Admin SDK/HTTP v1 và gửi tới token; không nhúng service-account key vào Flutter.

Mã cần chỉ: `lib/services/firebase/firebase_messaging_service.dart` (`onMessage`, `onMessageOpenedApp`, `getInitialMessage`, background handler), `lib/viewmodels/notifications_view_model.dart`, `lib/core/push_routes.dart`, `lib/app/app.dart`. Source hiện không có custom backend gửi FCM để chỉ cho giảng viên; phải nói đúng phạm vi triển khai.

**4. Analytics — thấy sự kiện thật và đúng tham số**

Kết nối điện thoại thật qua USB debugging, chấp nhận RSA. Trong PowerShell:

```powershell
$adb = 'C:\Users\Acer\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $adb devices
& $adb shell setprop debug.firebase.analytics.app com.longevityplate.longevity_plate
```

Mở lại app. Trên Firebase Console → Analytics → DebugView, chọn đúng thiết bị. Dùng DebugView để nghiệm thu trực tiếp; không chờ dashboard tổng hợp cập nhật ngay.

| Thao tác | Sự kiện cần đối chiếu | Tham số đáng xem |
|---|---|---|
| Đăng nhập Google | `login` | `method=google` |
| Mở chọn mục tiêu lần đầu | `tutorial_begin` | Không yêu cầu nhập tên/email |
| Hoàn tất mục tiêu lần đầu | `tutorial_complete` | `goal_count`, `duration_ms` |
| Bấm thêm bữa | `meal_add_start` | |
| Lưu bữa | `meal_saved` | `meal_type`, `duration_ms` |
| Mở bài kiến thức | `select_content` | `content_type`, `item_id` |
| Bấm lập kế hoạch từ bài | `plan_from_article` | `item_id` |
| Mở chi tiết món | `recipe_view` | `item_id` |
| Lưu món vào kế hoạch | `plan_slot_saved` | `meal`, `action`, `source`, `duration_ms` |
| Upload PDF thành công | `report_exported` | `meal_count`, `size_kb` |
| Chạm thông báo | `notification_opened` | `source`, `target` |
| Bật lỗi lưu bữa một lần rồi lưu | `meal_save_failed` | `meal_type`; đây là nhánh lỗi giả lập được ghi rõ |

Tiêu chí AN-01: ít nhất 7 sự kiện khác nhau đúng với `docs/analytics-plan.md`, không tính bảy lần lặp cùng một event. AN-02: mở từng event xem tham số đúng. AN-03: đổi màn có `screen_view`; không gửi tên/email/nội dung món/từ khóa tìm kiếm vào event. AN-04: nhánh lỗi ghi event phù hợp, không ghi thành công trước khi nghiệp vụ hoàn tất.

`tutorial_begin/complete` chỉ có ở onboarding lần đầu; sửa mục tiêu của tài khoản đã onboard không tạo lại hai event đó. Có thể dùng tài khoản B mới để thử, hoặc chọn các event khác cho mốc tối thiểu 7. `duration_ms` hiện đo theo đoạn luồng được mô tả trong analytics-plan, không mặc nhiên là toàn bộ thời gian từ lúc mở app.

Tắt debug sau khi thử:

```powershell
& $adb shell setprop debug.firebase.analytics.app .none.
```

Bằng chứng: timeline DebugView và ảnh chi tiết vài event có tham số; lưu riêng bảng plan trước tracking.

Mã cần chỉ: `lib/services/firebase/firebase_analytics_service.dart`, `lib/services/service_interfaces.dart`, các ViewModel tương ứng và `lib/app/app.dart`.

**5. Crashlytics — non-fatal, nút gây crash, UID và route**

Nên chạy APK release đã cài, mở bằng biểu tượng app trên điện thoại để tránh debugger can thiệp.

| Mã | Thao tác | Kết quả cần thấy |
|---|---|---|
| CR-01 | Đăng nhập A → Tài khoản → Khu vực trình diễn → “Ghi lỗi non-fatal” | App tiếp tục chạy; Console Crashlytics có issue/event non-fatal `demo_non_fatal` sau khi SDK gửi dữ liệu |
| CR-02 | Bấm “Gây crash thử nghiệm” → xác nhận “Gây crash” | App thực sự đóng; không chỉ hiện một thông báo mô phỏng |
| CR-03 | Mở lại app bằng icon, giữ mạng; mở Console Crashlytics chọn đúng Android app/build | Có fatal issue/event mới; đối chiếu giờ, phiên bản và thiết bị. Một issue có thể gom nhiều event, nên mở event mới nhất |
| CR-04 | Mở chi tiết event vừa tạo | Có UID A và custom key `route`; bấm crash tại Tài khoản thường có route `/account`; có stack trace |

Mở lại app sau native test crash là bước cần làm trong quy trình demo của bản này. Nếu chưa thấy sau khoảng 5 phút, kiểm tra đúng project/app, bộ lọc thời gian/build và log thay vì bấm crash liên tục:

```powershell
& $adb shell setprop log.tag.FirebaseCrashlytics DEBUG
& $adb logcat -s FirebaseCrashlytics
```

Lặp lại một crash có kiểm soát, mở app lại và tìm log `Crashlytics report upload complete` hoặc mã HTTP 204. Sau đó trả log level:

```powershell
& $adb shell setprop log.tag.FirebaseCrashlytics INFO
```

Lỗi non-fatal có thể được gửi theo đợt; nếu chậm, đưa app về nền/mở lại, giữ mạng và quan sát log. Custom key của app hiện là `route`; không tự ghi rằng đã có `screen`/`user_role` nếu chưa bổ sung.

Bằng chứng: video bấm nút → app đóng → mở lại; ảnh Console issue/event có thiết bị, giờ, UID, custom key và stack trace.

Mã cần chỉ: `lib/services/firebase/firebase_crash_service.dart`, `lib/viewmodels/account_view_model.dart`, `lib/viewmodels/session_view_model.dart`, `lib/app/app.dart`, `lib/views/account_screen.dart`.

Yêu cầu bổ sung của giảng viên: nhóm Dev được xem Console; Admin phải xem kết quả trên web riêng. CR-01–04 chỉ nghiệm thu mobile → Crashlytics → Console. Source đã rà chưa có web Admin/backend riêng. Phần Admin phải có thêm ca: Admin đăng nhập web → xem sự cố mới khớp thời gian/build/thiết bị → mở chi tiết; tài khoản không phải Admin bị từ chối. Ghi BLOCKED/CHƯA TRIỂN KHAI cho phần này nếu chưa có web và nguồn dữ liệu thật; không đánh dấu đạt bằng ảnh Console hoặc bảng dữ liệu tự nhập. API endpoint và cách lấy dữ liệu cho web phải được xác định trước khi triển khai, không giả định Crashlytics có sẵn API liệt kê issue tùy ý.

**6. Remote Config — hai tham số đổi UI, cache và mặc định**

Console → Remote Config: tạo đúng tên/kiểu, không chỉ Save mà phải Publish changes.

| Tham số | Kiểu | Bộ A | Bộ B | UI cần quan sát |
|---|---|---|---|---|
| `max_knowledge_results` | Number | 3 | 1 | Giới hạn danh sách bài trong Thư viện |
| `suggested_recipes_enabled` | Boolean | true | false | Hiện/ẩn phần “Món gợi ý” ở Kế hoạch tuần |

RC-01: giữ app online/foreground; publish bộ A; mở Tài khoản → Khu vực trình diễn để thấy giá trị; bỏ từ khóa tìm kiếm ở Thư viện và ghi ảnh trước thay đổi. Mở Kế hoạch và cuộn tới phần Món gợi ý.

RC-02: giữ app mở, publish bộ B; chờ listener realtime, có thể bấm “Tải lại cấu hình”; kiểm tra giá trị ở Tài khoản và quay lại hai màn. Thư viện giới hạn còn 1 bài (khi dữ liệu có đủ bài), Món gợi ý biến mất. Không build/cài APK khác giữa hai ảnh.

RC-03: sau khi bộ B đã áp dụng, tắt mạng, đóng/mở app; app vẫn dùng được và giữ cấu hình đã kích hoạt. Publish lại bộ A sau khi bật mạng để chứng minh có thể bật tính năng trở lại.

RC-04: kiểm tra nhánh fetch lỗi có phục hồi: bản debug đang đặt minimum interval bằng 0; tắt mạng và thử refresh, chờ timeout khoảng 10 giây, rồi bật mạng thử lại. Bản release có minimum fetch interval 1 giờ: refresh có thể trả cache và không báo lỗi ngay khi mất mạng, đây không tự động là FAIL.

RC-05: kiểm tra mặc định khi chưa từng nhận cấu hình. Code hiện có `3` và `true`. Ca này khác RC-03 dùng cache. Nếu cần chứng minh bằng UI, dùng môi trường test kiểm soát việc fetch Remote Config trong khi Auth vẫn hoạt động, hoặc instrument bản debug phù hợp. Không gỡ app rồi yêu cầu đăng nhập Google hoàn toàn offline để chứng minh default; nếu chưa tạo được điều kiện test, ghi CHƯA KIỂM TRA và dùng code/unit test làm bằng chứng hỗ trợ.

Lưu ý quan trọng: bản release cache fetch thường 1 giờ, debug bằng 0; app có `onConfigUpdated` rồi `activate()`. Listener realtime có thể nhận bản Publish mới trong phiên foreground và bỏ qua minimum fetch interval. Giữ app mở trước khi Publish là cách demo nhanh; không kết luận lỗi chỉ từ việc bấm refresh nhiều lần trong 1 giờ.

Bằng chứng: hai phiên bản Console đã Publish, ảnh/video Thư viện/Kế hoạch trước–sau cùng APK, ảnh cấu hình còn hiệu lực khi offline.

Mã cần chỉ: `lib/services/firebase/firebase_remote_config_service.dart`, `lib/services/service_interfaces.dart`, `lib/viewmodels/library_view_model.dart`, `lib/viewmodels/planner_view_model.dart`.

**7. Chốt nghiệm thu và thứ tự trình diễn**

Thứ tự thực hiện lần đầu: Auth → Upload → FCM → Analytics → Remote Config → Crashlytics. Crashlytics để cuối vì cố ý đóng app. Có thể bật Analytics DebugView từ đầu để thu các event trong toàn bộ phiên.

| Nhóm | Bằng chứng tối thiểu nên có | Trạng thái trước khi tự chạy |
|---|---|---|
| Auth | Google login + UID Console + hủy/mất mạng + A/B | NOT RUN |
| Upload | PDF thật + file dưới UID + tiến độ + lỗi/retry + rules A/B | NOT RUN |
| FCM | Ba trạng thái + token + route + lịch sử + từ chối quyền | NOT RUN |
| Analytics | Plan + ít nhất 7 event khác nhau + tham số DebugView | NOT RUN |
| Crashlytics | Non-fatal + video fatal + UID/route/stack trace | NOT RUN |
| Remote Config | Hai thay đổi UI cùng APK + Publish + cache/offline | NOT RUN |
| Web Admin bổ sung | Admin xem kết quả thật; người không phải Admin bị chặn | CHƯA TRIỂN KHAI trong source đã rà |

Mỗi dịch vụ cần cả luồng thành công và ít nhất một nhánh lỗi/giới hạn phù hợp. ARTEMIS, exploratory testing, AI review, GitHub, báo cáo/slide/video là các mục nghiệm thu Lab 3 khác; checklist Firebase không thay thế chúng.

**Nguồn Firebase chính thức để đối chiếu**

- https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- https://firebase.google.com/docs/cloud-messaging/customize-messages/set-message-type
- https://firebase.google.com/docs/cloud-messaging/send/firebase-console
- https://firebase.google.com/docs/analytics/debugview
- https://firebase.google.com/docs/crashlytics/flutter/test-implementation
- https://firebase.google.com/docs/remote-config/flutter/get-started
- https://firebase.google.com/docs/storage/flutter/start
