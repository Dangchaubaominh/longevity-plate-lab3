import { test, expect, type Page } from "@playwright/test";
async function api(page: Page, isAdmin = true) {
  await page.route("**/api/v1/**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    const data = path.endsWith("/me")
      ? { uid: "browser-test-admin", isAdmin }
      : path.endsWith("/overview")
        ? {
            statistics: {
              users: 8,
              meals: 24,
              devices: 2,
              plans: 6,
              campaigns: 1,
            },
          }
        : path.includes("crashlytics")
          ? {
              source: "firebase-crashlytics",
              fetchedAt: "2026-11-13T10:00:00Z",
              payload: {
                groups: [
                  {
                    issue: {
                      id: "issue-1",
                      title: "Test issue",
                      errorType: "FATAL",
                    },
                    eventCount: 1,
                  },
                ],
              },
            }
          : path.endsWith("/push")
            ? {
                deliveries: [
                  { id: "d1", installationId: "phone", status: "accepted" },
                ],
              }
            : { items: [], nextCursor: null };
    await route.fulfill({ json: data });
  });
}
test("server role controls whether privileged pages render", async ({
  page,
}) => {
  await api(page, false);
  await page.goto("/test/harness.html");
  await expect(
    page.getByRole("heading", { name: "Không có quyền truy cập" }),
  ).toBeVisible();
  await expect(page.getByRole("navigation")).toHaveCount(0);
});
test("desktop dashboard, notifications and crash report remain usable", async ({
  page,
}) => {
  await api(page);
  await page.goto("/test/harness.html");
  await expect(page.getByRole("heading", { name: "Tổng quan" })).toBeVisible();
  await page
    .getByRole("button", { name: "Gửi thông báo", exact: true })
    .click();
  await page.getByLabel("UID người nhận").fill("userA");
  await page.getByLabel("Tiêu đề", { exact: true }).fill("Nhắc bữa ăn");
  await page.getByLabel("Nội dung", { exact: true }).fill("Ghi lại bữa trưa");
  await page.getByRole("button", { name: "Xem trước" }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.getByRole("button", { name: "Xác nhận gửi" }).click();
  await expect(
    page.getByText("FCM đã chấp nhận", { exact: false }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Crashlytics", exact: true }).click();
  await expect(page.getByText("Test issue", { exact: true })).toBeVisible();
});
test("mobile layout has no document overflow and keeps navigation usable", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await api(page);
  await page.goto("/test/harness.html");
  await expect(page.getByRole("heading", { name: "Tổng quan" })).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  await page.getByRole("button", { name: "Người dùng", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Người dùng" })).toBeVisible();
  await page.screenshot({
    path: "test-results/admin-mobile.png",
    fullPage: true,
  });
});
