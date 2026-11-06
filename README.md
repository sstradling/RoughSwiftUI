<h1 align="center"><img src="docs/images/header.png" alt="Sketchy!" width="800"></h1>

![Hachure, cross-hatch, sunburst, and crayon on one paper card](docs/images/hero.png)

Sketchy draws shapes, SVG paths, and text in a hand-drawn style, in SwiftUI. Strokes are built by a native Swift port of the rough.js algorithms, then painted with `Canvas`. A seed redraws the same picture. Fill lines, brushes, and a wax-crayon stroke are part of the same view.

For AI coding agents: [AGENTS.md](AGENTS.md) is how to work in this repo, and [llms.txt](llms.txt) is the library API cheat-sheet.

## Installation

Add the package to your `Package.swift` dependencies and to the target that uses it. The package requires iOS 17 or later.

```swift
.package(url: "https://github.com/sstradling/Sketchy", from: "1.3.0"),
```

```swift
.product(name: "Sketchy", package: "Sketchy")
```

```swift
import SwiftUI
import Sketchy
```

## Renamed from RoughSwiftUI

The package, library product, and module were renamed to Sketchy in 1.2.0. Public type names did not change.

1. Point the package URL at `https://github.com/sstradling/Sketchy` and require `1.2.0`.
2. Depend on `.product(name: "Sketchy", package: "Sketchy")`.
3. Replace `import RoughSwiftUI` with `import Sketchy`.

`RoughView`, `RoughText`, `AnimatedRoughView`, and the other public types keep their names.

## Quick start

Give the view a frame. `.seed(42)` keeps the wobble stable across redraws. Hachure at 45° is the default fill angle.

![Hachure rectangle](docs/images/basics/hachure-rectangle.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(42)
    .rectangle()
    .frame(width: 240, height: 240)
```

## Examples

A short tour is below. The full set, with a picture and the snippet that drew it, is in [Examples](docs/Examples.md).

### Shapes

`.egg(tilt:)` narrows the top. `.curveStepCount` sets how many samples build the outline. Lines, arcs, polygons, curves, and rounded rectangles are in the catalog.

![Egg](docs/images/shapes/egg.png)

```swift
RoughView()
    .fill(Color(red: 0.45, green: 0.28, blue: 0.55))
    .fillStyle(.hachure)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .curveStepCount(16)
    .seed(28)
    .egg(tilt: 0.4)
```

### Fills

`.sunBurst` draws rays from the center. `.starBurst` uses the same filler. Other styles are `.hachure`, `.solid`, `.zigzag`, `.crossHatch`, `.dots`, `.dashed`, `.zigzagLine`, and `.scribble`.

![Sunburst](docs/images/fills/sunburst.png)

```swift
RoughView()
    .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
    .fillStyle(.sunBurst)
    .fillSpacing(2.2)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(55)
    .circle()
```

### Crayon

`.brushProfile(.crayon)` lays a wax stroke. `strokeWidth` is the wax width in points. Hachure and zigzag lines pick up the same wax, at `fillWeight`.

![Crayon stroke](docs/images/brushes/crayon.png)

```swift
RoughView()
    .stroke(Color(red: 0.45, green: 0.28, blue: 0.55))
    .strokeWidth(11)
    .brushProfile(.crayon(grit: 0.95, flakeSize: 1.5, seed: 4))
    .seed(4)
    .circle()
```

### Opacity

`.opacityProfile` multiplies `strokeOpacity` along the outline. `.uniform` changes nothing. `.values` spaces samples evenly, `.stops` places `OpacityStop` values from 0 to 1, and `.noise` wobbles between a minimum and a maximum. The same noise seed repeats. A varying profile is painted into one mask, so overlaps do not turn dark.

![Variable opacity](docs/images/brushes/variable-opacity.png)

```swift
RoughView()
    .stroke(Color(red: 0.18, green: 0.46, blue: 0.67))
    .strokeWidth(18)
    .opacityProfile(.stops([
        OpacityStop(0.15, at: 0),
        OpacityStop(1, at: 0.38),
        OpacityStop(0.2, at: 0.72),
        OpacityStop(0.95, at: 1)
    ]))
    .seed(128)
    .draw(Curve(points: [
        Point(x: 18, y: 118),
        Point(x: 70, y: 42),
        Point(x: 118, y: 142),
        Point(x: 168, y: 64)
    ]))
```

### Watercolor

`.brushProfile(.watercolor)` paints a lighter wash with a broken darker rim, a little grain, and round tapered ends. The base width stays even. `bleed` and `variation` make each edge wander, so the outline is not a smooth offset. Passes stack, so a crossing goes darker. `.fillStyle(.watercolor)` clips a wash to the shape. When the brush is watercolor, the fill uses that style.

![Watercolor stroke](docs/images/brushes/watercolor.png)

```swift
RoughView()
    .stroke(Color(red: 0.16, green: 0.40, blue: 0.66))
    .strokeWidth(26)
    .roughness(0.4)
    .bowing(0.2)
    .brushProfile(.watercolor(pigment: 0.82, wetness: 0.35, edgeDarkening: 0.9, layers: 3, variation: 0.5, bleed: 0.55, seed: 21))
    .seed(21)
    .draw(Curve(points: [
        Point(x: 22, y: 128),
        Point(x: 62, y: 36),
        Point(x: 112, y: 150),
        Point(x: 164, y: 58)
    ]))
```

### Watercolor fill

`.fillStyle(.watercolor)` clips an uneven wash to the shape. Layers glaze, the dried edge is darker, and blooms are irregular puddles. `fillPadding` insets the fill. The same seed repeats the wash.

![Watercolor fill](docs/images/brushes/watercolor-fill.png)

```swift
RoughView()
    .fill(Color(red: 0.16, green: 0.40, blue: 0.66))
    .fillStyle(.watercolor)
    .fillPadding(12)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(1.6)
    .seed(33)
    .circle()
```

Presets: `.calligraphic`, `.marker`, `.pen`, `.crayon`, and `.default`.

### Text

Text is traced to a path and drawn at the font size you set. It is placed in the view. It is not scaled to fill the frame the way an SVG path is. `.leading` and `.top` pin it to a corner. `offsetX` and `offsetY` move it after that. Positive x goes right. Positive y goes down.

![Rough text](docs/images/text/rough-word.png)

```swift
RoughView()
    .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(2)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(1.5)
    .seed(151)
    .text("Hi", font: .systemFont(ofSize: 76, weight: .heavy))
```

`RoughText` is the same drawing sized to the glyphs, so it can sit beside another view.

### Animation

`.animated(config:)` loops a seeded wobble. `AnimationConfig.seed` replays the same frames. The convenience `.animated(steps:speed:variance:)` does not take a seed.

![Breathing circle](docs/images/animation/breathing-circle.gif)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.crossHatch)
    .fillAngle(30)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(42)
    .circle()
    .animated(config: AnimationConfig(steps: 6, speed: .medium, variance: .high, seed: 42))
```

| Speed | Step |
| --- | --- |
| `.slow` | 600 ms |
| `.medium` | 300 ms |
| `.fast` | 100 ms |

| Variance | Amount |
| --- | --- |
| `.veryLow` | 0.5% |
| `.low` | 1% |
| `.medium` | 5% |
| `.high` | 10% |

## Options

`Options` is copied through the builder methods on `RoughView`. One view has one set of options. Stack views when a drawing needs two colours.

| Modifier | Default | What it changes |
| --- | --- | --- |
| `.roughness` | 1 | How far strokes and fill lines jitter |
| `.bowing` | 1 | How much long edges bend |
| `.maxRandomnessOffset` | 2 | How far the two outline passes wander |
| `.stroke` / `.fill` | black / clear | Line colour and interior colour |
| `.strokeWidth` | 1 | Outline width, in points |
| `.strokeOpacity` / `.fillOpacity` | 100 | 0 is clear, 100 is opaque |
| `.fillStyle` | `.hachure` | Interior pattern |
| `.fillWeight` | half the stroke, at least 1 | Width of each fill line |
| `.fillAngle` | 45 | Degrees clockwise from horizontal |
| `.fillSpacing` | 4 | Gap as a multiple of the fill weight, from 0.5 to 100 |
| `.fillPadding` | 0 | Inset of the fill from the outline, in points. Negative grows the fill |
| `.fillOffset` | `.zero` | Shifts the fill relative to the outline |
| `.seed` | `nil` | Stable random sequence. `nil` picks a new drawing on a cache miss |
| `.strokeContinuity` | `.legacy` | `.continuous` draws native outlines as a few cubic Beziers |

### Fill angle

`0` is horizontal and `90` is vertical for hachure, zigzag, cross-hatch, dashed, and zigzag-line. Positive angles rotate clockwise because Core Graphics y points down. Dots stay on the horizontal grid. Scribble strokes use `scribbleOrigin` with that same bearing. Sunburst fills are radial and ignore `fillAngle`.

`.fillPadding(0)` keeps the fill on the outline. A positive padding insets it (ellipse radii shrink, polygon edges move inward) and a negative padding grows it past the stroke. A padding that collapses the shape draws no fill. `.fillOffset(x:y:)` moves the fill without moving the outline.

### Seed

`.seed(42)` restarts a SplitMix64 sequence for that drawing. The same seed and the same options redraw the same strokes.

Crayon grain uses `CrayonStyle.seed`. When that seed is still `CrayonStyle.defaultSeed` (`1`) and `Options.seed` is set, the grain comes from `Options.seed`. Any other crayon seed wins. `AnimationConfig.seed` is separate and only affects the animation frames.

### Stroke continuity

`.strokeContinuity(.legacy)` is the default. Curved outlines are still sampled at `.curveStepCount` and stitched into short cubics. `.strokeContinuity(.continuous)` replaces that for `line`, `rectangle`, `ellipse`, `circle`, `linearPath`, `polygon`, `arc`, `roundedRectangle`, and `egg`: a circle is four cubics per pass, and a polygon is one subpath per pass with shared corners. `curve`, SVG paths, and text stay on the sampled path. `RoughText` has the same modifier for parity.

```swift
RoughView()
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(3)
    .strokeContinuity(.continuous)
    .seed(42)
    .circle()
    .frame(width: 240, height: 240)
```

### Scribble

`.fillStyle(.scribble)` draws one continuous zig-zag across the shape.

| Modifier | Default | Range |
| --- | --- | --- |
| `.scribbleOrigin` | 0 | Degrees. 0 goes right, 90 goes down |
| `.scribbleTightness` | 10 | 1 to 100 zig-zags |
| `.scribbleCurvature` | 0 | 0 to 50 |
| `.scribbleUseBrushStroke` | false | Draw the zig-zag with the current brush |
| `.scribbleTightnessPattern` | none | Density bands, such as `[6, 24, 8, 28]` |

### SVG paths

`.draw(Path(d:))` scales the path to the view and keeps its aspect ratio. `.svgStrokeWidth`, `.svgFillWeight`, and `.svgFillStrokeAlignment` (`.center`, `.inside`, `.outside`) apply to that path. Text is also stored as a path, but it is placed in the view and is not scaled to fit.

`A` and `a` draw elliptical arcs. A zero radius becomes a line, identical endpoints are skipped, and radii that cannot reach the endpoint scale up. The arc is split into cubic segments of at most 90° and roughened like the other path commands.

### Brushes

| Profile | Look |
| --- | --- |
| `.default` | Even round stroke |
| `.calligraphic` | Flat tip at 45°, tapered ends |
| `.marker` | Flat tip, butt caps. Even width |
| `.pen` | Pressure swell through the middle |
| `.crayon` | Continuous wax with grit on top |
| `.watercolor` | Lighter wash with a broken darker rim |

`.marker(variation:minimum:maximum:taperStart:taperEnd:pressure:seed:)` is that same marker with width that changes along an open stroke. `variation` of `0.35` keeps the body in `[0.65, 1.35]` times `strokeWidth`. `minimum` and `maximum` replace that range. They are multipliers, not points. `seed` repeats the wobble. `pressure` uses the same curve as `ThicknessProfile.pressure`. Taper may thin the ends to a point. The default `marker()` call is the even marker above.

```swift
RoughView()
    .stroke(Color(red: 0.76, green: 0.32, blue: 0.28))
    .strokeWidth(18)
    .brushProfile(.marker(variation: 1, minimum: 0.25, maximum: 1.45, taperStart: 0.12, taperEnd: 0.16, seed: 19))
    .seed(127)
    .draw(Line(from: Point(x: 24, y: 100), to: Point(x: 168, y: 92)))
```

`.thicknessProfile(.naturalPen)` tapers an open stroke. Closed shapes keep an even width so the join does not seam. A variable marker does the same on a closed contour.

`.widthStops([(0, 4), (0.1, 8), (0.9, 8), (1, 4)])` sets those widths in points: 4pt at the start, 8pt from 10% to 90% of the length, then 4pt. `strokeWidth` does not scale a non-empty list. `.custom([0.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.5])` with `strokeWidth` 8 is the same curve, as evenly spaced multipliers. Stops replace a `.variable` wobble. The marker's flat tip still changes width with direction. Closed contours ignore the stops.

![Width stops](docs/images/brushes/width-stops.png)

```swift
RoughView()
    .stroke(Color(red: 0.18, green: 0.46, blue: 0.67))
    .strokeWidth(2)
    .roughness(0.25)
    .widthStops([(0, 4), (0.1, 8), (0.9, 8), (1, 4)])
    .seed(149)
    .draw(Curve(points: [
        Point(x: 10, y: 120),
        Point(x: 58, y: 28),
        Point(x: 112, y: 156),
        Point(x: 174, y: 52)
    ]))
```

## Shapes

Auto-sized, filling the view: `.rectangle()`, `.circle()`, `.roundedRectangle(cornerRadius:)`, `.egg(tilt:)`, and `.text`.

Placed with `.draw`: `Line`, `Rectangle`, `Ellipse`, `Circle`, `LinearPath`, `Arc`, `Curve`, `Polygon`, `Path`, `RoundedRectangle`, and `EggShape`.

## Performance

Generators are cached by size. Drawings are cached by shape and by the options that change geometry, including the seed. How to clear those caches, and how to read the signposts in Instruments, is in [Performance](docs/Performance.md).

## Demo

`Example/SketchyDemo` is the sample app. Open `Example/SketchyDemo/SketchyDemoApp.xcodeproj` and run the `SketchyDemoApp` scheme. It links the local `Sketchy` package. The bundle id is `com.sstradling.SketchyDemo`.

## Author

**Seth Stradling** - [@sstradling](https://github.com/sstradling)

## Credits

- [**RoughSwift**](https://github.com/onmyway133/RoughSwift) by [Khoa Pham](https://github.com/onmyway133). Sketchy keeps that SwiftUI API and replaces the JavaScript engine with a native generator.
- [**rough.js**](https://github.com/pshihn/rough) by Prashant Sharma. The hand-drawn line, fill, and curve algorithms come from rough.js.
- [**SVGPath**](https://github.com/timrwood/SVGPath) by Tim Wood. SVG path parsing.

## License

Sketchy is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
