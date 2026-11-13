import { defineConfig } from "vitest/config";
import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.toml" },
      miniflare: {
        bindings: {
          TEST_MIGRATIONS: await readD1Migrations("./migrations"),
          RATE_LIMIT: "1000",
        },
      },
    }),
  ],
  test: {
    include: ["test/**/*.spec.ts"],
    setupFiles: ["./test/setup.ts"],
    testTimeout: 20000,
  },
});
