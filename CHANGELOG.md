# Changelog

## Unreleased

- Rounded-rectangle outlines draw each corner across the full quarter circle, so the arcs meet the straight sides. Corners keep a double stroke and the same seeded roughness as the other edges.
- Ellipse hachure lines are chords of the ellipse at `fillAngle`, spaced by the hachure gap measured perpendicular to the lines. A wide ellipse no longer fills a rotated copy that spills past the top and bottom and leaves the side ends empty. Cross-hatch, zigzag, dashed, dots, and zigzag-line ellipse fills use the same chords.

## 1.2.0

- The Swift package, library product, and module are named Sketchy. Import `Sketchy`. Public type names (`RoughView`, `RoughText`, `AnimatedRoughView`, and the rest) are unchanged. The previous module name was RoughSwiftUI.
- Drawings can be seeded with `Options.seed` so the same roughness comes back on the next render. `fillAngle` is measured from horizontal, so `0` draws flat lines and `90` draws vertical lines.
- The example catalog, README, and performance notes were rewritten. Seeded stills and GIFs live in `docs/Examples.md`. Cache and Instruments notes live in `docs/Performance.md`.
- Text alignment and offsets stay where you place them. `FullText` is drawn as text, so it is not scaled to fit the way an SVG path is.
- CI picks an available iPhone simulator. It prefers iPhone 17 Pro (not Pro Max), then iPhone 16 Pro, then any other iPhone, on the newest installed runtime.
- `AGENTS.md` and `llms.txt` describe how to work in the repo and how to call the library.
