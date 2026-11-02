// Renders a mockup page to WebP images, one per `.scene[id]`.
// Usage: node docs/mockups/render.js [marcellus.woff2] [--page ui-mockup.html] [--out images]
//   --page  a file in docs/mockups/ (default ui-mockup.html, the current UI)
//   --out   a folder under docs/ (default images, the README pictures)
// Design proposal: node docs/mockups/render.js font.woff2 --page design-v2.html --out images/v2
// The font is optional (falls back to Georgia). Marcellus (OFL) is a free
// stand-in for the game's Friz Quadrata; don't commit it.
const path = require("path");
const fs = require("fs");
const os = require("os");
const { chromium } = require("playwright");

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf(name); return i >= 0 ? args.splice(i, 2)[1] : def; };
const pageFile = opt("--page", "ui-mockup.html");
const outDir = opt("--out", "images");
const font = args[0];

(async () => {
  const here = __dirname;
  const out = path.join(here, "..", outDir);
  fs.mkdirSync(out, { recursive: true });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "sk-mock-"));
  fs.copyFileSync(path.join(here, pageFile), path.join(tmp, "page.html"));
  if (font) fs.copyFileSync(font, path.join(tmp, "marcellus.woff2"));

  const browser = await chromium.launch();

  // 1. Screenshot each scene as PNG (2x for sharp text).
  const page = await browser.newPage({ viewport: { width: 1200, height: 900 }, deviceScaleFactor: 2 });
  await page.goto("file://" + path.join(tmp, "page.html"));
  await page.evaluate(() => document.fonts.ready);
  const shots = await page.$$eval(".scene[id]", (els) => els.map((e) => e.id));
  for (const id of shots) {
    await (await page.$("#" + id)).screenshot({ path: path.join(tmp, id + ".png") });
  }

  // 2. Re-encode as WebP (about 5x smaller, colours stay exact enough).
  // (PNG passed as a data: URL; file:// images would taint the canvas.)
  const conv = await browser.newPage();
  for (const id of shots) {
    const data = await conv.evaluate(async (src) => {
      const img = new Image();
      img.src = src;
      await img.decode();
      const c = document.createElement("canvas");
      c.width = img.width;
      c.height = img.height;
      c.getContext("2d").drawImage(img, 0, 0);
      return c.toDataURL("image/webp", 0.9).split(",")[1];
    }, "data:image/png;base64," + fs.readFileSync(path.join(tmp, id + ".png")).toString("base64"));
    fs.writeFileSync(path.join(out, id + ".webp"), Buffer.from(data, "base64"));
    console.log("wrote", path.join(out, id + ".webp"));
  }
  await browser.close();
})();
