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

Lưu request ID/campaign ID, thời điểm, app/device/Android version, ảnh Admin và điện thoại. Token chỉ giữ ở evidence riêng đã che, không đưa lên Git. Đối chiếu kết quả thiết bị theo từng phiên, không suy ra đã nhận từ `accepted`.

## Khắc phục UNREGISTERED và gửi lại

`UNREGISTERED` nghĩa là FCM đã từ chối registration token không còn hợp lệ. Backend vô hiệu đúng token bị từ chối; không tự đổi delivery thành thành công. Mở app với tài khoản người nhận, cấp quyền thông báo và có mạng để đăng ký thiết bị hiện tại, rồi kiểm tra tab Thiết bị.

Admin giữ cùng requestKey khi thử lại một yêu cầu có kết quả chưa rõ để tránh gửi trùng. Trước bản sửa ngày 14/11/2026, key này cũng bị giữ sau khi toàn bộ delivery đã thất bại: gửi lại cùng nội dung luôn trả campaign lỗi cũ, kể cả khi điện thoại đã đăng ký token mới. Bản sửa hiện nút **Xem trước lượt gửi mới** khi tất cả delivery là `failed`; chỉ gửi campaign mới sau khi Admin xác nhận. Nếu có delivery accepted/pending/sending/retry/unknown, giữ key cũ. Nếu lượt mới timeout thì retry vẫn dùng key của lượt mới đó.

Chẩn đoán ngày 14/11/2026: D1 có lượt D01 bị UNREGISTERED với registration cũ; registration mới của cùng người nhận xuất hiện sau lượt lỗi. Token cache trên CPH2637 khớp registration active trong D1 và FCM validate_only trả HTTP200 lúc 11:59:32 UTC+7. Đây là bằng chứng token hiện tại được FCM chấp nhận, chưa chứng minh điện thoại đã nhận thông báo. Không có đủ log để kết luận vì sao token cũ bị FCM hủy.

Sau khi cập nhật Admin: Ctrl+F5, mở điện thoại và giữ kết nối mạng, gửi lại bằng lượt mới; kiểm tra notification trên điện thoại và openedAt trong Lịch sử gửi. Lỗi âm thanh data:audio bị CSP chặn trên Console không phải phản hồi UNREGISTERED từ FCM; source Admin không phát âm thanh và không cần nới CSP để gửi push.

Kiểm chứng bản sửa: 17/17 RTL/Vitest, lint/typecheck/build đạt; 5/5 Playwright trên Chrome cài sẵn với profile kiểm thử riêng, có ca UNREGISTERED → xác nhận lượt mới. Chromium headless đi kèm Playwright chưa được cài nên lần chạy mặc định không khởi tạo được trình duyệt; lần Chrome thực tế đạt. Staging version `a0322c1d-0a24-470c-becc-c19367c7ce19`, deploy ngày 14/11/2026; lúc 12:07 UTC+7 HTML/asset/health đều HTTP200 và hash bundle khớp build local. Sau cập nhật, người dùng xác nhận web chấp nhận và điện thoại đã nhận tin. D1 ghi nhận accepted/openedAt của các tin retest; xem docs/build-evidence/manual-device/2026-11-14/RESULTS.md để biết giới hạn bằng chứng.

Nguồn: [FCM error codes](https://firebase.google.com/docs/cloud-messaging/error-codes).
