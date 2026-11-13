# Chạy local, staging và build điện thoại

Staging đang chạy: **https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev**. Admin Google đã được cấu hình theo tài khoản người dùng chỉ định; Firebase authorized domain, remote D1 migrations và secret bindings đã hoàn tất. Phần dưới là hướng dẫn tái lập hoặc tạo môi trường riêng, không yêu cầu tạo database mới nếu nhóm tiếp tục dùng staging hiện có.

## 1. Điều kiện

Node 22+, npm, Flutter 3.47.2/Dart 3.13.2, Android SDK/JDK phù hợp. Giữ Firebase project `longevity-plate-beff9`. Không commit secret, không bật billing hoặc đổi IAM để vượt blocker khi chưa được chủ dự án duyệt.

## 2. Local

Từ thư mục dự án:

```powershell
cd admin
npm ci
npm run build
cd ../server
npm ci
npm run db:migrate
Copy-Item .dev.vars.example .dev.vars
# Điền giá trị trong editor trên máy, không gửi vào chat.
npm run dev
```

Ở terminal khác, `cd admin; npm run dev`. Local D1 không chứa dữ liệu production. Binding UUID zero trong wrangler.toml chỉ phục vụ local, không dùng deploy remote. `npm run build` ở server là **dry-run**, không deploy.

Secret/vars:

| Tên | Cách lấy/ý nghĩa |
|---|---|
| FIREBASE_PROJECT_ID | project hiện tại, đã có trong config |
| CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET | Cloudinary environment; secret chỉ Worker |
| GOOGLE_SERVICE_ACCOUNT_JSON | JSON credential server được chủ project cấp phù hợp, không phải Firebase client config |
| FIREBASE_APP_ID | Firebase Android app ID của bản Flutter |
| FIREBASE_WEB_CONFIG | JSON Web SDK public config: apiKey/appId/projectId/authDomain/messagingSenderId |
| ADMIN_ORIGIN | origin chính xác của web; local localhost:5173 |
| DB / ASSETS | D1 database và admin/dist |

`.dev.vars` cần cú pháp dotenv hợp lệ. JSON một dòng phải được quote đúng; ví dụ biến JSON là `'{}'` chỉ minh họa cú pháp, không phải cấu hình chạy được. Không thêm credential thật vào example. Dùng Wrangler secret put cho remote để tránh secrets nằm trong TOML.

## 3. Staging riêng

Chủ dự án đăng nhập Wrangler, tạo D1 staging riêng bằng `npx wrangler d1 create longevity-plate-lab3-staging`. Copy config thành wrangler.staging.toml (được gitignore), đổi Worker name sang tên staging và database_id thành UUID thực; giữ migrations_dir và assets. Cấu hình origin staging chính xác. Không ghi đè Worker đang dùng nếu chưa kiểm tra.

```powershell
npx wrangler d1 migrations apply DB --remote --config wrangler.staging.toml
npx wrangler secret put CLOUDINARY_CLOUD_NAME --config wrangler.staging.toml
npx wrangler secret put CLOUDINARY_API_KEY --config wrangler.staging.toml
npx wrangler secret put CLOUDINARY_API_SECRET --config wrangler.staging.toml
npx wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON --config wrangler.staging.toml
npx wrangler secret put FIREBASE_APP_ID --config wrangler.staging.toml
npx wrangler secret put FIREBASE_WEB_CONFIG --config wrangler.staging.toml
npx wrangler deploy --config wrangler.staging.toml
```

Deployment đã thực hiện trong môi trường riêng: Worker `longevity-plate-lab3-staging`, D1 `longevity-plate-lab3-staging-20261113`, namespace `longevity-plate-dai05.workers.dev`; migrations 0001–0003 áp dụng thành công. Không ghi đè production. Host staging đã được thêm đúng vào Firebase Auth authorized domains. Secret bindings được đưa qua stdin của Wrangler, không có trong TOML/Git.

Cloudinary đã qua 15/15 check thật sau khi dùng cấu hình private-backup do người dùng chỉ định; .dev.vars đang dùng bộ giá trị đã kiểm chứng. `npm run smoke:cloudinary` tạo hai fixture riêng, kiểm tra signed upload/authenticated metadata/receipt/private download/unsigned denial, rồi dọn chính fixture. Kết quả không chứa secret: artifacts/backend-implementation/cloudinary-live.json. Script nhận thêm đường dẫn file dotenv nếu cần; không commit private backup.

`STAGING_API_URL=https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev node scripts/live-api-smoke.mjs` (đặt env theo shell) chạy API E2E thật. Chỉ chấp nhận localhost hoặc đúng staging này, tạo test users có UUID, seed role trên đúng DB thử nghiệm rồi cleanup. API E2E đã đạt40/40; FCM dùng validate_only=true và không gửi message tới thiết bị.

## 4. Bootstrap Admin

Đăng nhập bằng tài khoản thử để `/me` tạo users row; lấy UID của **chính tài khoản muốn cấp Admin** từ Firebase Auth. Chủ D1 dùng CLI/Console có quyền ghi để INSERT admin_users hoặc UPDATE active; không có public bootstrap endpoint. Ví dụ SQL cần thay UID đã kiểm tra:

```sql
INSERT INTO admin_users(uid,active) VALUES('VERIFIED_ADMIN_UID',1)
ON CONFLICT(uid) DO UPDATE SET active=1;
```

Không chạy ví dụ UID placeholder; FK phải trỏ đúng users. Thu hồi: UPDATE admin_users SET active=0 WHERE uid=... . Ghi lại người cấp/quy trình vào hồ sơ nhóm. Không gán mọi user thành Admin.

## 5. Điện thoại và APK

```powershell
flutter devices
flutter run -d <device-id> --dart-define=API_BASE_URL=https://<staging-worker>
# Hoặc APK:
.\scripts\build-android.ps1 -Firebase -ApiBaseUrl https://<staging-worker>
```

API_BASE_URL bật toàn bộ backend sync; REPORT_API_URL chỉ là chế độ PDF cũ. Thay dart-define cần restart/rebuild bản đang chạy, hot reload không đổi define. Thêm SHA debug/release đúng signing key vào Firebase để Google sign-in trên điện thoại. Wireless debug chỉ thay cách kết nối ADB.

APK đã build: `artifacts/backend-implementation/longevity-plate-staging-arm64.apk`, ARM64 debug, đã nhúng API_BASE_URL/REPORT_API_URL staging. SHA256 đi kèm. Bản này dành cho điện thoại ARM64; compile không thay nghiệm thu trên thiết bị.

## 6. Kiểm tra

`scripts/check-backend-config.ps1 -ApiBaseUrl <URL>` chỉ kiểm tra presence secret local, health, anonymous 401 và ADB; không in giá trị và không khẳng định provider đã chạy. Sau đó làm TEST_PLAN.md. Real staging integration test:

```powershell
flutter test integration_test/staging_flow_test.dart -d <device-id> --dart-define=API_BASE_URL=https://<staging-worker>
```

Đăng nhập Google trên điện thoại trong khoảng chờ 2 phút. Test chỉ tạo meal có prefix acceptance_, upload ảnh catalog đã chuẩn hóa, đọc bằng owner, rồi tombstone dữ liệu của chính test trong finally. Camera native/FCM/crash và kiểm tra A/B vẫn cần checklist riêng.

Rollback: giữ Worker version/migration backup và legacy local backup. Migrations hiện chỉ additive, không tự drop tables hoặc xóa production data. Không downgrade client SQLite bằng cách xóa DB của người dùng.
