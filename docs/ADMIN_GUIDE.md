# Hướng dẫn Web Admin

Web staging: https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev . Tài khoản Google người dùng chỉ định đã được kiểm tra email verified/provider Google và cấp allowlist server-side; người dùng đã xác nhận vào dashboard.

Chạy `cd admin; npm ci; npm run dev`. Worker local ở 127.0.0.1:8787; Vite proxy `/api` tới Worker. Worker cần FIREBASE_WEB_CONFIG từ **Firebase Web app** cùng project, Google sign-in và auth domain phù hợp. Không dùng Android options hoặc service-account JSON làm Web config.

Đăng nhập Google. Web gọi `/me`; chỉ active Admin trong D1 mới vào dashboard. Tài khoản chưa được cấp quyền hiện màn từ chối. Việc sửa JavaScript/browser không cấp quyền server. Không có chức năng người dùng tự cấp Admin.

| Màn | Cách dùng |
|---|---|
| Tổng quan | Xem số user/meal/plan/device/campaign từ D1 |
| Người dùng | Tìm UID/tên, phân trang; chỉ thông tin cơ bản và thống kê cần thiết |
| Thiết bị | Xem owner, platform/version, active; không thấy FCM token |
| Gửi thông báo | Nhập UID từ Users, title/body, route; preview rồi confirm |
| Lịch sử gửi | Xem campaign và kết quả từng thiết bị; accepted khác delivered |
| Báo cáo PDF | Metadata tệp mới, không tự mở PDF riêng của người khác |
| Crashlytics | Refresh từ Firebase, lọc loại lỗi khi có, xem issue/event và nguồn/thời gian |
| Nhật ký quản trị | Theo dõi action/actor/target/request/time |

Lỗi mạng/config/quyền có thông báo; không có dữ liệu hiển thị empty state. Bố cục responsive kiểm thử bằng Playwright ở desktop và 390px. UI dùng tiếng Việt, cream/green thống nhất app. React escape dữ liệu nguồn; không render HTML từ provider. CSP chỉ cho Google loader ở apis.google.com/www.gstatic.com, không dùng unsafe-eval; COOP same-origin-allow-popups hỗ trợ đăng nhập Google. Có test browser tái hiện policy để tránh lỗi auth/internal-error do chặn loader.

Build `npm run build` tạo dist; Worker assets phục vụ cùng origin ở staging. Header CSP ở public/_headers. Google loader trên staging đã trả HTTP200, popup accounts.google.com mở được, 0 CSP Google blocks; người dùng đã xác nhận login thật. Nếu đổi project/domain phải chạy lại smoke test; test fixture riêng không thay bằng chứng này.

Tệp `test/harness.*` chỉ là entry của Vite DEV để test giao diện với HTTP fixtures; production index không import và build không đóng gói. Tuyệt đối không deploy Vite dev server/harness làm Admin production.
