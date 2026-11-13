import { render, screen, within, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import { App } from "../src/App";
import { ApiClient } from "../src/api";
import type { AuthGateway, Session } from "../src/auth";

function fixture({
  signedIn = true,
  admin = true,
  fail = false,
}: { signedIn?: boolean; admin?: boolean; fail?: boolean } = {}) {
  let listener: (s: Session | null) => void = () => {};
  const sent: unknown[] = [];
  const auth: AuthGateway = {
    subscribe(cb) {
      listener = cb;
      cb(signedIn ? { uid: "admin", displayName: "Quản trị viên" } : null);
      return () => {};
    },
    async token() {
      return "test-firebase-token";
    },
    async signIn() {
      listener({ uid: "admin", displayName: "Admin" });
    },
    async signOut() {
      listener(null);
    },
  };
  const transport = vi.fn<typeof fetch>(async (input, init) => {
    const url = String(input);
    expect(new Headers(init?.headers).get("Authorization")).toBe(
      "Bearer test-firebase-token",
    );
    if (url.endsWith("/me"))
      return Response.json({ isAdmin: admin, uid: "admin" });
    if (fail)
      return Response.json(
        { error: { code: "provider_http_503" } },
        { status: 503 },
      );
    if (url.includes("/overview"))
      return Response.json({
        statistics: { users: 2, meals: 4, plans: 2, devices: 1, campaigns: 0 },
      });
    if (url.includes("/crashlytics/issues/"))
      return Response.json({
        issue: { id: "issue-1", title: "SDK crash" },
        events: { events: [{ type: "FATAL", customKeys: { route: "/log" } }] },
      });
    if (url.includes("/crashlytics/issues"))
      return Response.json({
        source: "firebase-crashlytics",
        fetchedAt: "2026-11-13T10:00:00Z",
        payload: {
          groups: [
            {
              issue: { id: "issue-1", title: "SDK crash", errorType: "FATAL" },
              eventCount: 1,
            },
          ],
        },
      });
    if (url.endsWith("/admin/push")) {
      sent.push(JSON.parse(String(init?.body)));
      return Response.json({
        deliveries: [{ id: "d1", installationId: "phone", status: "accepted" }],
      });
    }
    if (url.includes("/users"))
      return Response.json({
        items: [{ id: "userA", displayName: "A", createdAt: "2026-11-13" }],
        nextCursor: null,
      });
    return Response.json({ items: [], nextCursor: null });
  });
  render(
    <App
      auth={auth}
      makeApi={() => new ApiClient((force) => auth.token(force), transport)}
    />,
  );
  return { auth, sent, transport };
}
describe("Admin authenticated user journeys", () => {
  it("uses Google sign-in before checking server role", async () => {
    fixture({ signedIn: false });
    await userEvent.click(
      screen.getByRole("button", { name: "Tiếp tục với Google" }),
    );
    expect(
      await screen.findByRole("heading", { name: "Tổng quan" }),
    ).toBeInTheDocument();
  });
  it("denies normal users without rendering privileged controls", async () => {
    fixture({ admin: false });
    expect(
      await screen.findByRole("heading", { name: "Không có quyền truy cập" }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Gửi thông báo" }),
    ).not.toBeInTheDocument();
  });
  it("loads dashboard counts and empty device state", async () => {
    fixture();
    expect(
      await screen.findByRole("heading", { name: "Tổng quan" }),
    ).toBeInTheDocument();
    expect(await screen.findByText("4")).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Thiết bị" }));
    expect(
      await screen.findByText("Không có dữ liệu phù hợp."),
    ).toBeInTheDocument();
  });
  it("shows an API failure and allows retry", async () => {
    fixture({ fail: true });
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "provider_http_503",
    );
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
  });
  it("searches and paginates user records", async () => {
    const f = fixture();
    await screen.findByRole("heading", { name: "Tổng quan" });
    await userEvent.click(screen.getByRole("button", { name: "Người dùng" }));
    await userEvent.type(
      await screen.findByLabelText("Tìm tên hoặc UID"),
      "userA",
    );
    await userEvent.click(screen.getByRole("button", { name: "Tìm kiếm" }));
    await waitFor(() =>
      expect(
        f.transport.mock.calls.some(([url]) =>
          String(url).includes("search=userA"),
        ),
      ).toBe(true),
    );
    expect(await screen.findByText("userA")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Trang tiếp" })).toBeDisabled();
  });
  it("requires preview and explicit confirmation before FCM send", async () => {
    const f = fixture();
    await screen.findByRole("heading", { name: "Tổng quan" });
    await userEvent.click(
      screen.getByRole("button", { name: "Gửi thông báo" }),
    );
    await userEvent.type(screen.getByLabelText("UID người nhận"), "userA");
    await userEvent.type(screen.getByLabelText("Tiêu đề"), "Nhắc bữa ăn");
    await userEvent.type(screen.getByLabelText("Nội dung"), "Ghi lại bữa trưa");
    await userEvent.click(screen.getByRole("button", { name: "Xem trước" }));
    expect(f.sent).toHaveLength(0);
    const dialog = screen.getByRole("dialog");
    expect(within(dialog).getByText("Nhắc bữa ăn")).toBeInTheDocument();
    await userEvent.click(
      within(dialog).getByRole("button", { name: "Xác nhận gửi" }),
    );
    expect(await screen.findByText(/FCM đã chấp nhận/)).toBeInTheDocument();
    expect(f.sent).toHaveLength(1);
  });
  it("displays Crashlytics provenance and actual issue details safely", async () => {
    fixture();
    await screen.findByRole("heading", { name: "Tổng quan" });
    await userEvent.click(screen.getByRole("button", { name: "Crashlytics" }));
    expect(await screen.findByText("SDK crash")).toBeInTheDocument();
    expect(screen.getByText(/Nguồn: firebase-crashlytics/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Xem chi tiết" }));
    expect(await screen.findByRole("dialog")).toHaveTextContent("FATAL");
  });
  it("logs out and removes protected content", async () => {
    fixture();
    await screen.findByRole("heading", { name: "Tổng quan" });
    await userEvent.click(screen.getByRole("button", { name: "Đăng xuất" }));
    expect(
      await screen.findByRole("button", { name: "Tiếp tục với Google" }),
    ).toBeInTheDocument();
    expect(screen.queryByRole("navigation")).not.toBeInTheDocument();
  });
});
