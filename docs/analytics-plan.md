# Kế hoạch Analytics

Mỗi sự kiện dưới đây trả lời một câu hỏi sản phẩm và gắn với một bước trong luồng của Lab 2. Tên hằng nằm ở `AnalyticsEvents` trong [service_interfaces.dart](../lib/services/service_interfaces.dart).

## Nguyên tắc

- Tên sự kiện dùng tên khuyến nghị của Firebase nếu có (`login`, `tutorial_begin`, `tutorial_complete`, `select_content`), còn lại dùng `snake_case`.
- Giá trị tham số chỉ là `String` hoặc `int`, vì SDK không nhận `bool`.
- Không gửi email, tên hiển thị, nội dung món ăn hay từ khóa tìm kiếm. Từ khóa có thể chứa thông tin riêng nên `article_search` chỉ gửi số kết quả. Có test kiểm tra điều này.
- User ID là Firebase `uid`, đặt khi trạng thái đăng nhập thay đổi và xóa khi đăng xuất.
- Mọi màn gửi `screen_view` qua listener của router với tên là đường dẫn route.

## Danh sách sự kiện

| Sự kiện | Thời điểm gửi | Tham số (kiểu) | Câu hỏi sản phẩm | Luồng và tiêu chí |
|---|---|---|---|---|
| `login` | Đăng nhập Google thành công (S10) | `method` (String) | Bao nhiêu người vượt qua bước đăng nhập? | F01 |
| `logout` | Bấm Đăng xuất (S11) | | Người dùng có thường xuyên rời tài khoản không? | Auth |
| `tutorial_begin` | Mở S02 lần đầu, không tính khi đổi mục tiêu | | Bao nhiêu người bắt đầu onboarding? | F01 |
| `tutorial_complete` | Lưu mục tiêu thành công lần đầu | `goal_count` (int), `duration_ms` (int) | Có đạt SC01 không? Người dùng chọn bao nhiêu mục tiêu? | F01, SC01 ≤ 60s |
| `meal_add_start` | Bấm "Thêm bữa ăn" (S04) | | Bao nhiêu người bắt đầu ghi bữa? | F02 |
| `meal_saved` | Lưu bữa thành công (S05) | `meal_type` (String), `duration_ms` (int) | Có đạt SC02 không? Bữa nào được ghi nhiều nhất? | F02, SC02 ≤ 45s |
| `meal_save_failed` | Lưu bữa thất bại (S05) | `meal_type` (String) | Tỷ lệ lỗi khi lưu là bao nhiêu? | F02, nhánh lỗi |
| `meal_draft_discarded` | Xác nhận "Bỏ thay đổi" (S05) | | Người dùng có bỏ giữa chừng nhiều không? | F02 |
| `select_content` | Mở S09 hoặc mở bài nguồn ngoài (S08) | `content_type` (String), `item_id` (String) | Bài nào được đọc nhiều? | F03 |
| `article_search` | 0,8 giây sau khi ngừng gõ tìm kiếm | `result_count` (int) | Tìm kiếm có hay ra kết quả rỗng không? | F03 |
| `plan_from_article` | Bấm "Lập kế hoạch bữa ăn" (S09) | `item_id` (String) | Bài nào dẫn người dùng tới lập kế hoạch? | F03 |
| `recipe_view` | Tải xong S07 | `item_id` (String) | Món nào được quan tâm? | F03 |
| `plan_slot_saved` | Lưu kế hoạch thành công (S07) | `meal` (String), `action` (String: `add`, `replace`), `source` (String: `article`, `planner`), `duration_ms` (int) | Có đạt SC03 không? Người dùng thêm mới hay thay món? | F03, SC03 ≤ 120s |
| `plan_save_failed` | Lưu kế hoạch thất bại (S07) | `meal` (String) | Tỷ lệ lỗi khi lưu kế hoạch? | F03, nhánh lỗi |
| `report_exported` | Tải báo cáo lên Storage thành công | `meal_count` (int), `size_kb` (int) | Tính năng báo cáo có được dùng không? | Storage |
| `report_export_failed` | Tạo hoặc tải báo cáo thất bại | `code` (String) | Lỗi nào hay gặp nhất? | Storage, nhánh lỗi |
| `notification_opened` | Chạm thông báo hoặc mục trong S12 | `source` (String: `system`, `foreground`, `history`), `target` (String) | Thông báo có dẫn người dùng vào app không? | FCM |

## Cách đo các tiêu chí

- **SC01:** `duration_ms` của `tutorial_complete` tính từ lúc mở S02, nên chưa gồm thời gian ở S01 và S10.
- **SC02:** `duration_ms` của `meal_saved` tính từ lúc mở S05.
- **SC03:** `duration_ms` của `plan_slot_saved` khi `source = article` tính từ lúc bấm CTA ở S09. Tiêu chí của Lab 2 tính sau khi đọc xong nên thời gian đọc không nằm trong số này.

## Kiểm tra bằng DebugView

```bash
adb shell setprop debug.firebase.analytics.app com.longevityplate.longevity_plate
```

Sau đó mở Firebase Console, vào Analytics, DebugView và thực hiện F01, F02, F03. Tắt chế độ debug bằng:

```bash
adb shell setprop debug.firebase.analytics.app .none.
```
