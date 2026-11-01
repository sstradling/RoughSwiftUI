# Agents working on Sketchy

This file is for coding agents changing this repository. Agents generating app code that only consumes the library should read [llms.txt](llms.txt) instead.

The package is iOS 17+ (`Package.swift`). Tests run on an iPhone simulator. Do not create a git tag unless a release task says so. The install line in the README is `from: "1.2.0"`. The module is `Sketchy`. Public types such as `RoughView` keep their names.

## Layout

| Path | Role |
| --- | --- |
| `Sources/Sketchy/RoughView.swift` | Public builder: options, shapes, text, brushes, `.animated` |
| `Sources/Sketchy/RoughText.swift` | Self-sizing text view over the same engine |
| `Sources/Sketchy/AnimatedRoughView.swift` | Looping wobble. `pinnedFrame(_:)` is internal and is how docs capture one frame |
| `Sources/Sketchy/Engine/Options.swift` | Defaults for roughness, fill, seed, scribble, SVG, brush |
| `Sources/Sketchy/Engine/FillStyle.swift` | Fill style cases |
| `Sources/Sketchy/Engine/Drawable.swift` | Shape values passed to `.draw`, plus text alignment enums |
| `Sources/Sketchy/Engine/NativeGenerator.swift` | Builds a `Drawing`. SVG paths stay `shape == "path"` and are fitted. `FullText` is emitted as `shape == "text"` and is not fitted |
| `Sources/Sketchy/Engine/BrushProfile.swift` | Tips, thickness, caps, joins, crayon preset |
| `Sources/Sketchy/Engine/CrayonStyle.swift` | Wax parameters and `defaultSeed` |
| `Sources/Sketchy/Engine/AnimationOptions.swift` | `AnimationConfig`, speed, variance |
| `Sources/Sketchy/Engine/Engine.swift` | Shared generator and drawing caches |
| `Sources/Sketchy/Engine/Fillers/` | One filler per fill style. `sunBurst` and `starBurst` share `StarburstFiller` |
| `Sources/Sketchy/Render/SwiftUIRenderer.swift` | Turns a `Drawing` into `Canvas` commands. Crayon on a view also textures hachure, zigzag, and scribble lines |
| `Sources/Sketchy/Render/CrayonStroke.swift` | Wax passes for a stroke |
| `Tests/SketchyTests/` | Unit tests. Docs catalog is under `Docs/` |
| `Tests/SketchyTests/Docs/DocExampleCatalog.swift` | Paper colour, tile size, and the example list |
| `scripts/render-docs.sh` | Renders the catalog into `docs/images` and `docs/Examples.md` |
| `.github/workflows/tests.yml` | CI test job |

`Example/` is a sample app. `DOCUMENTATION.md` is the long API reference. `docs/Examples.md` is generated. `docs/Performance.md` is the cache and signpost notes.

## Tests

CI does not hard-code a simulator UUID. It prefers an available iPhone 17 Pro (not Pro Max), then iPhone 16 Pro, then any other iPhone, and within that name the newest iOS runtime. The job then runs:

```bash
xcodebuild test \
  -scheme Sketchy \
  -destination "platform=iOS Simulator,id=${DEVICE}" \
  -only-testing:SketchyTests \
  -parallel-testing-enabled NO
```

`DEVICE` is the `udid` chosen by the Python block in `.github/workflows/tests.yml`. Locally, pick a booted or available iPhone the same way and pass its id. From the package root:

```bash
xcodebuild test \
  -scheme Sketchy \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -only-testing:SketchyTests \
  -parallel-testing-enabled NO
```

A normal run must stay green. The suite is 379 tests with `DocsGalleryTests` skipped. New tests are fine. Do not leave failures, and do not drop coverage so the count falls below 379 unless a test was intentionally removed and the PR says why.

`DocsGalleryTests` skips unless `TEST_RUNNER_RENDER_DOCS=1` or `RENDER_DOCS=1` is in the test process environment. Passing that name as an `xcodebuild` argument only sets a build setting. `scripts/render-docs.sh` sets it with `simctl spawn … launchctl setenv` on the booted simulator, and clears it when the script exits.

## Docs images

Regenerate pictures and `docs/Examples.md` with:

```bash
scripts/render-docs.sh
```

Requirements on `PATH`: `gifski`, `pngquant`, and `oxipng`. Do not start a Homebrew from-source build to get them.

The script is deterministic. Two consecutive runs must be byte-identical for `docs/Examples.md` and every file under `docs/images`. Every catalog drawing sets `Options.seed`. GIFs also set `AnimationConfig.seed`. Do not render an unseeded example.

Budgets, enforced by the script:

- each still PNG at most 120 KB
- each GIF at most 800 KB
- `docs/images` at most 10 MB

No Git LFS. Tiles are light paper cards only (`DocExampleCatalog.paper`, colour scheme `.light`). Do not add a dark-mode variant. `docs/images/hero.png` is the wide banner and is omitted from `docs/Examples.md`.

`docs/Examples.md` is generated. Change `DocExample` entries or the writer in `scripts/render-docs.sh`, then re-run the script. Do not hand-edit `docs/Examples.md`.

## Commits and pull requests

Branch from current `master`. Open the pull request against `master`.

Commit subjects are imperative and say what changed. Use a second paragraph when the reason is not obvious. Keep unrelated work in separate commits. One example from this repo: the text-placement bug fix landed on its own, and the new text tiles landed after it.

Do not commit `build/` or DerivedData. Do not add the crayon duck fixture unless a task names it. Run the test suite before pushing. If SwiftLint is installed, it should be clean.
