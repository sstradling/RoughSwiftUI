// Sketchy README header generator.
// Run: node render.mjs
// Writes header.svg beside this script and docs/images/header.png (2x).
import fs from 'node:fs';
import { createRequire } from 'node:module';
import opentype from 'opentype.js';
import { Resvg } from '@resvg/resvg-js';
const require = createRequire(import.meta.url);
const rough = require('roughjs');
// rough.js's dot filler (and a couple of other spots) call Math.random()
// directly, ignoring `seed`; swap in a seeded PRNG so output is reproducible.
{ let a = 0x5ce7c4; Math.random = () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

const W = 800, H = 200;            // SVG units; PNG is rendered at 2x
const CARD = { x: 10, y: 8, w: 780, h: 180, r: 14 };
const FONT_SIZE = 112;
const CAP = FONT_SIZE * 0.72;      // Bungee cap height is 720/1000 em
const LINE_GAP = CAP / 4;          // caps span exactly 4 ruled lines
const BASELINE = 140;              // letters sit on this ruled line
const FIRST_LINE = BASELINE - LINE_GAP * Math.floor((BASELINE - CARD.y - 14) / LINE_GAP);
const MARGIN_X = 72;               // red margin line x
const TRACKING = 9;

const font = opentype.parse(fs.readFileSync(new URL('./Bungee-Regular.ttf', import.meta.url)).buffer);
const gen = rough.generator();

// Per-letter styles. Note rough.js hachureAngle 90 == horizontal lines
// (Sketchy's fillAngle 0 == horizontal).
const styles = {
  S: { stroke: '#132358', fill: '#1f3a93', fillStyle: 'hachure',      hachureAngle: -41, hachureGap: 5,   fillWeight: 1.6, roughness: 1.4, strokeWidth: 2.4, bowing: 1 },
  k: { stroke: '#73221a', fill: '#c0392b', fillStyle: 'cross-hatch',  hachureAngle: -30, hachureGap: 8.5,   fillWeight: 1.2, roughness: 2.2, strokeWidth: 3,   bowing: 4 },
  e: { stroke: '#12492a', fill: '#1e7a46', fillStyle: 'zigzag',       hachureAngle: 45,  hachureGap: 7,   fillWeight: 1.3, roughness: 1.2, strokeWidth: 2,   bowing: 1 },
  t: { stroke: '#411f4f', fill: '#6c3483', fillStyle: 'dots',         hachureGap: 6.5,   fillWeight: 2.2, roughness: 1.0, strokeWidth: 2.2, bowing: 0.5, strokeLineDash: [7, 4] },
  c: { stroke: '#7f3200', fill: '#d35400', fillStyle: 'dashed',       hachureAngle: 30,  hachureGap: 6,   fillWeight: 1.6, dashOffset: 8, dashGap: 5, roughness: 0.6, strokeWidth: 2.6, bowing: 0.5 },
  h: { stroke: '#0a4953', fill: '#117a8b', fillStyle: 'zigzag-line',  hachureAngle: 0,   hachureGap: 8,   zigzagOffset: 4, fillWeight: 1.2, roughness: 1.6, strokeWidth: 1.6, bowing: 2, disableMultiStroke: false },
  y: { stroke: '#7b1e3a', fill: '#e8a0b4', fillStyle: 'solid', roughness: 1.7, strokeWidth: 2.8, bowing: 3 },
  '!': { stroke: '#6e5907', fill: '#b7950b', fillStyle: 'hachure',    hachureAngle: 90,  hachureGap: 4.5, fillWeight: 1.8, roughness: 1.8, strokeWidth: 2.2, bowing: 2, strokeLineDash: [3, 3] },
};

const text = 'Sketchy!';
// measure total width to center within the card (right of the margin)
const glyphs = [...text].map(ch => ({ ch, g: font.charToGlyph(ch) }));
const scale = FONT_SIZE / font.unitsPerEm;
const total = glyphs.reduce((a, { g }) => a + g.advanceWidth * scale + TRACKING, -TRACKING);
const areaL = MARGIN_X + 10, areaR = CARD.x + CARD.w - 14;
let x = areaL + (areaR - areaL - total) / 2;

let letters = '';
let seed = 7;
for (const { ch, g } of glyphs) {
  const d = g.getPath(x, BASELINE, FONT_SIZE).toPathData(2);
  x += g.advanceWidth * scale + TRACKING;
  if (!d) continue;
  const st = { ...styles[ch], seed: seed++ * 101, preserveVertices: false };
  let paths;
  if (st.fillStyle === 'solid') {
    // rough.js jitters the solid fill shape as much as the outline, which
    // spills outside the glyph; draw the fill with low roughness instead.
    const fillOnly = gen.toPaths(gen.path(d, { ...st, stroke: 'none', roughness: 0.4, fillShapeRoughnessGain: 0 }))
      .filter(p => p.fill !== 'none');
    const outline = gen.toPaths(gen.path(d, { ...st, fill: undefined, fillStyle: undefined }));
    paths = [...fillOnly, ...outline];
  } else {
    paths = gen.toPaths(gen.path(d, st));
  }
  let out = '';
  for (const p of paths) {
    const isOutline = p.fill === 'none' && p.stroke === st.stroke && Math.abs(p.strokeWidth - st.strokeWidth) < 1e-6;
    const dash = isOutline && st.strokeLineDash ? ` stroke-dasharray="${st.strokeLineDash.join(' ')}"` : '';
    const rule = p.fill && p.fill !== 'none' ? ' fill-rule="evenodd"' : '';
    out += `<path d="${p.d}" stroke="${p.stroke}" stroke-width="${+p.strokeWidth.toFixed(2)}" fill="${p.fill}"${rule}${dash} stroke-linecap="round" stroke-linejoin="round"/>`;
  }
  // round coordinates to shrink file
  out = out.replace(/-?\d+\.\d{2,}/g, n => (+(+n).toFixed(1)).toString());
  letters += `<g id="letter-${ch === '!' ? 'bang' : ch}">${out}</g>\n`;
}

// lined paper
let rules = '';
for (let y = FIRST_LINE; y < CARD.y + CARD.h - 6; y += LINE_GAP)
  rules += `<line x1="${CARD.x}" y1="${y.toFixed(1)}" x2="${CARD.x + CARD.w}" y2="${y.toFixed(1)}" stroke="#9cc3e6" stroke-width="1"/>`;

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="Sketchy!">
<defs>
<filter id="shadow" x="-5%" y="-10%" width="110%" height="130%"><feDropShadow dx="0" dy="2.5" stdDeviation="3" flood-color="#000" flood-opacity="0.18"/></filter>
<clipPath id="card"><rect x="${CARD.x}" y="${CARD.y}" width="${CARD.w}" height="${CARD.h}" rx="${CARD.r}"/></clipPath>
</defs>
<rect x="${CARD.x}" y="${CARD.y}" width="${CARD.w}" height="${CARD.h}" rx="${CARD.r}" fill="#fdf9ee" filter="url(#shadow)"/>
<g clip-path="url(#card)">
${rules}
<line x1="${MARGIN_X}" y1="${CARD.y}" x2="${MARGIN_X}" y2="${CARD.y + CARD.h}" stroke="#e57373" stroke-width="1.4"/>
<line x1="${MARGIN_X + 4}" y1="${CARD.y}" x2="${MARGIN_X + 4}" y2="${CARD.y + CARD.h}" stroke="#e57373" stroke-width="0.7" opacity="0.7"/>
${[0.3, 0.7].map(f => `<circle cx="${CARD.x + 30}" cy="${CARD.y + CARD.h * f}" r="7" fill="#efe8d6" stroke="#ddd3bb" stroke-width="1"/>`).join('')}
</g>
${letters}</svg>
`;
fs.writeFileSync(new URL('./header.svg', import.meta.url), svg);
const png = new Resvg(svg, { fitTo: { mode: 'width', value: W * 2 }, background: 'rgba(0,0,0,0)' }).render().asPng();
const pngPath = new URL('../../docs/images/header.png', import.meta.url);
fs.mkdirSync(new URL('./', pngPath), { recursive: true });
fs.writeFileSync(pngPath, png);
console.log('svg', svg.length, 'bytes; png', png.length, 'bytes ->', pngPath.pathname);
