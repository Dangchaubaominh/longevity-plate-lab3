# Kế hoạch upload ảnh bữa ăn lên Cloudinary

Ngày lập: 11/11/2026. Nền mã: `main` tại `12c60ae` cùng các thay đổi local đã hòa nhập. Đây là kế hoạch triển khai, chưa phải xác nhận tính năng cloud đã hoàn thành hoặc Worker đã deploy.

## 1. Quyết định kiến trúc

Giữ cơ chế lưu bữa ăn và ảnh local đang có. Bổ sung một hàng đợi upload bền vững theo UID; app xin chữ ký từ Cloudflare Worker bằng Firebase ID token, rồi gửi JPEG trực tiếp lên Cloudinary. Ảnh đặt chế độ `authenticated`. Secret Cloudinary chỉ đặt ở Worker.

Lý do: phù hợp kiến trúc hiện tại, tái sử dụng xác thực và server PDF, thao tác lưu bữa không phụ thuộc mạng, có trạng thái rõ ràng khi demo, và giữ được ảnh khi upload lỗi. Không đưa tác vụ mạng vào `DeviceMealPhotoService` hoặc thực hiện upload trong `build()` của widget.

Phạm vi bản đầu: một ảnh tùy chọn cho mỗi bữa. Bữa ăn vẫn được ghi trong SharedPreferences theo UID; Cloudinary lưu tệp ảnh. Chưa có đồng bộ danh sách bữa giữa thiết bị, chưa có API cho Admin xem toàn bộ nhật ký. Các khả năng đó cần kho metadata và phân quyền riêng ở giai đoạn sau.

## 2. Hiện trạng đã kiểm tra

| Thành phần | Hiện có | Cần bổ sung |
|---|---|---|
| Chụp/chọn ảnh | image_picker, phục hồi lost data Android | Kiểm thử lại trên điện thoại thật |
| Xử lý ảnh | JPEG, tối đa cạnh 1600 px, giới hạn file local 5 MiB, loại metadata qua mã hóa lại | Dùng lại bytes đã chuẩn hóa khi upload |
| Lưu bữa | `MealEntry.imagePath`, repository lưu theo UID | Metadata ảnh cloud và trạng thái upload |
| Hiển thị | Thumbnail, xem lớn, fallback khi file hỏng | Trạng thái đồng bộ, tải lại ảnh cloud khi thiếu local |
| Cloudinary | Chỉ PDF, `/reports/sign` và `/reports/url` | Các endpoint ảnh riêng |
| Quyền | Worker xác minh Firebase ID token và UID của báo cáo | Áp dụng độc lập cho namespace ảnh |
| Kết nối | `REPORT_API_URL`, cấu hình local dùng `longevity-plate-beff9` | Smoke test Worker đã deploy với cùng Firebase project |

Các kiểm tra sau lần hòa nhập trước: analyzer đạt, 75 test Flutter và 10 test server đạt. Chúng chưa chứng minh upload ảnh mới hoạt động; phải thêm test và bằng chứng cho tính năng này.

## 3. Luồng người dùng

1. Đăng nhập Google, mở Thêm bữa ăn.
2. Chọn ngày, loại bữa, nhập mô tả; chụp hoặc chọn ảnh nếu muốn.
3. App chuẩn hóa ảnh vào file nháp riêng của UID và hiện preview. Chưa upload ở bước này.
4. Bấm Lưu bữa ăn: kiểm tra dữ liệu, tạo file ảnh bền vững, ghi bữa + trạng thái `pending` trong cùng một lần ghi snapshot của repository.
5. Khi ghi local thành công, trở về Nhật ký và hiển thị bữa ngay. Nếu có ảnh, bộ điều phối bắt đầu upload trong lúc app hoạt động.
6. Thẻ bữa hiện một trong các trạng thái: Chờ tải ảnh / Đang tải ảnh / Đã tải ảnh / Chưa tải được - Thử lại.
7. Upload lỗi không xóa bữa hoặc ảnh local. Đóng/mở app hoặc mất mạng vẫn giữ việc cần làm.
8. Ảnh không bắt buộc. Bữa không ảnh lưu theo luồng hiện tại và không gọi API Cloudinary.

Không dùng chữ “Đã đồng bộ bữa ăn” khi chỉ tệp ảnh được upload. Thông báo lưu nên là “Đã lưu bữa ăn”; trạng thái ảnh được trình bày riêng.

## 4. Dữ liệu và trạng thái

Giữ `imagePath` để tương thích dữ liệu cũ. Thêm một đối tượng `photo` tùy chọn:

```text
photoId           = SHA-256 của JPEG chuẩn hóa, ổn định giữa các lần thử
publicId          = meal_photos/<uid>/<mealId>/<photoId>
version           = phiên bản do Cloudinary trả về khi xác nhận
format            = jpg
bytes, width, height
syncStatus        = pending | uploading | uploaded | failed
lastErrorCode     = mã lỗi giới hạn, không chứa token/URL bí mật
uploadedAt        = thời điểm xác nhận upload, có thể null
```

- Trạng thái không ảnh được biểu diễn bằng `photo == null`; bản ghi cũ chỉ có `imagePath` vẫn đọc được.
- Không lưu URL có chữ ký hết hạn như danh tính lâu dài của ảnh. Lưu `publicId` và metadata; xin URL khi cần.
- Chỉ chuyển `uploaded` sau khi nhận và kiểm tra kết quả thực tế từ Cloudinary. Byte đã gửi hết chưa có nghĩa upload thành công.
- Khởi động lại: `uploading` bị gián đoạn được đưa về `pending`, rồi kiểm tra lại asset trước khi tải tiếp.
- Dùng chính bản ghi bữa làm nguồn cho hàng đợi, tránh hai bản sao queue và meal lệch nhau. Bộ điều phối đọc các bữa có ảnh chưa hoàn tất.
- Sửa trạng thái bằng hàm patch có kiểm tra `mealId + photoId`, đọc snapshot mới nhất dưới khóa ghi theo UID. Không ghi đè danh sách cũ lấy trước một lần await.
- Ảnh cũ đã lưu không tự động upload toàn bộ. Cung cấp thao tác upload cho từng bữa cũ sau khi người dùng chọn, hoặc làm migration có lựa chọn trong giai đoạn sau.

## 5. API Worker

Tái sử dụng xác minh token, đọc cấu hình và ký Cloudinary; giữ nguyên hợp đồng `/reports/*`. Không mở API ký chung cho phép client tự chọn mọi tham số Cloudinary.

| Endpoint đề xuất | Đầu vào | Xử lý và đầu ra |
|---|---|---|
| `POST /meal-photos/sign` | `mealId`, `photoId` | Lấy UID từ token, kiểm tra định dạng ID, dựng publicId; ký upload JPG với `type=authenticated`, `overwrite=false`; trả uploadUrl, fields, publicId |
| `POST /meal-photos/resolve` | `mealId`, `photoId`, receipt nếu có | Dựng lại publicId thuộc UID; xác minh receipt Cloudinary; khi cần đối soát retry dùng thông tin asset từ Cloudinary; trả metadata được xác nhận và link tải có hạn |
| `POST /meal-photos/url` | `mealId`, `photoId` | Kiểm tra UID và publicId do server dựng, cấp link tải ảnh có hạn; response `Cache-Control: no-store` |
| `POST /meal-photos/delete` | `mealId`, `photoId` | Giai đoạn kế tiếp: xóa đúng asset thuộc UID, xử lý trường hợp asset đã không còn |

Quy tắc:

- API nhận `mealId/photoId`, không nhận UID để quyết định chủ sở hữu. Chặn ID chứa dấu slash hoặc path traversal. Namespace ảnh không dùng chung namespace báo cáo.
- Firebase project trên Worker phải khớp client: local hiện là `longevity-plate-beff9`. Chưa coi cấu hình file là bằng chứng bản Worker đang deploy đã đúng.
- App gửi bytes đã chuẩn hóa lên `image/upload`; ký các tham số cố định, giới hạn định dạng JPG. Không nhúng API Secret vào Dart, APK hay Git.
- 5 MiB là giới hạn app thực thi trước upload. Với direct upload, không tuyên bố Worker đã chặn cứng dung lượng trước khi Cloudinary nhận file. Kiểm tra metadata khi hoàn tất, từ chối và dọn asset vượt chính sách. Nếu cần giới hạn cứng trước upload cho client tùy ý, đổi riêng endpoint này sang proxy có kiểm soát bytes.
- Upload preset Cloudinary không cung cấp giới hạn dung lượng riêng cho từng preset; không dựa vào tham số `max_file_size` giả định để bảo vệ server.
- Đặt timeout, giới hạn body JSON, ánh xạ lỗi 400/401/403/404/429/5xx; giới hạn tần suất xin chữ ký khi triển khai. Khi bị 401, lấy token hiện tại lại và chỉ thử thêm một lần nếu UID không đổi.
- Kiểm tra chữ ký receipt Cloudinary theo đúng thuật toán receipt, không tái sử dụng chuỗi ký upload một cách máy móc. Trường hợp response mất giữa chừng phải đối soát asset cùng publicId trước khi kết luận thất bại.
- Không log Firebase token, chữ ký upload hoặc link ảnh có chữ ký. URL tải tạm là bearer link: người có link còn hạn vẫn có thể dùng; không mô tả là thu hồi ngay khi logout.

## 6. Chia trách nhiệm trong Flutter

| File/thành phần | Công việc |
|---|---|
| `lib/models/models.dart` | Model metadata ảnh cloud, enum trạng thái, JSON tương thích bản cũ |
| `lib/services/device_meal_photo_service.dart` | Giữ trách nhiệm camera/gallery, normalize, file local, kiểm tra UID |
| `lib/services/meal_photo_service.dart` | Giữ hợp đồng local; thêm interface cloud ở file riêng |
| `lib/services/cloud/cloudinary_meal_photo_service.dart` (mới) | sign/upload/resolve/url, tiến độ, timeout, kiểm tra response, không tự ghi bữa |
| `lib/services/meal_photo_upload_coordinator.dart` (mới) | Đọc pending theo UID, một upload tại một thời điểm, retry/resume, quản lý session và tiến độ |
| `lib/services/repositories.dart` | Ghi bữa + pending; patch metadata nguyên tử trong phạm vi repository; khóa ghi theo UID |
| `lib/app/app_services.dart` | Inject cloud service và coordinator; offline không gọi cloud, fake dùng mock |
| `lib/viewmodels/add_meal_view_model.dart` | Lưu local trước; gọi coordinator sau commit; không giữ màn nhập chờ upload |
| ViewModel nhật ký / `lib/views/meal_screens.dart` | Badge trạng thái, tiến độ có giới hạn, Thử lại; sự kiện sửa trạng thái không tạo thêm bữa |
| `lib/views/widgets/meal_photo.dart` | Ưu tiên ảnh local; thiếu local thì xin link/tải vào cache riêng UID; fallback rõ nếu lỗi |
| `lib/app/app.dart` | Kích hoạt xử lý pending khi login/resume; dừng công việc của session cũ khi logout |
| `scripts/build-android.ps1` | Dùng tham số URL Worker hiện có, tránh tạo hai base URL khác nhau cho PDF và ảnh |

Chỉ tách HTTP client/ký chung khỏi adapter PDF khi có nhu cầu dùng chung rõ ràng, không refactor toàn bộ PDF trước khi luồng ảnh chạy được.

## 7. Retry, tránh trùng và ranh giới phiên

- Dùng `mealId` đã tạo một lần cho bản nháp; `photoId` lấy từ bytes chuẩn hóa; `publicId` cố định. Bấm nhiều lần không tạo nhiều bữa hoặc nhiều tên asset.
- Nếu Cloudinary đã nhận ảnh nhưng app mất response, lần thử lại gọi đối soát. `overwrite=false` không tự bảo đảm app biết asset đã thành công; phải xử lý kết quả trùng/asset tồn tại rõ ràng.
- Mỗi upload chụp UID + generation của session. Kiểm tra trước xin chữ ký, sau upload và trước patch repository. Không chuyển job A sang tài khoản B.
- Dừng queue và bỏ callback UI cũ khi logout; xóa cache ảnh trong RAM để màn của B không hiện ảnh A. Tệp local vẫn giữ riêng cho A theo hành vi hiện có.
- Tự thử lại hữu hạn, chẳng hạn 2 lần với khoảng chờ tăng; sau đó hiện Thử lại. Không retry liên tục khi lỗi quyền hoặc cấu hình.
- Khởi động/resume/login quét pending của UID hiện tại. Bản đầu không hứa hẹn upload tiếp khi Android đã kill app; lúc mở lại mới tiếp tục.
- Hủy màn nhập trước khi Lưu chỉ dọn nháp local vì chưa upload cloud. Sau khi bữa đã commit, đóng màn không được xóa ảnh bền vững hoặc mất job.
- Nếu patch local sau upload lỗi, giữ file local và job để đối soát lại. Không tự xóa asset cloud có thể đang được dùng bởi một bản ghi đã commit.
- Xóa/thay ảnh và dọn asset mồ côi cần hàng đợi tombstone + retry ở giai đoạn kế tiếp. Phải tính tới chữ ký upload còn hiệu lực có thể tạo lại asset vừa xóa; không hứa hẹn xóa vĩnh viễn ngay sau một lệnh destroy. Tránh thêm nút thay ảnh của bữa đã lưu trước khi cơ chế này hoàn thành.

## 8. Thứ tự triển khai và điểm nghiệm thu

### Bước 1 — Kiểm tra kết nối cloud thật

Đối chiếu Worker URL, Firebase project và Cloudinary product environment; gọi thử sign bằng token của tài khoản kiểm thử. Kiểm tra PDF hiện tại vẫn hoạt động. Không bật unsigned upload, không đổi project Firebase hoặc billing chỉ để làm tính năng ảnh.

Đạt khi: request có token đúng project thành công; thiếu/sai token bị từ chối; PDF vẫn đạt. Nếu Worker chưa deploy, triển khai bản đã kiểm tra là một bước riêng có cấu hình cụ thể.

### Bước 2 — Model, repository và queue local

Thêm metadata, patch có khóa theo UID, tạo pending cùng bản ghi bữa, giữ tương thích dữ liệu cũ và luồng offline. Thử đóng/mở app với job pending trước khi gọi mạng thật.

Đạt khi: bữa có ảnh lưu được khi mất mạng; bữa không ảnh không tạo job; các bản ghi cũ không hỏng.

### Bước 3 — API ảnh và adapter Flutter

Làm sign → direct upload → resolve bằng một JPEG nhỏ; thêm kiểm tra receipt, quyền, timeout, đối soát retry. Không triển khai UI quản lý ảnh đã lưu ở bước này.

Đạt khi: Cloudinary có đúng một asset authenticated trong namespace UID; link không có chữ ký bị chặn; tài khoản B không xin được URL ảnh A.

### Bước 4 — Gắn queue với session và giao diện

Thêm badge/progress/Thử lại, resume trên app foreground, tải ảnh từ cloud khi cache local mất. Bảo đảm callback sau logout không cập nhật màn hoặc dữ liệu của tài khoản mới.

Đạt khi: lưu xong xem bữa ngay, lỗi upload giữ bữa, thử lại không tạo trùng, A/B tách biệt, URL hết hạn được xin lại có giới hạn.

### Bước 5 — Nghiệm thu, build và bằng chứng

Chạy analyzer + toàn bộ test cũ và mới + test Worker; build APK với URL Worker thật; cài lên điện thoại thật và kiểm tra các ca bên dưới. Cập nhật README, test-cases và nội dung slide luồng token/chữ ký/bytes/quyền UID.

Đạt khi: có APK đúng source, SHA-256, video màn hình thật, ảnh asset Cloudinary và kết quả truy cập trái quyền. Test mock chỉ là kiểm tra tự động, không thay thế bước này.

### Bước 6 — Mở rộng sau bản đầu

Thêm xóa/thay ảnh đã lưu và dọn asset mồ côi có retry. Nếu cần đăng nhập máy khác vẫn có lịch sử hoặc Admin web truy vấn bữa ăn, thiết kế kho metadata dùng chung như Firestore cùng security rules/API và cơ chế đồng bộ. Không dùng Cloudinary Media Library như database của nhật ký hoặc như web dành cho Admin ứng dụng.

## 9. Các ca kiểm thử bắt buộc

| Ca | Kết quả mong đợi |
|---|---|
| Camera và gallery trên điện thoại thật | Preview đúng chiều; JPEG hợp lệ, không vượt giới hạn app |
| Hủy camera, từ chối quyền, ảnh hỏng/quá lớn | Thông báo rõ; nội dung bữa không mất |
| Lưu không ảnh | Một bữa, không có request upload |
| Lưu có ảnh online | Bữa xuất hiện ngay; cuối cùng một asset đúng UID và badge đã tải |
| Lưu offline, đóng/mở app | Bữa và ảnh local còn; job không mất; mở lại có mạng tải được |
| Mất mạng sau Cloudinary nhận bytes | Đối soát được; retry không tạo asset/bữa trùng |
| Bấm Lưu hoặc Thử lại liên tục | Chỉ một job đang hoạt động cho cùng ảnh |
| URL ảnh hết hạn, file local không còn | Xin URL mới và tải lại; không crash hoặc lặp vô hạn |
| Logout A khi đang upload, login B | Không hiện ảnh/job A trên màn B; A đăng nhập lại đối soát được |
| B xin sign/url cho publicId A hoặc traversal | Bị từ chối hoặc không có cách chỉ định namespace của A |
| Token sai/hết hạn/sai project | 401; không upload tiếp bằng session khác |
| File không phải ảnh nhưng đổi đuôi JPG | Cloudinary từ chối nội dung không hợp lệ; không báo thành công |
| Worker lỗi, Cloudinary quota/429, timeout | Giữ dữ liệu local; lỗi rõ; retry hữu hạn |
| Ghi metadata local thất bại sau upload | Job đối soát lại; không mất bữa và không nhân bản |
| Hồi quy PDF/Auth/FCM/Analytics/RC | Các luồng hiện có tiếp tục hoạt động |

Các bài test mới cần mock HTTP, token và thời gian; kiểm tra hành vi nghiệp vụ ở repository/coordinator, không chỉ kiểm tra getter. Thêm widget test cho badge, retry, lỗi và chống lộ ảnh giữa các phiên.

## 10. Liên hệ yêu cầu Lab3 và tài liệu chính thức

Guide trang 9–10 yêu cầu tệp như PDF, tiến độ, URL cuối cùng, thành công/thất bại, quyền theo UID và ca mất mạng/truy cập trái quyền. Việc giảng viên cho phép Cloudinary thay Storage là chỉ dẫn riêng của người dùng; không diễn giải như câu chữ có sẵn trong guide. Ảnh là tính năng bổ sung, luồng PDF cần tiếp tục giữ để đối chiếu yêu cầu.

- Guide local: `D:\PRM393\Lab3\PRM393_Lab3_Preparation_Guide_v5_ToiUu.pdf`.
- Chữ ký upload và secret ở backend: https://cloudinary.com/documentation/authentication_signatures
- Upload trực tiếp qua server ký: https://cloudinary.com/documentation/client_side_uploading
- Authenticated media và link tải có hạn: https://cloudinary.com/documentation/control_access_to_media
- API upload/receipt/destroy: https://cloudinary.com/documentation/image_upload_api_reference
- Upload preset và giới hạn thực tế: https://cloudinary.com/documentation/upload_presets

## 11. Quyết định đề xuất để bắt đầu code

Làm bước 1 rồi bước 2–5 theo đúng thứ tự; ưu tiên hoàn thành một luồng upload ảnh nhỏ có xác thực từ đầu đến cuối trước. Giữ ảnh là tùy chọn, giữ bản local và dữ liệu cũ. Chỉ làm cloud cho tệp ảnh trong đợt này; đồng bộ database và Admin xem nhật ký là hạng mục tiếp theo nếu sản phẩm cần.
