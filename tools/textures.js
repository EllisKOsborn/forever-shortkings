// Draws the addon's few textures from simple shapes and writes them as
// 32-bit .tga files (for the game) and .png files (for preview/).
// Usage: node tools/textures.js
// Every size is a power of two, as WoW requires.
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const ROOT = path.join(__dirname, "..");
const TGA_DIR = path.join(ROOT, "Media", "Textures");
const PNG_DIR = path.join(ROOT, "preview", "img");

// Colours come from UI/Theme.lua (gold, beard); keep them in step.
const GOLD = [255, 192, 0];
const BEARD = [240, 107, 176];
const WHITE = [255, 255, 255];

// ---- shape tests (coordinates in a 0..size box, y down) -------------------
function inPolygon(x, y, pts) {
  let inside = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
function distToSegment(x, y, [ax, ay], [bx, by]) {
  const dx = bx - ax, dy = by - ay;
  const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)));
  return Math.hypot(x - (ax + t * dx), y - (ay + t * dy));
}
const poly = (pts, color) => ({ color, hit: (x, y) => inPolygon(x, y, pts) });
const circle = (cx, cy, r, color) => ({ color, hit: (x, y) => Math.hypot(x - cx, y - cy) <= r });
const ellipse = (cx, cy, rx, ry, color) => ({ color, hit: (x, y) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 });
const ring = (cx, cy, r, w, color) => ({ color, hit: (x, y) => Math.abs(Math.hypot(x - cx, y - cy) - r) <= w / 2 });
const line = (a, b, w, color) => ({ color, hit: (x, y) => distToSegment(x, y, a, b) <= w / 2 });
const cut = (shape) => ({ cut: true, hit: shape.hit });

// Rasterise with 8x8 supersampling. Later shapes paint over earlier ones;
// a `cut` shape clears what is under it.
function render(size, shapes) {
  const px = Buffer.alloc(size * size * 4);
  const S = 8;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < S; sy++) {
        for (let sx = 0; sx < S; sx++) {
          const fx = x + (sx + 0.5) / S, fy = y + (sy + 0.5) / S;
          let c = null;
          for (const s of shapes) if (s.hit(fx, fy)) c = s.cut ? null : s.color;
          if (c) { r += c[0]; g += c[1]; b += c[2]; a += 1; }
        }
      }
      const i = (y * size + x) * 4;
      if (a) { px[i] = r / a; px[i + 1] = g / a; px[i + 2] = b / a; }
      px[i + 3] = Math.round((a / (S * S)) * 255);
    }
  }
  return px;
}

function writeTGA(file, size, rgba) {
  const head = Buffer.alloc(18);
  head[2] = 2;                       // uncompressed true-colour
  head.writeUInt16LE(size, 12);
  head.writeUInt16LE(size, 14);
  head[16] = 32;                     // bits per pixel
  head[17] = 0x28;                   // 8 alpha bits, top-left origin
  const body = Buffer.alloc(size * size * 4);
  for (let i = 0; i < size * size; i++) {
    body[i * 4] = rgba[i * 4 + 2];   // BGRA
    body[i * 4 + 1] = rgba[i * 4 + 1];
    body[i * 4 + 2] = rgba[i * 4];
    body[i * 4 + 3] = rgba[i * 4 + 3];
  }
  fs.writeFileSync(file, Buffer.concat([head, body]));
}

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function writePNG(file, size, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; ihdr[9] = 6;          // 8-bit RGBA
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) rgba.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0)),
  ]));
}

// ---- the textures -----------------------------------------------------------
// Crest: a short king. A three-point gold crown over a pink beard, drawn on a
// 64 box (no face, no fake mascot art).
const crest = [
  poly([[12, 30], [12, 12], [22, 21], [32, 8], [42, 21], [52, 12], [52, 30]], GOLD),
  circle(12, 11, 3, GOLD), circle(32, 7, 3, GOLD), circle(52, 11, 3, GOLD),
  // forked beard, then a moustache across its top
  poly([[11, 39], [53, 39], [51, 50], [40, 62], [32, 55], [24, 62], [13, 50]], BEARD),
  ellipse(21, 37, 12, 4.2, BEARD), ellipse(43, 37, 12, 4.2, BEARD),
  cut(ellipse(32, 41.5, 3.2, 2.2, WHITE)),                          // mouth
];

const TEXTURES = {
  crest: [64, crest],
  // White glyphs, tinted in game with SetVertexColor.
  arrow: [16, [poly([[8, 4], [14, 12], [2, 12]], WHITE)]],
  close: [16, [line([4, 4], [12, 12], 2, WHITE), line([12, 4], [4, 12], 2, WHITE)]],
  dot: [16, [circle(8, 8, 6, WHITE)]],
  ring: [32, [ring(16, 16, 13, 2.5, WHITE)]],
};

fs.mkdirSync(TGA_DIR, { recursive: true });
fs.mkdirSync(PNG_DIR, { recursive: true });
for (const [name, [size, shapes]] of Object.entries(TEXTURES)) {
  const px = render(size, shapes);
  writeTGA(path.join(TGA_DIR, name + ".tga"), size, px);
  writePNG(path.join(PNG_DIR, name + ".png"), size, px);
  console.log("wrote", name, size + "x" + size);
}
