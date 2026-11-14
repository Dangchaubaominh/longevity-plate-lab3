# Kết quả nghiệm thu điện thoại — 14/11/2026

Người dùng tự thao tác/chụp ảnh trên OPPO CPH2637, Android 16; Codex đối chiếu ảnh, cập nhật APK và sửa Admin. Giờ dưới đây là UTC+7, đọc từ ảnh/server, không phải giờ chép file.

Hướng dẫn: [DEVICE_MANUAL_TEST_GUIDE_VI.md](../../../DEVICE_MANUAL_TEST_GUIDE_VI.md).

## Bản chạy

- Source tham chiếu: `5495798`; bản sửa Admin đi cùng commit minh chứng này.
- Trước 11:48:44: APK 1.0.0/build 1, chưa thấy nút xóa; chưa xác minh commit build của APK cũ.
- Lúc 11:48:44: cài cập nhật 1.0.1/build 2, ARM64 debug, build từ `5495798` với API_BASE_URL staging. SHA256: `78BD9FD2CD725FB9877881AC86BD85C4F925B85710E3D8913B78707A8D4AC1F2`. Nút xóa xuất hiện, bữa đã có được giữ lại.
- Admin staging sau sửa: `a0322c1d-0a24-470c-becc-c19367c7ce19`. Lúc 12:07 HTML/asset/health HTTP200; hash bundle khớp build local.
- D03/D04/D05 chụp trước cập nhật APK; không gộp tất cả ảnh thành một lượt trên cùng APK.

## Kết quả theo bằng chứng

Không tổng kết bộ ảnh thành 8/8 PASS đầy đủ. ĐẠT PHÍA APP/WEB xác nhận phần quan sát được; phần thiếu được ghi riêng.

| Ca | Kết quả | Quan sát / phần chưa xác minh | Minh chứng |
|---|---|---|---|
| TC-D03 | ĐẠT PHÍA APP | 11:38: bữa tối Lab3_D03_20261114_R1 hiện Đã đồng bộ; thiếu bằng chứng D1 riêng. | [Bữa synced](TC-D03/01-phone-synced.png) |
| TC-D05 | MỘT PHẦN | 11:39: PDF có 13 bữa, dòng cuối đúng bữa D03. Hai ảnh progress/success thực tế giống nhau, đều là thành công; chưa có frame tiến độ. | [PDF chứa bữa D03](TC-D05/03-phone-pdf-meal.png) |
| TC-D04 | ĐẠT PHÍA APP | 11:41: chế độ máy bay, bữa Lab3_D04_R1_Offline chờ đồng bộ; ảnh ADB 11:45 có mạng, cùng bữa đã đồng bộ. Không có video đóng/mở app. | [Offline](TC-D04/01-phone-offline-pending.png), [online](TC-D04/03-phone-online-synced.png) |
| TC-D04b | MỘT PHẦN | 11:49 có bữa D03 và nút xóa; 11:52 có biểu tượng máy bay và Đã xóa bữa ăn. Thiếu D1 deleted_at tương ứng. | [Trước xóa](TC-D04b/01-phone-before-delete.png), [sau xóa](TC-D04b/02-phone-offline-deleted.png) |
| TC-D01 | MỘT PHẦN; lỗi gửi đã sửa | 11:55 UNREGISTERED; sau sửa người dùng xác nhận web chấp nhận và điện thoại nhận tin. D1: Hi accepted lúc 12:08:10, openedAt 12:08:31. Thiếu ảnh route và trạng thái nền của lượt retest. | [Lỗi trước sửa](TC-D01/00-admin-unregistered-before-fix.png) |
| TC-D07 | MỘT PHẦN | 12:09 notification Xin chao trên Android; D1 accepted 12:09:37, openedAt 12:10:00. Thiếu log PID chứng minh process tắt hẳn và ảnh route sau chạm. | [Notification](TC-D07/01-phone-notification.png) |
| TC-D02 | ĐẠT PHÍA WEB | Web báo Không có quyền truy cập; chưa có ảnh request Admin 403 riêng trong phiên này. | [Web từ chối](TC-D02/01-web-access-denied.png) |
| TC-D06 | ĐẠT PHÍA APP | 12:13 nhật ký trống, xuất PDF báo chưa có bữa trong 7 ngày. Không có network trace của điện thoại để chứng minh không gọi media/sign; code/test là bằng chứng bổ trợ. | [Lỗi báo cáo trống](TC-D06/01-phone-empty-report-error.png) |

Lần đọc D1 sau phiên không tìm thấy record theo tên fixture D03/D04; không dùng lần đọc đó để khẳng định đã xác minh record/tombstone. Không suy luận nguyên nhân hoặc sửa dữ liệu để tạo minh chứng.

## Sửa lỗi và kiểm tra

Admin trước đây giữ requestKey sau thất bại toàn bộ, nên gửi lại cùng nội dung trả campaign lỗi cũ dù đã có đăng ký thiết bị mới. Bản sửa cho xem trước/xác nhận lượt mới sau thất bại xác định; giữ key khi timeout/unknown/accepted/partial để tránh gửi trùng. Token hiện tại khớp D1 active và FCM validate_only trả HTTP200; người dùng sau đó xác nhận nhận tin thật.

17/17 RTL/Vitest, lint/typecheck/build đạt; 5/5 Playwright trên Chrome cài sẵn. Có regression gửi lại sau UNREGISTERED và giữ key khi timeout. Xem [FCM_SETUP.md](../../../FCM_SETUP.md).

## Lưu ảnh

10 PNG trong đây giữ nguyên nội dung ảnh đã xem; chỉ sửa tên D03 bị thừa backtick. Ảnh online và trước xóa là ảnh ADB kiểm tra APK. SHA256/kích thước: [evidence-manifest.json](evidence-manifest.json).

Ảnh gốc giữ tại artifacts/manual-device/2026-11-14 (Git bỏ qua). Hai ảnh D05 chứa signed URL và UID không đưa lên Git; cả hai có cùng SHA256 C0D83C35F1DF17F30E9A0D178986F403234779E12F1A10FFC68FCD475EB02BCA. Không commit APK, token, credential, SQLite hoặc UI dump.
