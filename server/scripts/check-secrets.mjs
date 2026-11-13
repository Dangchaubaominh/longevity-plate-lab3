import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
const root = execFileSync("git", ["rev-parse", "--show-toplevel"], {
  encoding: "utf8",
}).trim();
const files = execFileSync(
  "git",
  ["ls-files", "--cached", "--others", "--exclude-standard"],
  { cwd: root, encoding: "utf8" },
)
  .split(/\r?\n/)
  .filter(Boolean);
const patterns = [
  /-----BEGIN PRIVATE KEY-----\s+[A-Za-z0-9+/=]{80,}/,
  /AIza[0-9A-Za-z_-]{35}/,
  /AKIA[0-9A-Z]{16}/,
  /(?:CLOUDINARY_API_SECRET|GOOGLE_SERVICE_ACCOUNT_JSON)\s*=\s*["']?[A-Za-z0-9+/]{20,}/,
];
// Firebase client API keys are public identifiers; only the project's known
// client config files may contain them. Server private keys are never allowed.
const publicConfig =
  /^(lib\/firebase_options\.dart(?:\.bak)?|android\/app\/google-services\.json|ios\/Runner\/GoogleService-Info\.plist)$/;
let failed = false;
for (const file of files) {
  if (/\.(png|jpg|jpeg|pdf|ttf|zip|docx)$/.test(file)) continue;
  const content = readFileSync(`${root}/${file}`, "utf8");
  if (
    patterns.some(
      (p, i) => !(i === 1 && publicConfig.test(file)) && p.test(content),
    )
  ) {
    console.error(`Potential credential in ${file} (value hidden)`);
    failed = true;
  }
}
if (failed) process.exit(1);
console.log(
  "No matching private credential patterns in tracked/unignored source. This is a pattern check, not a complete secret audit.",
);
