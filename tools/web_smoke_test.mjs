// Loads the web export in headless Chromium, checks for console errors,
// optionally taps through, and saves a screenshot (landscape 1280x720 by default).
// Usage: node tools/web_smoke_test.mjs [--viewport 1280x720] [--wait 8000] [--tap x,y ...] [--out docs/screens/name.png]
// Needs: npm i -D playwright (the browser itself is already installed in Claude Code cloud sessions).
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : fallback;
};
const taps = args.flatMap((a, i) => (a === "--tap" ? [args[i + 1]] : []));
const waitMs = Number(opt("--wait", "8000"));
const stamp = new Date().toISOString().replace(/[:.]/g, "-");
const out = opt("--out", `docs/screens/smoke-${stamp}.png`);
const root = path.resolve("build/web");

const types = {
  ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".svg": "image/svg+xml",
  ".json": "application/json", ".webmanifest": "application/manifest+json", ".ico": "image/x-icon",
};

const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split("?")[0]);
  const file = path.join(root, url === "/" ? "index.html" : url);
  if (!file.startsWith(root) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream" });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, r));
const port = server.address().port;

// Use Playwright's own browser if it matches, otherwise fall back to a preinstalled Chromium
// (Claude Code cloud sessions ship one at /opt/pw-browsers/chromium). Override with CHROMIUM_PATH.
const launchArgs = ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"];
const fallbacks = [process.env.CHROMIUM_PATH, "/opt/pw-browsers/chromium"].filter((p) => p && fs.existsSync(p));
let browser;
try {
  browser = await chromium.launch({ args: launchArgs, ...(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {}) });
} catch (err) {
  if (!fallbacks.length) throw err;
  browser = await chromium.launch({ args: launchArgs, executablePath: fallbacks[0] });
}
const [vw, vh] = opt("--viewport", "1280x720").split("x").map(Number);
const page = await browser.newPage({ viewport: { width: vw, height: vh }, deviceScaleFactor: 2, hasTouch: true });
const errors = [];
page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
page.on("pageerror", (e) => errors.push(String(e)));

await page.goto(`http://localhost:${port}/`);
await page.waitForSelector("canvas", { timeout: 30000 });
await page.waitForTimeout(waitMs);
for (const t of taps) {
  const [x, y] = t.split(",").map(Number);
  await page.touchscreen.tap(x, y);
  await page.waitForTimeout(1500);
}
fs.mkdirSync(path.dirname(out), { recursive: true });
await page.screenshot({ path: out });
await browser.close();
server.close();

console.log(`Screenshot: ${out}`);
if (errors.length) {
  console.error(`Console errors (${errors.length}):\n` + errors.join("\n"));
  process.exit(1);
}
console.log("No console errors.");
