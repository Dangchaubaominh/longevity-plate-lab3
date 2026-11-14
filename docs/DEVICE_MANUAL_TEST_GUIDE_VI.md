# Tự nghiệm thu 8 ca trên điện thoại

Chuẩn bị ngày 14/11/2026, source `5495798`. Tất cả kết quả của phiên này bắt đầu là **CHƯA CHẠY**. Các báo cáo cũ là kết quả tự báo cáo; không dùng thay cho lần nhóm tự xác nhận này. Không ghi PASS chỉ vì có code hoặc unit test.

## Lưu ảnh ở đâu

Gốc project: `D:\PRM393\Lab3\longevity-plate-lab3`.

- Ảnh gốc vừa chép từ điện thoại/máy tính: `artifacts/manual-device/2026-11-14/<mã-ca>/`. Thư mục artifacts được Git bỏ qua.
- Ảnh đã kiểm tra, che thông tin để commit: `docs/build-evidence/manual-device/2026-11-14/<mã-ca>/`.
- Kết quả: `docs/build-evidence/manual-device/2026-11-14/RESULTS.md`.
- Đặt tên theo danh sách từng ca bên dưới. Lần thử tiếp theo thêm hậu tố `-r2`, giữ ảnh lần lỗi và mô tả cách thử lại.
- Ảnh công khai cần đọc được trạng thái và tên bữa test. Che email, UID, FCM token, Bearer token, signed URL và tài khoản/dữ liệu ngoài ca thử. Ảnh gốc giữ nguyên trong artifacts; không sửa trạng thái hoặc nội dung bằng chứng.
- Không dùng `git add .` hoặc `git add -A`. Chỉ stage hướng dẫn và thư mục minh chứng đã kiểm tra.

## Chuẩn bị một lần

1. Ghi model điện thoại, Android, giờ bắt đầu (UTC+7), tên APK và nguồn APK vào RESULTS.md. Hash của APK và commit build chỉ điền khi xác minh được; commit source hiện tại không chứng minh APK đang cài được build từ commit đó.
2. Dùng bản Firebase có `API_BASE_URL` nối cùng staging với web. Không dùng bản có banner OFFLINE, dịch vụ giả lập, hoặc nút xuất PDF chỉ lưu local.
3. Mở Tài khoản: phải có nút **Đồng bộ dữ liệu**. Đăng nhập bằng tài khoản thử A, hoàn tất mục tiêu. Không bật các lỗi giả lập ở Khu vực trình diễn.
4. Bật quyền thông báo cho app trong Android. Mở app khi có mạng để đăng ký thiết bị.
5. Máy tính mở [Admin staging](https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev), đăng nhập tài khoản có quyền Admin. Tab Người dùng: xác định UID của A để gửi; tab Thiết bị: xác nhận thiết bị active. UID chỉ giữ riêng, che trước khi commit ảnh.
6. Có tài khoản thử B chưa ghi bữa trong 7 ngày gần nhất và không có quyền Admin, dùng cho D02/D06. Không xóa dữ liệu thật để tạo trạng thái trống.
7. Chụp bằng Power + Giảm âm lượng trên Android; máy tính dùng Win + Shift + S. Chép ảnh vào thư mục tương ứng. Với trạng thái quá nhanh như tiến độ PDF, quay màn hình ngắn để trích frame; giữ video gốc trong artifacts.

Nếu cần build lại, chạy tại gốc project:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev
Get-FileHash build/app/outputs/flutter-apk/app-debug.apk -Algorithm SHA256
```

Cài cập nhật APK `build/app/outputs/flutter-apk/app-debug.apk` lên điện thoại. Nếu báo sai chữ ký, dừng và kiểm tra bản cài; không gỡ app/xóa dữ liệu để xử lý vội. Web đã deploy có thể khác source vừa pull; ghi nhận giao diện thực tế.

## Thứ tự nên chạy

**D03 → D05 → D04 → D04b → D01 → D07 → D02 → D06.** Xuất PDF trước khi xóa bữa D03. D02/D06 đổi tài khoản nên để cuối.

## TC-D03 — Ghi bữa online

1. Bật mạng, đăng nhập A. Nhật ký → ngày hôm nay → Thêm bữa ăn.
2. Chọn **Tối**, nhập `LAB3_D03_20261114_R1 Com rau`, Lưu. Không cần thêm ảnh món ăn.
3. Chờ nhãn **Đã đồng bộ** trên thẻ bữa, chụp `01-phone-synced.png`. Nhãn **Đã lưu bữa ăn** riêng lẻ chưa đủ chứng minh cloud.
4. Trên máy tính kiểm tra D1 bằng câu SQL ở cuối hướng dẫn; chụp `02-d1-record.png`, thấy đúng description, version và `deleted_at` rỗng.
5. Giữ bữa này cho D05 rồi D04b.

## TC-D05 — PDF chứa đúng bữa vừa ghi

1. Giữ A và mạng đang bật. Nhật ký → Xuất báo cáo PDF → **Tạo và tải lên**.
2. Chụp tiến độ `01-phone-progress.png`; nếu quá nhanh, lấy frame từ video gốc. Không chụp được thì ghi thiếu bằng chứng tiến độ.
3. Khi thành công chụp `02-phone-upload-success.png`, che URL trước khi chuyển sang thư mục công khai.
4. Bấm **Mở báo cáo**, tìm dòng `LAB3_D03_20261114_R1 Com rau`; chụp `03-phone-pdf-meal.png`, thấy tên bữa/ngày trong PDF. PDF tải được nhưng không thấy bữa này thì chưa đạt đủ kỳ vọng.

## TC-D04 — Ghi offline rồi mở lại app

1. Khi A đã đăng nhập, tắt **cả Wi-Fi và dữ liệu di động**. Nếu dùng chế độ máy bay, kiểm tra Wi-Fi không tự bật lại.
2. Nhật ký → thêm bữa `LAB3_D04_20261114_R1 Offline` → Lưu.
3. Chụp `01-phone-offline-pending.png`, thấy bữa và **Đã lưu trên máy · chờ đồng bộ**. Có thể chụp thêm Quick Settings `02-network-off.png` để chứng minh mạng tắt.
4. Nhấn Home đưa app về nền, bật mạng lại, mở app từ biểu tượng. Chờ đồng bộ; chụp `03-phone-online-synced.png`, phải là chính bữa đó và **Đã đồng bộ**.
5. Kiểm tra D1 có đúng một dòng tương ứng; chụp `04-d1-record.png`.
6. Nếu phải vào Tài khoản → Đồng bộ dữ liệu → Đồng bộ lại, ghi rõ thao tác hỗ trợ; không ghi ca tự đồng bộ đạt nguyên vẹn. Nếu sau khoảng 30–60 giây chưa đổi trạng thái, giữ ảnh lỗi và thời điểm để điều tra; không xóa bữa hoặc cài lại app.

## TC-D04b — Xóa bữa đã đồng bộ

1. Chỉ sau D05: xác nhận bữa D03 còn **Đã đồng bộ**, chụp `01-phone-before-delete.png`.
2. Tắt Wi-Fi và dữ liệu di động. Bấm thùng rác ở bữa D03 → xác nhận Xóa.
3. Chụp `02-phone-offline-deleted.png`: bữa biến mất khỏi Nhật ký đúng ngày; có thông báo **Đã xóa bữa ăn** nếu kịp chụp. Không xóa bữa thật.
4. Bật mạng, mở lại app, chờ sync. D1 vẫn giữ record của bữa D03 nhưng `deleted_at` phải có thời gian; chụp `03-d1-tombstone.png` bằng cùng câu SQL. Record mất khỏi UI chưa chứng minh tombstone đã lên server.

## TC-D01 — FCM khi app ở nền

1. A đang đăng nhập, có mạng/quyền thông báo; mở app ở tab Kiến thức rồi nhấn Home. Không Đăng xuất và không Buộc dừng.
2. Máy tính: Admin → Gửi thông báo → UID của A, tiêu đề `LAB3_D01_20261114_R1`, nội dung `Mo Nhat ky tu thong bao nen`, route `/log` → Xem trước → Xác nhận gửi.
3. Kéo thanh thông báo điện thoại, chụp `01-phone-notification.png` thấy đúng tiêu đề; không để lộ thông báo ứng dụng khác.
4. Chạm đúng thông báo, app phải mở **Nhật ký**. Chụp `02-phone-log.png`.
5. Admin → Lịch sử gửi → tìm đúng tiêu đề → **Xem kết quả**. Chụp `03-admin-opened.png` có `openedAt` khác null của thiết bị thử, che định danh riêng.
6. Bảng hiện tại có thể chỉ hiện trạng thái xử lý; openedAt nằm trong chi tiết JSON. Ghi rõ giới hạn này; nếu yêu cầu bắt buộc nhãn “Đã mở” ngay trên bảng, đánh dấu chưa đạt phần hiển thị. `accepted` không chứng minh điện thoại nhận/mở.

## TC-D07 — FCM khi app đóng hẳn

1. A đang đăng nhập, có mạng/quyền thông báo. Mở màn đa nhiệm rồi vuốt đóng Longevity Plate. Không vào Cài đặt → Buộc dừng; Android có thể chặn push khi force-stop.
2. Vuốt khỏi đa nhiệm chưa chứng minh tiến trình đã tắt. Muốn xác nhận chính xác, kết nối ADB và kiểm tra không còn PID trước gửi (Codex có thể hỗ trợ); nếu không xác minh được, ghi “đóng qua đa nhiệm, chưa xác minh process”, giữ kết quả một phần.
3. Gửi từ Admin: tiêu đề `LAB3_D07_20261114_R1`, nội dung `Mo Nhat ky sau khi dong app`, route `/log`. Không mở app bằng biểu tượng trong lúc chờ tin.
4. Chụp `01-phone-notification.png`, chạm thông báo → Nhật ký, chụp `02-phone-log.png`.
5. Admin → Lịch sử gửi → Xem kết quả của tin D07 → chụp `03-admin-opened.png` có openedAt. Bằng chứng PID đã tắt lưu `04-process-check.txt` nếu có.
6. Không có tin sau khoảng 60 giây: giữ ảnh/trạng thái Admin và thời điểm để kiểm tra; không kết luận thiếu chức năng hoặc gửi lại liên tục.

## TC-D02 — User thường bị từ chối Admin

1. Dùng cửa sổ ẩn danh hoặc trình duyệt khác trên máy tính để giữ phiên Admin chính. Đăng nhập web staging bằng tài khoản B chưa được cấp Admin.
2. Kỳ vọng **Không có quyền truy cập**, không có các nút quản trị; chụp `01-web-access-denied.png`.
3. Phần backend `/api/v1/admin/*` phải trả 403 cần kiểm tra riêng bằng request có phiên B qua công cụ kiểm thử an toàn. UI bị chặn hoặc `/me` trả `isAdmin: false` chưa chứng minh trực tiếp 403 của route Admin. Không chép ID token vào ảnh/chat/Git; Codex hỗ trợ bước này nếu cần.
4. Nếu chỉ có ảnh web, ghi đạt phần UI, backend 403 chưa xác minh lại trong phiên này.

## TC-D06 — Tài khoản trống không xuất PDF

1. Điện thoại: Tài khoản → Đăng xuất → đăng nhập B, chọn mục tiêu nếu được hỏi. B không có bữa trong 7 ngày gần nhất, không chỉ riêng ngày hôm nay.
2. Nhật ký → Xuất báo cáo PDF → Tạo và tải lên.
3. Chụp `01-phone-empty-report-error.png` thấy thông báo **7 ngày gần nhất chưa có bữa ăn nào...**, không có link PDF/thành công.
4. Không tạo PDF/không gọi `/media/sign` cần đối chiếu log theo thời điểm hoặc kiểm thử có theo dõi lời gọi; ảnh báo lỗi không tự chứng minh điều này. Ghi chưa có bằng chứng network nếu chưa thu được; không dùng DevTools của web Admin để suy ra request từ app Android.
5. Kết thúc có thể đăng nhập lại A; không ghi thêm bữa B trước khi hoàn tất ca này.

## Truy vấn D1 chỉ đọc cho D03/D04/D04b

Cloudflare Dashboard → D1 → database `longevity-plate-lab3-staging-20261113` → Console. Chạy câu dưới; chỉ lấy các tên bữa fixture của phiên này, không lấy toàn bộ dữ liệu người dùng:

```sql
SELECT id,
       json_extract(data_json, '$.description') AS description,
       version, deleted_at, updated_at
FROM records
WHERE kind = 'meal'
  AND json_extract(data_json, '$.description') IN (
    'LAB3_D03_20261114_R1 Com rau',
    'LAB3_D04_20261114_R1 Offline'
  )
ORDER BY updated_at DESC;
```

Nếu không có quyền D1, tiếp tục chụp phần app và đánh dấu phần D1 chờ xác minh. Codex có thể hỗ trợ truy vấn trên máy đã cấu hình quyền; không chia sẻ secret. Khi chạy lại R2, đổi hậu tố ở cả tên bữa và câu SQL. Không chạy SQL UPDATE/DELETE để giả tạo kết quả ca thử.

## Ghi kết quả và đưa lên Git

1. Điền kết quả thực tế/timestamp/tên ảnh vào RESULTS.md: CHƯA CHẠY, PASS, FAIL, MỘT PHẦN hoặc BLOCKED. Nếu thiếu một kỳ vọng thì chưa chốt PASS toàn ca.
2. Cho Codex biết ảnh đã chép vào artifacts/manual-device/2026-11-14. Codex kiểm tra từng ảnh, giữ nguyên ảnh gốc và đưa bản đã kiểm tra/che thông tin vào docs/build-evidence/manual-device/2026-11-14.
3. Ảnh tĩnh không chứng minh mọi hành vi: đặc biệt backend 403, không gọi media/sign và process terminated phải có log/kiểm tra hỗ trợ hoặc ghi rõ giới hạn.
4. Khi hoàn tất phần minh chứng thực tế, chỉ stage hướng dẫn và thư mục public, xem staged diff rồi commit/push nhánh feature/artemis. Các thay đổi slide và .wrangler đang có không thuộc lần commit này. Không cần đợi mọi ca PASS mới được lưu kết quả thật lên Git.

```powershell
git add -- docs/DEVICE_MANUAL_TEST_GUIDE_VI.md docs/build-evidence/manual-device/2026-11-14
git diff --cached --stat
git diff --cached -- docs/DEVICE_MANUAL_TEST_GUIDE_VI.md docs/build-evidence/manual-device/2026-11-14/RESULTS.md
git commit -m "docs: record manual device acceptance evidence"
git push origin feature/artemis
```

Chỉ chạy commit/push sau khi ảnh và kết quả đã được kiểm tra. Push nhánh này chưa merge vào main.
