# AI Code Review

Cập nhật backend13/11/2026, commit9215cf9: CR-02 được xử lý bằng queue mỗi sự kiện một khóa theo UID/event ID; client không chuyển queue củaA choB. Có test notification_owner_test.dart và hồi quy Firebase. Bảng dưới giữ nguyên kết quả tại vòng review gốc09/11; trạng thái CR-02 lịch sử không phải trạng thái code hiện tại.

## Cách rà soát

- **Công cụ:** Claude Code, lệnh `/code-review` ở mức `high`. Đây là công cụ tương đương Copilot hoặc CodeRabbit theo trang 24 của đề.
- **Phạm vi:** toàn bộ nhánh `feature/lab3-firebase` so với `main`, tức pull request [#1](https://github.com/Dangchaubaominh/longevity-plate-lab3/pull/1), gồm app Flutter và server báo cáo trong `server/`.
- **Thời điểm:** 09/11/2026, trên commit `749183d`. Số dòng trong bảng tính theo commit này.
- **Cách làm:** công cụ đọc diff theo tám góc nhìn: từng dòng, hành vi bị xóa, ảnh hưởng chéo giữa các tệp, dùng lại code, đơn giản hóa, hiệu năng, sửa đúng tầng và quy ước dự án. Nhóm kiểm chứng từng phát hiện bằng cách đọc lại code và chạy test, rồi mới quyết định.

## Phát hiện và quyết định

Quyết định có ba loại. **Chấp nhận:** phát hiện đúng, sửa như đề xuất. **Điều chỉnh:** phát hiện đúng nhưng sửa ở chỗ khác hoặc theo cách khác. **Bác bỏ:** không sửa, kèm lý do.

| ID | Nhóm | Vị trí | Phát hiện | Quyết định | Lý do kỹ thuật | Commit |
|---|---|---|---|---|---|---|
| CR-01 | Đúng đắn | `lib/viewmodels/add_meal_view_model.dart:87` | `logEvent(meal_saved)` nằm chung khối `try` với `meals.add`. Analytics ném lỗi sau khi bữa đã lưu thì app báo thất bại, người dùng bấm Thử lại sẽ tạo bản ghi trùng | Điều chỉnh | Lỗi có thật, nhưng sửa ở gốc (CR-05) thay vì thêm `try` riêng ở từng ViewModel. Cùng lỗi còn có ở báo cáo PDF và mục tiêu | `59363a2` |
| CR-02 | Đúng đắn | `lib/services/repositories.dart:223` | `load()` đọc hàng chờ thông báo rồi mới xóa. Tin do handler nền ghi vào giữa hai bước này bị mất | Chấp nhận, chưa sửa | SharedPreferences không có khóa giữa các isolate nên không sửa triệt để được trong vài dòng. Cách đúng là mỗi tin một khóa riêng hoặc dùng cơ sở dữ liệu có transaction. Khoảng thời gian xảy ra rất ngắn, ghi vào giới hạn đã biết | Chưa có |
| CR-03 | Đúng đắn, riêng tư | `lib/viewmodels/session_view_model.dart:46` | Chỉ đặt User ID của Crashlytics khi có uid, nên sau khi đăng xuất, lỗi vẫn bị gắn cho người dùng trước | Chấp nhận | Báo cáo lỗi của hai người dùng bị trộn, ảnh hưởng kiểm thử FB-13. Đặt chuỗi rỗng khi đăng xuất, thêm kiểm tra vào test đăng xuất | `be41a2c` |
| CR-04 | Xử lý lỗi | `lib/viewmodels/notifications_view_model.dart:22` | `initialMessage().then(...)` không xử lý lỗi, lỗi bị Crashlytics ghi thành crash | Chấp nhận | App vẫn chạy khi lỗi này xảy ra, nên đây là non-fatal. Ghi thành crash làm sai số liệu không crash trên Console | `953e9a5` |
| CR-05 | Sửa đúng tầng | `lib/services/firebase/firebase_analytics_service.dart:13` | Lỗi của Analytics lọt vào luồng chính. Nên sửa trong dịch vụ Analytics thay vì từng nơi gọi | Chấp nhận | Analytics chỉ để đo. Bắt lỗi một chỗ thì mọi ViewModel đều an toàn, kể cả lệnh `setUserId` không được `await` | `59363a2` |
| CR-06 | Đúng đắn | `lib/viewmodels/home_view_model.dart:20` | Ngày "hôm nay" chỉ tính một lần lúc tạo ViewModel. Tab Hôm nay được giữ trong IndexedStack nên để app mở qua đêm vẫn hiện ngày cũ | Điều chỉnh | Đổi thành getter, nên lần tải kế tiếp dùng đúng ngày. Không thêm hẹn giờ nửa đêm: màn tự tải lại khi có bữa hoặc kế hoạch mới, và khi mở lại app | `a2bebb9` |
| CR-07 | Đúng đắn | `server/src/index.js:128` | Header hoặc payload của token là JSON `null` thì server trả 500 thay vì 401 | Chấp nhận | Token rác phải nhận 401 như mọi token sai khác. Thêm hai ca vào test | `0873691` |
| CR-08 | Bảo mật | `server/src/index.js:135` | So sánh với `undefined` luôn sai, nên token thiếu `iat` hoặc `auth_time` vẫn qua bước kiểm tra | Điều chỉnh | Token do Google ký luôn có hai claim này nên rủi ro thấp. Vẫn sửa vì rẻ và đúng tài liệu Firebase. Chạy test mới trên code cũ thì token thiếu `iat` được chấp nhận (200), code mới trả 401 | `0873691` |
| CR-09 | Hiệu năng | `lib/viewmodels/notifications_view_model.dart:66` | Mỗi lần `reload()` đều hỏi lại quyền thông báo qua kênh nền tảng | Bác bỏ | Người dùng có thể đổi quyền trong Cài đặt hệ thống, và `reload()` cũng là chỗ cập nhật quyền khi quay lại app. Chi phí là một lệnh gọi mỗi lần chạm, không đáng kể | Không sửa |
| CR-10 | Dùng lại code | `lib/services/repositories.dart:181` | `article()` chép lại phép tìm của `articleById`, trong khi `recipe()` đã dùng `recipeById` | Chấp nhận | Hai bản sao có thể lệch nhau khi đổi quy tắc tìm | `5095940` |

Tổng cộng: 10 phát hiện thuộc 6 nhóm. Chấp nhận 6, điều chỉnh 3, bác bỏ 1. Đã sửa 8 phát hiện qua 6 commit; CR-02 được ghi nhận là giới hạn.

## Kiểm chứng sau khi sửa

- `flutter analyze` không có lỗi, `flutter test` đạt 54/54.
- Test server (`npm test` trong `server`) đạt 10/10, gồm bốn ca token mới. Trên code cũ, ca thiếu `iat` thất bại vì server trả 200.
- Server đã được triển khai lại lên Cloudflare Workers. Gọi với token có phần JSON là `null` nhận `401 invalid-token`.
- Chưa chạy lại các ca thủ công trên thiết bị sau các commit này.
