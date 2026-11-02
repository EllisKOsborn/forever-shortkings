// Renders docs/mockups/ui-mockup.html to WebP images in docs/images/.
// Usage: node docs/mockups/render.js [path/to/marcellus.woff2]
// The font is optional (falls back to Georgia). Marcellus (OFL) is a free
// stand-in for the game's Friz Quadrata.
const path = require("path");
const fs = require("fs");
const os = require("os");
const { chromium } = require("playwright");

const SHOTS = ["banner", "overview", "roster", "attunement", "character", "crafters", "settings"];

(async () => {
  const here = __dirname;
  const out = path.join(here, "..", "images");
  fs.mkdirSync(out, { recursive: true });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "sk-mock-"));
  fs.copyFileSync(path.join(here, "ui-mockup.html"), path.join(tmp, "ui-mockup.html"));
  if (process.argv[2]) fs.copyFileSync(process.argv[2], path.join(tmp, "marcellus.woff2"));

  const browser = await chromium.launch();

  // 1. Screenshot each scene as PNG (2x for sharp text).
  const page = await browser.newPage({ viewport: { width: 1200, height: 900 }, deviceScaleFactor: 2 });
  await page.goto("file://" + path.join(tmp, "ui-mockup.html"));
  await page.evaluate(() => document.fonts.ready);
  for (const id of SHOTS) {
    await (await page.$("#" + id)).screenshot({ path: path.join(tmp, id + ".png") });
  }

  // 2. Re-encode as WebP (about 5x smaller, colours stay exact enough).
  // (PNG passed as a data: URL; file:// images would taint the canvas.)
  const conv = await browser.newPage();
  for (const id of SHOTS) {
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
