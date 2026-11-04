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

| ID | Dịch vụ | Bước | Kỳ vọng | Kết quả | Bằng chứng |
|---|---|---|---|---|---|
| FB-01 | Auth | Đăng nhập Google thành công | Vào S02 hoặc S03, có user trên Console | | |
| FB-02 | Auth, lỗi | Hủy hộp chọn tài khoản | Ở lại S10, báo đã hủy | | |
| FB-03 | Auth, lỗi | Tắt mạng rồi đăng nhập | Báo mất mạng hoặc lỗi kết nối | | |
| FB-04 | Auth | Đăng xuất rồi Back | Không vào lại được màn bảo vệ | | |
| FB-05 | Storage | Xuất báo cáo | Thấy tiến độ, URL, tệp trên Console | | |
| FB-06 | Storage, lỗi | Thử đọc báo cáo của UID khác | Bị từ chối `unauthorized` | | |
| FB-07 | Storage, lỗi | Tắt mạng rồi xuất báo cáo | Báo lỗi trong khoảng 30 giây, Thử lại được | | |
| FB-08 | FCM | Gửi tin khi app đang mở | SnackBar, có trong S12 | | |
| FB-09 | FCM | Gửi tin khi app ở nền, chạm vào | Mở đúng màn trong `route` | | |
| FB-10 | FCM | Gửi tin khi app đã đóng, chạm vào | Mở đúng màn, có trong S12 | | |
| FB-11 | FCM, lỗi | Từ chối quyền trên Android 13+ | S12 có banner, app vẫn dùng được | | |
| FB-12 | Analytics | Làm F01, F02, F03 với DebugView | Đủ sự kiện, không có email hay tên | | |
| FB-13 | Crashlytics | Bật lỗi lưu bữa rồi lưu | Non-fatal `meal_save_failed` có user ID và key `route` | | |
| FB-14 | Crashlytics | Crash thử nghiệm rồi mở lại app | Crash hiện trên Console | | |
| FB-15 | Remote Config | Đổi `max_knowledge_results` thành 1 | S08 còn 1 bài, không cần build lại | | |
| FB-16 | Remote Config, lỗi | Tắt mạng rồi mở app | App vẫn chạy bằng giá trị đã lưu hoặc mặc định | | |

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
