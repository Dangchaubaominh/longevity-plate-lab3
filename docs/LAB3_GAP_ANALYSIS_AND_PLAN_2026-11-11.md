# Lab 3: đối chiếu yêu cầu và kế hoạch bổ sung chi tiết

Ngày đánh giá: 11/11/2026. Đối tượng: working tree `D:/PRM393/Lab3/longevity-plate-lab3`, nhánh `feature/lab3-firebase`, HEAD `3abfa0e` và các thay đổi chưa commit. Đây là bản kế hoạch mới sau khi đã build APK, thay cho các kết luận về trạng thái ngày 04/11 trong bản audit cũ.

## 1. Kết luận và giới hạn đánh giá

**Chưa đủ điều kiện kết luận hoàn thành Lab 3 hoặc mang bản hiện tại đi chấm đầy đủ.** Phần Flutter đã có nền tảng tốt, có APK offline và kết quả kiểm thử tự động. Khoảng trống chính hiện là cấu hình/dữ liệu Firebase thật, kiểm thử trên điện thoại, web Admin/backend, ARTEMIS, hồ sơ AI review và bằng chứng trong bộ nộp.

Đã thực hiện trong lần đánh giá này:

- Đọc nội dung cả 25 trang PDF, kiểm tra trực quan các trang 23-25 về kiểm thử, review và sản phẩm nộp.
- Đọc mã cấu hình, bootstrap, adapter sáu dịch vụ, ViewModel phiên/thông báo, storage rules, kế hoạch Analytics, ca kiểm thử và tài liệu thiết kế/kiến trúc.
- Đối chiếu log analyze, 53 test, build APK, chữ ký, metadata và hồ sơ validation đã lưu.
- Kiểm tra sản phẩm PDF hiện có: báo cáo 12 trang, slide 15 trang; cả hai vẫn có nội dung chờ bổ sung/xác minh.
- Đọc lại tài liệu chính thức về FCM, Crashlytics, BigQuery và quyền truy cập tệp để xác định các phụ thuộc của phần còn thiếu.

Không chạy lại build hoặc test vì không sửa mã ứng dụng trong lượt lập kế hoạch. Không đăng nhập Console, không truy vấn PR/GitHub online, không deploy, không tạo tài nguyên tính phí và không có kết quả chạy điện thoại mới. Vì vậy, “chưa thấy bằng chứng” dưới đây có nghĩa là chưa có trong dữ liệu đã kiểm tra, không khẳng định dữ liệu không tồn tại ở tài khoản của nhóm.

### Các mức trạng thái

| Ký hiệu | Ý nghĩa |
|---|---|
| Có mã | Đã có cấu trúc/logic trong source, chưa đồng nghĩa chạy dịch vụ thật |
| Đã kiểm tra local | Có log phân tích/unit/widget/build hoặc kiểm tra file APK |
| Chưa kiểm chứng thật | Cần kết quả từ điện thoại, Console hoặc hệ thống đang chạy |
| Thiếu triển khai | Chưa thấy module/cấu hình cần thiết trong working tree |
| Cần quyết định | Có nhiều phương án hợp lệ, phải chọn trước khi làm phần phụ thuộc |

Không đưa tỷ lệ “hoàn thành X%” vì đề không cung cấp trọng số chấm. Không lấy 53 test local làm 53 ca ARTEMIS hoặc bằng chứng sáu dịch vụ thật.

## 2. Điều đã có và không cần làm lại từ đầu

| Hạng mục | Bằng chứng hiện có | Phạm vi được xác nhận |
|---|---|---|
| Ứng dụng Flutter/MVVM + Provider | `lib/views/`, `lib/viewmodels/`, `lib/services/`, `AppServices` | Có phân tầng và dependency injection; không thấy View/ViewModel import Firebase SDK trực tiếp |
| Ba luồng Lab 2 | `docs/design-traceability.md`, `test/flows_test.dart`, `test/auth_and_guard_test.dart` | Có F01 onboarding, F02 ghi bữa, F03 bài viết đến kế hoạch; chưa so trực tiếp nguồn Lab 2 gốc và chưa nghiệm thu device |
| UI và trạng thái | Loading/data/empty/error, validate và retry; `test/layout_test.dart` | Có test 360/412/800 dp, vùng chạm và tương phản theo test hiện có |
| Sáu adapter Firebase | `lib/services/firebase/` | Có mã Auth, Storage, FCM, Analytics, Crashlytics, Remote Config |
| APK offline | `artifacts/android/longevity-plate-offline.apk` | Build release thành công, 69.604.902 byte, minSdk 24, ba ABI; chữ ký v2 hợp lệ |
| Hồ sơ local và PDF trên máy | `local_services.dart`, `MainActivity.kt`, `local_mobile_test.dart` | Có giữ phiên local và giao tiếp hộp chọn PDF Android; phần Android chưa được thao tác trên máy thật |
| Phân tích mã | `docs/build-evidence/flutter-analyze.txt` | Không có issues tại lần chạy đã lưu |
| Kiểm thử | `docs/build-evidence/flutter-test.txt` | 53/53 test pass; chủ yếu fake/unit/widget, có mock MethodChannel |
| Khắc phục mới | `session_view_model.dart:45-47`, `resilient_telemetry.dart` | Đã có xóa Crashlytics UID khi logout và wrapper Analytics chống lỗi lan sang nghiệp vụ; không liệt kê lại hai việc này là “chưa viết mã” |
| Tài liệu | architecture, traceability, Analytics, setup, test cases | Đã có nền tài liệu; cần cập nhật theo source mới và bổ sung kết quả thật |
| Báo cáo/slide | `../../output/pdf/` tính từ `docs/` | Đúng số trang nhưng là bản nháp, chưa đủ bằng chứng để nộp nguyên trạng |

SHA-256 APK: `2D7EB94128FF808B1AB1023D3E46311106C5644EABE647A5EB5F63B2124B813B`.

## 3. Nguồn yêu cầu và cách áp dụng lưu ý bổ sung

Nguồn chính G: `D:/PRM393/Lab3/PRM393_Lab3_Preparation_Guide_v5_ToiUu.pdf`, 25 trang. SHA-256: `9e019002d34c888e650f3e5991892cbce1a0ea5b3d741692fdc83aa1cfb6cb1e`.

Nguồn bổ sung U: lưu ý người dùng đã cung cấp trong chat, gồm:

1. Upload được thay bằng Cloudinary/AWS S3 hoặc dịch vụ tương đương.
2. Khi chấm phải chạy trên **thiết bị thật**.
3. Crashlytics demo bằng nút gây crash trong app, chờ Firebase cập nhật.
4. Dev xem Firebase Console, Admin dùng **web của nhóm** để xem kết quả. Web chỉ phục vụ Admin.
5. Ưu tiên giải thích công nghệ/nguyên lý, đặc biệt FCM token và phần server/client.
6. GitHub, báo cáo PDF 8-12 trang, slide PDF 12-15 trang, video 5-10 phút.

Áp dụng U tại các điểm khác G: dùng điện thoại thật khi nghiệm thu; một nhà cung cấp upload được phép thay Firebase Storage nhưng phải giữ tiêu chí tương đương về tệp, tiến độ, kết quả, quyền và lỗi. Web Admin/backend là phần bổ sung ngoài mô tả ban đầu của G. Flutter vẫn là nền tảng bắt buộc vì chưa được phép chuyển Expo/React Native.

**Ranh giới yêu cầu và phương án đề xuất:** G yêu cầu gửi FCM thử từ Console, không ghi bắt buộc nhóm phải có một màn Admin gửi tin riêng. U yêu cầu Admin xem kết quả trên web và giải thích được phần server/client. Kế hoạch đề xuất thêm server gửi FCM và màn gửi tin để có đường code thực tế phục vụ trình bày, nhưng đây là phạm vi cần chốt, không được tự quy thành tiêu chí bắt buộc nguyên văn của PDF. Web xem kết quả crash thật vẫn là yêu cầu rõ từ U; danh sách báo cáo trên web chỉ làm nếu nhóm chốt cần. Các endpoint, ngôn ngữ backend, database và BigQuery là phương án triển khai, không phải tên công nghệ mà đề bắt buộc.

## 4. Ma trận đối chiếu đủ 25 trang

| Trang G | Yêu cầu | Hiện trạng | Việc còn lại / đầu ra |
|---|---|---|---|
| 1 | Màn/3 luồng Lab 2, lỗi, 6 dịch vụ, kiến trúc và bằng chứng | Có mã và test local | Đối chiếu thiết kế gốc, demo thật, ảnh/log truy vết |
| 2 | Flutter stable, Android, Firebase/CLI, GitHub/Lab 2, ARTEMIS | Có Flutter stable và bộ Android đã build | Xác nhận điện thoại Android 13+ để thử quyền; cấu hình CLI/project, runtime ARTEMIS và nguồn Lab 2 |
| 3 | Tạo app Android Firebase, configure, initialize và thử kết nối | `main.dart` có initialize, `firebase_options.dart` vẫn placeholder | Tạo/chọn project riêng, cấu hình Android và build Firebase thật |
| 4 | MVVM + Provider/Riverpod, bốn trạng thái, fake, architecture | Có cấu trúc/Provider/fake/trạng thái | Cập nhật kiến trúc thêm local/Admin/backend và kiểm chứng ranh giới khi bổ sung |
| 5 | Google Sign-In, duy trì phiên, hủy/logout/guard | Có mã và test fake | Login thật, phiên sau mở lại, guard trên điện thoại |
| 6 | Google provider, SHA, authStateChanges, xóa trạng thái khi logout | Có listener và logout; trạng thái lưu theo UID còn giữ | Cấu hình provider/SHA; chốt chính sách local state và chứng minh tài khoản A/B tách biệt |
| 7 | Demo Auth thành công/lỗi, ảnh trước/sau, Console Users | Bảng FB để trống | Ảnh và kết quả AUTH-01...06 thật |
| 8 | Tạo/upload tệp, reports/{uid}, tiến độ, quyền chủ sở hữu | Có PDF + adapter Storage; APK hiện lưu local | Upload cloud thật theo G hoặc phương án U |
| 9 | Ít nhất một tệp, progress, URL, rules theo UID | Có rules/code, chưa có cấu hình cloud | Deploy chính sách, upload thật, ảnh progress/URL/object |
| 10 | Rules trong repo, offline/unauthorized, không public-all | Rules không public-all, probe dùng đường dẫn không có tệp | Test bằng tệp thật A/B và tài khoản chưa login; log policy denied |
| 11 | FCM ba trạng thái, Android 13+, lịch sử và chạm điều hướng | Có callback/permission/history | Gửi thật và kiểm chứng theo đúng payload/OS |
| 12 | Xin quyền, foreground/background/terminated, history và route | Có code, lịch sử local | Test điện thoại, sửa queue theo chủ tài khoản; backend gửi áp dụng theo phạm vi đã chốt |
| 13 | Gửi thử Console, 3 trạng thái, từ chối quyền, ghi device/token | Chưa có ảnh/token thật trong hồ sơ | Bắt buộc Console test; ghi riêng Admin send test nếu chọn custom sender |
| 14 | Analytics >=7 event, không PII | Có plan 17 event và test bảo vệ dữ liệu | DebugView thật, kiểm tra tham số, danh tính và lỗi |
| 15 | Plan trước tracking, tên chuẩn, user ID | Có plan nhưng commit docs sau code | Ghi nhận lệch trình tự trung thực; cập nhật plan trước tracking mới, không sửa lịch sử giả |
| 16 | Trigger/type/question/flow/criteria, ảnh từng event | Plan có phần lớn thông tin | Ảnh từng event trong plan; xác nhận đơn vị đo và kết quả quan sát |
| 17 | Non-fatal, crash thử, UID và key | Có adapter/nút | Console fatal/non-fatal và Admin web thật |
| 18 | Error handlers, lỗi nghiệp vụ, UID/key, nút demo | Có handler, catch nghiệp vụ, key route | Chạy lỗi nghiệp vụ thật/simulatable qua nhánh xử lý thật; thử crash trên device |
| 19 | Hai loại lỗi trên Console, UID/key, UI báo lỗi, crash chỉ khu demo | Có vùng demo; bản offline ẩn crash thật | Ảnh, log thời gian, mở lại app; bảo đảm không crash trong luồng thường |
| 20 | >=2 RC param tạo thay đổi quan sát được | Có hai key và UI binding | Publish thật và chụp cả hai hiệu ứng |
| 21 | Default, service fetch/activate, UI thay đổi không build | Có service và listener | Demo trên cùng APK, đối chiếu default/cache/activated |
| 22 | Ảnh before/after/Console, offline/default/cache, giải thích fetch | Chưa có bằng chứng thật | Thử đủ hai key, offline và release fetch interval một giờ |
| 23 | ARTEMIS >=10 ca, mỗi ca >=3 lần, lỗi/native, log/rate, khám phá 15-30 phút | Có 12 kịch bản, ô kết quả trống | Xác định đúng ARTEMIS môn học, chạy 36 lượt nếu giữ 12 ca và ghi phiên khám phá |
| 24 | AI review PR >=5 finding/2 nhóm, quyết định/lý do, sửa >=3 có commit | Chưa thấy hồ sơ review; thay đổi mobile mới chưa commit | PR thật, finding có dòng/commit, quyết định và commit sửa/retest |
| 25 | Đủ dịch vụ và lỗi, tài liệu, log/ảnh/review, GitHub và 3 sản phẩm | Có source, log local và PDF nháp đúng trang | Hoàn thiện toàn bộ evidence, cập nhật PDF và quay video; xác nhận link nộp |

## 5. Những khoảng trống đang cản trở nghiệm thu

| ID | Mức | Khoảng trống | Căn cứ hiện tại |
|---|---|---|---|
| B01 | P0 | Firebase chưa cấu hình trong app | `lib/firebase_options.dart:5` ném UnsupportedError; chưa thấy google-services.json; app Gradle chưa áp dụng Google Services/Crashlytics plugin |
| B02 | P0 | Chỉ có APK offline, chưa có APK Firebase được nghiệm thu | Build dùng `USE_LOCAL_SERVICES=true`; factory local dùng fake Messaging/Analytics/Crash/RC |
| B03 | P0 | Chưa có xác nhận chạy điện thoại thật | Hồ sơ validation ghi không có device; chưa có kết quả cài/chạy mới |
| B04 | P0 | Web Admin chưa triển khai | `web/index.html` là Flutter bootstrap; chưa có entry/module quản trị |
| B05 | P1 / cần chốt | Chưa có server gửi FCM/registry theo phương án đề xuất; quyền và nguồn dữ liệu Admin phải được hoàn thiện | Không có mã server/token registry/verify-role/API gửi FCM. G chỉ bắt buộc Console test; phạm vi custom sender cần xác nhận theo U |
| B06 | P0 | Chưa có nguồn dữ liệu crash thật cho Admin web | Chưa có export/query/ingest pipeline hoặc API xem lỗi |
| B07 | P1 | Upload cloud và chính sách truy cập chưa nghiệm thu | APK lưu PDF local; adapter/rules cloud chưa chạy thật |
| B08 | P1 | Chưa có hồ sơ thành công/lỗi cho từng dịch vụ | FB-01...16 để trống, không có bộ ảnh Console tương ứng |
| B09 | P1 | ARTEMIS chưa chạy | 12 kịch bản có sẵn nhưng thiếu runner/config/log/rate/actual |
| B10 | P1 | Chưa có phiên khám phá 15-30 phút | Có bảng mẫu trống |
| B11 | P1 | Chưa có hồ sơ AI review đáp ứng rubric | Chưa thấy >=5 finding/2 nhóm/quyết định/>=3 sửa có commit |
| B12 | P1 | Thay đổi mới chưa được ghi commit/push xác minh | `git status` còn modified/deleted/untracked; HEAD vẫn 3abfa0e |
| B13 | P1 | Báo cáo/slide chưa cập nhật theo source và bằng chứng | Đúng 12/15 trang nhưng còn marker chờ, tên nhóm/device và một số mô tả trước lần sửa mã mới |
| B14 | P1 | Chưa thấy video 5-10 phút | Không tìm thấy file/link video trong bộ nộp đã đọc |
| B15 | P1 | Nguồn thiết kế Lab 2 chưa truy cập trực tiếp | Traceability trỏ repo khác nhưng thiếu liên kết/version và handoff gốc trong folder này |
| B16 | P1 | Cần sửa/xác minh các điểm kỹ thuật còn lại | Queue thông báo A/B, refresh token/registration, probe quyền thật, lỗi telemetry thứ cấp, chính sách logout |

P0: phải giải quyết trước khi tuyên bố bản chấm hoạt động. P1: phải khép lại trước khi nộp. P2 trong kế hoạch là cải thiện trình bày/bảo trì sau khi các điều kiện bắt buộc đã đạt.

## 6. Quyết định đầu vào cần chốt sớm

| Quyết định | Khuyến nghị theo hiện trạng | Hệ quả |
|---|---|---|
| Firebase project | Dùng project riêng mà người dùng muốn tạo; ghi Project ID và người quản lý | Không tự dùng cấu hình project bạn cùng nhóm. Chưa có Project ID mới trong source |
| Upload | Giữ Firebase Storage nếu nhóm chấp nhận yêu cầu billing và muốn tận dụng adapter đã có; nếu không, chọn đúng một phương án S3/Cloudinary | Không triển khai ba nhà cung cấp cùng lúc. Việc lưu PDF local không thay được upload cloud |
| Crash cho Admin web | Ưu tiên pipeline Crashlytics -> BigQuery -> backend -> Admin web nếu phù hợp tài khoản/billing | Batch có độ trễ; demo crash mới trên web trong buổi chấm cần đường dữ liệu cập nhật phù hợp |
| Web Admin | Đề xuất Flutter web entry riêng để tận dụng Dart/Provider; backend tách biệt. Tối thiểu xem crash thật; chốt riêng màn gửi tin/danh sách báo cáo | Không dùng nguyên mobile AppServices.firebase cho web vì có adapter native-only; không tự mở rộng mọi chức năng quản trị |
| Device | Một Android thật có Google Play Services; ưu tiên Android 13+ để demo quyền thông báo | Một thiết bị đáp ứng đồng thời device thật và native permission test; ghi model/OS |
| ARTEMIS | Dùng đúng repo/phiên bản/CLI mà môn học chỉ định | PDF không nêu link cài. Cần lấy nguồn từ lớp/giảng viên; không tự gọi widget test là ARTEMIS |
| Logout/local data | Viết chính sách phân biệt state phiên, cache cá nhân và dữ liệu nghiệp vụ lưu theo UID | Cần đáp ứng trang 6, không để A/B thấy dữ liệu nhau; nếu rubric yêu cầu xóa cả khóa UID thì phải bổ sung thao tác xóa phù hợp |

Lưu ý vận hành đã kiểm tra từ nguồn chính thức:

- Cloud Storage for Firebase hiện yêu cầu Blaze. Đây là phụ thuộc lựa chọn triển khai, không phải lý do bỏ kiểm chứng upload. [S1]
- Crashlytics export mặc định là batch hằng ngày. Streaming có điều kiện/gói riêng và có thể mất đến một giờ để bắt đầu sau khi bật. Chuẩn bị trước buổi chấm, không chờ đến lúc demo mới cấu hình. [S2]
- FCM SDK hiện có luồng FID mới và đánh dấu registration-token APIs deprecated. Repo đang dùng getToken(). Cần chốt cặp client/server tương thích và chứng minh hoạt động, không trộn FID vào trường token của luồng cũ. [S3]

## 7. Lộ trình thực hiện theo mốc

| Mốc | Công việc chính | Phụ thuộc | Điều kiện qua mốc |
|---|---|---|---|
| M0 | Chốt source, thiết bị, project, upload, ARTEMIS và nguồn Lab 2 | Không | Có input/version/owner, chính sách dữ liệu và lựa chọn dịch vụ |
| M1 | Cài thử offline, cấu hình Firebase, build/install bản thật | M0 | App mở trên điện thoại, xác thực Google thật và đúng project |
| M2 | Khép upload, Analytics, Crashlytics, RC và sửa lỗi phía mobile | M1 | Sáu dịch vụ có nhánh thành công/lỗi, Console có dữ liệu |
| M3 | Backend/quyền Admin và registry/gửi FCM nếu chốt custom sender | M1 | API Admin có role checks; nếu có custom sender thì đăng ký đích và gửi được |
| M4 | Web Admin và pipeline crash | M2 (Crashlytics) + M3 + lựa chọn pipeline M0 | Admin xem kết quả crash thật; gửi tin/xem báo cáo chỉ nghiệm thu nếu nằm trong phạm vi đã chốt |
| M5 | Chạy bộ nghiệm thu device, ARTEMIS và khám phá | M2-M4 | Log/rate/evidence đầy đủ, lỗi nghiêm trọng được sửa và retest |
| M6 | AI review PR và hồ sơ quyết định | PR có phạm vi rõ; có thể bắt đầu trước M5 | >=5 finding/2 nhóm, >=3 sửa có commit, quyết định có lý do |
| M7 | Chốt build cuối, cập nhật report/slide, quay video và nộp | M5-M6 | Cùng source/build, số trang/thời lượng đúng, link truy cập được |

Người phụ trách trong bảng dưới là **vai trò đề xuất cho thành viên nhóm**, chưa phải phân công người thật: Mobile, Backend, Admin UI, QA, Tài liệu. Một người có thể làm nhiều vai trò. Các việc có cùng đầu vào có thể chia cho các thành viên, nhưng phải dùng cùng Project ID, API contract và commit chốt.

## 8. Backlog triển khai chi tiết

### M0: đóng phiên bản và chuẩn bị đầu vào

| Task | Thao tác cụ thể | Đầu ra/điều kiện hoàn tất | Vai trò |
|---|---|---|---|
| T01 | Xem `git status`, diff và untracked; giữ source/local changes, loại cache/artifact khỏi commit | Có danh sách thay đổi mobile, không commit .gradle-local/build/keystore | Mobile |
| T02 | Commit bản offline đang chạy và log validation với thông điệp đúng phạm vi | Source mới có commit truy vết. Không gắn nhãn “Firebase hoàn tất” | Mobile |
| T03 | Lấy Figma URL, DESIGN.md, flutter-handoff.md/nguồn tương đương và version Lab 2 | `docs/design-traceability.md` có nguồn thực, ảnh expected/actual và giải thích khác biệt | Mobile/Tài liệu |
| T04 | Chuẩn bị điện thoại, Google Play Services, USB debugging, ADB RSA và tài khoản test A/B | `docs/device-profile.md`: model, Android/API, ABI, app/package, cách reset, tài khoản alias | QA |
| T05 | Chốt project riêng, nhà cung cấp upload và đường dữ liệu crash Admin | `docs/implementation-decisions.md` ghi lựa chọn và lý do; đánh dấu dịch vụ cần billing | Nhóm |
| T06 | Xác định ARTEMIS môn học; kiểm tra Python 3.12+, uv, ADB và khóa mô hình | Có nguồn/commit ARTEMIS, version lệnh và runbook. Không coi chỉ có uv là đã đủ | QA |

### M1: điện thoại thật và Firebase project mới

**T07 - Cài APK offline để xác minh nền thiết bị.** Cài file đã build, ghi version/hash, đi F01/F02/F03, đóng/mở lại kiểm tra bữa/kế hoạch, thử lưu/hủy/mở PDF bằng hộp thoại Android. Ghi ảnh và lỗi. Đây là smoke test nền tảng, chưa tính là nghiệm thu sáu dịch vụ.

Kiểm tra lại `flutter doctor -v` trước khi triển khai. Lần kiểm tra môi trường trong quá trình build từng báo thiếu Android cmdline-tools/không xác định trạng thái license; việc APK build qua không tự chứng minh mọi công cụ của ARTEMIS đã sẵn sàng. ADB đã có trong Android SDK trên máy nhưng có thể chưa nằm trong PATH. Cài/bổ sung công cụ nếu kết quả kiểm tra mới còn báo thiếu, không cần cài lại toàn bộ SDK đã dùng build thành công.

**T08 - Tạo/chọn project Firebase riêng.** Ghi Project ID, Android app ID và người có quyền cấu hình. Đăng ký package `com.longevityplate.longevity_plate`. Bật Analytics. Tạo tài khoản Google test A/B riêng. Chỉ có tên project chưa đủ, phải xác minh Android app trỏ đúng project.

**T09 - Chuẩn bị CLI và client config.** Kiểm tra Firebase CLI và FlutterFire CLI trong môi trường dev; lần kiểm tra PATH hiện chưa tìm thấy hai lệnh này. Chạy configure với Project ID rõ ràng để thay `lib/firebase_options.dart`, tạo `android/app/google-services.json`; thêm web config khi làm T27. Không sao chép cấu hình project cũ nhầm sang project mới.

```powershell
flutterfire configure --project=<PROJECT_ID> --platforms=android --android-package-name=com.longevityplate.longevity_plate
```

**T10 - Hoàn thiện Gradle Firebase.** Trong `android/settings.gradle.kts` khai báo Google Services và Crashlytics plugin ở phiên bản phù hợp AGP đang dùng; trong `android/app/build.gradle` (Groovy) áp dụng hai plugin. Giữ các phần package, Java 17, cờ offline, giới hạn RAM và cache build đã sửa. Kiểm tra resource Google/OAuth sinh ra và mapping/report upload của Crashlytics nếu bật native minification. Không thay bằng file cấu hình giả để build qua.

**T11 - Google provider và SHA.** Bật Google Sign-In, thêm SHA-1/SHA-256 của đúng khóa ký bản cài, cập nhật config và kiểm tra web OAuth client mà Google Sign-In sử dụng. Public fingerprint có sẵn ở `docs/build-evidence/apk-signature.txt`, nhưng phải đối chiếu khóa khi đổi máy/khóa ký. Không nhầm SHA file APK với SHA chứng thư ký.

**T12 - Build và cài bản Firebase.** Chạy analyze/test sau thay đổi, build không có hai cờ fake/local. Có thể dùng `scripts/build-android.ps1 -Firebase` sau khi config thật đã sinh. Lần này cần dự trù thời gian cho R8/cấu hình Crashlytics trên máy ít RAM; có thể chốt profile lab không obfuscate nếu cần và ghi đúng cấu hình. Kết quả phải là `longevity-plate-firebase.apk` với hash/version riêng, không dùng bản offline thay tên.

Điều kiện qua M1: điện thoại mở app; Google Sign-In thật tạo user trên đúng Console; đăng xuất/guard làm việc; mở app không phải vào nút fallback offline. Ghi ít nhất một log bootstrap và ảnh project/app tương ứng.

### M2-A: hoàn thiện Auth và chính sách local state

**T13 - Chạy Auth thật và khép logout.** Kiểm tra đăng nhập thành công/hủy/mất mạng, khôi phục phiên sau restart, logout/Back và A/B. Xác định các ViewModel/timer/subscription/state cá nhân phải được hủy. UID Analytics và Crashlytics đã có mã xóa; kiểm tra SDK thật và không ghi lại là phần chưa triển khai.

**T14 - Chốt dữ liệu khi logout.** Đề trang 6 yêu cầu xóa trạng thái cục bộ gắn người dùng, trong khi repo giữ bản lưu theo UID. Ghi rõ phạm vi state/cache/dữ liệu nghiệp vụ. Nếu cần xóa cả persisted UID keys để bám cách chấm, thêm phương thức xóa có chủ đích và thông báo tác động trước khi dùng; cập nhật test đang mong đợi login lại còn dữ liệu. Không tự coi việc đổi route là đã đáp ứng mọi cách hiểu của yêu cầu này.

**T15 - Bảo vệ lỗi thứ cấp.** Xác minh lỗi `CrashService.recordError/setUserId/setKey` không biến một lỗi đã xử lý thành unhandled exception hoặc làm UI kẹt. Analytics đã có wrapper best-effort, cần giữ behavior đó. Thêm fake ném lỗi tại dịch vụ ghi nhận sự cố và kiểm tra trạng thái lỗi/retry của thao tác gốc vẫn đúng.

Đầu ra: kết quả AUTH-01...06, chính sách logout trong architecture, test hồi quy và commit các sửa phát sinh.

### M2-B: upload cloud đúng quyền sở hữu

**T16 - Chọn một adapter thật và triển khai.**

| Phương án | Công việc cần có | Bằng chứng tương đương |
|---|---|---|
| Firebase Storage | Bật bucket đúng project, đáp ứng billing, deploy `firebase/storage.rules`; giữ `FirebaseReportStorageService` | Progress, URL, object tại reports/UID, Rules Console, denied A/B và offline |
| S3 | Backend xác minh Firebase ID token, tự tính key theo UID; cấp presigned upload/download giới hạn thời gian; bucket private; validate metadata và kiểm soát hoàn tất upload | Policy/backend checks, object, signed URL, unauthorized và URL hết hạn; không đưa AWS secret vào client [S6] |
| Cloudinary | Backend ký upload phù hợp PDF/raw và kiểm tra UID; thiết lập chính sách đọc tệp hạn chế cùng cơ chế cấp URL hợp lệ | Asset, cấu hình access control, upload progress, denied A/B và offline. Signed upload một mình không chứng minh file private [S7] |

Đường dẫn code chung giữ `ReportStorageService` để ViewModel không phụ thuộc provider. Nếu đổi provider, đổi mô tả UI/README/report tương ứng, không để UI ghi Cloud Storage trong khi dùng S3.

**T17 - Xác minh tệp và quy tắc.** Kiểm tra PDF tiếng Việt mở được trên điện thoại; chỉ gồm bảy ngày theo logic hiện có. Thử upload thành công, tệp sai MIME/quá ngưỡng, mất mạng/retry và không login. Dùng file thật do A tạo rồi B đọc/ghi bằng SDK/API. Probe hiện dùng `reports/uid-khac-de-kiem-thu/khong-co.pdf` chỉ nên là kiểm tra phụ, không thay kết quả cross-user trên object thật.

Rules hiện chỉ cho owner **read/create**, không update/delete. Nếu chủ đích là báo cáo bất biến, ghi rõ; nếu nghiệp vụ cần sửa/xóa thì bổ sung quyền owner tương ứng và test. Không mở public-all. Firebase download URL chứa token mang khả năng chia sẻ quyền đọc, nên phép thử rules phải qua SDK/đường có kiểm tra auth, không dùng mở URL có token để suy ra quyền UID.

**T18 - Metadata cho Admin.** Nếu web cần xem danh sách báo cáo, hiện chưa có kho metadata phía server. Bổ sung record ID, owner UID, provider/key, createdAt, MIME, size, status; server xác minh object trước khi đánh dấu complete. Chỉ cho Admin được phép cấp link theo chính sách đã chốt. Không tin owner UID từ body client.

Đầu ra: adapter thật duy nhất, cấu hình quyền trong repo, kết quả UP-01...07, mẫu PDF tải từ cloud và ảnh progress/object/policy.

### M2-C: Analytics và Remote Config

**T19 - Hoàn thiện kế hoạch Analytics trước phần tracking mới.** Giữ 17 event hiện có hoặc sửa kế hoạch theo phạm vi sản phẩm có lý do, vẫn >=7 event. Không xóa các event khó kích hoạt chỉ để né bằng chứng. Mỗi event có trigger, kiểu tham số, câu hỏi sản phẩm, flow/criterion và cách kiểm chứng. Bổ sung liên kết ảnh DebugView theo từng hàng.

**T20 - Kiểm chứng Analytics SDK thật.** Bật DebugView, thực hiện cả event thành công và lỗi. Kiểm tra UID sau login/logout, tên snake_case và không có email/tên/nội dung bữa/từ khóa. Bổ sung ca offline: app vẫn thao tác được, ghi thời điểm offline/online và kiểm tra sự kiện khi kết nối lại. Tách test wrapper bị ném lỗi khỏi bằng chứng Firebase thật.

**T21 - Chạy Remote Config cả hai key.** Publish `max_knowledge_results` từ 3 sang 1 để S08 đổi số bài; publish `suggested_recipes_enabled` từ true sang false để S06 ẩn gợi ý. Ghi cùng version/hash APK trước và sau, ảnh Console và UI. Không dùng switch của bản offline làm bằng chứng này.

**T22 - Kiểm tra default/cache/release interval.** Thử offline khi có cache, lỗi fetch và tình huống chưa có giá trị remote. Mã release đang dùng minimumFetchInterval một giờ, debug là 0; nút refresh không tự bảo đảm bỏ qua cache. Giải thích realtime update/activate và status. Chốt cách tái lập default trên device mà vẫn giữ được phiên Auth, ví dụ profile test kiểm soát lần fetch đầu trước khi tắt mạng; tránh xóa toàn bộ dữ liệu làm mất phiên rồi không vào được màn cần quan sát.

Đầu ra: bảng event -> ảnh/log, kết quả AN/RC, ảnh hai thay đổi UI, runbook offline/default/cache và cập nhật architecture.

### M3: FCM client, backend và quản lý đích nhận

T23 và kiểm chứng FCM thật là cần thiết. T24/T25 và phần registry trong T26 áp dụng khi chọn tự triển khai server gửi tin. Nếu phạm vi chấm chỉ dùng Console để gửi, giữ đầy đủ MSG-01...05/07 và giải thích vai trò dịch vụ gửi phía Firebase; không buộc xây thêm custom sender chỉ vì kế hoạch đã liệt kê phương án này. Phần sửa cách ly lịch sử/lỗi client vẫn cần xem xét dù chọn cách gửi nào.

**T23 - Chốt định danh/phiên bản FCM.** Repo đang đọc getToken() và chỉ sao chép token ở S11. Làm một kiểm chứng nhỏ trên device để chốt registration token hoặc FID cùng API server tương thích theo tài liệu SDK hiện tại. Nếu giữ API token cho lab, ghi rõ deprecated và đường nâng cấp; nếu dùng FID thì cập nhật đồng bộ client/interface/storage/server/demo. Không giả định hai định danh thay thế trực tiếp cho nhau. [S3,S4]

**T24 - Bổ sung registry đích nhận.** Client gửi đích nhận lên endpoint có Firebase ID token. Server tự lấy UID sau verify, lưu device/install ID, loại định danh, thời gian cập nhật, trạng thái permission và active. Theo dõi thay đổi định danh, xử lý stale/invalid target, cho phép nhiều thiết bị một user và tháo liên kết khi logout. Không dùng FCM token như token xác thực Admin.

**T25 - Bổ sung server gửi FCM.** Tạo backend Node.js/TypeScript hoặc môi trường server tương đương, dùng Firebase Admin SDK/HTTP v1 từ môi trường có đặc quyền. Kiểm tra admin role, validate độ dài/nội dung/route, lấy target từ registry, gửi notification + data.route và lưu request ID/kết quả/error. Giữ credentials phía server. API send trả thành công chỉ chứng minh dịch vụ chấp nhận gửi; kết quả nhận/mở phải kiểm tra ở client. [S4]

**T26 - Sửa cách ly thông báo và lỗi bất đồng bộ.**

- `NotificationRepository` hiện có queue `notifications.pending` cấp thiết bị, rồi chuyển hết sang UID đang load. Đây là nguy cơ A/B theo mã, chưa có ca tái hiện được lưu.
- Bổ sung envelope chứa chủ nhận/loại public-personal, ID ổn định và route đã kiểm tra. Tin cá nhân phải gắn đúng người nhận do server xác định; người khác login không được nhận lịch sử đó.
- Thử A đang đăng nhập -> logout -> tin nền đến -> B login; A/B đổi trong lúc save/load; pending notification khi login; cùng message đến nhiều callback; route lạ; lỗi ghi lịch sử.
- Các listener `_onForeground/_onOpened` còn có await ghi dữ liệu; bảo vệ lỗi để không thành exception không xử lý, kiểm tra UID và lifecycle sau await trước khi hiện SnackBar/điều hướng.
- Điều hướng đợi router và onboarding sẵn sàng; không gọi là đạt chỉ vì một hàm resolver trả route đúng.

Đầu ra: client đăng ký/cập nhật đích, server gửi, lịch sử đúng UID, không trùng và kết quả MSG-01...09. Gửi thử Console theo G và gửi từ Admin web theo U đều phải có bằng chứng.

### M4: web Admin và nguồn crash thật

T27-T30 và phần quyền xem crash là phạm vi rõ theo U. Form gửi tin trong T28 và danh sách báo cáo T31 là phần mở rộng theo quyết định M0; có thể bỏ nếu không thuộc yêu cầu được chốt. Ghi điều chỉnh vào scope, không ghi PASS cho một chức năng không triển khai.

**T27 - Tạo entry quản trị độc lập.** Đề xuất `lib/admin_main.dart` và `lib/admin/` cho web quản trị, dùng Auth web và API client phù hợp nền tảng. Sinh Firebase web config, cấu hình authorized domain. Không bootstrap AppServices.mobile Firebase nguyên trạng vì có Crashlytics/Messaging native và màn người dùng.

**T28 - Đăng nhập, role và màn gửi tin.** Bổ sung login Admin, phiên, logout và các trạng thái loading/empty/error. Route guard trên web phục vụ UX; backend kiểm tra role trên từng endpoint mới là ranh giới quyền. Người dùng thường, người chưa login và token hết hạn phải bị chặn. Form gửi tin chọn user/device hợp lệ, nội dung và route allowlist, báo request/result rõ ràng.

**T29 - Pipeline Crashlytics cho Admin.** Phương án chính: Android Crashlytics -> export BigQuery -> backend query/aggregate -> Admin web. Backend trả issue/event ID nếu nguồn có, fatal/non-fatal, timestamp, version/build và ngữ cảnh được phép xem. UI hiển thị nguồn và lần cập nhật cuối. Không thay crash thật bằng log “sắp gây crash” hoặc dữ liệu viết tay trước khi app đóng.

Nếu cần xem crash vừa bấm trong cùng buổi chấm, cấu hình và chạy thử đường cập nhật từ trước. Batch mặc định hằng ngày không đủ để hứa xem ngay; streaming có yêu cầu gói và thời gian khởi tạo. Nếu chọn cơ chế alert/event khác, phải chứng minh loại sự kiện được hỗ trợ, phân biệt issue mới với từng occurrence và đáp ứng đúng phạm vi hiển thị; không suy ra số lần crash từ số alert. [S2]

**T30 - Nút crash và non-fatal thật.** Giữ nút tại S11 có xác nhận, đi qua AccountViewModel -> CrashService -> SDK crash(). Đăng nhập user test, ghi route/version, bấm trên điện thoại thật, mở lại app có mạng, chờ Console, rồi chờ pipeline cập nhật Admin web. Thêm non-fatal từ nhánh lỗi lưu bữa/report; UI vẫn thông báo và retry được. Chụp UID/key trên Console. Nếu chưa thấy Console sau khoảng năm phút, dùng Crashlytics debug logging để chẩn đoán, không coi năm phút là SLA. [S5]

**T31 - Danh sách báo cáo và trạng thái hệ thống.** Nếu đã chọn đưa báo cáo lên web, dùng metadata T18 và API cấp link có kiểm tra quyền. Trang lỗi/crash có lọc thời gian/version, empty/loading/error và retry. Khi nguồn chưa cập nhật, hiển thị pending/updatedAt, không hiện số 0 gây hiểu nhầm thành không có lỗi. Không cần làm web người dùng, CMS, thanh toán hay CRUD ngoài phạm vi.

**T32 - Kết nối/deploy có thể dùng trong buổi chấm.** Chốt API base URL, HTTPS, CORS, role provisioning, query limits và nơi lưu cấu hình server. Điện thoại phải truy cập được endpoint đăng ký đích nhận; `localhost` của điện thoại không phải máy tính dev. Tài liệu phải chỉ rõ cách khởi động/đăng nhập Admin và các tài khoản alias được chấm. Không tạo billing/deploy ngoài lựa chọn đã chốt chỉ để hoàn tất checklist.

### Hợp đồng API và thư mục mới đề xuất

Các endpoint/tệp dưới đây **chưa tồn tại**, là đầu ra triển khai của M3-M4.

| API | Quyền | Hành vi cần có |
|---|---|---|
| `PUT /me/devices/{installationId}` | User đã xác thực | Upsert target của chính UID từ token, validate loại định danh và permission |
| `DELETE /me/devices/{installationId}` | User sở hữu binding | Vô hiệu hóa liên kết khi logout/đổi tài khoản |
| `POST /admin/messages` | Admin | Validate request, chọn target từ server, gửi FCM, lưu kết quả/request ID |
| `GET /admin/messages` | Admin | Xem kết quả gửi, phân biệt accepted/sent với received/opened |
| `GET /admin/crashes` | Admin | Truy vấn nguồn crash thật, filter/pagination và sourceUpdatedAt |
| `GET /admin/crashes/{id}` | Admin | Chi tiết theo schema nguồn và quyền được phép |
| `GET /admin/reports` | Admin theo chính sách | Metadata báo cáo T18 |
| `POST /reports/{id}/download-link` | Owner hoặc Admin được phép | Cấp quyền đọc có thời hạn/đúng provider |

Nếu chọn S3/Cloudinary: bổ sung upload-intent/complete API xác minh owner, MIME/size/object. Trường UID trong body không được quyết định quyền sở hữu.

```text
lib/admin_main.dart
lib/admin/admin_app.dart
lib/admin/views/{login,messages,crashes,reports}_screen.dart
lib/admin/viewmodels/
lib/admin/services/admin_api_client.dart
lib/services/device_registration_service.dart
server/src/auth/{verify_identity,require_admin}.ts
server/src/routes/{devices,messages,crashes,reports}.ts
server/src/services/{messaging,crash_query,report_metadata}.ts
server/test/
docs/admin-web.md
docs/api-contract.md
docs/crash-data-pipeline.md
```

Kho lưu binding/metadata là phụ thuộc server mới. Có thể dùng database phù hợp, ví dụ Firestore nếu nhóm chọn, nhưng G không bắt buộc phải bổ sung Firestore cho nhật ký bữa ăn. Không tự mở rộng sang đồng bộ toàn bộ dữ liệu mobile giữa thiết bị.

## 9. Bộ nghiệm thu điện thoại và dịch vụ thật

Tất cả hàng dưới là **ca đề xuất/chưa có kết quả thật**. Các ca custom sender, registry, signed URL hay danh sách báo cáo chỉ áp dụng khi chọn phương án tương ứng; đánh dấu N/A có lý do khi ngoài phạm vi, không ghi PASS. Mỗi ca áp dụng phải ghi điều kiện đầu, bước, expected, actual, trạng thái, thời gian, device, commit/hash và evidence path. Đây là ca nghiệm thu thủ công/integration, không tự động tính vào số lượt ARTEMIS.

| ID | Tình huống và thao tác | Kết quả bắt buộc |
|---|---|---|
| DEV-01 | Cài APK Firebase đúng hash trên Android thật | Mở được app, đúng project/mode/version |
| DEV-02 | Chạy F01, F02, F03 | Đúng màn, ngày, bữa/slot và dữ liệu sau thao tác |
| DEV-03 | Đóng/mở lại app, xoay màn, Back hệ thống, thử bàn phím | Không mất trạng thái ngoài thiết kế hoặc tràn UI; ghi các sai khác |
| AUTH-01 | Google login thành công | UID thật, màn đích đúng và user trên Console |
| AUTH-02 | Hủy hộp Google | Ở màn login, thông báo rõ, không coi hủy là crash |
| AUTH-03 | Mất mạng khi login | Báo lỗi phù hợp và retry được |
| AUTH-04 | Restart sau login | Khôi phục phiên đúng, không vào tài khoản khác |
| AUTH-05 | Logout rồi Back/deep link | Không truy cập màn bảo vệ; xóa các state/identity theo chính sách |
| AUTH-06 | A logout, B login rồi A quay lại | Không lẫn dữ liệu, notification hay danh tính đo lường |
| UP-01 | Tạo và upload PDF từ dữ liệu thật | Progress, kết quả, URL và object thật |
| UP-02 | Tải PDF từ cloud trên máy | Mở được, tiếng Việt đúng, đủ phạm vi bảy ngày |
| UP-03 | Mất mạng giữa upload, nối lại/retry | Báo lỗi có thời hạn phù hợp, không kẹt spinner, không nhân bản sai |
| UP-04 | B đọc/ghi file thật của A | Bị từ chối bởi rules/server policy |
| UP-05 | Chưa login truy cập file qua API/SDK | Bị từ chối |
| UP-06 | Sai MIME/vượt size theo policy | Bị từ chối và báo lỗi rõ |
| UP-07 | Với signed URL: hết hạn hoặc key không được cấp | Bị từ chối đúng phạm vi, không cấp URL tùy ý |
| MSG-01 | Console gửi khi foreground | Nhận, hiện UI, lưu đúng một tin |
| MSG-02 | App background, gửi rồi chạm | Vào đúng màn và lịch sử đúng |
| MSG-03 | App terminated thông thường, chạm mở | Router/onboarding/phiên xử lý đúng, không trùng tin |
| MSG-04 | Android 13+ từ chối quyền rồi mở lại màn | UI phản ánh đúng, app vẫn dùng được |
| MSG-05 | Route lạ hoặc item không có | Fallback an toàn, không mở route/URL tùy ý |
| MSG-06 | Định danh thay đổi hoặc target stale | Server cập nhật/vô hiệu hóa đúng, thông báo lỗi gửi phù hợp |
| MSG-07 | A/B và queue nền | Tin cá nhân không sang người khác |
| MSG-08 | Mạng lỗi khi đăng ký/gửi hoặc backend timeout | Retry có kiểm soát và UI không báo đã nhận khi chỉ mới accepted |
| MSG-09 | Admin web gửi đến thiết bị | Có request log, tin đến điện thoại, chạm mở đúng màn |
| AN-01 | Kích hoạt từng event trong kế hoạch | DebugView có tên/kiểu/giá trị đúng, ảnh cho từng event |
| AN-02 | Login/logout | User ID gắn/xóa đúng; không PII trong params |
| AN-03 | Offline rồi online, thực hiện event | Nghiệp vụ vẫn hoạt động; ghi nhận kết quả quan sát khi nối lại |
| AN-04 | Fake Analytics ném lỗi | Unit test xác nhận không làm sai kết quả nghiệp vụ; không thay ảnh AN-01 |
| CR-01 | Lỗi lưu bữa/report đi qua catch | UI báo lỗi/retry, Console có non-fatal từ nhánh đó |
| CR-02 | Bấm nút crash trên device, mở lại | App crash thật, Console có fatal đúng version/device |
| CR-03 | Xem chi tiết crash | UID và key route đúng, không UID cũ sau logout |
| CR-04 | Offline lúc ghi, online/mở lại | App xử lý đúng, ghi thời gian báo cáo được gửi/nhận, không hứa xuất hiện ngay |
| CR-05 | Admin web xem cùng lỗi đã kiểm tra | Nguồn thật, cùng định danh/version/time có thể đối chiếu và updatedAt |
| RC-01 | Đổi max results 3 -> 1 | UI thư viện thay đổi, cùng APK/hash |
| RC-02 | Đổi suggested recipes true -> false | Mục món gợi ý ẩn, cùng APK/hash |
| RC-03 | Offline sau khi có activated cache | App dùng giá trị đã kích hoạt gần nhất |
| RC-04 | Chưa có remote/cache, fetch thất bại | Default dùng được theo runbook tái lập |
| RC-05 | Remote value không hợp lệ, ví dụ max <=0 | Không gây UI rỗng ngoài ý muốn; fallback theo chính sách |
| RC-06 | Refresh bản release trong fetch interval | Giải thích và quan sát cache/realtime đúng, không coi nút refresh là force fetch |
| ADM-01 | Admin login/logout | Phiên/route đúng, backend xác minh role |
| ADM-02 | User thường gọi API trực tiếp | 403 theo contract, không chỉ bị ẩn nút |
| ADM-03 | Chưa login/token hết hạn | 401 hoặc refresh hợp lệ, không lộ dữ liệu |
| ADM-04 | Không có crash/report | Empty state đúng, có nguồn và mốc cập nhật |
| ADM-05 | API/BQ/storage lỗi | Error state và retry, không giả số liệu thành 0 |
| ADM-06 | Request sai route/target/owner hoặc payload lớn | Validate/reject và audit log phù hợp |
| ADM-07 | Kiểm tra báo cáo, link hết hạn, tài khoản không có quyền | Không cấp dữ liệu ngoài chính sách đã chốt |

Với FCM trên Android, force-stop trong Settings không phải phép thử terminated tương đương: phải mở app lại để nhận hoạt động theo điều kiện SDK. Ghi rõ cách đưa app vào từng trạng thái và loại payload dùng. [S8]

## 10. ARTEMIS và kiểm thử khám phá

**T33 - Chuẩn hóa 12 ca đã có.** Giữ AR-01...AR-12 trong `docs/test-cases.md`, thêm điều kiện đầu riêng từng ca, reset dữ liệu/slot/permission, tài khoản alias và tiêu chí đọc từ UI. AR-01/09/10 cung cấp các tương tác hệ thống Android. Khi thử hộp xin quyền, phải đưa permission về trạng thái chưa hỏi bằng quy trình reset phù hợp, không nhấn lại trong trạng thái đã từ chối vĩnh viễn rồi tính đó là test hộp gốc.

**T34 - Chạy trên điện thoại thật.** Mỗi ca ít nhất ba lần; nếu giữ đủ 12 ca thì tối thiểu 36 lượt. Lưu cả lần thất bại, không chỉ rerun đạt. Có thể thêm ca cloud/Admin nhưng không làm mất bao phủ ba luồng Lab 2, một lỗi và một tương tác native.

**T35 - Tổng hợp và kiểm chứng.** Lưu `runs.csv` với case_id, run_id, precondition, expected, actual, pass/fail, duration, device, app_hash, commit và log_path. Tỷ lệ đạt mỗi ca = số lượt đạt / số lượt thực chạy x100%; toàn bộ = tổng lượt đạt / tổng lượt thực chạy. Không bình quân các tỷ lệ nếu số lượt khác nhau mà không giải thích. Đối chiếu giá trị quan sát, không chỉ SUCCESS.

**T36 - Khám phá 15-30 phút.** Ghi giờ bắt đầu/kết thúc, người chạy, build, phạm vi và thao tác. Gợi ý: Back khi lưu, đổi ngày/tuần, bàn phím, permission, đổi tài khoản, tin trùng/route lạ, offline/retry, mở link ngoài và PDF. Mỗi lỗi có reproduction, expected/actual, mức độ, ảnh/log, commit sửa và retest. Phiên không tìm thấy lỗi vẫn phải có nhật ký thật.

Đầu ra: `docs/artemis-runbook.md`, ca chi tiết, raw logs, runs.csv, bảng tỷ lệ và `docs/exploratory-session.md` có evidence. 53 test Flutter giữ làm regression bổ trợ, không đổi nhãn thành ARTEMIS.

## 11. AI Code Review đúng trình tự và bằng chứng

**T37 - Tạo PR có phạm vi review rõ.** Dùng code mới trong phần FCM/Admin/sửa lỗi thật để tạo PR, ghi base/head và link. Chạy công cụ được môn chấp nhận. Không mặc định các sửa UID/Analytics đã làm local trước đây tự động trở thành ba finding của một phiên AI review chưa có.

**T38 - Ghi nhận ít nhất năm finding thuộc ít nhất hai nhóm.** Ví dụ nhóm security/privacy, reliability/concurrency, testing/maintainability. Mỗi finding: tool, nội dung, file, dòng đúng tại commit review, severity, bằng chứng tái hiện và quyết định accept/adjust/reject có lý do kỹ thuật.

**T39 - Sửa ít nhất ba finding đã chấp nhận.** Có commit liên kết finding và kết quả test/retest. Đề yêu cầu ba finding được sửa có commit truy vết, **không bắt buộc ba commit riêng**. Sửa dòng checklist hiện ghi “ít nhất 3 commit sửa” để tránh diễn giải sai rubric.

Các điểm có thể đưa vào phiên review thật, chưa tự tính là finding đã được AI xác nhận:

- Queue `notifications.pending` và việc đổi A/B; nguồn ở `repositories.dart` và `notifications_view_model.dart`.
- Lỗi bất đồng bộ/in-flight notification khi uid đổi hoặc màn dispose.
- Lỗi CrashService thứ cấp phát sinh trong catch của nghiệp vụ.
- Probe Storage dựa đường dẫn không có object và thiếu test owner/non-owner/chưa login với tệp thật.
- Quyền Admin/token registry/validate input trong backend mới sau khi được triển khai.

Nếu review chưa đủ năm phát hiện có cơ sở, tiếp tục review phạm vi thực tế hoặc bổ sung kiểm thử, không bịa finding để đủ số.

Đầu ra: `docs/review-decisions.md`, PR/review links, >=5 finding/2 nhóm, >=3 sửa có commit và evidence test. Không có hồ sơ này thì trang review trong báo cáo vẫn là kế hoạch, chưa phải kết quả.

## 12. Tài liệu, bằng chứng và GitHub

**T40 - Cập nhật tài liệu theo source thật.**

| File | Cần sửa/bổ sung |
|---|---|
| README.md | Phân biệt offline/Firebase/Admin; lệnh chạy đúng, build cuối, nguồn Lab 2 và link nộp |
| docs/architecture.md | Factory local mới, resilient Analytics, cơ chế logout, adapter upload chọn cuối, token registry/backend/Admin, queue sau sửa |
| docs/design-traceability.md | Nguồn Figma/handoff/version, expected/actual trên device và các màn thêm cho Lab 3 |
| docs/analytics-plan.md | Revision trước tracking mới, event -> ảnh, xác nhận tiêu chí đo; ghi nhận trình tự cũ thay vì sửa lịch sử |
| docs/test-cases.md | Bắt buộc device thật theo U; thêm test còn thiếu cho Analytics/RC key thứ hai, kết quả và bằng chứng; bỏ cách diễn giải sai về số commit |
| docs/SETUP-FIREBASE.md | Project/Android/Web/CLI/Gradle Groovy, SHA đúng khóa và provider cuối; lệnh demo có thể lặp lại |
| docs/ANDROID-APK.md | Hash/version Firebase mới, phân biệt validation offline với device/cloud |
| docs/admin-web.md | Cài/chạy, quyền, API base, tài khoản alias, đường dữ liệu và độ trễ |
| docs/crash-data-pipeline.md | Nguồn thật, schema, cadence/updatedAt, query/permission, cách đối chiếu Console-web |

**T41 - Tạo chỉ mục bằng chứng.** Không nhét tất cả ảnh lớn vào report rồi mất truy vết. Dùng một bảng nối requirement -> test -> file -> commit/hash. Mỗi ảnh/log có thời điểm, device/build và mô tả kết quả. Kiểm tra người chấm mở được link.

```text
docs/evidence-index.md
evidence/device/
evidence/auth/
evidence/upload/
evidence/fcm/
evidence/analytics/
evidence/crashlytics/
evidence/remote-config/
evidence/admin/
evidence/artemis/raw/
evidence/artemis/runs.csv
evidence/exploratory/
evidence/review/
deliverables/report-lab3-final.pdf
deliverables/slides-lab3-final.pdf
deliverables/video-link.md
```

Quy ước đề xuất: `MSG-03_run-02_<build>_<time>.png/log`. Chỉ mục có các cột ID yêu cầu, test/run, device, source commit, APK hash, expected, actual, status, evidence path và người xác minh.

Che thông tin cá nhân trong ảnh công khai. Không commit service-account key, khóa mô hình ARTEMIS, secret cloud, keystore hay biến môi trường thật. Với URL có token/token thiết bị, giữ bản gốc ở nơi nộp phù hợp và bản che dùng trong slide công khai. Không dùng việc che dữ liệu để làm mất khả năng đối chiếu build/issue/request cần chứng minh.

**T42 - Chốt GitHub.** Đưa source mobile, Admin/backend và docs thực sự cần thiết vào repository; dependencies/cache/APK lớn theo nơi phân phối đã chốt. Commit từng phần có ý nghĩa, push và kiểm tra nhánh/PR/release người chấm truy cập được. Trạng thái nhiều thay đổi chưa commit hiện tại phải được xử lý, không chỉ gửi URL trỏ nhánh main khung cũ. Ghi commit cuối/hash APK trong bộ nộp. Không gắn tag hoàn thành trước khi M5-M6 đạt.

## 13. Hoàn thiện báo cáo, slide và video

**T43 - Cập nhật report PDF 8-12 trang.** File hiện có 12 trang đúng số lượng nhưng còn placeholder/bằng chứng chờ. Cập nhật thông tin nhóm/MSSV/lớp, commit mới, kiến trúc local/Firebase/Admin và provider thật. Thay nội dung “đề xuất/chờ” bằng kết quả thực tế khi đã có evidence; phần nào chưa làm phải giữ trạng thái trung thực. Trình bày cấu hình build Groovy/APK mới thay mô tả cũ nếu liên quan. Không thêm trang ngoài ngưỡng chỉ để chứa mọi ảnh; dùng chỉ mục/phụ lục ngoài report khi cách nộp cho phép.

**T44 - Cập nhật slide PDF 12-15 trang.** File hiện có 15 trang. Gợi ý giữ 15 trang theo bố cục: mục tiêu, ba luồng, kiến trúc, Auth, upload, định danh FCM, server gửi, client ba trạng thái, Analytics, Crashlytics, Admin/pipeline, RC, ARTEMIS, AI review và kết quả/link. Bổ sung ảnh thực tế, rút gọn chữ khi cần. Slide phải phân biệt diagram nguyên lý với ảnh thật/đo đạc.

**T45 - Chuẩn bị giải thích trực tiếp.** Mỗi thành viên phụ trách dịch vụ phải chỉ được đường code client/server, dữ liệu đi qua đâu, ai cấp quyền, lỗi nào có thể xảy ra và cách kiểm chứng. Học theo câu hỏi ở mục 14, không chỉ học thuộc tên SDK.

**T46 - Quay video 5-10 phút.** Mục tiêu khoảng tám phút: 0:00-0:40 kiến trúc/build/device; 0:40-2:10 ba luồng/Auth; 2:10-3:00 upload; 3:00-4:10 Admin gửi FCM/device nhận; 4:10-4:50 Analytics; 4:50-6:00 nút crash, Console và web; 6:00-6:45 RC; 6:45-8:00 ARTEMIS, review và link. Không yêu cầu hệ thống cloud cập nhật trong vài giây để vừa video: có thể dùng bằng chứng cùng phiên đã thu, ghi rõ thời gian/nguồn và bảo đảm không làm người xem hiểu đó là real-time nếu không phải.

**T47 - Kiểm tra bộ nộp cuối.** Đếm trang/thời lượng, font tiếng Việt, ảnh rõ và link hoạt động. Xác nhận file APK/Console/web trong ảnh cùng project/version/commit được báo cáo. Mở thử trên máy khác hoặc cửa sổ không có quyền Dev để kiểm tra cách người chấm truy cập theo quyền được cấp. Người chấm Admin không phải dùng tài khoản Firebase Console của Dev để xem kết quả trên web.

## 14. Câu hỏi nguyên lý phải giải thích được

| Chủ đề | Câu trả lời cần chuẩn bị | Bằng chứng/đường mã để chỉ |
|---|---|---|
| MVVM | View gửi lệnh và quan sát state; VM gọi interface; adapter mới gọi SDK; vì sao fake kiểm tra logic nhưng không chứng minh cloud | app_services.dart, một View/VM/service/test cụ thể |
| Auth | Google credential đổi thành phiên Firebase ra sao; authStateChanges làm gì; SHA/OAuth và Firebase ID token có vai trò nào | firebase_auth_service.dart, session_view_model.dart, router.dart, Console Users |
| Upload | Tạo bytes/PDF, tính progress, lưu key theo UID; ai kiểm tra quyền; vì sao URL có token/presigned URL mang quyền truy cập | report_builder.dart, adapter thật, rules/server policy và ca A/B |
| FCM token/FID | Ai cấp định danh; SDK quản lý trên máy; app đọc và server lưu binding ra sao; khi đổi định danh/logout làm gì | messaging adapter, device registration client/server và record đã che |
| FCM server | Code gửi nằm ở đâu; quyền Admin được kiểm thế nào; server dùng Admin SDK/HTTP v1 ra sao; gửi accepted có khác nhận/mở không | route gửi tin, verify-role, request log và ảnh device [S4] |
| FCM client | Callback nào dùng cho mỗi trạng thái; permission Android 13+; notification/data payload; cách giữ lịch sử và route an toàn | messaging_service.dart, notifications_view_model.dart, push_routes.dart [S8] |
| Analytics | Event/params trả lời câu hỏi nào; UID khác PII ra sao; DebugView chứng minh gì; ba ngưỡng thời gian đo từ đâu | analytics-plan, VM/router, DebugView |
| Crashlytics | Fatal khác non-fatal; nút crash gọi gì; tại sao mở lại app và chờ; UID/key phục vụ chẩn đoán nào | AccountViewModel, crash service, Console và thời gian thực [S5] |
| Web Admin | Vì sao browser không giữ secret server; backend xác minh role; dữ liệu crash web đến từ đâu, cập nhật chậm thế nào | middleware, query service, schema/API/sourceUpdatedAt [S2] |
| Remote Config | Default/cache/fetched/activated khác nhau; fetch interval và realtime update; vì sao đổi được hành vi mà không build | RC service, hai màn UI và cặp ảnh cùng APK |
| ARTEMIS | Điều kiện đầu/reset/expected; agent SUCCESS khác kết quả đạt; tính rate thế nào | case + ba run + actual UI/raw log |
| AI review | Vì sao accept/adjust/reject; sửa gì và test nào chứng minh sửa đúng | PR dòng mã, decision table, commit và retest |

## 15. Ước lượng và đường ưu tiên

Ước lượng sau là dự kiến công sức, không phải kết quả đã làm hoặc cam kết theo ngày. Chưa biết deadline, số thành viên, quyền tài khoản và công cụ ARTEMIS. Thời gian chờ cloud/tài khoản/build lần đầu tính riêng.

| Nhóm việc | Công sức dự kiến |
|---|---|
| M0 + cài device + project/CLI/Firebase build | 3-6 giờ |
| Auth/upload/Analytics/RC/Crash mobile và ca lỗi | 6-10 giờ nếu giữ Storage hiện có; đổi provider cần 3-6 giờ bổ sung |
| FCM registry/backend/auth-role/API | 5-9 giờ |
| Admin UI + crash pipeline và đối chiếu dữ liệu | 8-14 giờ, phụ thuộc cấu hình export/billing |
| Device regression + ARTEMIS + khám phá | 5-9 giờ, phụ thuộc runner và lỗi phát hiện |
| AI review, sửa/retest, hồ sơ | 3-6 giờ |
| Hoàn thiện PDF/slide/video/GitHub | 4-7 giờ |

Với một người, phương án đầy đủ nêu trên khoảng **34-61 giờ làm**, chưa tính đổi provider và các khoảng chờ. Ước lượng này có phần custom sender/Admin UI đề xuất; khi chốt phạm vi tối thiểu phải loại các đầu việc tùy chọn và ước lượng lại, không coi 34-61 giờ là yêu cầu của rubric. Một nhóm có thể chia việc Mobile, Backend/Admin và QA/Tài liệu sau khi M0/API contract đã chốt.

Đường ưu tiên: **Project + device -> bản Firebase thật -> sáu dịch vụ + server FCM -> Admin nhận crash thật -> kiểm thử/evidence -> review/sửa -> bộ nộp**. Có thể cập nhật tài liệu và chuẩn hóa ca trong khi chờ Console/export, nhưng không viết kết quả đạt trước khi có lần chạy.

## 16. Các việc không nên tự mở rộng lúc này

- Không viết lại ba luồng Flutter đã có và không chuyển Expo khi chưa được phép.
- Không coi phải thêm Firestore cho toàn bộ nhật ký là yêu cầu của G; chỉ thêm lưu server khi Admin/token registry/metadata thực sự cần.
- Không triển khai đồng thời Firebase Storage, Cloudinary và S3.
- Không làm web người dùng/CMS/thanh toán/AI gợi ý món nếu không có yêu cầu mới.
- Không thay toàn bộ thư viện/build tools chỉ vì cảnh báo tương lai khi bản hiện tại đã build; chỉ thay khi có lỗi hoặc yêu cầu tương thích cụ thể.
- Không chạy lại nhiều vòng unit test chỉ để tăng số lượng bằng chứng; dành thời gian cho các khoảng trống thật: cloud/device/Admin/ARTEMIS/review.

## 17. Checklist chốt sẵn sàng chấm

- [ ] Nguồn Lab 2 truy cập được và ba luồng có đối chiếu expected/actual.
- [ ] Source mới có commit/push, nhánh/PR/release được ghi đúng.
- [ ] Firebase project riêng cấu hình đúng, không còn placeholder trên bản chấm.
- [ ] APK Firebase mở trên điện thoại thật, ghi device/version/hash.
- [ ] Google login/hủy/offline/logout/guard/UID A-B được kiểm chứng.
- [ ] Upload thật có tệp/progress/kết quả/quyền và ca lỗi; provider đúng tài liệu.
- [ ] FCM Console gửi được, đủ ba trạng thái/permission/history/route; Admin gửi được nếu đã chốt custom sender.
- [ ] Binding định danh và queue không làm lẫn thông báo cá nhân A/B.
- [ ] Analytics có >=7 event, đầy đủ event trong kế hoạch được xác minh, không PII.
- [ ] Crash thật từ nút và non-fatal nghiệp vụ có trên Console, UID/custom key đúng.
- [ ] Admin web xem kết quả crash thật, có nguồn/updatedAt/role checks.
- [ ] Hai Remote Config param thay đổi UI trên cùng APK; default/cache/offline đúng.
- [ ] Mỗi dịch vụ có ít nhất một ca lỗi và bằng chứng quan sát được.
- [ ] ARTEMIS >=10 ca, mỗi ca >=3 lần; có native interaction, nhánh lỗi, raw log và rate.
- [ ] Có phiên khám phá 15-30 phút và retest lỗi phát hiện.
- [ ] AI review PR >=5 finding thuộc >=2 nhóm, quyết định có lý do, >=3 sửa có commit.
- [ ] Kiến trúc/truy vết/Analytics/setup/admin/runbook/evidence index đã cập nhật.
- [ ] Report PDF 8-12 trang và slide PDF 12-15 trang đã thay placeholder bằng dữ liệu thật.
- [ ] Video 5-10 phút, GitHub và các link nộp mở được đúng quyền.
- [ ] Thành viên giải thích được nguyên lý và chỉ được đường code client/server thực tế.

## 18. Việc bắt đầu ngay trong phiên tiếp theo

1. Tạo/chốt Firebase project riêng, cung cấp Project ID và chọn provider upload/pipeline Admin theo điều kiện nhóm.
2. Cắm điện thoại Android thật, hoàn tất USB debugging/RSA, cài APK offline và ghi smoke test.
3. Lấy nguồn thiết kế/handoff Lab 2 và nguồn ARTEMIS từ môn học.
4. Cấu hình Firebase/Gradle/SHA, build APK Firebase rồi chứng minh Google login trên Console.
5. Chốt API contract và chia phần mobile/Firebase, backend/Admin, QA/evidence. Khi các input này đã rõ mới triển khai các phần phụ thuộc.

## 19. Nguồn kỹ thuật bổ trợ

### Lệnh tham khảo cho M0-M2

Các lệnh này là hướng dẫn để chạy khi bắt đầu triển khai, không phải kết quả thực thi của lần audit này. Chạy trong thư mục app và dùng đúng serial khi có nhiều thiết bị. Trên máy hiện tại có thể dùng ADB tại `C:/Users/Acer/AppData/Local/Android/Sdk/platform-tools/adb.exe` hoặc thêm platform-tools vào PATH.

```powershell
git status --short
flutter doctor -v
adb devices -l
adb install -r artifacts/android/longevity-plate-offline.apk
```

Sau khi project/config/provider/SHA đã hoàn tất:

```powershell
./scripts/build-android.ps1 -Firebase
adb install -r artifacts/android/longevity-plate-firebase.apk
adb shell setprop debug.firebase.analytics.app com.longevityplate.longevity_plate
adb shell setprop log.tag.FirebaseCrashlytics DEBUG
adb logcat -s FirebaseCrashlytics
```

Tắt cờ chẩn đoán sau phiên thu bằng chứng:

```powershell
adb shell setprop debug.firebase.analytics.app .none.
adb shell setprop log.tag.FirebaseCrashlytics INFO
```

Nếu đổi khóa ký và Android không cho cập nhật đè, phải lưu dữ liệu cần thiết trước khi cân nhắc gỡ bản cũ. Không đưa lệnh xóa dữ liệu thiết bị vào bước mặc định của runbook.

### Tài liệu chính thức

G và U quyết định tiêu chí chấm. Các nguồn dưới đây dùng để kiểm tra cơ chế triển khai hiện hành, không tự bổ sung yêu cầu ngoài đề. Truy cập ngày 11/11/2026.

- [S1] [Firebase Storage billing/bucket FAQ](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024), [Storage troubleshooting](https://firebase.google.com/docs/storage/faq-and-troubleshooting).
- [S2] [Crashlytics BigQuery export, batch/streaming và độ trễ](https://firebase.google.com/docs/crashlytics/bigquery-export).
- [S3] [FCM Flutter registration/token/FID](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
- [S4] [Gửi thông báo từ Firebase Admin SDK](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk).
- [S5] [Kiểm tra crash Flutter và debug logging](https://firebase.google.com/docs/crashlytics/flutter/test-implementation).
- [S6] [AWS S3 presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html).
- [S7] [Cloudinary media access control](https://cloudinary.com/documentation/control_access_to_media).
- [S8] [FCM client receive và trạng thái app](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

Không có mã ứng dụng, Console hay tài nguyên cloud nào được thay đổi bởi việc tạo bản kế hoạch này. Các task T01-T47 là công việc đề xuất tiếp theo, không phải danh sách đã thực hiện.
