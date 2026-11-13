# Sơ đồ cho slide (sau PR #4)

Vẽ lại từ [api-contract.md](api-contract.md) (mục 3, 4) và [workflows.md](workflows.md) (mục 4–6), theo đúng code thật trên `main` sau PR #4. Sơ đồ nghiệp vụ tổng thể (slide 07) nằm ở mục 9 của workflows.md.

Xuất ảnh cho slide: dán từng khối vào https://mermaid.live rồi tải PNG hoặc SVG.

## 1. State machine bữa ăn trên máy (nhãn hiện ở S04)

```mermaid
stateDiagram-v2
  direction LR
  state "Chờ đồng bộ" as pending
  state "Đã đồng bộ" as synced
  state "Có xung đột" as conflict
  state "Cần thử lại" as failed

  [*] --> pending: Ghi/sửa/xóa, đạt BR-01, BR-02<br/>(ghi vào outbox cùng lúc)
  pending --> synced: POST /sync/push thành công,<br/>xóa dòng outbox
  pending --> pending: Mất mạng, lỗi tạm thời<br/>thử lại, có backoff
  pending --> failed: Hết 3 lần thử
  pending --> conflict: 409 version_conflict<br/>(baseVersion đã lỗi thời)
  failed --> pending: Người dùng bấm Thử lại
  conflict --> pending: Người dùng chọn giữ bản máy<br/>(tạo opId mới)
  conflict --> synced: Người dùng chọn dùng bản server
  synced --> [*]

  note right of conflict
    Khác bản 0.1: không còn
    "bị từ chối vĩnh viễn" —
    người dùng tự chọn ở màn Đồng bộ
  end note
```

## 2. State machine thông báo tới một thiết bị (`deliveries.status`)

```mermaid
stateDiagram-v2
  direction LR
  [*] --> pending: Admin gửi, đạt BR-05, BR-06, BR-07, BR-12
  pending --> sending: Khóa dòng để gửi<br/>(không gửi trùng)
  sending --> accepted: FCM nhận, trả message_id
  sending --> failed: Token hỏng (UNREGISTERED...)<br/>thiết bị active = 0
  sending --> retry: Lỗi tạm thời (429/5xx),<br/>còn dưới 3 lần thử
  retry --> sending: Job nền thử lại, backoff tăng
  sending --> unknown: Tiến trình bị ngắt giữa chừng
  accepted --> accepted: Người dùng chạm,<br/>chỉ đặt opened_at nếu còn trống (BR-08)
  failed --> [*]
  unknown --> [*]
```

## 3. ERD thật (12 bảng D1)

```mermaid
erDiagram
  users ||--o{ records : "sở hữu"
  users ||--o| admin_users : "có thể là"
  users ||--o{ device_tokens : "đăng ký"
  users ||--o{ assets : "sở hữu"
  records ||--o{ changes : "lịch sử"
  admin_users ||--o{ campaigns : "gửi"
  users ||--o{ campaigns : "nhận"
  campaigns ||--|{ deliveries : "tách theo thiết bị"
  device_tokens ||--o{ deliveries : "nhận"
  assets }o--o| records : "ảnh gắn vào bữa ăn"

  users {
    TEXT uid PK
  }
  admin_users {
    TEXT uid PK, FK
    INTEGER active "0 hoặc 1"
  }
  records {
    TEXT uid PK, FK
    TEXT kind PK "profile, goals, meal, plan"
    TEXT id PK "self, ID bữa ăn, hoặc ngày_buổi"
    TEXT data_json
    INTEGER version "optimistic concurrency"
    TEXT deleted_at "tombstone"
  }
  changes {
    INTEGER seq PK "con trỏ pull tăng dần"
    TEXT uid FK
    TEXT op_id UK
  }
  assets {
    TEXT id PK
    TEXT uid FK
    TEXT kind "photo hoặc pdf"
    TEXT meal_id "liên kết lỏng tới records"
    TEXT public_id UK "Cloudinary"
    TEXT status "pending, ready, rejected, deleted"
  }
  device_tokens {
    TEXT installation_id PK
    TEXT uid FK
    TEXT token UK
    TEXT secret_hash
    INTEGER generation
    INTEGER active
  }
  campaigns {
    TEXT id PK
    TEXT actor_uid FK, UK "cùng request_key"
    TEXT request_key UK
    TEXT target_uid FK
    TEXT route "danh sách cho phép"
  }
  deliveries {
    TEXT id PK
    TEXT campaign_id FK, UK
    TEXT installation_id UK
    TEXT status "pending..accepted/failed/unknown"
    TEXT opened_at
  }
```

`admin_audit_logs`, `crash_snapshots`, `maintenance_jobs`, `rate_limits` không vẽ ở đây vì không thuộc 3 workflow demo — chi tiết ở mục 3 của api-contract.md.

## 4. Activity WF-01 · Gửi lời nhắc ăn uống

```mermaid
flowchart TB
  subgraph AD["Admin (web, tab Gửi thông báo / Lịch sử gửi)"]
    a1["Chọn người nhận,<br/>soạn nội dung, chọn route"] --> a3["Xác nhận gửi"]
    a4["Web báo lỗi"]
    a6["Tab Lịch sử gửi: đã mở"]
  end
  subgraph SV["Hệ thống (Worker, D1)"]
    s1{"BR-05 Admin active?"}
    s2{"BR-06 route hợp lệ?"}
    s3{"BR-07 requestKey đã xử lý?"}
    s4{"BR-12 có 1..5<br/>thiết bị active?"}
    s5["Tạo campaign + deliveries pending,<br/>gọi FCM từng cái"]
    s6["accepted"]
    s7["failed / retry,<br/>BR-09 nếu token hỏng"]
    s9["opened_at (BR-08)"]
    s11["Trả lại lượt cũ"]
  end
  subgraph FC["FCM"]
    f2["Hiện thông báo trên điện thoại"]
  end
  subgraph US["Người dùng (app)"]
    u1["Chạm thông báo"]
    u4["Mở route trong data.route<br/>sang WF-02 nếu là /log"]
  end

  a3 --> s1
  s1 -- "không, 403" --> a4
  s1 -- "có" --> s2
  s2 -- "không, 400" --> a4
  s2 -- "có" --> s3
  s3 -- "rồi" --> s11 --> a6
  s3 -- "chưa" --> s4
  s4 -- "không, 400/409" --> a4
  s4 -- "có" --> s5
  s5 --> s6 --> f2 --> u1 --> u4
  s5 -. "lỗi FCM" .-> s7
  u4 -- "báo đã mở" --> s9 --> a6
```

## 5. Activity WF-02 · Ghi nhận / xóa bữa ăn trong ngày

```mermaid
flowchart TB
  subgraph US["Người dùng"]
    u1["Mở S05, hoặc bấm xóa ở S04"]
    u3["S04 hiện bữa kèm trạng thái,<br/>hoặc biến mất nếu đã xóa"]
  end
  subgraph AP["Hệ thống (app)"]
    p1{"BR-01, BR-02 hợp lệ?"}
    p2["Báo trường sai"]
    p5["Ghi SQLite cục bộ +<br/>1 dòng outbox (cùng transaction)"]
    p7{"SyncEngine gửi<br/>/sync/push thành công?"}
    p8["Giữ outbox pending,<br/>thử lại có backoff"]
    p10["Xóa dòng outbox:<br/>Đã đồng bộ"]
    p11["Có xung đột:<br/>chờ người dùng chọn"]
  end
  subgraph SV["Hệ thống (Worker, D1)"]
    s1{"BR-01..04 hợp lệ,<br/>BR-03 đúng baseVersion?"}
    s2["records: version+1<br/>hoặc deleted_at"]
  end

  u1 --> p1
  p1 -- "không" --> p2 --> u1
  p1 -- "có" --> p5 --> u3
  p5 --> p7
  p7 -- "mất mạng, timeout, 5xx" --> p8 --> p7
  p7 -- "có" --> s1
  s1 -- "409 version_conflict" --> p11 --> u3
  s1 -- "có" --> s2 -- "200" --> p10 --> u3
```

## 6. Activity WF-03 · Xuất báo cáo bữa ăn 7 ngày

```mermaid
flowchart TB
  subgraph US["Người dùng"]
    u1["S04 bấm Xuất báo cáo PDF"]
    u2["Báo 7 ngày gần nhất<br/>chưa có bữa ăn nào"]
    u3["Báo mất kết nối, nút Thử lại"]
    u5["Mở PDF"]
  end
  subgraph AP["Hệ thống (app)"]
    p1{"BR-10 có bữa trong 7 ngày?"}
    p2["Tạo PDF 7 ngày gần nhất"]
  end
  subgraph SV["Hệ thống (Worker)"]
    s1["POST /media/sign:<br/>ký vé tải thẳng lên Cloudinary"]
    s5["POST /media/:id/reconcile:<br/>xác nhận với Cloudinary, status=ready"]
    s7{"BR-11 đúng chủ asset?"}
    s8["POST /media/:id/url:<br/>cấp link hạn 15 phút"]
  end
  subgraph CL["Cloudinary"]
    c1["Nhận tệp PDF trực tiếp từ app"]
  end

  u1 --> p1
  p1 -- "không" --> u2
  p1 -- "có" --> p2 --> s1 --> c1
  c1 -- "mất mạng" --> u3 --> c1
  c1 --> s5 --> s7
  s7 -- "có" --> s8 --> u5
```

Link quá 15 phút thì không mở được nữa, người dùng xin link mới qua `POST /media/:id/url`, không cần tạo lại PDF.
