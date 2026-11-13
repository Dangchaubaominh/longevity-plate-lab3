import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type FormEvent,
} from "react";
import { liveAuth, type AuthGateway, type Session } from "./auth";
import { ApiClient, array, errorText, object, type Json } from "./api";

const tabs = [
  ["overview", "Tổng quan"],
  ["users", "Người dùng"],
  ["devices", "Thiết bị"],
  ["notifications", "Gửi thông báo"],
  ["history", "Lịch sử gửi"],
  ["reports", "Báo cáo PDF"],
  ["crashes", "Crashlytics"],
  ["audit", "Nhật ký quản trị"],
] as const;
type Tab = (typeof tabs)[number][0];
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
      <main className="auth">
        <div className="login">
          <span className="brand">Longevity Plate</span>
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
      </main>
    );
  if (allowed !== true)
    return (
      <main className="auth">
        <div className="login">
          <span className="brand">Longevity Plate</span>
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
      </main>
    );
  return (
    <div className="shell">
      <aside>
        <a
          className="brand"
          href="#overview"
          onClick={() => setTab("overview")}
        >
          Longevity
          <br />
          Plate<span>ADMIN</span>
        </a>
        <nav aria-label="Điều hướng quản trị">
          {tabs.map(([key, label]) => (
            <button
              key={key}
              aria-current={tab === key ? "page" : undefined}
              onClick={() => setTab(key)}
            >
              {label}
            </button>
          ))}
        </nav>
        <div className="identity">
          <strong>{user.displayName ?? "Quản trị viên"}</strong>
          <button
            onClick={() =>
              void auth.signOut().catch((e) => setError(errorText(e)))
            }
          >
            Đăng xuất
          </button>
        </div>
      </aside>
      <main className="workspace">
        <header>
          <p>Không gian quản trị / {tabs.find((t) => t[0] === tab)?.[1]}</p>
          <span>Dữ liệu có phân quyền</span>
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
function Overview({ api }: { api: ApiClient }) {
  const { data, error, loading, reload } = useData(api, "/admin/overview");
  const stats = object(data?.statistics);
  const crashes=useData(api,'/admin/crashlytics/issues');
  const recent=array(object(crashes.data?.payload).groups).slice(0,3);
  return (
    <>
      <Title
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
        <div className="metrics">
          {[
            ["users", "Người dùng"],
            ["meals", "Bữa ăn"],
            ["plans", "Ô kế hoạch"],
            ["devices", "Thiết bị hoạt động"],
            ["campaigns", "Lượt gửi thông báo"],
          ].map(([key, label]) => (
            <article key={key}>
              <p>{label}</p>
              <strong>{Number(stats[key] ?? 0).toLocaleString("vi-VN")}</strong>
            </article>
          ))}
        </div>
      )}
      <div className="editorial">
        <h2>Chất lượng ứng dụng</h2>
        <p>
          Crashlytics cung cấp sự cố và ngữ cảnh từ Firebase. Kết quả gửi thông
          báo phân biệt lượt được FCM chấp nhận với lượt người dùng đã mở.
        </p>
        {recent.length>0&&<><h3>Sự cố trong snapshot gần nhất</h3><ul>{recent.map((group,index)=><li key={index}>{String(object(group.issue).title??'Issue')} · {String(object(group.issue).errorType??'')}</li>)}</ul></>}
      </div>
    </>
  );
}
function Title({ label, description }: { label: string; description: string }) {
  return (
    <div className="page-title">
      <h1>{label}</h1>
      <p>{description}</p>
    </div>
  );
}
function Loading() {
  return (
    <p role="status" className="empty">
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
    setConfirm(true);
  }
  async function send() {
    setBusy(true);
    setError("");
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
        label="Gửi thông báo"
        description="Gửi đến các thiết bị đang hoạt động của một tài khoản. Xem trước và xác nhận trước khi gửi."
      />
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
          <small>Tra UID tại mục Người dùng. Tối đa 5 thiết bị mỗi lượt.</small>
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
          <button type="submit">Xem trước</button>
        </fieldset>
      </form>
      {error && <ErrorBox message={error} />}{" "}
      {result && (
        <div className="send-result">
          <h2>Kết quả gửi</h2>
          {array(result.deliveries).map((row) => (
            <p key={String(row.id)}>
              <strong>{String(row.installationId)}</strong> ·{" "}
              {row.status === "accepted"
                ? "FCM đã chấp nhận"
                : row.status === "retry"
                  ? "Đang chờ thử lại"
                  : row.status === "unknown"
                    ? "Chưa xác định kết quả"
                    : `Thất bại (${String(row.errorCode ?? row.status)})`}
              {row.openedAt ? " · Người dùng đã mở" : ""}
            </p>
          ))}
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
            return (
              <article key={String(id ?? index)}>
                <div>
                  <h2>
                    {String(issue.title ?? issue.subtitle ?? id ?? "Issue")}
                  </h2>
                  {issue.errorType ? (
                    <span>{String(issue.errorType)}</span>
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
