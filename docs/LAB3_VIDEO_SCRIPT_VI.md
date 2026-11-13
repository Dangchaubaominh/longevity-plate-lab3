# Kịch bản nhóm tự quay 5–10 phút

1. 0:00–0:40: CPH2637 thật, giới thiệu3flow và kiến trúc Flutter/MVVM→Worker/D1→Cloudinary.
2. 0:40–2:00: Google login/cancel; chọn mục tiêu; ghi một bữa có ảnh gallery/camera; chỉ validation khi thiếu trường.
3. 2:00–3:00: Kiến thức→công thức→kế hoạch; thử thay món rồi Hủy, chứng minh món cũ giữ nguyên.
4. 3:00–4:00: Xuất PDF, tiến độ, URL private; mở tệp. Giải thích ký upload/owner từ UID trong JWT; không lộ secret.
5. 4:00–5:20: Admin Google login; gửi push riêng tài khoản demo; điện thoại nhận và chạm→Nhật ký; lịch sử. Nêu onMessage/onMessageOpenedApp/getInitialMessage.
6. 5:20–6:20: Dev mở DebugView và Crashlytics; show các event/parameters, UID/route. Nút non-fatal vẫn dùng app; nút crash có xác nhận rồi app dừng. Mở lại để upload. Có thể cắt phần chờ nhưng giữ timestamp.
7. 6:20–7:20: Admin web refresh Crashlytics, mở issue/events thật. Admin chỉ cần Web, Dev dùng Console.
8. 7:20–8:10: Console RC đổi max_knowledge_results và suggested_recipes_enabled; app list/recipe suggestions đổi không rebuild, sau đó khôi phục3/true.
9. 8:10–9:00: Show169automated checks, CI, ARTEMIS10case×3+log và bảng16PASS/14FAIL; giải thích false positive được loại. Show AI reviewfindings/decisions/commits.

Câu hỏi phải giải thích: FCM token do FCM qua SDK cấp cho app instance, SDK quản lýcache; app getToken/onTokenRefresh→đăng kýserver theoUID; server/src/notifications.ts gửiHTTPv1. Firebase ID token khácFCMtoken. Khi retry, SQLitetransaction/outbox+opId+revision ngăn recordtrùng. Crashlytics có độ trễ sau reopen; không suy ra crash thật chỉ từ sự kiện bấm nút.

Chụp bổ sung các ảnh Console được liệt kê trong ASSIGNMENT_ACCEPTANCE.md khi thực hiện các bước trên. Không quay mật khẩu/private key/Cloudinary API Secret/JWT/FCM token hoặc ứng dụng cá nhân.
