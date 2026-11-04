# Đối chiếu với thiết kế Lab 2

Nguồn thiết kế là repo `prm323-lab2`: `design/DESIGN.md`, `design/screen-spec.md`, `ux/user-flow.md`, `design/figma-completion/design-system-v2/TOKENS.json` và các màn trong `assets/stitch`.

## Màn hình

| Màn | Route | View | ViewModel | Nguồn |
|---|---|---|---|---|
| S01 Chào mừng | `/welcome` | `onboarding_screens.dart` | | Lab 2 |
| S02 Chọn mục tiêu | `/goals` | `onboarding_screens.dart` | `GoalViewModel` | Lab 2 |
| S03 Hôm nay | `/home` | `home_screen.dart` | `HomeViewModel` | Lab 2 |
| S04 Nhật ký | `/log` | `meal_screens.dart` | `MealLogViewModel` | Lab 2 |
| S05 Thêm bữa ăn | `/log/add` | `meal_screens.dart` | `AddMealViewModel` | Lab 2 |
| S06 Kế hoạch tuần | `/plan`, `/article-plan` | `plan_screens.dart` | `PlannerViewModel` | Lab 2 |
| S07 Chi tiết món | `/plan/recipe/:id` | `plan_screens.dart` | `RecipeViewModel` | Lab 2 |
| S08 Thư viện | `/library` | `library_screens.dart` | `LibraryViewModel` | Lab 2 |
| S09 Chi tiết bài | `/library/:id` | `library_screens.dart` | `ArticleViewModel` | Lab 2 |
| S10 Đăng nhập | `/login` | `onboarding_screens.dart` | `SessionViewModel` | Thêm cho Lab 3 |
| S11 Tài khoản | `/account` | `account_screen.dart` | `AccountViewModel` | Thêm cho Lab 3 |
| S12 Thông báo | `/notifications` | `notifications_screen.dart` | `NotificationsViewModel` | Thêm cho Lab 3 |

## Luồng

| Luồng | Đường đi | Kiểm thử |
|---|---|---|
| F01 Onboarding | S01 → S10 → S02 → S03 | `auth_and_guard_test.dart` |
| F02 Ghi nhận bữa | S03 → S04 → S05 → S04 | `flows_test.dart` |
| F03 Kiến thức đến kế hoạch | S08 → S09 → S06 → S07 → S06 | `flows_test.dart` |

## Khác biệt so với Lab 2

| # | Khác biệt | Lý do |
|---|---|---|
| 1 | Thêm S10, S11, S12. Lab 2 ghi rõ không có đăng nhập, hồ sơ hay màn thứ mười | Lab 3 bắt buộc Auth, đăng xuất, lịch sử thông báo và khu vực trình diễn |
| 2 | F01 có thêm bước đăng nhập giữa S01 và S02 | Yêu cầu chặn truy cập và tách dữ liệu theo tài khoản |
| 3 | Thêm nút "Xuất báo cáo PDF" ở S04 | Lab 3 yêu cầu tải tệp lên Cloud Storage |
| 4 | Header của tab có thêm chuông và tài khoản | Cần lối vào S11, S12 |
| 5 | Dùng font Roboto thay vì Noto Sans | Repo Lab 2 không có tệp TTF của Noto Sans. Roboto có sẵn và hỗ trợ tiếng Việt |
| 6 | Bữa do người dùng nhập dùng icon thay cho ảnh | Dữ liệu nhập tay không có ảnh |
| 7 | S03 hiển thị dữ liệu thật thay cho số cố định, thêm trạng thái chưa có bữa và lỗi tải | Bản thiết kế chỉ vẽ trạng thái có dữ liệu |
| 8 | "Chọn món" mở bottom sheet chọn công thức rồi tới S07 | Thiết kế chưa mô tả bước này |
| 9 | Thêm 2 công thức và nội dung bài "Chuẩn bị bữa ăn cho ngày bận rộn" | Cần đủ dữ liệu để chọn và đọc. Tất cả gắn nhãn minh họa, không gán cho WHO hay Harvard |
| 10 | S11 cho đổi mục tiêu qua route `/goals?edit=true` | Câu trong S02 hứa người dùng đổi được mục tiêu sau này |

## Ràng buộc nội dung giữ nguyên từ Lab 2

- Không có claim y tế, calo hay điểm sức khỏe.
- Nội dung minh họa không gán cho WHO hoặc Harvard. Bài từ nguồn ngoài có nhãn "Tham khảo", ngày nguồn và link gốc.
- Trạng thái lỗi và đã chọn có icon hoặc chữ, không chỉ dùng màu.

## Việc cần lưu ý

Ảnh món được cắt từ PNG Stitch trong repo Lab 2. README của Lab 2 ghi giấy phép ảnh Stitch chưa được xác minh. Cần xác minh hoặc thay ảnh trước khi công khai rộng rãi.
