import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type FormEvent,
} from "react";
import { liveAuth, type AuthGateway, type Session } from "./auth";
import { ApiClient, array, errorText, object, type Json } from "./api";

// Trang trí thuần túy — không mang nội dung, ẩn khỏi trình đọc màn hình.
const ICONS = {
  grid: "M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z",
  users: "M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm0 2c-3 0-6 1.5-6 4v2h12v-2c0-2.5-3-4-6-4Zm8-5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Zm0 1.2c-.7 0-1.4.1-2 .3 1.3.9 2 2.1 2 3.5v2h4v-2c0-1.9-1.8-3.3-4-3.8Z",
  devices: "M7 3h10v15H7zM10 20h4M9 6h6",
  bell: "M12 3a5 5 0 0 0-5 5v3.3c0 .6-.2 1.2-.6 1.7L5 15h14l-1.4-2c-.4-.5-.6-1.1-.6-1.7V8a5 5 0 0 0-5-5Zm-2 17a2 2 0 0 0 4 0",
  clock: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0-14v5l3 2",
  file: "M7 3h7l4 4v14H7Zm7 0v4h4",
  warn: "M12 4 3 20h18ZM12 10v4m0 3h.01",
  log: "M4 6h16M4 12h16M4 18h10",
  logout: "M9 5H5v14h4M15 15l4-3-4-3M19 12H9",
  check: "M4 12l5 5 11-11",
  chart: "M4 20h16M7 20v-7M12 20V7M17 20v-11",
} as const;
function Icon({ name, className }: { name: keyof typeof ICONS; className?: string }) {
  return (
    <svg
      className={`icon${className ? ` ${className}` : ""}`}
      viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <path d={ICONS[name]} />
    </svg>
  );
}

const tabs = [
  ["overview", "Tổng quan", "grid"],
  ["users", "Người dùng", "users"],
  ["devices", "Thiết bị", "devices"],
  ["notifications", "Gửi thông báo", "bell"],
  ["history", "Lịch sử gửi", "clock"],
  ["reports", "Báo cáo PDF", "file"],
  ["crashes", "Crashlytics", "warn"],
  ["audit", "Nhật ký quản trị", "log"],
] as const;
type Tab = (typeof tabs)[number][0];
function statusBadge(value: string) {
  const v = value.toLowerCase();
  const kind = ["accepted", "opened", "active", "ready", "1", "true"].includes(v)
    ? "success"
    : ["retry", "unknown", "pending", "sending"].includes(v)
      ? "warn"
      : ["failed", "rejected", "0", "false", "deleted"].includes(v)
        ? "danger"
        : "neutral";
  return <span className={`badge badge-${kind}`}>{value}</span>;
}
export function App({
  auth = liveAuth,
  makeApi = (a: AuthGateway) => new ApiClient((force) => a.token(force)),
}: {
  auth?: AuthGateway;
  makeApi?: (a: AuthGateway) => ApiClient;
}) {
  const [user, setUser] = useState<Session | null>(null),
    [ready, setReady] = useState(false),
    [allowed, setAllowed] = useState<boolean | null>(null),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [tab, setTab] = useState<Tab>("overview");
  const [api] = useState(() => makeApi(auth));
  useEffect(
    () =>
      auth.subscribe(
        (value) => {
          setUser(value);
          setReady(true);
          setAllowed(null);
          setError("");
        },
        (e) => {
          setError(errorText(e));
          setReady(true);
        },
      ),
    [auth],
  );
  useEffect(() => {
    let stale = false;
    if (user)
      void api
        .call("/me")
        .then((data) => {
          if (!stale) setAllowed(data.isAdmin === true);
        })
        .catch((e) => {
          if (!stale) setError(errorText(e));
        });
    return () => {
      stale = true;
    };
  }, [user, api]);
  async function login() {
    setBusy(true);
    setError("");
    try {
      await auth.signIn();
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  }
  if (!ready)
    return (
      <main className="auth">
        <p role="status">Đang khôi phục phiên…</p>
      </main>
    );
  if (!user)
    return (
      <main className="auth auth-split">
        <div className="auth-panel">
          <div className="login">
            <span className="brand">
              <span className="brand-mark" aria-hidden="true">
                <Icon name="chart" />
              </span>
              Longevity Plate
            </span>
            <p className="eyebrow">Không gian quản trị</p>
            <h1>
              Theo dõi ứng dụng,
              <br />
              đồng hành cùng người dùng.
            </h1>
            <p>
              Quản lý thông báo, báo cáo và chất lượng ứng dụng bằng tài khoản
              được cấp quyền.
            </p>
            {error && <ErrorBox message={error} />}
            <button onClick={() => void login()} disabled={busy}>
              {busy ? "Đang đăng nhập…" : "Tiếp tục với Google"}
            </button>
            <small>Chỉ dành cho quản trị viên Longevity Plate.</small>
          </div>
        </div>
        <div className="auth-art" aria-hidden="true">
          <div className="auth-art-copy">
            <strong>Theo dõi 3 workflow lõi</strong>
            <span>
              Gửi lời nhắc · ghi nhận bữa ăn · xuất báo cáo — tất cả dữ liệu
              có phân quyền theo đúng tài khoản Admin.
            </span>
          </div>
        </div>
      </main>
    );
  if (allowed !== true)
    return (
      <main className="auth auth-split">
        <div className="auth-panel">
          <div className="login">
            <span className="brand">
              <span className="brand-mark" aria-hidden="true">
                <Icon name="chart" />
              </span>
              Longevity Plate
            </span>
            <h1>
              {allowed === false
                ? "Không có quyền truy cập"
                : "Đang kiểm tra quyền…"}
            </h1>
            <p>
              {allowed === false
                ? "Tài khoản đã đăng nhập chưa nằm trong danh sách quản trị viên. Liên hệ người quản lý dự án để được cấp quyền."
                : "Quyền quản trị được xác nhận bởi máy chủ."}
            </p>
            {error && <ErrorBox message={error} />}
            <button
              onClick={() =>
                void auth.signOut().catch((e) => setError(errorText(e)))
              }
            >
              Đăng xuất
            </button>
          </div>
        </div>
        <div className="auth-art" aria-hidden="true">
          <div className="auth-art-copy">
            <strong>Mỗi tài khoản một vai trò</strong>
            <span>
              Admin được cấp quyền thủ công trên D1 — không có API tự nâng
              quyền.
            </span>
          </div>
        </div>
      </main>
    );
  const initials = (user.displayName ?? "Quản trị viên")
    .split(" ")
    .slice(-2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
  return (
    <div className="shell">
      <aside>
        <a
          className="brand"
          href="#overview"
          onClick={() => setTab("overview")}
        >
          <span className="brand-mark" aria-hidden="true">
            <Icon name="chart" />
          </span>
          <span className="brand-text">
            Longevity
            <br />
            Plate<span className="brand-tag">ADMIN</span>
          </span>
        </a>
        <nav aria-label="Điều hướng quản trị">
          {tabs.map(([key, label, icon]) => (
            <button
              key={key}
              aria-current={tab === key ? "page" : undefined}
              onClick={() => setTab(key)}
            >
              <Icon name={icon} />
              {label}
            </button>
          ))}
        </nav>
        <div className="identity">
          <span className="identity-avatar" aria-hidden="true">
            {initials || "?"}
          </span>
          <div className="identity-name">
            <strong>{user.displayName ?? "Quản trị viên"}</strong>
            <span className="identity-role">Quản trị viên</span>
          </div>
          <button
            className="secondary identity-logout"
            title="Đăng xuất"
            aria-label="Đăng xuất"
            onClick={() =>
              void auth.signOut().catch((e) => setError(errorText(e)))
            }
          >
            <Icon name="logout" />
          </button>
        </div>
      </aside>
      <main className="workspace">
        <header>
          <p>Không gian quản trị / {tabs.find((t) => t[0] === tab)?.[1]}</p>
          <span>
            <Icon name="check" />
            Dữ liệu có phân quyền
          </span>
        </header>
        {error && <ErrorBox message={error} />}
        <section key={tab}>
          {tab === "overview" ? (
            <Overview api={api} />
          ) : tab === "notifications" ? (
            <NotificationForm api={api} />
          ) : tab === "crashes" ? (
            <Crashes api={api} />
          ) : (
            <Records api={api} tab={tab} />
          )}
        </section>
        <footer>Longevity Plate · PRM393 Lab 3</footer>
      </main>
    </div>
  );
}
export function ErrorBox({ message }: { message: string }) {
  return (
    <p className="error" role="alert">
      {message}
    </p>
  );
}
const METRIC_ICONS = {
  users: "users",
  meals: "file",
  plans: "clock",
  devices: "devices",
  campaigns: "bell",
} as const;
function Overview({ api }: { api: ApiClient }) {
  const { data, error, loading, reload } = useData(api, "/admin/overview");
  const stats = object(data?.statistics);
  const crashes=useData(api,'/admin/crashlytics/issues');
  const recent=array(object(crashes.data?.payload).groups).slice(0,3);
  return (
    <>
      <Title
        icon="grid"
        label="Tổng quan"
        description="Hoạt động được tổng hợp từ dữ liệu trên máy chủ."
      />
      {loading ? (
        <Loading />
      ) : error ? (
        <>
          <ErrorBox message={error} />
          <button onClick={reload}>Thử lại</button>
        </>
      ) : (
        <>
          <div className="metrics">
            {[
              ["users", "Người dùng"],
              ["meals", "Bữa ăn"],
              ["plans", "Ô kế hoạch"],
              ["devices", "Thiết bị hoạt động"],
              ["campaigns", "Lượt gửi thông báo"],
            ].map(([key, label]) => (
              <article key={key}>
                <span className="metric-icon" aria-hidden="true">
                  <Icon name={METRIC_ICONS[key as keyof typeof METRIC_ICONS]} />
                </span>
                <p>{label}</p>
                <strong>{Number(stats[key] ?? 0).toLocaleString("vi-VN")}</strong>
              </article>
            ))}
          </div>
          <OverviewBars stats={stats} />
        </>
      )}
      <div className="editorial">
        <div className="editorial-head">
          <span className="page-title-icon" aria-hidden="true">
            <Icon name="warn" />
          </span>
          <h2>Chất lượng ứng dụng</h2>
        </div>
        <p>
          Crashlytics cung cấp sự cố và ngữ cảnh từ Firebase. Kết quả gửi thông
          báo phân biệt lượt được FCM chấp nhận với lượt người dùng đã mở.
        </p>
        {recent.length > 0 && (
          <>
            <h3>Sự cố trong snapshot gần nhất</h3>
            <ul>
              {recent.map((group, index) => (
                <li key={index}>
                  <Icon name="warn" />
                  {String(object(group.issue).title ?? "Issue")} ·{" "}
                  {String(object(group.issue).errorType ?? "")}
                </li>
              ))}
            </ul>
          </>
        )}
      </div>
    </>
  );
}
// Biểu đồ cột ngang — dùng đúng số liệu thật từ /admin/overview, không có số
// nào bịa; chỉ là cách trình bày khác cho cùng 5 con số ở trên.
function OverviewBars({ stats }: { stats: Json }) {
  const rows: [string, string][] = [
    ["users", "Người dùng"],
    ["meals", "Bữa ăn"],
    ["plans", "Ô kế hoạch"],
    ["devices", "Thiết bị hoạt động"],
    ["campaigns", "Lượt gửi thông báo"],
  ];
  const values = rows.map(([key]) => Number(stats[key] ?? 0));
  const max = Math.max(1, ...values);
  return (
    <div className="bars">
      <h3>So sánh quy mô</h3>
      {rows.map(([key, label], i) => (
        <div className="bar-row" key={key}>
          <span className="bar-label">{label}</span>
          <div className="bar-track">
            <div
              className="bar-fill"
              style={{ width: `${(values[i] / max) * 100}%` }}
            />
          </div>
          <span className="bar-value">
            {values[i].toLocaleString("vi-VN")}
          </span>
        </div>
      ))}
    </div>
  );
}
function Title({
  label,
  description,
  icon,
}: {
  label: string;
  description: string;
  icon?: keyof typeof ICONS;
}) {
  return (
    <div className="page-title">
      {icon && (
        <span className="page-title-icon" aria-hidden="true">
          <Icon name={icon} />
        </span>
      )}
      <div>
        <h1>{label}</h1>
        <p>{description}</p>
      </div>
    </div>
  );
}
function Loading() {
  return (
    <p role="status" className="empty">
      <Icon name="clock" />
      Đang tải dữ liệu…
    </p>
  );
}
function useData(api: ApiClient, path: string) {
  const [data, setData] = useState<Json | null>(null),
    [loading, setLoading] = useState(true),
    [error, setError] = useState(""),
    [generation, setGeneration] = useState(0);
  const reload = useCallback(() => setGeneration((g) => g + 1), []);
  useEffect(() => {
    let stale = false;
    setLoading(true);
    setError("");
    void api
      .call(path)
      .then((value) => {
        if (!stale) setData(value);
      })
      .catch((e) => {
        if (!stale) setError(errorText(e));
      })
      .finally(() => {
        if (!stale) setLoading(false);
      });
    return () => {
      stale = true;
    };
  }, [api, path, generation]);
  return { data, loading, error, reload };
}
function Records({
  api,
  tab,
}: {
  api: ApiClient;
  tab: Exclude<Tab, "overview" | "notifications" | "crashes">;
}) {
  const [cursor, setCursor] = useState(""),
    [search, setSearch] = useState(""),
    [query, setQuery] = useState("");
  const endpoints = {
    users: "users",
    devices: "devices",
    history: "push-jobs",
    reports: "reports",
    audit: "audit-logs",
  };
  const path = `/admin/${endpoints[tab]}?limit=15&cursor=${encodeURIComponent(cursor)}${tab === "users" ? `&search=${encodeURIComponent(query)}` : ""}`;
  const { data, loading, error, reload } = useData(api, path);
  const items = array(data?.items);
  const columns: Record<typeof tab, [string, string][]> = {
    users: [
      ["id", "UID"],
      ["displayName", "Tên hiển thị"],
      ["createdAt", "Ngày tạo"],
      ["mealCount", "Bữa ăn"],
      ["planCount", "Ô kế hoạch"],
    ],
    devices: [
      ["installationId", "Bản cài"],
      ["uid", "UID"],
      ["platform", "Nền tảng"],
      ["appVersion", "Phiên bản"],
      ["active", "Hoạt động"],
    ],
    history: [
      ["id", "Mã lượt gửi"],
      ["targetUid", "Người nhận"],
      ["title", "Tiêu đề"],
      ["status", "Trạng thái xử lý"],
    ],
    reports: [
      ["id", "Mã tệp"],
      ["uid", "Chủ sở hữu"],
      ["status", "Trạng thái"],
      ["bytes", "Dung lượng (byte)"],
    ],
    audit: [
      ["id", "Mã"],
      ["actorUid", "Người thực hiện"],
      ["action", "Thao tác"],
      ["createdAt", "Thời điểm"],
    ],
  };
  const [detail, setDetail] = useState<Json | null>(null),
    [detailError, setDetailError] = useState("");
  async function inspect(id: unknown) {
    setDetailError("");
    try {
      setDetail(
        await api.call(`/admin/push-jobs/${encodeURIComponent(String(id))}`),
      );
    } catch (e) {
      setDetailError(errorText(e));
    }
  }
  return (
    <>
      <Title
        icon={tabs.find((t) => t[0] === tab)![2]}
        label={tabs.find((t) => t[0] === tab)![1]}
        description={
          tab === "history"
            ? "Accepted nghĩa là FCM đã chấp nhận yêu cầu; opened được ghi khi người dùng mở thông báo."
            : "Thông tin được giới hạn theo quyền quản trị."
        }
      />
      {tab === "users" && (
        <form
          className="search"
          onSubmit={(e) => {
            e.preventDefault();
            setCursor("");
            setQuery(search);
          }}
        >
          <label htmlFor="search">Tìm tên hoặc UID</label>
          <input
            id="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            maxLength={80}
          />
          <button>Tìm kiếm</button>
        </form>
      )}
      {loading ? (
        <Loading />
      ) : error ? (
        <>
          <ErrorBox message={error} />
          <button onClick={reload}>Thử lại</button>
        </>
      ) : items.length === 0 ? (
        <p className="empty">Không có dữ liệu phù hợp.</p>
      ) : (
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                {columns[tab].map(([key, label]) => (
                  <th key={key}>{label}</th>
                ))}
                {tab === "history" && <th>Chi tiết</th>}
              </tr>
            </thead>
            <tbody>
              {items.map((row, i) => (
                <tr key={String(row.id ?? row.installationId ?? i)}>
                  {columns[tab].map(([key]) => (
                    <td key={key}>
                      {row[key] === null || row[key] === undefined
                        ? "—"
                        : key === "status" || key === "active"
                          ? statusBadge(String(row[key]))
                          : String(row[key])}
                    </td>
                  ))}
                  {tab === "history" && (
                    <td>
                      <button
                        className="secondary"
                        onClick={() => void inspect(row.id)}
                      >
                        Xem kết quả
                      </button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <div className="pagination">
        <button
          className="secondary"
          disabled={!cursor || loading}
          onClick={() => setCursor("")}
        >
          Về đầu
        </button>
        <button
          disabled={!data?.nextCursor || loading}
          onClick={() => setCursor(String(data?.nextCursor))}
        >
          Trang tiếp
        </button>
      </div>
      {detailError && <ErrorBox message={detailError} />}{" "}
      {detail && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="history-detail"
          className="modal-backdrop"
        >
          <div className="modal">
            <h2 id="history-detail">Kết quả từng thiết bị</h2>
            <pre>{JSON.stringify(detail, null, 2)}</pre>
            <button onClick={() => setDetail(null)}>Đóng</button>
          </div>
        </div>
      )}
    </>
  );
}
function NotificationForm({ api }: { api: ApiClient }) {
  const [targetUid, setTargetUid] = useState(""),
    [title, setTitle] = useState(""),
    [body, setBody] = useState(""),
    [route, setRoute] = useState("/log"),
    [confirm, setConfirm] = useState(false),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [result, setResult] = useState<Json | null>(null);
  const requestKey = useRef<string | null>(null);
  const deliveries = array(result?.deliveries);
  // A confirmed rejection is safe to submit as a new campaign. Keep the key
  // for accepted, partial, pending or unknown outcomes to avoid duplicate push.
  const allFailed =
    deliveries.length > 0 && deliveries.every((row) => row.status === "failed");
  const hasUnregisteredToken = deliveries.some(
    (row) => row.errorCode === "UNREGISTERED",
  );
  function changed() {
    requestKey.current = null;
    setResult(null);
    setError("");
  }
  function preview(e: FormEvent) {
    e.preventDefault();
    if (!targetUid.trim() || !title.trim() || !body.trim()) {
      setError("Điền người nhận, tiêu đề và nội dung.");
      return;
    }
    if (allFailed) requestKey.current = null;
    setConfirm(true);
  }
  async function send() {
    setBusy(true);
    setError("");
    // The previous rejection must not allow another new key if this attempt
    // times out after the server may already have accepted it.
    setResult(null);
    requestKey.current ??= crypto.randomUUID();
    try {
      setResult(
        await api.call("/admin/push", "POST", {
          targetUid: targetUid.trim(),
          title: title.trim(),
          body: body.trim(),
          route,
          requestKey: requestKey.current,
        }),
      );
      setConfirm(false);
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <Title
        icon="bell"
        label="Gửi thông báo"
        description="Gửi đến các thiết bị đang hoạt động của một tài khoản. Xem trước và xác nhận trước khi gửi."
      />
      <div className="notification-layout">
        <form className="notification-form" onSubmit={preview}>
          <fieldset disabled={busy}>
            <label htmlFor="target">UID người nhận</label>
            <input
              id="target"
              required
              maxLength={128}
              value={targetUid}
              onChange={(e) => {
                changed();
                setTargetUid(e.target.value);
              }}
            />
            <label htmlFor="title">Tiêu đề</label>
            <input
              id="title"
              required
              maxLength={100}
              value={title}
              onChange={(e) => {
                changed();
                setTitle(e.target.value);
              }}
            />
            <label htmlFor="message">Nội dung</label>
            <textarea
              id="message"
              required
              maxLength={500}
              rows={5}
              value={body}
              onChange={(e) => {
                changed();
                setBody(e.target.value);
              }}
            />
            <label htmlFor="route">Màn hình khi chạm</label>
            <select
              id="route"
              value={route}
              onChange={(e) => {
                changed();
                setRoute(e.target.value);
              }}
            >
              <option value="/log">Nhật ký</option>
              <option value="/plan">Kế hoạch</option>
              <option value="/library">Kiến thức</option>
              <option value="/home">Hôm nay</option>
            </select>
            <button type="submit">
              <Icon name="check" />
              {allFailed ? "Xem trước lượt gửi mới" : "Xem trước"}
            </button>
          </fieldset>
        </form>
        <div className="tip-card">
          <h3>
            <Icon name="users" />
            Tra UID ở đâu?
          </h3>
          <ul>
            <li>Mở tab Người dùng, tìm theo tên hoặc UID, sao chép cột UID.</li>
            <li>Tối đa 5 thiết bị đang hoạt động nhận được mỗi lượt gửi.</li>
            <li>
              Khi chưa rõ kết quả, thử lại sẽ kiểm tra cùng lượt gửi để tránh
              thông báo trùng. Nếu tất cả thiết bị đã báo thất bại, bạn có thể
              xem trước và xác nhận một lượt gửi mới.
            </li>
          </ul>
        </div>
      </div>
      {error && <ErrorBox message={error} />}{" "}
      {result && (
        <div className="send-result">
          <h2>Kết quả gửi</h2>
          {hasUnregisteredToken && (
            <p role="status">
              Token thông báo của thiết bị cũ đã hết hiệu lực. Mở Longevity Plate
              trên điện thoại, bật quyền thông báo và kết nối mạng để đăng ký
              thiết bị hiện tại. Kiểm tra tab Thiết bị trước khi gửi lại.
            </p>
          )}
          {allFailed && (
            <p>
              Lượt này đã thất bại trên tất cả thiết bị. Sau khi xử lý nguyên
              nhân, bấm “Xem trước lượt gửi mới” rồi xác nhận để gửi lại.
            </p>
          )}
          {deliveries.map((row) => {
            const text =
              row.status === "accepted"
                ? "FCM đã chấp nhận"
                : row.status === "retry"
                  ? "Đang chờ thử lại"
                  : row.status === "unknown"
                    ? "Chưa xác định kết quả"
                    : row.status === "pending" || row.status === "sending"
                      ? "Đang xử lý gửi"
                      : row.errorCode === "UNREGISTERED"
                        ? "Thất bại: token thiết bị đã hết hiệu lực (UNREGISTERED)"
                        : `Thất bại (${String(row.errorCode ?? row.status)})`;
            const kind =
              row.status === "accepted"
                ? "success"
                : ["retry", "unknown", "pending", "sending"].includes(
                    String(row.status),
                  )
                  ? "warn"
                  : "danger";
            return (
              <p key={String(row.id)}>
                <strong>{String(row.installationId)}</strong> ·{" "}
                <span className={`badge badge-${kind}`}>{text}</span>
                {row.openedAt ? " · Người dùng đã mở" : ""}
              </p>
            );
          })}
        </div>
      )}
      {confirm && (
        <div className="modal-backdrop">
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="confirm-title"
            className="modal"
          >
            <h2 id="confirm-title">Xác nhận gửi thông báo</h2>
            <p>Người nhận: {targetUid}</p>
            <h3>{title}</h3>
            <p className="preview-body">{body}</p>
            <p>Màn hình đích: {route}</p>
            {error && <ErrorBox message={error} />}
            <div className="actions">
              <button
                className="secondary"
                disabled={busy}
                onClick={() => setConfirm(false)}
              >
                Quay lại
              </button>
              <button disabled={busy} onClick={() => void send()}>
                {busy ? "Đang gửi…" : "Xác nhận gửi"}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
// Tổng hợp từ đúng các issue backend đã đọc được — không ước tính phần trăm
// crash-free vì server không có tổng số phiên để tính đúng số đó.
function CrashSummary({ groups }: { groups: Json[] }) {
  const events = groups.reduce(
    (sum, row) => sum + (Number(row.eventCount) || 0),
    0,
  );
  const impacted = groups.reduce(
    (sum, row) => sum + (Number(row.impactedUserCount) || 0),
    0,
  );
  return (
    <div className="metrics crash-summary">
      <article>
        <span className="metric-icon" aria-hidden="true">
          <Icon name="warn" />
        </span>
        <p>Tổng sự cố</p>
        <strong>{groups.length.toLocaleString("vi-VN")}</strong>
      </article>
      <article>
        <span className="metric-icon" aria-hidden="true">
          <Icon name="chart" />
        </span>
        <p>Tổng sự kiện</p>
        <strong>{events.toLocaleString("vi-VN")}</strong>
      </article>
      <article>
        <span className="metric-icon" aria-hidden="true">
          <Icon name="users" />
        </span>
        <p>Người dùng bị ảnh hưởng</p>
        <strong>{impacted.toLocaleString("vi-VN")}</strong>
      </article>
    </div>
  );
}
const SEVERITY_LABELS: Record<string, string> = {
  FATAL: "Fatal",
  NON_FATAL: "Non-fatal",
  ANR: "ANR",
};
const SEVERITY_COLORS: Record<string, string> = {
  FATAL: "var(--danger)",
  NON_FATAL: "var(--warn)",
  ANR: "var(--accent)",
};
function severityOf(row: Json) {
  return (
    String(object(row.issue).errorType ?? row.errorType ?? "").toUpperCase() ||
    "KHÁC"
  );
}
// Donut + top-issue theo đúng "groups" đã tải (snapshot đầy đủ, không phải
// trang phân trang) — không suy diễn thêm số liệu nào backend không trả.
function CrashBreakdown({ groups }: { groups: Json[] }) {
  if (groups.length === 0) return null;
  const counts = new Map<string, number>();
  for (const row of groups) {
    const key = severityOf(row);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  const total = groups.length;
  const r = 54,
    c = 2 * Math.PI * r;
  let cumulative = 0;
  const arcs = [...counts.entries()].map(([key, count]) => {
    const frac = count / total;
    const arc = {
      key,
      color: SEVERITY_COLORS[key] ?? "var(--ink-faint)",
      dasharray: `${frac * c} ${c - frac * c}`,
      dashoffset: -cumulative,
    };
    cumulative += frac * c;
    return arc;
  });
  const top = [...groups]
    .sort((a, b) => (Number(b.eventCount) || 0) - (Number(a.eventCount) || 0))
    .slice(0, 5);
  const topMax = Math.max(1, ...top.map((row) => Number(row.eventCount) || 0));
  return (
    <div className="crash-breakdown">
      <div className="donut-card">
        <h3>Phân loại mức độ</h3>
        <div className="donut-wrap">
          <svg viewBox="0 0 140 140" className="donut" aria-hidden="true">
            <circle cx="70" cy="70" r={r} className="donut-track" />
            {arcs.map((arc) => (
              <circle
                key={arc.key}
                cx="70"
                cy="70"
                r={r}
                stroke={arc.color}
                strokeDasharray={arc.dasharray}
                strokeDashoffset={arc.dashoffset}
              />
            ))}
          </svg>
          <div className="donut-center">
            <strong>{total.toLocaleString("vi-VN")}</strong>
            <span>sự cố</span>
          </div>
        </div>
        <ul className="donut-legend">
          {arcs.map((arc) => (
            <li key={arc.key}>
              <span
                className="legend-dot"
                style={{ background: arc.color }}
                aria-hidden="true"
              />
              {SEVERITY_LABELS[arc.key] ?? arc.key} · {counts.get(arc.key)}
            </li>
          ))}
        </ul>
      </div>
      <div className="bars top-issues">
        <h3>Top sự cố theo số sự kiện</h3>
        {top.map((row, i) => {
          const issue = object(row.issue);
          const label = String(issue.title ?? issue.subtitle ?? `Issue ${i + 1}`);
          const value = Number(row.eventCount) || 0;
          return (
            <div className="bar-row" key={String(issue.id ?? i)}>
              <span className="bar-label" title={label}>
                {label}
              </span>
              <div className="bar-track">
                <div
                  className="bar-fill"
                  style={{ width: `${(value / topMax) * 100}%` }}
                />
              </div>
              <span className="bar-value">{value.toLocaleString("vi-VN")}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
function Crashes({ api }: { api: ApiClient }) {
  const { data, error, loading, reload } = useData(
    api,
    "/admin/crashlytics/issues",
  );
  const [refreshing, setRefreshing] = useState(false),
    [actionError, setActionError] = useState(""),
    [detail, setDetail] = useState<Json | null>(null),
    [filter, setFilter] = useState("all");
  const payload = object(data?.payload);
  const groups = array(payload.groups);
  const visible = groups.filter(
    (row) =>
      filter === "all" ||
      String(
        object(row.issue).errorType ?? row.errorType ?? "",
      ).toUpperCase() === filter,
  );
  async function refresh() {
    setRefreshing(true);
    setActionError("");
    try {
      await api.call("/admin/crashlytics/refresh", "POST", {});
      reload();
    } catch (e) {
      setActionError(errorText(e));
    } finally {
      setRefreshing(false);
    }
  }
  async function inspect(id: unknown) {
    setActionError("");
    try {
      setDetail(
        await api.call(
          `/admin/crashlytics/issues/${encodeURIComponent(String(id))}`,
        ),
      );
    } catch (e) {
      setActionError(errorText(e));
    }
  }
  return (
    <>
      <Title
        icon="warn"
        label="Crashlytics"
        description="Báo cáo sự cố được backend đọc từ Firebase Crashlytics. Dữ liệu có độ trễ tiếp nhận và thời điểm cập nhật riêng."
      />
      <div className="toolbar">
        <label>
          Loại sự cố{" "}
          <select value={filter} onChange={(e) => setFilter(e.target.value)}>
            <option value="all">Tất cả</option>
            <option value="FATAL">Fatal</option>
            <option value="NON_FATAL">Non-fatal</option>
            <option value="ANR">ANR</option>
          </select>
        </label>
        <button disabled={refreshing} onClick={() => void refresh()}>
          {refreshing ? "Đang lấy dữ liệu…" : "Làm mới từ Firebase"}
        </button>
      </div>
      {data?.fetchedAt ? (
        <p className="source">
          Nguồn: {String(data.source)} · Cập nhật:{" "}
          {new Date(String(data.fetchedAt)).toLocaleString("vi-VN")}
        </p>
      ) : null}
      {!loading && !error && (
        <>
          <CrashSummary groups={groups} />
          <CrashBreakdown groups={groups} />
        </>
      )}
      {actionError && <ErrorBox message={actionError} />}{" "}
      {loading ? (
        <Loading />
      ) : error ? (
        <>
          <ErrorBox message={error} />
          <button onClick={reload}>Thử lại</button>
        </>
      ) : visible.length === 0 ? (
        <p className="empty">
          Không có sự cố trong dữ liệu và bộ lọc hiện tại.
        </p>
      ) : (
        <div className="issue-list">
          {visible.map((row, index) => {
            const issue = object(row.issue);
            const id =
              issue.id ??
              String(issue.name ?? "")
                .split("/")
                .at(-1);
            const severity = String(issue.errorType ?? "");
            return (
              <article key={String(id ?? index)} data-severity={severity}>
                <div className="issue-main">
                  <span className="issue-icon" aria-hidden="true">
                    <Icon name="warn" />
                  </span>
                  <div>
                  <h2>
                    {String(issue.title ?? issue.subtitle ?? id ?? "Issue")}
                  </h2>
                  {issue.errorType ? (
                    <span
                      className={`badge ${severity === "FATAL" ? "badge-danger" : "badge-warn"}`}
                    >
                      {severity}
                    </span>
                  ) : null}
                  <p>
                    {row.eventCount !== undefined
                      ? `${String(row.eventCount)} sự kiện`
                      : ""}
                    {row.impactedUserCount !== undefined
                      ? ` · ${String(row.impactedUserCount)} người dùng`
                      : ""}
                  </p>
                  </div>
                </div>
                {id ? (
                  <button
                    className="secondary"
                    onClick={() => void inspect(id)}
                  >
                    Xem chi tiết
                  </button>
                ) : (
                  <pre>{JSON.stringify(row, null, 2)}</pre>
                )}
              </article>
            );
          })}
        </div>
      )}
      {detail && (
        <div className="modal-backdrop">
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="crash-detail"
            className="modal"
          >
            <h2 id="crash-detail">Issue và event từ Firebase</h2>
            <p>
              Stacktrace, app version và custom keys hiển thị theo dữ liệu nguồn
              trả về.
            </p>
            <pre>{JSON.stringify(detail, null, 2)}</pre>
            <button onClick={() => setDetail(null)}>Đóng</button>
          </div>
        </div>
      )}
    </>
  );
}
