# README Media Checklist

Tracks which README sections have visual captures and which added/changed features
still need an image or GIF. Delete this file once the README media is complete.

Legend: `[x]` capture exists · `[ ]` capture needed · **(GIF)** = motion capture recommended

All images live in `Screenshots/` and are referenced from `README.md`.

---

## Existing captures (verify still representative of the rewrite)

- [x] Hero image 1 — `Screenshots/s.png` (top of README)
- [x] Hero image 2 — `Screenshots/s1.png` (top of README)
- [x] Basic → green rectangle — `Screenshots/green_rectangle.png`
- [x] Fill Styles → circles grid — `Screenshots/circles.png` *(now includes `scribble` — recapture to show it)*
- [x] SVG → apple path — `Screenshots/svg.png`
- [x] Creative Shapes → chart — `Screenshots/chart.png`

## New / changed features needing captures

These sections were added or rewritten relative to the original and currently have
no image/GIF. Capture and add each under its README heading.

### Fills
- [ ] Fill Angle — three circles at 0° / 45° / 90°
- [ ] Fill Spacing — dense / normal / sparse circles
- [ ] Fill Spacing Pattern (Gradients) — Fibonacci + dense-sparse-dense examples
- [ ] Scribble Fill — basic, curved+brush, and variable-density variants

### Text
- [ ] Text Rendering — system font, custom font, attributed string
- [ ] Text Positioning and Alignment — leading/top, trailing/bottom, offset, combined

### SVG
- [ ] SVG-Specific Customization — svgStrokeWidth / svgFillWeight comparison
- [ ] SVG Fill Stroke Alignment — center / inside / outside side-by-side

### Strokes & brushes
- [ ] Brush Profiles — calligraphic tip, tapered, custom thickness profile
- [ ] Variable stroke width (brushTip directionSensitive) — **(GIF)** or annotated still

### Animation **(GIF)**
- [ ] Basic Animation — `.animated()` loop **(GIF)**
- [ ] Animation Parameters — steps/speed/variance comparison **(GIF)**
- [ ] AnimatedRoughView — direct usage example **(GIF)**
- [ ] Animated SVG Paths — animated apple path **(GIF)**

### New shapes
- [ ] Rounded Rectangle — default, custom radius, pill
- [ ] Egg Shape — positive tilt, symmetric, negative tilt

### Diagnostics (optional)
- [ ] Performance Instrumentation — Instruments os_signpost timeline screenshot
- [ ] Performance Report — `PerformanceStatistics.shared.printReport()` console output

---

## Capture guidance

- Use `ImageRenderer` (per project conventions) or the iOS simulator to export clean stills.
- Prefer consistent frame sizes and a transparent/white background across a section's set.
- Keep GIFs short (2–4 s), looping, and reasonably compressed to limit repo size.
- Name files by feature (e.g. `fill_angle.png`, `animation_basic.gif`) and place them in `Screenshots/`.
- After adding a file, insert `![](Screenshots/<name>)` under the matching README heading and tick its box here.
