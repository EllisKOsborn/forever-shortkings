// Contrast check for the Short Kings design tokens (docs/DESIGN.md).
// Usage: node docs/design/contrast.js            (prints the table, exit 1 if a floor fails)
//        node docs/design/contrast.js --markdown (the table as Markdown, for DESIGN.md)
// Surfaces include the derived ones a row can sit on (hover and selected
// washes on the lightest ground, the hot end of the header band).
const fs = require("fs");
const path = require("path");
const T = JSON.parse(fs.readFileSync(path.join(__dirname, "tokens.json"), "utf8"));
const C = T.color;

const rgb = (hex) => [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t); // t = alpha of b over a
const lin = (v) => (v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
const lum = (c) => 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]);
const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
const WHITE = [1, 1, 1];

// Rows and list states live on panel; controls (panelAlt) only take hover
// and pressed with text or textDim labels; the band carries text and textDim only.
const ALL = null;
const surfaces = {
  sidebar: [rgb(C.sidebar), ALL],
  bg: [rgb(C.bg), ALL],
  panel: [rgb(C.panel), ALL],
  "panel+hover": [mix(rgb(C.panel), WHITE, T.wash.hover), ALL],
  "panel+selected": [mix(rgb(C.panel), WHITE, T.wash.selected), ALL],
  panelAlt: [rgb(C.panelAlt), ALL],
  "panelAlt+pressed": [mix(rgb(C.panelAlt), WHITE, T.wash.pressed), ["text", "textDim"]],
  sky: [rgb(C.sky), ALL],
  "band (hot end)": [mix(rgb(C.sky), rgb(C.brand), T.band.brandWash), ["text", "textDim"]],
};
const inks = { text: "primary", textDim: "other", textMuted: "other", accent: "other",
  success: "other", warning: "other", danger: "other" };

let failed = 0;
const rows = [];
for (const [ink, level] of Object.entries(inks)) {
  const floor = T.floors[level];
  const cells = Object.values(surfaces).map(([s, allowed]) => {
    if (allowed && !allowed.includes(ink)) return "–";
    const r = ratio(rgb(C[ink]), s);
    if (r < floor) failed++;
    return (r < floor ? "FAIL " : "") + r.toFixed(1);
  });
  rows.push([ink + ` (≥${floor})`, ...cells]);
}
const extra = [
  ["onAccent on accent (≥7)", ratio(rgb(C.onAccent), rgb(C.accent))],
  ["accent (focus/selection bar) on panelAlt (≥3, non-text)", ratio(rgb(C.accent), rgb(C.panelAlt))],
  ["hairline on panel (non-text, info)", ratio(mix(rgb(C.panel), WHITE, T.wash.hairline), rgb(C.panel))],
];
if (extra[0][1] < 7) failed++;
if (extra[1][1] < 3) failed++;

const md = process.argv.includes("--markdown");
const head = ["ink", ...Object.keys(surfaces)];
if (md) {
  console.log("| " + head.join(" | ") + " |");
  console.log("|" + head.map(() => "---").join("|") + "|");
  rows.forEach((r) => console.log("| " + r.join(" | ") + " |"));
  console.log("");
  extra.forEach(([k, v]) => console.log(`- ${k}: ${v.toFixed(1)}`));
} else {
  console.log(head.join("\t"));
  rows.forEach((r) => console.log(r.join("\t")));
  extra.forEach(([k, v]) => console.log(`${k}: ${v.toFixed(1)}`));
}

// Subject colours (class and item quality) on the window and panel grounds:
// informational, the game's own colours are kept.
const subj = Object.entries(T.subject).filter(([k]) => k[0] !== "_");
const subjLine = subj.map(([k, v]) => `${k} ${ratio(rgb(v), rgb(C.panel)).toFixed(1)}`).join(", ");
console.log((md ? "\nSubject colours on panel (info only): " : "subject on panel (info): ") + subjLine);

// The design mockup must use the same colours as tokens.json.
const html = fs.readFileSync(path.join(__dirname, "..", "mockups", "ui-mockup.html"), "utf8");
for (const [k, v] of Object.entries(C)) {
  const m = html.match(new RegExp("--" + k + ":#([0-9A-Fa-f]{6})"));
  if (!m || m[1].toUpperCase() !== v.toUpperCase()) { console.error(`mockup --${k} does not match tokens.json (${v})`); failed++; }
}

if (failed) { console.error(`${failed} contrast floor(s) failed`); process.exit(1); }
