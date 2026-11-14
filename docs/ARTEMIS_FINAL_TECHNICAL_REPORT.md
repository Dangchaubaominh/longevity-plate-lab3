# ARTEMIS remediation — tiến độ thực tế

Cập nhật 06:59:29 14/11/26 (Asia/Bangkok). Campaign `remediation_20261114`.

## Kết quả và cách tính

Ba lượt AR13 đều có người dùng tự chọn ảnh fixture. Tác nhân báo PASS cả ba; R3 có ảnh popup, R1/R2 còn thiếu ảnh popup trong trace và giữ PENDING_REVIEW. Người dùng yêu cầu dừng đối chiếu, không chạy thêm. Kết quả báo về tổng hợp 30/30; bằng chứng đầy đủ xác nhận 28/30.

- Baseline lịch sử: **16/30 PASS, 14 FAIL, 53,33%**, 36 raw attempts. Giữ nguyên file baseline và SHA-256 `988336e50331e7af311b36fbaf0de5566c6ac1e414d18a7ad40549e3991e7856`.
- Chạy lại đúng 14 cặp baseline FAIL: **12/14 PASS được xác minh**. Đã có 14 cặp được thử, 26 raw attempts; retries/lỗi cấu hình/lỗi provider vẫn giữ riêng.
- Tổng hợp: **28/30 PASS (93.33%)**, còn 2 lượt chưa được xác nhận đạt. Số này kết hợp **16 PASS lịch sử** với PASS chạy lại, không phải 30 lượt chạy mới trên cùng APK/model.
- Những PASS đã xác minh được giữ nguyên theo yêu cầu, không chạy lại hoặc đối chiếu lại.

| Lượt | Baseline | Chạy lại | Session được chọn | Attempt |
|---|---|---|---|---:|
| AR03-R2 | FAIL | PASS | d986c3a6-dbb2-47fd-8873-7eaf33ff97a3 | 4 |
| AR03-R3 | FAIL | PASS | 392c23a8-1889-4935-9977-deddaa070b8f | 2 |
| AR04-R1 | FAIL | PASS | da797c92-0af0-495a-9947-9f12491c57f1 | 1 |
| AR04-R2 | FAIL | PASS | da8e8b47-20e6-474e-a37c-491bb480ca82 | 1 |
| AR04-R3 | FAIL | PASS | 346327ca-527d-40ff-8c19-b64e98446016 | 1 |
| AR05-R3 | FAIL | PASS | df6191d5-deaa-4593-9b9e-a57215ff8ac2 | 1 |
| AR07-R1 | FAIL | PASS | d363889c-28b2-46a3-97d7-23e5a98ad6b3 | 2 |
| AR07-R2 | FAIL | PASS | 4c307945-5e33-4fdc-b929-f88c5fe69e39 | 1 |
| AR07-R3 | FAIL | PASS | 37f2ea8e-0275-42f3-a586-5cddefce3f28 | 1 |
| AR08-R2 | FAIL | PASS | 4851c73e-9dbd-4ec6-8e7a-c7e32042cdc7 | 3 |
| AR08-R3 | FAIL | PASS | 0c25930e-65d1-4af6-95f5-cf8dfd819fcd | 2 |
| AR13-R1 | FAIL | PENDING_REVIEW | 94b22f51-9783-416e-9e66-fbc374555b95 | 3 |
| AR13-R2 | FAIL | PENDING_REVIEW | 9049e407-4881-4a83-aa81-edaa43cc0792 | 2 |
| AR13-R3 | FAIL | PASS | 43901200-dedb-4f22-b1ed-2dfc86eba963 | 2 |

## Nguyên nhân và cách sửa

RCA baseline có sẵn trong `ARTEMIS_ROOT_CAUSE_ANALYSIS.md` và `baseline-analysis.json`: B=2 lượt, C=12 lượt, A/D/E=0 lượt có bằng chứng chính. Không diễn giải 14 lượt FAIL thành 14 lỗi ứng dụng độc lập. Chưa xác nhận hoặc sửa lỗi nghiệp vụ ứng dụng trong phiên remediation này.

1. Cuộn/target sai: ARTEMIS nhấn phần card bị cắt dưới CTA. Làm rõ vuốt ngón tay lên toàn màn hình, chỉ nhập khi ô thực sự hiện và nhận focus. AR04 giữ yêu cầu đủ cả hai validation. AR03/AR05 mở đúng journal rồi form, phân biệt chính xác nhãn từng run.
2. Nhập liệu: clipboard SUCCESS không chứng minh trường app nhận chữ; native key injection còn bị Telex biến ARTEMIS thành chữ có dấu. Driver opt-in dùng UIAutomator ACTION_SET_TEXT trên đúng EditText đang focus trong package app, đọc lại giá trị chính xác. Actuator chuyển quyền thay/append cho driver để tránh xóa thiếu rồi nối chuỗi. Không đổi bàn phím người dùng, validation, login hoặc bảo mật ứng dụng.
3. Phạm vi và lịch sử: chặn launch/stop app khác, phím Home/app switch/power và capture ngoài package cho campaign này; Scope guard vẫn chặn capture picker AR13; người dùng hỗ trợ chọn ảnh, chưa sửa xong giới hạn này. Runner vẫn chạy từng lượt có giám sát. Mỗi campaign có thư mục/nhãn riêng, giữ mọi retry, không dùng agent SUCCESS làm kết quả cuối.

Đã xác minh giải quyết 12 **lượt FAIL baseline** thuộc test/tool; đây không phải số lỗi code độc lập. Hai ca AR13-R1/R2 còn thiếu ảnh popup; không thực hiện thêm theo yêu cầu người dùng. Các lần đánh giá AR08 ban đầu nhầm PASS vì chỉ thấy empty state đã được sửa thành FAIL khi phát hiện truy vấn sai từng ký tự; lịch sử sửa đánh giá vẫn lưu trong adjudication.json.

## Kiểm thử đã thực sự chạy

- Flutter analyzer: no issues. Flutter regression: **102/102 PASS**. Release APK Firebase/staging build thành công; log private `artifacts/artemis-remediation/fresh-build.log`.
- Runner tests: **3/3 PASS**. Driver/actuator/scope targeted unittest: **9/9 PASS**. Suite pytest có sẵn chưa chạy được vì môi trường ARTEMIS chưa cài pytest; không ghi suite đó là PASS.
- ARTEMIS thực tế: các sessions/attempts trong bảng, screenshots và DataEngine SQLite thật. Raw logs ở `artifacts/artemis-campaigns/remediation_20261114/`, được Git ignore. Một số UI tree thiếu text nên ảnh thật và read-back/backend là oracle bổ sung, không tự đổi missing thành PASS.
- API proof dùng Firebase token của tài khoản thử đã đăng nhập trên máy, D1/staging thật. Script oracle chỉ đọc record/media để đối chiếu, không sửa dữ liệu hay bỏ qua đăng nhập trong ứng dụng. Signed URLs/tokens không được đưa vào hồ sơ công khai.
- Dịch vụ/provider/integration khác trong báo cáo cũ vẫn là **baseline lịch sử** (169 local, 15/15 provider, 40/40 staging, 2/2 integration Android). Không gọi các số đó là kiểm thử chạy lại trong phiên này.

## Build, thiết bị và cấu hình

OPPO CPH2637, Android 16/API36. APK đã cài bằng install -r, giữ session và dữ liệu. Version `1.0.0+1`, SHA-256 `0A5E3EAEF3364594B46DD724F253B4F61F62577174A9C65D16F906ABCDAFDC67`. Backend staging: `https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev`.

Source HEAD `6a5e92fea3002ebaf28756f41a71791a1423aa57`, working tree có thay đổi chưa commit. Tool HEAD `351ca8422f7b5b54e80a9c1ce03a222e02415b6b` với patch local được giữ tại `scripts/patches/artemis-verified-input.patch`. Baseline model gemini-3.5-flash-lite; các lượt mới chuyển gemini-3.1-flash-lite khi provider trả 429 quota ngày. Model/attempt/session được ghi trong raw metadata/log; không gộp thành một campaign model cố định.

Sự cố môi trường đã gặp: Wireless ADB đổi cổng (hiện dùng mDNS cùng OPPO), cài APK cần chủ máy xác nhận, quota Gemini 429/503, xét duyệt Codex hết hạn mức ở một số thời điểm, một attempt thiếu fallback schema trước khi có action. Các sự cố được giữ trong attempts, không quy thành lỗi ứng dụng hoặc xóa để làm đẹp tỷ lệ.

## Files thay đổi trong remediation

`scripts/run-artemis-suite.mjs`, `scripts/artemis-cases.json`, `scripts/export-artemis-evidence.py`, `scripts/artemis-campaign.mjs`, `scripts/artemis-campaign.test.mjs`, `scripts/artemis-cloud-oracle.mjs`, `scripts/artemis-review-sheet.py`, `scripts/test_artemis_verified_input.py`, `scripts/summarize-artemis-remediation.mjs`, `scripts/write-artemis-remediation-report.mjs`, `scripts/patches/artemis-verified-input.patch`, hồ sơ Markdown và JSON kết quả. Patch tool sửa `artemis/drivers/android/adb_driver.py` và `artemis/mcp/actuators/adb.py` trong checkout `../tools/artemis`.

Đã pull feature và merge origin/main vào feature tại 0145c47, không có conflict. Code main mới có thay đổi meal delete/BR10, không thuộc APK source 6a5e92f đã đo trên thiết bị. Không chạy lại test sau merge theo yêu cầu. Commit/push hồ sơ remediation được ghi trong Git history. Giữ nguyên các thay đổi ngoài phạm vi, backup Firebase, output DOCX và file khóa PowerPoint.

## Slide và giới hạn

Deck 15 slide cập nhật kết quả báo về và mức hỗ trợ tại `output/pdf/Longevity_Plate_Lab3_Slides_ARTEMIS_Remediation_20261114.pptx`. Ba lượt AR13 đều có người dùng tự chọn ảnh fixture. Tác nhân báo PASS cả ba; R3 có ảnh popup, R1/R2 còn thiếu ảnh popup trong trace và giữ PENDING_REVIEW. Người dùng yêu cầu dừng đối chiếu, không chạy thêm. Kết quả báo về tổng hợp 30/30; bằng chứng đầy đủ xác nhận 28/30.

Giới hạn rubric về ảnh Firebase/Cloudinary Console và video người dùng tự quay vẫn theo ASSIGNMENT_ACCEPTANCE.md. Không dùng ảnh minh họa hoặc kết quả local thay screenshot nghiệm thu native/cloud.

Nguồn machine-readable: [remediation_20261114-summary.json](build-evidence/artemis-remediation/remediation_20261114-summary.json). Chi tiết 10 ca: [ARTEMIS_CASES.md](ARTEMIS_CASES.md).
