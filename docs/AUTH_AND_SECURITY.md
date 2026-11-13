# Xác thực và phân quyền

Google Sign-In tạo Firebase session trên Flutter/Admin. Firebase SDK cấp và làm mới **Firebase ID token**. Token này chứng minh danh tính với Worker; nó khác FCM registration token và Google OAuth access token của service account.

Worker kiểm tra RS256 signature bằng Google public keys, kid và key rotation, issuer `https://securetoken.google.com/<project>`, audience, exp/iat/auth_time và subject. Unknown kid làm mới key cache từ Google. UID chỉ lấy từ JWT; request body không thể tự cấp owner/Admin. Production không có biến bypass authentication.

Mọi truy vấn nghiệp vụ chứa UID đã xác minh. Owner khác nhận 404 đối với record/file để giảm tiết lộ. Admin routes kiểm tra active allowlist ở D1 mỗi request. Không có API tự cấp Admin. Cấp quyền bằng quy trình chủ dự án trong DEPLOYMENT_GUIDE.md; thu hồi bằng active=0. Admin web chỉ là UI, server là ranh giới bảo vệ.

CORS chỉ nhận same origin hoặc ADMIN_ORIGIN chính xác. Rate mặc định 120 request/phút/UID. Body tối đa 64KiB; giới hạn danh sách/sync/provider; Zod strict chặn trường owner/Admin không hợp lệ. SQL inputs luôn bind. API lỗi/log chỉ chứa code/request ID; không log Firebase/FCM token, private key hay request body.

Cloudinary authenticated asset, signed ticket, public ID do server tạo, receipt/provider metadata, owner check và URL có hạn. Không dùng secure_url công khai để thay cho phân quyền. Private download/PDF delivery của gói đang sử dụng vẫn cần kiểm chứng trực tiếp. Ai đã nhận URL có thể dùng đến khi URL hết hạn; không tuyên bố URL là session-bound.

Device transfer yêu cầu secret riêng của installation (server chỉ lưu hash) và generation tăng. Logout cũ không được vô hiệu token đã chuyển sang tài khoản mới. Khi offline không thể cam kết server đã unregister; app xóa session RAM và ngăn xử lý payload targetUid khác. Không đưa dữ liệu nhạy cảm vào nội dung push.

SQLite/file local nằm trong Android app sandbox, tách theo UID; không được quảng cáo là mã hóa dữ liệu at-rest. Cache cũ vẫn lưu trên máy theo owner sau logout để offline phục hồi; nếu cần thiết bị dùng chung với yêu cầu cao hơn phải thêm encryption/secure storage và chính sách xóa cache.

Secret scan: `npm run security` kiểm tra pattern và chỉ in tên file; Firebase client config được cho phép ở đúng file cấu hình. `npm audit --audit-level=high` cho backend/Admin. Các kiểm tra này không thay thế pentest hoặc review credential history. Tests security nằm trong server/test/api.spec.ts và Flutter tests sync/API/notifications.
