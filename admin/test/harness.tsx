// Test-only entrypoint, never included by the production index.html build.
import { createRoot } from "react-dom/client";
import { App } from "../src/App";
import type { AuthGateway } from "../src/auth";
import "../src/style.css";
if (!import.meta.env.DEV)
  throw new Error("Test harness cannot run in production");
const auth: AuthGateway = {
  subscribe(listener) {
    listener(
      new URLSearchParams(location.search).has("signedOut")
        ? null
        : { uid: "browser-test-admin", displayName: "Admin kiểm thử" },
    );
    return () => {};
  },
  async token() {
    return "browser-fixture-token";
  },
  async signIn() {
    location.search = "";
  },
  async signOut() {
    location.search = "?signedOut=1";
  },
};
createRoot(document.getElementById("root")!).render(<App auth={auth} />);
