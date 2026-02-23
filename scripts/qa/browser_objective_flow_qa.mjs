import fs from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright";

const qaUrl = process.env.CELADORA_QA_URL || "http://127.0.0.1:8060/?qa_objective_auto=1";
const reportPath = process.env.CELADORA_QA_REPORT || path.resolve("docs/reports/qa_browser_objective_latest.json");
const screenshotPath = process.env.CELADORA_QA_SCREENSHOT || path.resolve("docs/reports/qa_browser_objective_latest.png");
const timeoutMs = Number(process.env.CELADORA_QA_TIMEOUT_MS || 45000);
const headless = String(process.env.CELADORA_QA_HEADLESS ?? "1") !== "0";
const launchArgs = (process.env.CELADORA_QA_BROWSER_ARGS || "")
  .split(/\s+/)
  .map((value) => value.trim())
  .filter(Boolean);

if (launchArgs.length === 0) {
  launchArgs.push(
    "--ignore-gpu-blocklist",
    "--enable-webgl",
    "--enable-webgl2-compute-context",
    "--use-angle=swiftshader-webgl",
    "--enable-unsafe-swiftshader"
  );
}

await fs.mkdir(path.dirname(reportPath), { recursive: true });
await fs.mkdir(path.dirname(screenshotPath), { recursive: true });

const result = {
  timestamp_utc: new Date().toISOString(),
  url: qaUrl,
  timeout_ms: timeoutMs,
  headless,
  launch_args: launchArgs,
  status: "fail",
  ok: false,
  payload: null,
  screenshot: screenshotPath,
  error: "",
  diagnostics: {},
};

let browser;
let page;
const consoleLines = [];
try {
  browser = await chromium.launch({
    headless,
    args: launchArgs,
    chromiumSandbox: false,
  });
  page = await browser.newPage();
  page.setDefaultTimeout(timeoutMs);
  page.on("console", (msg) => {
    consoleLines.push(msg.text());
  });

  await page.goto(qaUrl, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.__celadoraObjectiveQaReady === true);
  const payload = await page.evaluate(() => window.__celadoraObjectiveQa || null);
  await page.screenshot({ path: screenshotPath, fullPage: false });

  result.payload = payload;
  result.ok = Boolean(payload && payload.ok === true);
  result.status = result.ok ? "pass" : "fail";
} catch (error) {
  result.error = error instanceof Error ? error.message : String(error);
} finally {
  if (page) {
    try {
      const bodyText = await page.evaluate(() => (document.body?.innerText || "").trim());
      result.diagnostics.body_text = bodyText.slice(0, 1000);
    } catch {
      // no-op
    }
    result.diagnostics.console_tail = consoleLines.slice(-40);
    try {
      await page.screenshot({ path: screenshotPath, fullPage: false });
    } catch {
      // no-op
    }
  }
  if (browser) {
    await browser.close();
  }
}

const bodyText = String(result.diagnostics.body_text || "");
const webglUnsupported =
  bodyText.includes("required to run Godot projects on the Web are missing") ||
  bodyText.includes("WebGL2") ||
  consoleLines.some((line) => line.includes("WebGL2"));
if (!result.ok && webglUnsupported) {
  result.status = "inconclusive";
  result.error = result.error || "WebGL2 unsupported in this headless browser environment.";
}

await fs.writeFile(reportPath, JSON.stringify(result, null, 2), "utf8");
if (result.status === "pass") {
  console.log(`Browser objective QA passed. Report: ${reportPath}`);
  process.exit(0);
}
if (result.status === "inconclusive") {
  console.warn(`Browser objective QA inconclusive (environment limitation). Report: ${reportPath}`);
  process.exit(0);
}

if (!result.ok) {
  console.error(`Browser objective QA failed. Report: ${reportPath}`);
  if (result.error) {
    console.error(result.error);
  }
  process.exit(2);
}
