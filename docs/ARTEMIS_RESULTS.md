# ARTEMIS - kết quả đối chiếu thực tế

Thiết bị CPH2637 Android16, official google/artemis CLI; profile Flash, model gemini-3.5-flash-lite. Chiến dịch 13–14/11/2026.

10 ca ×3 =30 lượt có tên, lưu36 attempts gồm retry. Kết quả theo lượt cuối từng tên: **16/30 PASS (53,33%), 14/30 FAIL**. FAIL gồm thiếu tiêu chí quan sát hoặc tác nhân đi sai flow; không suy ra tất cả là lỗi sản phẩm. Không xóa retry để tăng tỷ lệ.

| Ca | R1 | R2 | R3 | Đạt |
|---|---|---|---|---|
| AR01 | PASS | PASS | PASS | 3/3 |
| AR02 | PASS | PASS | PASS | 3/3 |
| AR03 | PASS | FAIL | FAIL | 1/3 |
| AR04 | FAIL | FAIL | FAIL | 0/3 |
| AR05 | PASS | PASS | FAIL | 2/3 |
| AR06 | PASS | PASS | PASS | 3/3 |
| AR07 | FAIL | FAIL | FAIL | 0/3 |
| AR08 | PASS | FAIL | FAIL | 1/3 |
| AR10 | PASS | PASS | PASS | 3/3 |
| AR13 | FAIL | FAIL | FAIL | 0/3 |

## Quyết định sau đối chiếu

- AR03: R2 ban đầu chọn breakfast sai; retry không tạo record lunch đúng. R3 không có record mô tả chính xác. R1 xác nhận lunch trong D1.
- AR04: agent chưa ghi đủ cả hai validation. Phiên khám phá riêng có ảnh cả hai lỗi; kết quả thủ công không ghi đè FAIL của agent.
- AR05-R3: không có dấu vết hộp xác nhận trong trace; không nhận PASS chỉ từ lời công cụ.
- AR07: các lượt chưa mở công thức khác và hộp xác nhận thay thế. Cần đi qua Chọn món để chọn Bánh mì và trứng; Món gợi ý chỉ hiển thị công thức đầu.
- AR13-R1: chọn ảnh khác fixture bowl quy định. R2 không ghi nhận picker/lưu đúng record. R3 bị dừng do mở com.bbook.app ngoài phạm vi.
- --locked-app chỉ là gợi ý điều hướng của SDK, không phải sandbox. Runner hiện dừng mặc định, chỉ cho đúng một case/run khi có giám sát trực tiếp. Không tiếp tục tác nhân không giám sát.

## Bằng chứng và tái kiểm tra

`docs/build-evidence/artemis-summary.json` lưu session IDs, image hashes, số steps và lý do từng lượt; không chứa token, email hoặc nội dung ứng dụng khác. Raw private: `artifacts/artemis-runs/` gồm logs, `traces/data_engine.db` (steps/images) và `traces/images/<hash>.jpg`. `steps.json` upstream có thể trống; không bỏ qua DB thật. Export read-only bằng `python scripts/export-artemis-evidence.py`.

Case/preconditions/steps/expected: `docs/ARTEMIS_CASES.md`, `scripts/artemis-cases.json`. Kết quả khám phá có giám sát được ghi riêng ở `docs/EXPLORATORY_SESSION.md`. Không tính lại các bước ADB thủ công thành lượt ARTEMIS.

## Chạy lại có giám sát

Đặt LAB3_DEVICE_SERIAL, LAB3_ADMIN_EMAIL, LAB3_ARTEMIS_SUPERVISED=1, LAB3_ARTEMIS_CASE=<một ID>, LAB3_ARTEMIS_RUN=1..3 rồi chạy `node scripts/run-artemis-suite.mjs`. Người vận hành phải theo dõi và dừng ngay nếu sai package; script không đảm bảo chặn tool ở cấp SDK. Không chạy hàng loạt trên thiết bị có ứng dụng cá nhân.

Đối chiếu ảnh bổ sung AR08-R2/R3: query chỉ ở clipboard gợi ý của bàn phím, ô tìm kiếm app vẫn trống. Không coi text trong UI cây bàn phím là giá trị đã nhập; hai lượt này FAIL.

<!-- ARTEMIS_REMEDIATION_START -->
## Remediation thực tế 06:59:29 14/11/26

Baseline giữ **16/30 PASS, 14 FAIL**. Campaign `remediation_20261114` chạy lại riêng 14 lượt FAIL: **12/14 PASS đã xác minh**, 26 attempts được giữ. Tổng hợp kế thừa 16 PASS baseline: **28/30 (93.33%)**, còn 2 lượt chưa đạt xác nhận. Đây không phải 30 lượt chạy mới.

Chi tiết và giới hạn: [ARTEMIS_REMEDIATION_STATUS.md](ARTEMIS_REMEDIATION_STATUS.md). Ba lượt AR13 đều có người dùng tự chọn ảnh fixture. Tác nhân báo PASS cả ba; R3 có ảnh popup, R1/R2 còn thiếu ảnh popup trong trace và giữ PENDING_REVIEW. Người dùng yêu cầu dừng đối chiếu, không chạy thêm. Kết quả báo về tổng hợp 30/30; bằng chứng đầy đủ xác nhận 28/30. Model, sessions và bằng chứng có trong hồ sơ.
<!-- ARTEMIS_REMEDIATION_END -->
