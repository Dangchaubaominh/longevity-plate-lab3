# Ca kiểm thử

## Test tự động

Chạy với dịch vụ giả lập, không cần Firebase:

```bash
flutter test
```

| Tệp | Nội dung |
|---|---|
| `test/auth_and_guard_test.dart` | Guard, F01, hủy đăng nhập, mất mạng, đăng xuất, tách dữ liệu theo uid |
| `test/flows_test.dart` | F02, F03, nhánh lỗi, tìm kiếm, link ngoài, không gửi dữ liệu cá nhân lên Analytics |
| `test/firebase_features_test.dart` | Remote Config, FCM ở các trạng thái, báo cáo PDF, Khu vực trình diễn |
| `test/layout_test.dart` | Không tràn layout ở 360, 412, 800dp, kích thước vùng chạm |

Các test này kiểm tra logic app với bản giả lập. Chúng không chứng minh Firebase thật hoạt động, nên vẫn phải chạy phần thủ công bên dưới trên thiết bị.

## Kiểm thử thủ công mỗi dịch vụ

Điền kết quả sau khi chạy trên thiết bị Android thật hoặc emulator.

Lần chạy ngày 04 và 05/11/2026 trên emulator Android 17 (API 37), bản debug, dự án Firebase `longevity-plate`. Phần lớn các ca dùng tài khoản chủ dự án; FB-01 dùng tài khoản kiểm thử riêng. Giờ ghi theo giờ Việt Nam.

Cách ghi kết quả:

- **Đạt:** đã thấy đúng kỳ vọng, kể cả phần trên Console.
- **Đạt phía app:** app chạy đúng, nhưng còn thiếu ảnh Console mà kỳ vọng yêu cầu.
- **Đạt một phần:** còn một phần của kỳ vọng chưa quan sát được.
- **Chưa chạy:** chưa đủ điều kiện để thử.

| ID | Dịch vụ | Bước | Kỳ vọng | Kết quả | Bằng chứng |
|---|---|---|---|---|---|
| FB-01 | Auth | Đăng nhập Google thành công | Vào S02 hoặc S03, có user trên Console | Đạt phía app | 05/11 18:58, tài khoản kiểm thử mới vào S02 rồi S03, log có `login` và UID mới. Cần ảnh Authentication → Users |
| FB-02 | Auth, lỗi | Hủy hộp chọn tài khoản | Ở lại S10, báo đã hủy | Đạt | 05/11, ở lại S10 và báo "Bạn đã hủy đăng nhập", không ghi lỗi vào Crashlytics |
| FB-03 | Auth, lỗi | Tắt mạng rồi đăng nhập | Báo mất mạng hoặc lỗi kết nối | Đạt sau khi sửa | 05/11, lần đầu báo nhầm là đã hủy. Sau commit `3813108` báo "Không có kết nối mạng" và ghi non-fatal `sign_in_failed` |
| FB-04 | Auth | Đăng xuất rồi Back | Không vào lại được màn bảo vệ | Đạt | 05/11 17:52, đăng xuất về S10, Back về S01, log có `logout` |
| FB-05 | Storage | Xuất báo cáo | Thấy tiến độ, URL, tệp trên Console | Chưa chạy | Storage chưa bật vì cần gói Blaze. Xem ghi chú bên dưới về lần xuất thất bại |
| FB-06 | Storage, lỗi | Thử đọc báo cáo của UID khác | Bị từ chối `unauthorized` | Chưa chạy | Storage chưa bật |
| FB-07 | Storage, lỗi | Tắt mạng rồi xuất báo cáo | Báo lỗi trong khoảng 30 giây, Thử lại được | Chưa chạy | Storage chưa bật |
| FB-08 | FCM | Gửi tin khi app đang mở | SnackBar, có trong S12 | Đạt một phần | 04/11 19:27, tin đến và có trong S12. Chưa quan sát trực tiếp SnackBar, tin thử không có `route` |
| FB-09 | FCM | Gửi tin khi app ở nền, chạm vào | Mở đúng màn trong `route` | Đạt | 04/11 19:32, chạm thông báo mở bài `who-diverse`, S12 lưu `route` và đánh dấu đã đọc |
| FB-10 | FCM | Gửi tin khi app đã đóng, chạm vào | Mở đúng màn, có trong S12 | Đạt | 04/11, sau commit `c5d9d5e`, chạm thông báo mở bài `who-diverse`, Back về S03, tin có trong S12. Xem ghi chú về tiến trình nền |
| FB-11 | FCM, lỗi | Từ chối quyền trên Android 13+ | S12 có banner, app vẫn dùng được | Đạt | 05/11, S12 hiện banner có nút "Bật thông báo", các màn khác dùng bình thường |
| FB-12 | Analytics | Làm F01, F02, F03 với DebugView | Đủ sự kiện, không có email hay tên | Đạt một phần | 04/11 và 05/11, 16 trên 17 sự kiện trong `analytics-plan.md` đã phát và nhóm đã chụp DebugView. Tham số trong log không có email hay tên. Còn `report_exported` chờ Storage |
| FB-13 | Crashlytics | Bật lỗi lưu bữa rồi lưu | Non-fatal `meal_save_failed` có user ID và key `route` | Đạt phía app | 05/11, app báo "Chưa lưu được bữa ăn", giữ nội dung đã nhập, ghi non-fatal `meal_save_failed`. Cần ảnh Console có User ID và key `route` |
| FB-14 | Crashlytics | Crash thử nghiệm rồi mở lại app | Crash hiện trên Console | Đạt | 04/11 20:07, crash `FirebaseCrashlyticsTestCrash`, nhóm đã thấy trên Console cùng non-fatal `demo_non_fatal` |
| FB-15 | Remote Config | Đổi `max_knowledge_results` thành 1 | S08 còn 1 bài, không cần build lại | Đạt | 04/11 19:05, app tải giá trị mới, S08 còn 1 bài. `suggested_recipes_enabled = false` ẩn "Món gợi ý" ở S06. Cần ảnh Console trước và sau khi đổi |
| FB-16 | Remote Config, lỗi | Tắt mạng rồi mở app | App vẫn chạy bằng giá trị đã lưu hoặc mặc định | Đạt | 05/11, còn cấu hình đã lưu thì giữ `1`/`false`. Khi xóa cache trên emulator thì dùng mặc định `3`/`true` |

Ghi chú:

- **Lỗi tìm được và đã sửa:**
  - FB-03: khi mất mạng, Google trả về mã hủy nên app báo nhầm là người dùng đã hủy. Commit `3813108` kiểm tra mạng khi nhận mã này. Chưa thử trường hợp đang mất mạng mà người dùng hủy thật; theo mã, app sẽ báo mất mạng.
  - FB-10: khi mở app từ thông báo lúc app đã đóng, `route` trong dữ liệu tin được Flutter dùng thẳng làm màn khởi đầu và bỏ qua `resolvePushRoute`. Commit `c5d9d5e` bỏ cơ chế này trong `MainActivity`.
- **FB-05:** khi chưa có bucket, ngày 05/11 18:08 app báo "Chưa tải được báo cáo lên. Vui lòng thử lại", có nút Thử lại, ghi `report_export_failed` với `code=object-not-found` và non-fatal cùng tên. Đây là lỗi thật, không phải lỗi giả lập.
- **FB-10:** ở lần thử đạt, tiến trình nền của app vẫn còn chạy dù giao diện đã đóng. Lần tiến trình đã tắt hẳn thì `route` bị nhập thiếu `/` ở đầu, nên app về S12 đúng quy tắc. Tổ hợp tiến trình tắt hẳn với `route` hợp lệ chưa được thử riêng.
- **Ca thêm ngoài bảng:** ngày 05/11 đã thử lỗi lưu kế hoạch (báo "Chưa lưu được kế hoạch", ghi `plan_save_failed`) và hủy bữa đang nhập (ghi `meal_draft_discarded`).
- **Emulator:** ngày 04/11, emulator mất DNS làm Remote Config báo lỗi tải cấu hình. Khởi động emulator với `-dns-server 8.8.8.8,1.1.1.1` thì hết lỗi.

## Ca kiểm thử ARTEMIS

Đề yêu cầu tối thiểu 10 ca, mỗi ca chạy ít nhất 3 lần, có tỷ lệ đạt và nhật ký. Ô kết quả để trống cho đến khi có lần chạy thật. PDF hướng dẫn không có link cài đặt ARTEMIS nên cần hỏi giảng viên.

Điều kiện chung: dùng tài khoản Google kiểm thử đã đăng nhập sẵn trên thiết bị, trừ AR-01.

| ID | Loại | Yêu cầu cho agent | Tiêu chí đạt | Lần 1 | Lần 2 | Lần 3 | Tỷ lệ đạt |
|---|---|---|---|---|---|---|---|
| AR-01 | F01, Android gốc | Mở app từ đầu, bắt đầu, đăng nhập Google qua hộp chọn tài khoản của hệ thống, chọn một mục tiêu, hoàn tất | Thấy màn "Chào …" | | | | |
| AR-02 | F01, nhánh lỗi | Ở màn mục tiêu, không chọn gì, bấm Hoàn tất | Thấy "Hãy chọn ít nhất một mục tiêu." và vẫn ở màn đó | | | | |
| AR-03 | F02 | Ghi bữa trưa "Cơm rau" cho hôm nay | Nhật ký có "Cơm rau", có "Đã lưu bữa ăn" | | | | |
| AR-04 | F02, nhánh lỗi | Mở Thêm bữa ăn, bấm Lưu khi chưa nhập gì | Thấy lỗi loại bữa và lỗi món ăn, không tạo bản ghi | | | | |
| AR-05 | F02 | Nhập nội dung, bấm Back, chọn Bỏ thay đổi | Về Nhật ký, không có bản ghi mới | | | | |
| AR-06 | F03 | Từ Kiến thức, đọc bài đầu tiên, lập kế hoạch, thêm món vào bữa sáng hôm nay | Kế hoạch có món ở bữa Sáng và thông báo đã thêm | | | | |
| AR-07 | F03 | Thay món đã có ở bữa Sáng, chọn Hủy | Món cũ được giữ | | | | |
| AR-08 | Tìm kiếm | Tìm "dia an", sau đó tìm một cụm không có, rồi xóa tìm kiếm | Có kết quả, rồi màn rỗng, rồi đủ danh sách | | | | |
| AR-09 | Android gốc | Bấm Thông báo, chạm "Bật thông báo", trả lời hộp thoại quyền của hệ thống | Trạng thái đúng với lựa chọn | | | | |
| AR-10 | Android gốc | Mở bài WHO, bấm "Xem nguồn WHO" rồi quay lại app bằng nút Back của hệ thống | Mở trình duyệt, quay lại đúng bài viết | | | | |
| AR-11 | Nhánh lỗi | Ở Tài khoản, bật lỗi lưu bữa, ghi một bữa, rồi bấm Thử lại | Thấy "Chưa lưu được bữa ăn.", sau đó lưu được đúng một bản ghi | | | | |
| AR-12 | Auth | Đăng xuất, bấm Back của hệ thống | Không vào lại được màn bảo vệ | | | | |

Ngoài ra cần một phiên khám phá 15 đến 30 phút. Ghi lại lỗi tìm được vào bảng sau.

| Thời điểm | Màn | Mô tả | Mức độ | Hướng xử lý |
|---|---|---|---|---|
| | | | | |

## Danh sách bằng chứng cần thu thập

- [ ] Ảnh Console của cả 6 dịch vụ: Users, Files và Rules, Messaging, DebugView, Crashlytics, Remote Config
- [ ] Token FCM và thiết bị đã dùng để gửi thử
- [ ] Nhật ký ARTEMIS và tỷ lệ đạt
- [ ] PR có AI Code Review với ít nhất 5 phát hiện gắn dòng mã, thuộc ít nhất 2 nhóm
- [ ] Bảng chấp nhận, điều chỉnh, bác bỏ kèm lý do, và ít nhất 3 commit sửa
- [ ] Báo cáo PDF 8 đến 12 trang, slide PDF 12 đến 15 trang, video 5 đến 10 phút
