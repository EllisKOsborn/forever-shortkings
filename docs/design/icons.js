// Generates the Short Kings glyph textures (docs/DESIGN.md section 14).
// Usage: node docs/design/icons.js
// Writes Media/Icons/<name>.tga: 32x32, white with an alpha channel, so the
// addon tints them at runtime (Texture:SetVertexColor). Our own drawings on
// a 24-unit grid (2.25 stroke, square caps); nothing is traced from anyone
// else's art. Rerun after changing a glyph and commit the .tga files.
// The mockup (docs/mockups/ui-mockup.html) draws the same paths in SVG.
const path = require("path");
const fs = require("fs");
const { chromium } = require("playwright");

// name -> SVG body on a 24x24 grid. `fill: true` draws a filled shape.
const GLYPHS = {
  overview: '<rect x="4" y="4" width="7" height="7"/><rect x="13" y="4" width="7" height="7"/><rect x="4" y="13" width="7" height="7"/><rect x="13" y="13" width="7" height="7"/>',
  roster: '<path d="M9 6h11M9 12h11M9 18h11"/><path d="M4 5h2v2H4zM4 11h2v2H4zM4 17h2v2H4z"/>',
  character: '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1c0-3.3 3.6-6 8-6s8 2.7 8 6v1"/>',
  crafters: '<path d="M13 3l8 8-3 3-8-8z"/><path d="M11.5 9.5L3 18l3 3 8.5-8.5"/>',
  settings: '<path d="M4 6h16M4 12h16M4 18h16"/><path d="M8 4v4M15 10v4M10 16v4"/>',
  raids: '<path d="M12 3l8 3v6c0 4.6-3.4 7.8-8 9-4.6-1.2-8-4.4-8-9V6z"/>',
  professions: '<path d="M9 3h6M10 3v6l-5.5 10.5c-.4.8.2 1.5 1 1.5h13c.8 0 1.4-.7 1-1.5L14 9V3"/><path d="M7 15h10"/>',
  close: { body: '<path d="M4 4l16 16M20 4L4 20"/>', stroke: 3 },
  search: '<circle cx="10" cy="10" r="6.5"/><path d="M15 15l6 6"/>',
  chevron: { body: '<path d="M4 8l8 8 8-8"/>', stroke: 3 },
  chevronUp: { body: '<path d="M4 16l8-8 8 8"/>', stroke: 3 },
  chevronLeft: { body: '<path d="M16 4l-8 8 8 8"/>', stroke: 3 },
  copy: '<rect x="8" y="8" width="12" height="12"/><path d="M4 16V4h12"/>',
  inbox: '<path d="M3 13l3-8h12l3 8v6H3z"/><path d="M3 13h5l1 3h6l1-3h5"/>',
  whisper: '<path d="M4 5h16v11H9l-5 4z"/>',
  refresh: '<path d="M20 12a8 8 0 1 1-2.3-5.7"/><path d="M20 4v5h-5"/>',
  // Status shape for "online without the addon": a hollow square (shown at 8 px).
  statusHollow: { body: '<rect x="2.5" y="2.5" width="19" height="19"/>', stroke: 5, cap: "butt" },
};

const SIZE = 32;

// Uncompressed 32-bit TGA, bottom-left origin, 8 alpha bits.
function tga(width, height, rgba) {
  const head = Buffer.alloc(18);
  head[2] = 2;                 // uncompressed true colour
  head.writeUInt16LE(width, 12);
  head.writeUInt16LE(height, 14);
  head[16] = 32;               // bits per pixel
  head[17] = 0x08;             // 8 alpha bits, bottom-left origin
  const body = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y++) {
    const src = (height - 1 - y) * width * 4; // flip rows
    for (let x = 0; x < width; x++) {
      const i = src + x * 4, o = (y * width + x) * 4;
      body[o] = 255; body[o + 1] = 255; body[o + 2] = 255; // always white: tinted in game
      body[o + 3] = rgba[i + 3];
    }
  }
  return Buffer.concat([head, body]);
}

(async () => {
  const out = path.join(__dirname, "..", "..", "Media", "Icons");
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const [name, def] of Object.entries(GLYPHS)) {
    const g = typeof def === "string" ? { body: def } : def;
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="${g.stroke || 2.25}" stroke-linecap="${g.cap || "square"}" stroke-linejoin="miter">${g.body}</svg>`;
    const pixels = await page.evaluate(async ({ svg, size }) => {
      const img = new Image();
      img.src = "data:image/svg+xml;base64," + btoa(svg);
      await img.decode();
      const c = document.createElement("canvas");
      c.width = size; c.height = size;
      const ctx = c.getContext("2d");
      ctx.drawImage(img, 0, 0, size, size);
      return Array.from(ctx.getImageData(0, 0, size, size).data);
    }, { svg, size: SIZE });
    fs.writeFileSync(path.join(out, name + ".tga"), tga(SIZE, SIZE, pixels));
    console.log("wrote Media/Icons/" + name + ".tga");
  }
  await browser.close();
})();
