# Phiên kiểm thử khám phá có giám sát

Thời gian UTC: 2026-11-13T17:20:28.787Z → 2026-11-13T17:36:31.109722+00:00. Thời lượng: **16.04 phút** (giờ Việt Nam 14/11/2026). Thiết bị OPPO CPH2637 Android16, APK staging SHA256 1B1AB859CB85FB377F289055F18F1E30D0254B8DF1E2FC37594582A0F13C6C86.

Phạm vi: chỉ Longevity Plate và camera Android được mở từ app; ADB thao tác có giám sát từng màn, kiểm tra đúng MainActivity trước hành động. Không quay video. Không gọi đây là phiên autonomous ARTEMIS. Phiên gồm tương tác thiết bị, đối chiếu nguồn/API và ghi quyết định trong cùng thời gian.

| Ca | Kết quả | Quan sát |
|---|---|---|
| EX01 | PASS | Both required field errors visually present after submit and upward scroll; no record saved. UI hierarchy omitted description card despite screenshot visibility, so screenshot oracle required. |
| EX02 | PASS | Native com.oplus.camera/.component.CapturePhotoActivity launched; Back cancelled without saving a photo; returned to own draft/discard dialog. No camera preview screenshot retained. |
| EX03 | PASS | Different recipe Banh mi va trung selected through Chon mon; 20/11 breakfast triggers replace dialog. Huy; live GET plan retains rice-veg-beans, version1, updatedAt15:34:25.343Z. |
| EX04 | PASS | Native export reports 7 meals uploaded; Admin metadata ready PDF14925bytes; private download200 and %PDF- header. |
| EX05 | PASS | RC live template v4=1/false: knowledge list ends after WHO article; planner ends after dinner, no suggestions. v5 restored3/true; suggestions visible again in same APK. |

Phát hiện: hierarchy Android bỏ sót phần mô tả form dù screenshot có đủ tên món/lỗi; oracle dựa text cần kết hợp ảnh. Runner ARTEMIS không cô lập package bằng --locked-app; batch không giám sát đã bị khóa. Món gợi ý chỉ có món đầu; muốn chọn công thức khác phải mở Chọn món.

Khôi phục: Remote Config về3/true (v5); hủy bản nháp và camera, kế hoạch20/11 breakfast vẫn rice-veg-beans revision1. Không sửa/xóa dữ liệu ứng dụng khác. Giữ bữa ảnh gallery do người dùng chọn. Raw private dưới artifacts/backend-implementation; bản tóm tắt sanitized nằm docs/build-evidence/exploratory-summary.json.
