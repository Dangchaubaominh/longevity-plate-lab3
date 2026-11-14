# Chính sách lưu tệp

Lab3 đang dùng Cloudinary thay Firebase Storage theo giảng viên. Quyền thực thi nằm ở Worker: Firebase ID token → UID owner, xác minh upload ticket/receipt/provider metadata và cấp URL tải có hạn. Xem `server/src/media.ts`, `AUTH_AND_SECURITY.md` và `FILE_UPLOAD_FLOW.md` trong docs.

`storage.rules` là chính sách tham chiếu được nộp cùng source theo guide p9–10, cho phương án Firebase Storage: chỉ owner đọc/ghi/xóa PDF dưới `reports/{uid}/`, tối đa10MiB; mọi path khác bị từ chối. File này không được tự deploy và không kiểm soát tài sản Cloudinary. Không có quy tắc mở công khai.
