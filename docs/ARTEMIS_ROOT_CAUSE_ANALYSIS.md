# Phân tích nguyên nhân ARTEMIS baseline

Baseline lịch sử giữ nguyên16/30PASS,14/30FAIL,53,33%;30lượt chính thức được chọn theo session trong artemis-summary.json. Có36rawattempts gồm retry. Đây không phải số liệu chạy lại.

## Phân loại

| Nhóm | Số lượt FAIL chính |
|---|---:|
| A | 0 |
| B | 2 |
| C | 12 |
| D | 0 |
| E | 0 |

A ứng dụng; B thiết kế ca; C công cụ/tác nhân; D môi trường; E không đủ bằng chứng. Mỗi lượt có một nguyên nhân chính. Yếu tố góp phần được ghi riêng; số này không phải số lỗi code độc lập.

Nhóm ảnh hưởng lớn nhất là C với12/14lượt. Hai lượt B có hướng cuộn mơ hồ; các lượt còn lại có chuỗi thao tác đi sai màn, nhập clipboard không vào trường, chọn sai ảnh hoặc vượt phạm vi. Không tìm thấy bằng chứng từ14lượt để kết luận một lỗi P0 về mất dữ liệu, owner hay idempotency. Sự thiếu ổn định của hierarchy ở form dài là yếu tố hỗ trợ cần kiểm tra khả năng truy cập, không được coi là lỗi nghiệp vụ đã tái hiện trên máy thật.

## Mười bốn lượt không đạt

| Test | Run | Gốc | Nhóm và nguyên nhân | Bằng chứng | Cách xử lý | Trạng thái |
|---|---:|---|---|---|---|---|
| AR03 | 2 | FAIL | C: Lặp Home → Nhật ký; không mở form mới, không nhập và không lưu record đúng nhãn. | session aed4e499-ed5b-4601-8960-20fe18f01727; s1:9f7a58dee088, s5:9f7a58dee088, s6:fae4ff6df7cd | Chuẩn bị form mới; kiểm tra màn trước nhập; backend oracle theo nhãn riêng mỗi campaign. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR03 | 3 | FAIL | C: Nhấn tọa độ/target rỗng từ Nhật ký; không có action nhập mô tả hoặc lưu; record đúng nhãn không xuất hiện trong snapshot cloud. | session ead0575f-5587-4a48-9427-13093819371f; s1:b03a5adfbf1f, s2:b03a5adfbf1f, s4:90943aff7569, s5:7b1aa047a549 | Kiểm tra target hợp lệ và màn form; read-back trường và kiểm tra đúng một record lunch. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR04 | 1 | FAIL | B: Goal viết SCROLL DOWN theo chiều nội dung, tool down kéo ngón tay xuống. Sau một swipe up ngắn, agent bấm Save lại và đưa focus về lỗi đầu. | session 840e07a8-638c-436b-8b5e-b1bec89c33e4; s4:385750985b37, s5:12f05bcb0e27, s8:9d78b49c927e, s9:47d7cb4a3c60 | Mô tả rõ vuốt ngón tay lên, chờ màn ổn định; giữ hai lỗi và quan sát từng trường, không resubmit để cuộn. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR04 | 2 | FAIL | C: Trace chỉ có ba click trước kết luận, dừng ở Nhật ký thay vì form validation. | session 2e9f279c-3d66-49c4-b5f7-9c6766aa2946; s1:917007549e2d, s2:564f7c709205, s3:917007549e2d | Preflight form route; không cho kết luận nếu thiếu các mốc Save và lỗi bắt buộc. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR04 | 3 | FAIL | B: Lặp tool swipe down; hai swipe up chỉ quay về vùng loại bữa/ảnh, chưa đến lỗi tên món. | session e168fc6e-7a60-4b63-be96-a6b0137bace4; s4:0f95ebfb0064, s5:bfb537c2bf87, s10:387bc7547086, s13:9e7f1f94795c, s14:06ec2b38384a | Hướng cuộn theo tọa độ ngón tay; label/identifier trường; summary lỗi cho form dài. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR05 | 3 | FAIL | C: Rời Nhật ký tới launcher rồi mở lại app; không có input mô tả hoặc hộp bỏ bản nháp. | session d6cdb56f-a4ab-4b68-9734-c7487dfe21c1; s1:0b7ead50eb53, s2:5a09dbc6effd, s3:06e0d56814fa, s4:5a09dbc6effd, s6:bff1a6c68106 | Phân biệt tab Hôm nay với Android Home; chặn phím Home trong campaign và đòi dialog + record absence. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR07 | 1 | FAIL | C: Mở Xem chi tiết của món đang có, rồi quay lại; không chọn công thức khác và không mở dialog thay thế. | session af1438ee-892c-4086-9ab8-1f8eb26abe25; s11:c5b37eccc308, s12:14f99b0123e1, s14:a7e9fe191721, s18:54d5944d9a2e | Đi qua Chọn món ở slot trống, chọn Bánh mì và trứng, đặt lại slot test rồi mới submit và Hủy. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR07 | 2 | FAIL | C: Chỉ mở món hiện tại rồi chuyển tab; không có submit hay thao tác Hủy dialog. | session 1a5eef48-7471-4d2f-8b67-c66ac64f1ea6; s2:ea1777a89bff, s3:b9c3ac2e33c4, s4:42c0d53c7c1b, s5:83c14e3b3363 | Fixture đúng slot và recipe candidate khác recipe gốc; oracle so sánh server revision trước/sau. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR07 | 3 | FAIL | C: Tìm kiếm trong thư viện bài viết thay vì chọn công thức; tiếp tục mở recipe hiện tại và Back. | session 459f2924-0509-4f05-a103-a6508a320046; s4:5eedeb6b1d67, s7:ac26f1d518b3, s10:46f67a635b77, s11:671c47dd6f8c | Phân biệt bài viết và công thức; mở bộ chọn món; xác nhận tên candidate trước thao tác. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR08 | 2 | FAIL | C: Ảnh cho thấy ô app vẫn trống; chuỗi chỉ ở gợi ý clipboard của bàn phím sau input_text. | session c384ecdc-b14e-4c78-8902-e60daf1a41c4; s2:35e91507f62a, s4:c25eab81afa3, s5:ab6628126ba3 | Read-back đúng EditText thuộc package app; driver nhập không được xác nhận từ clipboard. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR08 | 3 | FAIL | C: input_text đặt chuỗi ở clipboard, app không hiện truy vấn hoặc empty state. | session 8cfbefdc-5a32-47c5-b17e-89d0f29fc9e0; s2:2efec704cc4e, s8:1b6334bd17fa, s9:5dd32c696a91 | ASCII fixture qua input native có kiểm tra focus và giá trị; lỗi read-back phải trả lỗi thao tác. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR13 | 1 | FAIL | C: Picker có mở nhưng preview/asset là ảnh người dùng đã chọn trước đó, không phải bowl fixture yêu cầu. Asset228597bytes khác fixture8589bytes. | session e350fbb9-ac1d-4fcc-9ab4-86c59631b99a; s6:440a93836cb6, s7:469f2cb98fbd, s28:487da42d9f60, s35:78ced3ac98a1, s37:1c9efe73fd7a | Fixture trong album riêng có tên duy nhất và manifest hash; đối chiếu ảnh input/asset, không chọn ảnh khác để hoàn thành ca. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR13 | 2 | FAIL | C: Chỉ xem ảnh của record có sẵn rồi đóng viewer; không có picker hoặc record mới đúng nhãn. | session 68fb60e2-83f9-4f74-be42-7f78ea2852eb; s1:55f14cb46e49, s4:14fa04da1f00, s5:fa78f148b07d | Form sạch theo campaign; yêu cầu picker transition và ready asset gắn đúng record mới. | Đã phân tích; kiểm chứng bản sửa ghi riêng |
| AR13 | 3 | FAIL | C: Sau picker, agent gọi manage_app launch package khác; người vận hành dừng phiên. | session 18d86694-e6fc-4381-aada-06343e2e5984; s6:825ebf920f7d, s19:b3b7bfd099e5, s20:97b9200e207c | Scope guard trước dispatch và screenshot; manage_app chỉ launch package app; từ chối launcher và app khác. | Đã phân tích; kiểm chứng bản sửa ghi riêng |

## Tất cả ba mươi lượt baseline

| Test | Run | Gốc | Session | Steps |
|---|---:|---|---|---:|
| AR01 | 1 | PASS | 23c4a7b0-e9d3-4cab-8a24-4479dcd4fb05 | 8 |
| AR01 | 2 | PASS | 742758fb-ef13-4c10-9b7f-689713e3200d | 10 |
| AR01 | 3 | PASS | 95fb5be8-789e-497f-b10b-d04cc5060319 | 15 |
| AR02 | 1 | PASS | aa117132-4830-4c6d-963a-7c8505787c8b | 7 |
| AR02 | 2 | PASS | 39b400c0-2500-46f7-bed3-7ae8d5884bad | 7 |
| AR02 | 3 | PASS | 88786ddc-0e37-4cff-a178-0599f80231e6 | 7 |
| AR03 | 1 | PASS | 6b153094-acb7-4fb0-ae1f-eb631c42a411 | 13 |
| AR03 | 2 | FAIL | aed4e499-ed5b-4601-8960-20fe18f01727 | 7 |
| AR03 | 3 | FAIL | ead0575f-5587-4a48-9427-13093819371f | 7 |
| AR04 | 1 | FAIL | 840e07a8-638c-436b-8b5e-b1bec89c33e4 | 12 |
| AR04 | 2 | FAIL | 2e9f279c-3d66-49c4-b5f7-9c6766aa2946 | 4 |
| AR04 | 3 | FAIL | e168fc6e-7a60-4b63-be96-a6b0137bace4 | 21 |
| AR05 | 1 | PASS | d30b441d-d673-4dba-a6b6-1f798959a509 | 9 |
| AR05 | 2 | PASS | cc749371-f797-4c26-a2ea-1c9154a406db | 10 |
| AR05 | 3 | FAIL | d6cdb56f-a4ab-4b68-9734-c7487dfe21c1 | 8 |
| AR06 | 1 | PASS | 04212146-6b97-450f-9b89-574d464f502e | 9 |
| AR06 | 2 | PASS | 4943811e-3784-49c0-aa42-c2e7c48e173b | 13 |
| AR06 | 3 | PASS | 375a43b9-400c-47cb-9b3e-7b2c2f8ee530 | 10 |
| AR07 | 1 | FAIL | af1438ee-892c-4086-9ab8-1f8eb26abe25 | 19 |
| AR07 | 2 | FAIL | 1a5eef48-7471-4d2f-8b67-c66ac64f1ea6 | 6 |
| AR07 | 3 | FAIL | 459f2924-0509-4f05-a103-a6508a320046 | 14 |
| AR08 | 1 | PASS | a3402525-c174-4951-80da-2d6aa39a665a | 25 |
| AR08 | 2 | FAIL | c384ecdc-b14e-4c78-8902-e60daf1a41c4 | 7 |
| AR08 | 3 | FAIL | 8cfbefdc-5a32-47c5-b17e-89d0f29fc9e0 | 11 |
| AR10 | 1 | PASS | cd1b8b4f-24b9-4db7-9899-72ee1f2dad32 | 7 |
| AR10 | 2 | PASS | 68f2670f-fde5-4dac-97ed-89294504634f | 7 |
| AR10 | 3 | PASS | 67673f4e-a609-4fc7-ba50-337b0a20a736 | 7 |
| AR13 | 1 | FAIL | e350fbb9-ac1d-4fcc-9ab4-86c59631b99a | 40 |
| AR13 | 2 | FAIL | 68fb60e2-83f9-4f74-be42-7f78ea2852eb | 7 |
| AR13 | 3 | FAIL | 18d86694-e6fc-4381-aada-06343e2e5984 | 20 |

## Truy vết chi tiết

`docs/build-evidence/artemis-remediation/baseline-analysis.json` chứa action timeline, timestamps, hashes ảnh và các mốc quyết định cho cả30lượt. Raw log theo tên trong artifacts/artemis-runs; ảnh ở traces/images/<hash>.jpg; các bước gốc nằm trong traces/data_engine.db. Phần ứng dụng ngoài phạm vi được loại khỏi bản xuất công khai. Không đọc hoặc đưa nội dung riêng tư của ứng dụng đó vào báo cáo.

Kết quả baseline và schema phân loại được giữ độc lập với campaign chạy lại. Trạng thái bản sửa, lệnh test mới, build/commit và30lượt mới chỉ được cập nhật sau thực thi.

<!-- ARTEMIS_REMEDIATION_MATRIX_START -->
## Trạng thái remediation đã xác minh

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

12/14 lượt FAIL baseline đã có PASS chạy lại. Giữ cả retry và lịch sử đánh giá sửa sai. Xem ARTEMIS_FINAL_TECHNICAL_REPORT.md và JSON summary để đối chiếu từng nguồn.
<!-- ARTEMIS_REMEDIATION_MATRIX_END -->
