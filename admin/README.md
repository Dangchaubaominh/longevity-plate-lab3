# Longevity Plate Admin

React/TypeScript/Vite, chỉ dành cho Admin. Chạy `npm ci`, `npm run dev` sau khi Worker local đã chạy tại 127.0.0.1:8787. Build `npm run build`; Worker phục vụ dist bằng ASSETS.

Firebase Web app phải cùng project và Worker cần FIREBASE_WEB_CONFIG public config. Google session không tự cấp Admin: server kiểm tra admin_users allowlist.

Lệnh kiểm tra: `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`, `npx playwright install chromium`, `npm run test:e2e`.

Playwright sử dụng test/harness.html trong Vite DEV với HTTP fixtures. Test harness không được import vào production build và không chứng minh cloud providers chạy thật.

Hướng dẫn đầy đủ: [Admin guide](../docs/ADMIN_GUIDE.md), [Deployment](../docs/DEPLOYMENT_GUIDE.md), [Known limitations](../docs/KNOWN_LIMITATIONS.md).
