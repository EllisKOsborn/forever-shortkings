// Renders the README pictures (docs/images/*.png) from the browser preview,
// preview/index.html, which draws the windows from UI/Theme.lua's values.
// Usage: node docs/mockups/render.js
// Uses Playwright when installed (cloud sessions), otherwise Google Chrome's
// headless mode. Pictures are 2x PNG. Run
// `node tools/preview-tokens.js` first if Theme.lua changed.
const path = require("path");
const fs = require("fs");
const { execFileSync } = require("child_process");

const ROOT = path.join(__dirname, "..", "..");
const OUT = path.join(ROOT, "docs", "images");
const PAGE = "file://" + path.join(ROOT, "preview", "index.html");
const W = 880, H = 580;

// name -> [query, width, height]
const SHOTS = {
  banner: ["shot=banner", 1200, 300],
  overview: ["shot=1&screen=overview&data=full", W, H],
  roster: ["shot=1&screen=roster&data=full", W, H],
  attunement: ["shot=1&screen=roster&data=full&raid=ony", W, H],
  character: ["shot=1&screen=character&data=full", W, H],
  crafters: ["shot=1&screen=crafters&data=full", W, H],
  settings: ["shot=1&screen=settings&data=full", W, H],
};

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

async function withPlaywright(chromium) {
  const browser = await chromium.launch();
  for (const [name, [q, w, h]] of Object.entries(SHOTS)) {
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 2 });
    await page.goto(PAGE + "?" + q);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(OUT, name + ".png") });
    console.log("wrote", name + ".png");
  }
  await browser.close();
}

function withChrome() {
  for (const [name, [q, w, h]] of Object.entries(SHOTS)) {
    const png = path.join(OUT, name + ".png");
    execFileSync(CHROME, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
      `--window-size=${w},${h}`, "--virtual-time-budget=1500", `--screenshot=${png}`, PAGE + "?" + q], { stdio: "ignore" });
    console.log("wrote", name + ".png");
  }
}

fs.mkdirSync(OUT, { recursive: true });
let chromium = null;
try { ({ chromium } = require("playwright")); } catch (e) { /* not installed */ }
if (chromium) withPlaywright(chromium);
else if (fs.existsSync(CHROME)) withChrome();
else { console.error("Needs Playwright or Google Chrome."); process.exit(1); }
