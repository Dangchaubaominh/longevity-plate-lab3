import { env } from "cloudflare:workers";
import { applyD1Migrations } from "cloudflare:test";
import { beforeAll, beforeEach } from "vitest";
import type { Bindings } from "../src/types";
const bindings = env as unknown as Bindings & {
  TEST_MIGRATIONS: Parameters<typeof applyD1Migrations>[1];
};
beforeAll(async () => {
  await applyD1Migrations(bindings.DB, bindings.TEST_MIGRATIONS);
});
beforeEach(async () => {
  const names = [
    "maintenance_jobs",
    "assets",
    "deliveries",
    "campaigns",
    "device_tokens",
    "changes",
    "sync_operations",
    "records",
    "admin_users",
    "users",
    "admin_audit_logs",
    "crash_snapshots",
    "rate_limits",
  ];
  for (const name of names)
    await bindings.DB.prepare(`DELETE FROM ${name}`).run();
});
