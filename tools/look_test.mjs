// Runs the M1 look test in headless Chromium: loads build/web with ?scene=look_test, saves a
// screenshot each time the game prints "HC_SHOT <name>", acknowledges it through window.hcAck, and
// records the "HC_PERF {...}" line. Fails on console errors.
// Usage: node tools/look_test.mjs [--out docs/screens/m1] [--viewport 1280x720] [--dpr 1.5]
//        [--query "qualities=medium&times=midday"] [--throttle 4] [--perf-name perf_desktop]
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : fallback;
};
const outDir = opt("--out", "docs/screens/m1");
const [vw, vh] = opt("--viewport", "1280x720").split("x").map(Number);
const dpr = Number(opt("--dpr", "1.5"));
const query = opt("--query", "");
const throttle = Number(opt("--throttle", "1"));
const perfName = opt("--perf-name", "perf");
const timeoutMs = Number(opt("--timeout", String(60 * 60 * 1000)));
const root = path.resolve("build/web");
fs.mkdirSync(outDir, { recursive: true });

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

const launchArgs = ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"];
const fallbacks = [process.env.CHROMIUM_PATH, "/opt/pw-browsers/chromium"].filter((p) => p && fs.existsSync(p));
let browser;
try {
  browser = await chromium.launch({ args: launchArgs });
} catch (err) {
  if (!fallbacks.length) throw err;
  browser = await chromium.launch({ args: launchArgs, executablePath: fallbacks[0] });
}
const context = await browser.newContext({ viewport: { width: vw, height: vh }, deviceScaleFactor: dpr, hasTouch: true });
const page = await context.newPage();
if (throttle > 1) {
  const cdp = await context.newCDPSession(page);
  await cdp.send("Emulation.setCPUThrottlingRate", { rate: throttle });
}

const errors = [];
const shots = [];
let perf = null;
let done;
const finished = new Promise((r) => (done = r));
let queue = Promise.resolve();
const started = Date.now();

page.on("pageerror", (e) => errors.push(String(e)));
page.on("console", (m) => {
  const text = m.text();
  if (m.type() === "error") errors.push(text);
  if (text.startsWith("HC_SHOT ")) {
    const name = text.slice(8).trim();
    queue = queue.then(async () => {
      const file = path.join(outDir, `${name}.png`);
      await page.screenshot({ path: file, timeout: 15 * 60 * 1000 });
      shots.push(file);
      console.log(`[${((Date.now() - started) / 1000).toFixed(0)}s] ${file}`);
      await page.evaluate((n) => { window.hcAck = n; }, name);
    });
  } else if (text.startsWith("HC_PERF ")) {
    perf = JSON.parse(text.slice(8));
    perf.throttle = throttle;
    perf.css_viewport = [vw, vh];
    perf.device_pixel_ratio = dpr;
    perf.renderer = "Chromium headless, SwiftShader (CPU WebGL 2)";
    fs.writeFileSync(path.join(outDir, `${perfName}.json`), JSON.stringify(perf, null, 2) + "\n");
    console.log("Perf:", JSON.stringify(perf));
  } else if (text.startsWith("HC_DONE")) {
    queue.then(() => done());
  } else if (text.startsWith("HC_")) {
    console.log(text);
  }
});

await page.goto(`http://localhost:${port}/?scene=look_test${query ? "&" + query : ""}`);
const timer = setTimeout(() => { errors.push(`Timed out after ${timeoutMs / 1000}s`); done(); }, timeoutMs);
await finished;
clearTimeout(timer);
await browser.close();
server.close();

console.log(`${shots.length} screenshots in ${outDir}`);
if (errors.length) {
  console.error(`Console errors (${errors.length}):\n` + errors.join("\n"));
  process.exit(1);
}
console.log("No console errors.");
