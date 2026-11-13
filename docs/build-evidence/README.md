# Bằng chứng nộp Lab3

- `backend-implementation-summary.json`:169automated checks, provider15/15 và staging40/40; phân biệt fixtures với dịch vụ thật.
- `artemis-summary.json`:10case×3,16PASS/14FAIL theo oracle; giữ retries và incident. Session IDs và image hashes truy vết tới raw private.
- `artemis-execution.jsonl`:419steps thực từ DataEngine, chỉ metadata/action names; không UI text/args/token.
- `exploratory-summary.json`:phiên có giám sát16.04phút/5kiểm tra; không quay video.
- `device/`:ảnh app thật kiểm tra validation, replacement cancel và Remote Config đổi hành vi.
- `device-pdf-proof.json`:PDF xuất từ điện thoại, tải Cloudinary riêng tư200/14925bytes,1trang.
- `remote-config-demo.json`, `remote-config-defaults.json`:publishv4=1/false và khôi phụcv5=3/true. Không secret.
- `delivery-manifest.json`:hash/bytes của báo cáo12trang,slide15trang và PPTX editable.

Ảnh Analytics DebugView có sẵn ở `evidence/analysis/`; đây là bằng chứng trước campaign mới, không gọi là capture của build cuối. Chi tiết các ảnh Console cần bổ sung nằm `docs/ASSIGNMENT_ACCEPTANCE.md`.

Raw logs, app private meal PDF, credentials, Cloudinary signed URL, FCM token và trace có tài khoản/app ngoài phạm vi giữ Git-ignored ở artifacts. Không publish dữ liệu ứng dụng khác. Developer có thể kiểm tra raw trên máy; bản public giữ metadata cần thiết để truy vết.
