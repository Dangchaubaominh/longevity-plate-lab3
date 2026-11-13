# Bộ ca ARTEMIS thực thi trên CPH2637

Đối chiếu guide trang23: tối thiểu10ca, mỗi ca3lượt, bao phủ3flow, lỗi và Android native; đánh giá giá trị quan sát, không chỉ SUCCESS. Bộ thực thi ở scripts/artemis-cases.json. Tài khoản thử được truyền bằng LAB3_ADMIN_EMAIL, không hardcode trong source.

Điều kiện chung: APK ARM64 nối staging, thiết bị CPH2637 Android16 mở khóa và kết nối ADB; Google account đã được chủ máy cho phép; có mạng cho các ca cloud. Nội dung dữ liệu và ảnh kiểm thử có nhãn riêng. Các ca không xóa dữ liệu người dùng. Ảnh fixture ở Pictures/Lab3Verification/lab3-meal-fixture.jpg; khi cần cập nhật timestamp và scan lại để photo picker đưa vào danh sách recent. Giá trị expected phải đối chiếu với hình/UI tree và D1/Cloudinary.

| ID | Điều kiện riêng | Bước chính | Giá trị mong đợi |
|---|---|---|---|
| AR01 | Đang có session Google | Account→logout→Back→Google login→chọn đúng account đã cho phép | Không vào được màn bảo vệ sau logout; login về Home có greeting |
| AR02 | Đã có mục tiêu | Đổi mục tiêu→bỏ mọi lựa chọn→Hoàn tất→Back không lưu | Thấy lỗi yêu cầu ít nhất1mục tiêu; dữ liệu cũ giữ nguyên |
| AR03 | Không có record cùng nhãn của lượt đó | Thêm meal→chọn Bữa trưa→nhập ARTEMIS_AR03_Rn_COM_RAU→đóng keyboard→lưu | Journal/D1 có đúng1record, type=lunch, đúng description |
| AR04 | Form thêm bữa mới | Không chọn loại/nhập món→Save→quan sát lỗi loại→swipe UP để xem lỗi món | Cả hai lỗi hiện; không có record mới; không coi thấy1lỗi là đạt cả ca |
| AR05 | Form mới | Nhập ARTEMIS_AR05_Rn_DISCARD→Back→Bỏ thay đổi | Dialog hiện; nội dung không được lưu |
| AR06 | Slot test20/11/2026/breakfast được xác nhận trống trước chiến dịch | Đọc bài→Lập kế hoạch→recipe→chọn20/11/Sáng→thêm | Recipe xuất hiện đúng slot; các lượt sau có thể giữ/thay cùng fixture |
| AR07 | AR06 đã tạo recipe cho slot test | Mở recipe khác từ Món gợi ý→chọn đúng slot→thêm→Hủy dialog thay thế | Dialog thật và action Hủy; recipe gốc giữ nguyên, không suy ra từ lời agent |
| AR08 | Search trống trong Kiến thức | Tìm dia an→query không khớp ARTEMIS_NO_SUCH_ARTICLE_Rn→xóa | Kết quả có/empty/list trở lại; kiểm tra input và trạng thái UI |
| AR10 | Có bài WHO | Xem nguồn WHO→Android browser→system Back | Đúng nguồn who.int; quay về bài trong app |
| AR13 | Có JPEG fixture nhận dạng được, không dùng ảnh cá nhân khác | Scroll tới nút Chọn từ thư viện→native picker→fixture→preview→meal có nhãn→lưu→xem ảnh | Native picker đã mở; đúng ảnh input, description/type; asset ready và ảnh đọc được |

## Chạy lại và đọc kết quả

Thiết lập LAB3_DEVICE_SERIAL và LAB3_ADMIN_EMAIL trong PowerShell rồi chạy `node scripts/run-artemis-suite.mjs`. Runner dùng official ARTEMIS CLI, cấu hình model riêng,40turn/case và timeout10phút; không bật fake LLM, không thêm bypass trong app/API. Chỉ chạy1agent trên1điện thoại cùng lúc.

Mỗi attempt giữ log riêng. `suite-results.json` ghi kết luận ban đầu của agent. `export-artemis-evidence.py` đọc DataEngine SQLite và screenshots để tìm các quan sát cần thiết; các giá trị tạo meal/asset được đối chiếu thêm với API thật. UI tree có thể thiếu text; khi đó phải xem ảnh, không tự thay missing thành PASS.

Kết quả và tỷ lệ cuối được ghi ở ARTEMIS_RESULTS.md. Phiên khám phá15–30phút được ghi riêng theo thời gian, màn, vấn đề, mức độ và cách xử lý. Các lần đã fail hoặc agent báo sai phải giữ trong lịch sử khi chạy lại.
