# FCM: cấu hình, nguyên lý và nghiệm thu

**Registration token** là địa chỉ gửi của một bản cài app với Firebase Messaging. FCM cấp token qua SDK; đây không phải UID, Firebase ID token hay Firebase installation ID. Firebase SDK quản lý token trên thiết bị; app lấy token rồi đăng ký với backend để server biết gửi tới installation nào của tài khoản nào. Token có thể đổi.

Client: `firebase_messaging_service.dart` lấy registration token; token refresh stream đăng ký lại. SyncEngine.registerDevice tuần tự hóa các request, gửi token + installationId + secret proof + generation tăng. Backend `notifications.ts` lưu token, quản lý ownership và vô hiệu registration cũ. Unregister tạo tombstone inactive kể cả khi request đăng ký đầu tiên chưa tới server; registration cùng generation tới trễ không được kích hoạt lại. Không đưa token đầy đủ vào UI Admin/log.

Backend cần GOOGLE_SERVICE_ACCOUNT_JSON thuộc đúng project. Cấu hình quyền gửi FCM phù hợp tại project; không tự thay IAM/billing trong triển khai này. Service account ký JWT assertion lấy OAuth access token với scope `https://www.googleapis.com/auth/firebase.messaging`. Worker gửi HTTPS POST `https://fcm.googleapis.com/v1/projects/<projectId>/messages:send`. Client Firebase ID token không thể thay credential server cho request này.

Payload gồm notification title/body và data route/notificationId/targetUid. Android foreground đưa tin vào lịch sử/SnackBar; background/terminated do Firebase SDK + notification tray và handler mở app. Background queue theo UID + event ID, không gộp nhầm sang tài khoản khác. Routes được whitelist. Lịch sử server cập nhật opened khi owner mở tin; local vẫn mở được khi endpoint lỗi và có thông báo phù hợp.

Admin → Gửi thông báo → nhập UID nhận/title/body/route → Xem trước → Xác nhận. requestKey không đổi khi thử lại cùng nội dung. Backend lưu campaign/delivery trước send, tối đa 5 installation/target, trả trạng thái từng thiết bị. `accepted` = FCM API chấp nhận; không khẳng định đã tới/hiển thị trên máy. `openedAt` là lần owner xác nhận mở. Lỗi tạm thời 429/5xx tối đa 3 attempts; network outcome không rõ được đánh dấu unknown, không tự gửi lại gây trùng. UNREGISTERED/SENDER_ID_MISMATCH làm inactive đúng token.

Checklist thiết bị thật:

1. Build với API_BASE_URL staging, Google sign-in, cấp quyền Android 13+; thấy device active trên Admin.
2. Gửi từ Admin khi foreground; kiểm tra SnackBar/lịch sử/route và API accepted riêng biệt.
3. Home app về background, gửi rồi chạm notification tray; kiểm tra destination và opened.
4. Đóng app theo cách hệ điều hành cho phép nhận push (không force-stop), gửi và mở; kiểm tra initialMessage.
5. Từ chối quyền: app vẫn chạy, UI có hướng dẫn; bật lại rồi registration.
6. Đổi token, logout/login tài khoản B, kiểm tra đúng owner; stale unregister A không vô hiệu B.
7. Kiểm tra thêm một lượt gửi từ Firebase Console theo guide; dùng targetUid/route phù hợp nếu gửi data.

Lưu request ID/campaign ID, thời điểm, app/device/Android version, ảnh Admin và điện thoại. Token chỉ giữ ở evidence riêng đã che, không đưa lên Git. Hiện chưa có bằng chứng giao nhận thật cho backend mới.
