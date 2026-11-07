# Server báo cáo

Một Cloudflare Worker nhỏ, giữ vai trò của storage.rules khi app lưu báo cáo PDF trên Cloudinary thay cho Firebase Storage. Server kiểm tra ID token Firebase, ký lệnh tải lên vào `reports/<uid>/` của chính người gọi, và chỉ cấp link tải có hạn dùng cho chủ tệp. Khóa bí mật Cloudinary chỉ nằm trong secret của Cloudflare.

Lý do và luồng chi tiết nằm ở [docs/architecture.md](../docs/architecture.md#lưu-trữ-báo-cáo-trên-cloudinary).

## API

Cả hai đường dẫn đều cần header `Authorization: Bearer <ID token Firebase>`.

| Đường dẫn | Body | Kết quả |
|---|---|---|
| `POST /reports/sign` | `{"fileName": "meal-report-<số>.pdf"}` | `uploadUrl`, các `fields` đã ký để gửi kèm tệp, `publicId` |
| `POST /reports/url` | `{"publicId": "reports/<uid>/meal-report-<số>"}` | `url` hết hạn sau 15 phút, `expiresAt` |

| Mã lỗi | Ý nghĩa |
|---|---|
| 400 | Tên tệp hoặc `publicId` sai dạng |
| 401 | Thiếu token, token sai, hết hạn hoặc của dự án khác |
| 403 | `publicId` thuộc uid khác |
| 500 | Thiếu biến cấu hình |

## Chuẩn bị

1. Cài Node.js bản LTS.
2. Tạo tài khoản Cloudinary miễn phí. Trong Cloudinary Console, vào **Settings → Security** và bật **Allow delivery of PDF and ZIP files**, vì tài khoản mới chặn PDF. Lấy Cloud name, API key và API secret ở trang **API Keys**.
3. Tạo tài khoản Cloudflare miễn phí.

## Chạy test

Chạy trong thư mục `server`:

```bash
npm install
```

```bash
npm test
```

## Triển khai

```bash
npx wrangler login
```

```bash
npx wrangler deploy
```

Lệnh in ra địa chỉ dạng `https://longevity-plate-reports.<tên>.workers.dev`. Sau đó đặt ba giá trị Cloudinary. Mỗi lệnh sẽ hỏi giá trị, bạn tự dán vào terminal:

```bash
npx wrangler secret put CLOUDINARY_CLOUD_NAME
```

```bash
npx wrangler secret put CLOUDINARY_API_KEY
```

```bash
npx wrangler secret put CLOUDINARY_API_SECRET
```

Khi chưa đặt đủ ba giá trị, server trả lỗi 500 `server-not-configured`.

Build app với địa chỉ server, ví dụ:

```bash
flutter run --dart-define=REPORT_API_URL=https://longevity-plate-reports.<tên>.workers.dev
```

Không ghi API secret vào `wrangler.toml`, mã nguồn hay tệp nào được commit.
