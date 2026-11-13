# Upload ảnh và báo cáo PDF

1. Camera/gallery → chuẩn hóa JPEG tối đa 1600px, 5MiB, xóa metadata qua decode/re-encode; file được copy vào sandbox theo UID.
2. Repository lưu bữa + outbox trong transaction SQLite, hiển thị chờ đồng bộ. Không phụ thuộc upload thành công để giữ bữa ăn.
3. SyncEngine push meal bằng stable ID/opId/baseVersion. Sau ack mới upload ảnh.
4. Backend `/media/sign` xác minh owner, meal tồn tại và mealVersion mong đợi; tạo asset ID ổn định từ UID/kind/meal/content hash.
5. Ticket ký SHA-1 theo Cloudinary, type=authenticated, overwrite=false, allowed_formats jpg/pdf. Cloudinary API secret ở Worker.
6. Flutter thử reconcile trước để phục hồi response đã mất. Nếu provider báo chưa có file, upload multipart trực tiếp Cloudinary và báo tiến độ bytes gửi.
7. Worker reconcile/complete đọc Cloudinary Admin API và kiểm tra public ID, type, resource type, format, version và bytes. Receipt complete còn kiểm tra signature. Provider metadata mới là nguồn kích thước/định dạng; client hash chỉ là định danh dedup.
8. D1 batch gắn đúng revision, chỉ một ready photo/bữa; ảnh cũ tombstone, lên lịch xóa. Meal revision/change tăng để thiết bị khác thấy attachment.
9. Flutter lưu asset ID, dùng URL download ký 15 phút và cache file theo UID. Không lưu URL có hạn làm định danh bền.

PDF giữ nguyên nội dung ReportBuilder, giới hạn 10MiB, folder reports/UID; path ảnh meal_photos/UID. ConnectedReportStorage hoàn tất khi server xác nhận rồi mới cấp link. Chế độ legacy vẫn dùng CloudinaryReportStorageService và hai API PDF cũ.

Retry an toàn nhờ public ID ổn định, overwrite=false, cached operation và reconcile. Không biến Cloudinary HTTP 200 thành dữ liệu meal đã hoàn tất khi D1 chưa gắn asset. Nếu bữa thay đổi trong lúc upload: conflict, giữ file local và yêu cầu chọn bản. Expired/tombstoned asset không được confirm lại để hồi sinh. Cleanup trì hoãn ít nhất đến khi ticket hết khả năng replay; cron xử lý tối đa 3 job/lần, tối đa 3 attempts. Không xóa file local chưa được commit thành công vì lỗi mạng.

Ảnh cloud bị xóa không tự re-upload ảnh cache cũ. Thay ảnh ở thiết bị khác làm mất cache path cũ khi pull. Khi một ảnh local chưa upload gặp attachment khác trên server, giữ pending và hiển thị lựa chọn; không tự thay ảnh.

Nghiệm thu thật còn cần: upload JPEG/PDF; kiểm tra asset authenticated trong Cloudinary; mở URL hợp lệ; thử hết hạn/khác UID; kiểm tra PDF delivery account; mất mạng giữa upload/confirm rồi retry. Các provider trong tests local được mock, không là bằng chứng Cloudinary thật.
