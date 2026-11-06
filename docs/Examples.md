# Examples

Rendered by `scripts/render-docs.sh` from the `DocExample` catalog. Each example sets a fixed seed so the picture matches the snippet. Tiles are light paper cards.

The pictures below are the full catalog. A shorter tour lives in the [README](../README.md).

## Contents

- [Basics](#basics)
- [Shapes](#shapes)
- [Fills](#fills)
- [Strokes](#strokes)
- [Roughness](#roughness)
- [Brushes](#brushes)
- [Stickers](#stickers)
- [Seeding](#seeding)
- [SVG](#svg)
- [Text](#text)
- [Animation](#animation)

## Basics

A seeded shape is the smallest useful drawing. Every tile on this page sets a seed so the picture matches the snippet.

### Hachure rectangle

A seeded rectangle with hachure at 45°, the default fill angle.

![Hachure rectangle](images/basics/hachure-rectangle.png)

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
```

## Shapes

Rectangles, ellipses, lines, arcs, polygons, curves, rounded rectangles, and eggs. Coordinates are in the 184-point box inside the card.

### Ellipse

An ellipse placed by center, width, and height inside the card.

![Ellipse](images/shapes/ellipse.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(14)
    .draw(Ellipse(x: 92, y: 92, width: 150, height: 108))
```

### Circle

A circle that fills the card. The diameter follows the shorter side.

![Circle](images/shapes/circle.png)

```swift
RoughView()
    .fill(Color(red: 0.45, green: 0.28, blue: 0.55))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(15)
    .circle()
```

### Line

A single line from one point to another. The outline is two offset passes.

![Line](images/shapes/line.png)

```swift
RoughView()
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(3)
    .roughness(1.3)
    .seed(16)
    .draw(Line(from: Point(x: 24, y: 140), to: Point(x: 160, y: 44)))
```

### Open arc

An arc in radians. This one stays open, so it is a stroke without a pie fill.

![Open arc](images/shapes/open-arc.png)

```swift
RoughView()
    .stroke(Color(red: 0.18, green: 0.46, blue: 0.67))
    .strokeWidth(3)
    .seed(17)
    .draw(Arc(
        x: 92,
        y: 96,
        width: 140,
        height: 140,
        start: Float.pi * 0.15,
        stop: Float.pi * 0.85,
        closed: false
    ))
```

### Closed arc

A closed arc draws the chord back to the center and fills the wedge.

![Closed arc](images/shapes/closed-arc.png)

```swift
RoughView()
    .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
    .fillStyle(.hachure)
    .fillSpacing(2.5)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(19)
    .draw(Arc(
        x: 92,
        y: 100,
        width: 140,
        height: 140,
        start: -Float.pi / 2,
        stop: Float.pi / 2,
        closed: true
    ))
```

### Polygon

A closed polygon through the given points. The last edge joins back to the first.

![Polygon](images/shapes/polygon.png)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(21)
    .draw(Polygon(points: [
        Point(x: 92, y: 22),
        Point(x: 162, y: 158),
        Point(x: 22, y: 158)
    ]))
```

### Linear path

An open polyline. Unlike a polygon, the ends are not joined and there is no fill.

![Linear path](images/shapes/linear-path.png)

```swift
RoughView()
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2.5)
    .seed(23)
    .draw(LinearPath(points: [
        Point(x: 16, y: 140),
        Point(x: 52, y: 44),
        Point(x: 92, y: 112),
        Point(x: 132, y: 36),
        Point(x: 168, y: 140)
    ]))
```

### Curve

A spline through the points. curveTightness(0.8) pulls it toward those points.

![Curve](images/shapes/curve.png)

```swift
RoughView()
    .stroke(Color(red: 0.18, green: 0.46, blue: 0.67))
    .strokeWidth(3)
    .curveTightness(0.8)
    .seed(24)
    .draw(Curve(points: [
        Point(x: 20, y: 124),
        Point(x: 60, y: 36),
        Point(x: 112, y: 150),
        Point(x: 164, y: 60)
    ]))
```

### Rounded rectangle

A full-card rectangle with a shared corner radius of 36 points.

![Rounded rectangle](images/shapes/rounded-rectangle.png)

```swift
RoughView()
    .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
    .fillStyle(.hachure)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(27)
    .roundedRectangle(cornerRadius: 36)
```

### Egg

tilt 0.4 narrows the top. The outline is four continuous cubics per pass. curveStepCount(16) samples the hachure polygon.

![Egg](images/shapes/egg.png)

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

## Fills

Hachure, solid, zigzag, cross-hatch, dots, dashed, zigzag-line, sunburst, and scribble. 0° is horizontal. Positive angles rotate clockwise.

### Horizontal hachure

Hachure at 0° runs horizontally. Positive angles rotate clockwise.

![Horizontal hachure](images/fills/horizontal-hachure.png)

```swift
RoughView()
    .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillSpacing(2.5)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(11)
    .circle()
```

### Vertical hachure

Hachure at 90° runs from top to bottom.

![Vertical hachure](images/fills/vertical-hachure.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(90)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(31)
    .rectangle()
```

### Clockwise hachure

20° is a shallow clockwise slope from the horizontal axis.

![Clockwise hachure](images/fills/clockwise-hachure.png)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.hachure)
    .fillAngle(20)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(33)
    .circle()
```

### Solid fill

A solid interior. The outline stays sketchy.

![Solid fill](images/fills/solid-fill.png)

```swift
RoughView()
    .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
    .fillStyle(.solid)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(36)
    .circle()
```

### Zigzag fill

Hachure lines joined at the ends, so the fill is one zigzagging stroke.

![Zigzag fill](images/fills/zigzag-fill.png)

```swift
RoughView()
    .fill(Color(red: 0.45, green: 0.28, blue: 0.55))
    .fillStyle(.zigzag)
    .fillAngle(40)
    .fillSpacing(3.5)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(37)
    .rectangle()
```

### Cross-hatch

Two hachure passes. The second sits across the first.

![Cross-hatch](images/fills/cross-hatch.png)

```swift
RoughView()
    .fill(Color(red: 0.20, green: 0.45, blue: 0.52))
    .fillStyle(.crossHatch)
    .fillAngle(30)
    .fillSpacing(3.5)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(41)
    .circle()
```

### Dots

A dot grid. Dots stay on the horizontal lattice and ignore fillAngle.

![Dots](images/fills/dots.png)

```swift
RoughView()
    .fill(Color(red: 0.55, green: 0.32, blue: 0.22))
    .fillStyle(.dots)
    .fillSpacing(2.2)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(44)
    .circle()
```

### Dashed fill

Hachure broken into dashes. dashOffset is the dash length and dashGap is the skip.

![Dashed fill](images/fills/dashed-fill.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.dashed)
    .fillAngle(45)
    .fillSpacing(3)
    .dashOffset(12)
    .dashGap(8)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(48)
    .rectangle()
```

### Zigzag line

Each hachure line is itself a zigzag. zigzagOffset(14) sets the size of those peaks.

![Zigzag line](images/fills/zigzag-line.png)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.zigzagLine)
    .fillAngle(0)
    .fillSpacing(4)
    .zigzagOffset(14)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(52)
    .circle()
```

### Sunburst

Rays from the center. .starBurst draws this same radial filler.

![Sunburst](images/fills/sunburst.png)

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

### Scribble

One continuous zig-zag that crosses the shape. The bearing comes from scribbleOrigin.

![Scribble](images/fills/scribble.png)

```swift
RoughView()
    .fill(Color(red: 0.45, green: 0.28, blue: 0.55))
    .fillStyle(.scribble)
    .scribble(origin: 18, tightness: 14, curvature: 0)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(61)
    .circle()
```

### Heavy fill lines

fillWeight(5) thickens each hachure line. fillSpacing(1.6) keeps them close.

![Heavy fill lines](images/fills/heavy-fill.png)

```swift
RoughView()
    .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillWeight(5)
    .fillSpacing(1.6)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(64)
    .rectangle()
```

### Wide fill gap

fillSpacing(9) opens the gap between thin hachure lines. The factor multiplies fillWeight.

![Wide fill gap](images/fills/wide-gap.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillWeight(1.5)
    .fillSpacing(9)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(67)
    .circle()
```

### Spacing pattern

fillSpacingPattern stacks a hachure pass for each multiplier of fillSpacing. The tightest pass covers the shape.

![Spacing pattern](images/fills/spacing-pattern.png)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillWeight(2)
    .fillSpacing(2)
    .fillSpacingPattern([1, 1, 2, 3, 5, 8])
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(71)
    .rectangle()
```

### Curved scribble

scribbleOrigin(110) aims the strokes, tightness(11) sets the count, and curvature(36) rounds the corners.

![Curved scribble](images/fills/curved-scribble.png)

```swift
RoughView()
    .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
    .fillStyle(.scribble)
    .scribble(origin: 110, tightness: 11, curvature: 36)
    .fillWeight(2)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(77)
    .roundedRectangle(cornerRadius: 28)
```

### Scribble bands

A tightness pattern splits the traversal into sparse and dense bands.

![Scribble bands](images/fills/scribble-bands.png)

```swift
RoughView()
    .fill(Color(red: 0.20, green: 0.45, blue: 0.52))
    .fillStyle(.scribble)
    .scribble(origin: 90, tightnessPattern: [6, 24, 8, 28], curvature: 10)
    .fillWeight(1.8)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(81)
    .rectangle()
```

### Brush scribble

scribbleUseBrushStroke draws the zig-zag with the current brush. This one uses the calligraphic preset.

![Brush scribble](images/fills/brush-scribble.png)

```swift
RoughView()
    .fill(Color(red: 0.45, green: 0.28, blue: 0.55))
    .fillStyle(.scribble)
    .scribble(origin: 75, tightness: 12, curvature: 8, useBrushStroke: true)
    .fillWeight(6)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .brushProfile(.calligraphic)
    .seed(88)
    .circle()
```

### Fill padding zero

fillPadding(0) puts the fill edge on the outline. The hachure meets the circle.

![Fill padding zero](images/fills/fill-padding-zero.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillSpacing(2.5)
    .fillPadding(0)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(90)
    .circle()
```

### Fill padding

fillPadding(16) insets the fill. Ellipse radii shrink and polygon edges move inward.

![Fill padding](images/fills/fill-padding.png)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillSpacing(2.5)
    .fillPadding(16)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(91)
    .circle()
```

### Negative fill padding

fillPadding(-12) grows the fill past the outline. A padding that collapses the shape draws nothing.

![Negative fill padding](images/fills/fill-padding-outset.png)

```swift
RoughView()
    .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillSpacing(2.5)
    .fillPadding(-12)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(92)
    .circle()
```

### Fill offset

fillOffset shifts the fill and leaves the outline where it is. Positive x moves right, negative y moves up.

![Fill offset](images/fills/fill-offset.png)

```swift
RoughView()
    .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(2.5)
    .fillOffset(x: 18, y: -12)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(93)
    .circle()
```

## Strokes

Width, colour, opacity, and several lines in one view. Each outline is drawn as two offset passes.

### Several strokes

One view can draw several lines. Each outline is itself two offset passes.

![Several strokes](images/strokes/several-lines.png)

```swift
RoughView()
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2.5)
    .roughness(1.4)
    .seed(91)
    .draw(Line(from: Point(x: 28, y: 48), to: Point(x: 156, y: 48)))
    .draw(Line(from: Point(x: 28, y: 92), to: Point(x: 156, y: 92)))
    .draw(Line(from: Point(x: 28, y: 136), to: Point(x: 156, y: 136)))
```

### Thick stroke

strokeWidth(12) with square caps and bevel joins on an open polyline.

![Thick stroke](images/strokes/thick-stroke.png)

```swift
RoughView()
    .stroke(Color(red: 0.18, green: 0.46, blue: 0.67))
    .strokeWidth(12)
    .strokeCap(.square)
    .strokeJoin(.bevel)
    .seed(97)
    .draw(LinearPath(points: [
        Point(x: 28, y: 132),
        Point(x: 70, y: 48),
        Point(x: 114, y: 120),
        Point(x: 156, y: 52)
    ]))
```

### Stroke opacity

strokeOpacity takes 0 to 100. Here the outline is 40, over a solid fill.

![Stroke opacity](images/strokes/stroke-opacity.png)

```swift
RoughView()
    .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
    .fillStyle(.solid)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(8)
    .strokeOpacity(40)
    .seed(101)
    .circle()
```

### Fill opacity

fillOpacity(35) lets the paper show through a solid interior.

![Fill opacity](images/strokes/fill-opacity.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.solid)
    .fillOpacity(35)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(104)
    .roundedRectangle(cornerRadius: 28)
```

## Roughness

Roughness, bowing, and maxRandomnessOffset set how far those two passes wander from the true edge.

### Even outline

Roughness, bowing, and maxRandomnessOffset at zero leave a nearly even double outline.

![Even outline](images/roughness/smooth.png)

```swift
RoughView()
    .fill(Color(red: 0.20, green: 0.45, blue: 0.52))
    .fillStyle(.solid)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(0)
    .bowing(0)
    .maxRandomnessOffset(0)
    .seed(108)
    .rectangle()
```

### Rough outline

roughness(2.8) scales the jitter on the outline and the fill.

![Rough outline](images/roughness/rough.png)

```swift
RoughView()
    .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
    .fillStyle(.hachure)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(2.8)
    .seed(111)
    .rectangle()
```

### Bowed edges

bowing(6) bends each edge. maxRandomnessOffset(3) is how far that bend can travel.

![Bowed edges](images/roughness/bowed.png)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.solid)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(1)
    .bowing(6)
    .maxRandomnessOffset(3)
    .seed(115)
    .rectangle()
```

### Loose double stroke

maxRandomnessOffset(6) sets how far the two outline passes wander from the true edge.

![Loose double stroke](images/roughness/loose-wobble.png)

```swift
RoughView()
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(1.6)
    .bowing(1)
    .maxRandomnessOffset(6)
    .seed(120)
    .draw(Line(from: Point(x: 20, y: 92), to: Point(x: 164, y: 92)))
```

## Brushes

Calligraphic, marker, and pen presets, plus crayon wax. A crayon brush textures fill lines as well as the outline.

### Calligraphic brush

The calligraphic preset uses a flat tip at 45° and tapered ends.

![Calligraphic brush](images/brushes/calligraphic.png)

```swift
RoughView()
    .stroke(Color(red: 0.18, green: 0.46, blue: 0.67))
    .strokeWidth(8)
    .brushProfile(.calligraphic)
    .seed(123)
    .draw(Curve(points: [
        Point(x: 24, y: 132),
        Point(x: 64, y: 40),
        Point(x: 116, y: 148),
        Point(x: 160, y: 56)
    ]))
```

### Marker

The marker preset is a flat tip with butt caps and bevel joins.

![Marker](images/brushes/marker.png)

```swift
RoughView()
    .stroke(Color(red: 0.76, green: 0.32, blue: 0.28))
    .strokeWidth(16)
    .brushProfile(.marker)
    .seed(127)
    .draw(Line(from: Point(x: 24, y: 140), to: Point(x: 160, y: 44)))
```

### Variable marker

Width swells between a minimum and maximum and thins at both ends. The marker seed repeats that wobble. The default marker stays an even width.

![Variable marker](images/brushes/variable-marker.png)

```swift
RoughView()
    .stroke(Color(red: 0.76, green: 0.32, blue: 0.28))
    .strokeWidth(18)
    .brushProfile(.marker(
        variation: 1,
        minimum: 0.25,
        maximum: 1.45,
        taperStart: 0.12,
        taperEnd: 0.16,
        seed: 19
    ))
    .seed(127)
    .draw(Line(from: Point(x: 24, y: 100), to: Point(x: 168, y: 92)))
```

### Pen pressure

The pen preset swells through the middle of the stroke.

![Pen pressure](images/brushes/pen.png)

```swift
RoughView()
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(7)
    .brushProfile(.pen)
    .seed(131)
    .draw(Curve(points: [
        Point(x: 20, y: 110),
        Point(x: 70, y: 36),
        Point(x: 120, y: 150),
        Point(x: 164, y: 72)
    ]))
```

### Crayon stroke

A wax ring. The crayon seed pins the grit, and strokeWidth is the wax width in points.

![Crayon stroke](images/brushes/crayon.png)

```swift
RoughView()
    .stroke(Color(red: 0.45, green: 0.28, blue: 0.55))
    .strokeWidth(11)
    .brushProfile(.crayon(grit: 0.95, flakeSize: 1.5, seed: 4))
    .seed(4)
    .circle()
```

### Crayon fill

Hachure lines use the same wax. fillWeight is the width of each line. The preset crayon seed follows Options.seed.

![Crayon fill](images/brushes/crayon-fill.png)

```swift
RoughView()
    .fill(Color(red: 0.55, green: 0.32, blue: 0.22))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillWeight(3.5)
    .fillSpacing(2.4)
    .stroke(Color(red: 0.55, green: 0.32, blue: 0.22))
    .strokeWidth(5)
    .brushProfile(.crayon)
    .seed(12)
    .rectangle()
```

### Tapered pen

thicknessProfile(.naturalPen) tapers both ends of an open curve.

![Tapered pen](images/brushes/tapered-stroke.png)

```swift
RoughView()
    .stroke(Color(red: 0.22, green: 0.48, blue: 0.34))
    .strokeWidth(10)
    .thicknessProfile(.naturalPen)
    .seed(137)
    .draw(Curve(points: [
        Point(x: 22, y: 120),
        Point(x: 68, y: 40),
        Point(x: 118, y: 146),
        Point(x: 162, y: 64)
    ]))
```

### Width stops

widthStops sets point widths on an open curve: 4pt, 8pt from 10% to 90%, then 4pt. strokeWidth stays 2 and does not scale them.

![Width stops](images/brushes/width-stops.png)

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

### Variable opacity

Opacity stops run from faint to solid and back. The profile multiplies strokeOpacity, and one mask keeps the overlaps from turning dark.

![Variable opacity](images/brushes/variable-opacity.png)

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

### Watercolor stroke

A broken rim that fades in and out, darker where the pigment dries, with grain inside and round tapered ends. The same seed repeats the wash.

![Watercolor stroke](images/brushes/watercolor.png)

```swift
RoughView()
    .stroke(Color(red: 0.16, green: 0.40, blue: 0.66))
    .strokeWidth(26)
    .roughness(0.4)
    .bowing(0.2)
    .brushProfile(.watercolor(
        pigment: 0.82,
        wetness: 0.35,
        edgeDarkening: 0.9,
        layers: 3,
        variation: 0.5,
        bleed: 0.55,
        seed: 21
    ))
    .seed(21)
    .draw(Curve(points: [
        Point(x: 22, y: 128),
        Point(x: 62, y: 36),
        Point(x: 112, y: 150),
        Point(x: 164, y: 58)
    ]))
```

### Watercolor fill

fillStyle(.watercolor) is an uneven clipped wash: layered glazes, a darker dried edge, and a little grain. fillPadding insets it. The fill seed follows Options.seed.

![Watercolor fill](images/brushes/watercolor-fill.png)

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

### Watercolor overlap

Two washes cross. Pigment stacks in the crossing, so that patch is darker than either stroke alone.

![Watercolor overlap](images/brushes/watercolor-overlap.png)

```swift
RoughView()
    .stroke(Color(red: 0.16, green: 0.40, blue: 0.66))
    .strokeWidth(20)
    .roughness(0.35)
    .brushProfile(.watercolor(
        pigment: 0.7,
        wetness: 0.3,
        edgeDarkening: 0.85,
        layers: 2,
        variation: 0.35,
        bleed: 0.4,
        seed: 27
    ))
    .seed(27)
    .draw(Line(from: Point(x: 36, y: 40), to: Point(x: 150, y: 148)))
    .draw(Line(from: Point(x: 36, y: 148), to: Point(x: 150, y: 40)))
```

## Stickers

A sheet behind the ink. Smoothness chooses the rough edge or the input silhouette. .smooth keeps corners, .fullySmooth() rounds the whole cut, and torn chops the margin. The slate rectangle is gallery chrome so the white paper shows. It is not part of the snippet.

### Sticker star

White paper past the stroke. Smoothness 0.85 follows the star and drops the sketch wobble. The slate mat is only in the gallery so the white margin shows.

![Sticker star](images/stickers/sticker-star.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(1.4)
    .seed(42)
    .stickerBacking(width: 14, smoothness: 0.85)
    .draw(Polygon(points: [
            Point(x: 92, y: 36),
    Point(x: 106, y: 73),
    Point(x: 145, y: 75),
    Point(x: 115, y: 99),
    Point(x: 125, y: 137),
    Point(x: 92, y: 116),
    Point(x: 59, y: 137),
    Point(x: 69, y: 99),
    Point(x: 39, y: 75),
    Point(x: 78, y: 73)
    ]))
```

### Torn sticker

The same star with a chopped edge. Depth, facet length, and jaggedness are seeded, so the tear repeats.

![Torn sticker](images/stickers/sticker-torn.png)

```swift
RoughView()
    .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(1.4)
    .seed(42)
    .stickerBacking(
        width: 16,
        smoothness: 0.55,
        edge: .torn(StickerTear(depth: 7, length: 14, jaggedness: 0.45))
    )
    .draw(Polygon(points: [
            Point(x: 92, y: 36),
    Point(x: 106, y: 73),
    Point(x: 145, y: 75),
    Point(x: 115, y: 99),
    Point(x: 125, y: 137),
    Point(x: 92, y: 116),
    Point(x: 59, y: 137),
    Point(x: 69, y: 99),
    Point(x: 39, y: 75),
    Point(x: 78, y: 73)
    ]))
```

### Crayon on paper

The wax stroke paints on top of the sheet. A wider margin keeps most of the grit on the paper.

![Crayon on paper](images/stickers/sticker-crayon.png)

```swift
RoughView()
    .fill(Color(red: 0.45, green: 0.28, blue: 0.55))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillSpacing(3.5)
    .stroke(Color(red: 0.45, green: 0.28, blue: 0.55))
    .strokeWidth(12)
    .brushProfile(.crayon(seed: 4))
    .seed(4)
    .stickerBacking(width: 18, smoothness: 0.7)
    .circle()
```

### Tinted paper

The sheet color and the grain are separate. Fibers stay inside the cutout and repeat with the texture seed.

![Tinted paper](images/stickers/sticker-paper.png)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(18)
    .stickerBacking(
        width: 16,
        smoothness: 0.8,
        color: Color(red: 0.96, green: 0.91, blue: 0.78),
        texture: .paper(amount: 0.55, scale: 10, seed: 18)
    )
    .egg(tilt: 0.4)
```

### Fully smooth edge

fullySmooth rounds the whole cutout, including corners of the sampled egg. smoothness still only chooses the silhouette. The slate mat is gallery chrome.

![Fully smooth edge](images/stickers/sticker-fully-smooth.png)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.hachure)
    .fillAngle(0)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(17)
    .stickerBacking(width: 22, smoothness: 1, edge: .fullySmooth())
    .egg(tilt: 0.42)
```

## Seeding

The same seed redraws the same strokes. A different seed is a different drawing of the same shape.

### Seed 7

A circle pinned with seed 7.

![Seed 7](images/seeding/seed-seven.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(40)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(2.2)
    .seed(7)
    .circle()
```

### Seed 7, again

The same circle and the same seed. The strokes match the previous tile.

![Seed 7, again](images/seeding/seed-seven-again.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(40)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(2.2)
    .seed(7)
    .circle()
```

### Seed 99

The same circle with seed 99. The wobble is a different drawing.

![Seed 99](images/seeding/seed-ninety-nine.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(40)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(2.2)
    .seed(99)
    .circle()
```

## SVG

Path strings are scaled to fit the card. Stroke width, fill weight, and fill alignment can be set for SVG paths alone.

### SVG star

An SVG path string, scaled to the card. svgStrokeWidth overrides the outline width.

![SVG star](images/svg/svg-star.png)

```swift
RoughView()
    .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .svgStrokeWidth(2.5)
    .seed(141)
    .draw(Path(d: "M50,5 L63,40 L100,40 L70,62 L82,98 L50,78 L18,98 L30,62 L0,40 L37,40 Z"))
```

### Outside SVG stroke

svgFillStrokeAlignment(.outside) lays the stroke on the outer edge. svgFillWeight sets the fill-line width.

![Outside SVG stroke](images/svg/svg-outside.png)

```swift
RoughView()
    .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
    .fillStyle(.hachure)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .svgStrokeWidth(8)
    .svgFillWeight(2)
    .svgFillStrokeAlignment(.outside)
    .seed(144)
    .draw(Path(d: "M50,28 C50,28 38,8 22,8 C8,8 0,20 0,34 C0,55 22,72 50,96 C78,72 100,55 100,34 C100,20 92,8 78,8 C62,8 50,28 50,28 Z"))
```

### SVG arcs

A pie slice and a rounded speech bubble. The wedge and the four corners are elliptical arc commands.

![SVG arcs](images/svg/svg-arcs.png)

```swift
RoughView()
    .fill(Color(red: 0.45, green: 0.28, blue: 0.55))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(4)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(146)
    .draw(Path(d: "M52 110 L52 66 A44 44 0 0 1 96 110 Z M126 48 H166 A18 18 0 0 1 184 66 V112 A18 18 0 0 1 166 130 H150 L138 152 L128 130 H126 A18 18 0 0 1 108 112 V66 A18 18 0 0 1 126 48 Z"))
```

## Text

Glyphs are drawn at the font size you set and placed in the card. Text is not scaled to fill the frame the way an SVG path is.

### Rough text

Text is traced to a path and centered. The letters take the same hachure as a shape.

![Rough text](images/text/rough-word.png)

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

### Named font

A PostScript font name, drawn at that size and centered in the card.

![Named font](images/text/named-font.png)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.solid)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(1.5)
    .seed(155)
    .text("Note", fontName: "Helvetica-Bold", fontSize: 48)
```

### Leading top

Leading and top pin the glyphs to the corner of the card, at the font size you set.

![Leading top](images/text/leading-text.png)

```swift
RoughView()
    .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(1.8)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(1.5)
    .seed(160)
    .text(
        "Top",
        font: .systemFont(ofSize: 32, weight: .bold),
        horizontalAlignment: .leading,
        verticalAlignment: .top
    )
```

### Offset text

offsetX and offsetY move a centered word. Positive x goes right and positive y goes down.

![Offset text](images/text/offset-text.png)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(1.8)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(1.5)
    .seed(164)
    .text(
        "Hi",
        font: .systemFont(ofSize: 40, weight: .bold),
        offsetX: 24,
        offsetY: 32
    )
```

### Attributed text

An attributed string can mix sizes in one run. The bang uses a smaller font than the letters.

![Attributed text](images/text/attributed-text.png)

```swift
let title = NSMutableAttributedString(
    string: "Hi!",
    attributes: [.font: UIFont.systemFont(ofSize: 64, weight: .heavy)]
)
title.addAttribute(
    .font,
    value: UIFont.systemFont(ofSize: 28, weight: .regular),
    range: NSRange(location: 2, length: 1)
)
RoughView()
    .fill(Color(red: 0.45, green: 0.28, blue: 0.55))
    .fillStyle(.solid)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(1.5)
    .seed(168)
    .text(attributedString: title)
```

### RoughText

RoughText sizes itself to the glyphs, so the word keeps its size beside a shape that fills the rest of the card.

![RoughText](images/text/rough-text.png)

```swift
HStack(spacing: 12) {
    RoughText("Hi", font: .systemFont(ofSize: 44, weight: .heavy))
        .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
        .fillStyle(.hachure)
        .fillAngle(45)
        .fillSpacing(1.6)
        .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
        .strokeWidth(1.5)
        .seed(172)
    RoughView()
        .fill(Color(red: 0.20, green: 0.45, blue: 0.52))
        .fillStyle(.solid)
        .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
        .strokeWidth(2)
        .seed(173)
        .circle()
}
```

## Animation

AnimationConfig.seed replays the same wobble. Options.seed still pins the base drawing. The GIF rate follows the step speed.

### Breathing circle

A seeded cross-hatch circle. AnimationConfig.seed replays the same wobble.

![Breathing circle](images/animation/breathing-circle.gif)

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

### Slow breath

Very low variance and the slow step, 600 ms. The GIF plays the four frames at 2 fps.

![Slow breath](images/animation/slow-breath.gif)

```swift
RoughView()
    .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(30)
    .rectangle()
    .animated(config: AnimationConfig(steps: 4, speed: .slow, variance: .veryLow, seed: 30))
```

### Low wobble

Low variance (1%) on a seeded ellipse, played at 3 fps for the medium step.

![Low wobble](images/animation/low-wobble.gif)

```swift
RoughView()
    .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
    .fillStyle(.solid)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .roughness(1.4)
    .seed(32)
    .draw(Ellipse(x: 92, y: 92, width: 150, height: 110))
    .animated(config: AnimationConfig(steps: 4, speed: .medium, variance: .low, seed: 32))
```

### Sketch cycle

Medium variance on a triangle, five steps, played at 3 fps.

![Sketch cycle](images/animation/sketch-cycle.gif)

```swift
RoughView()
    .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
    .fillStyle(.hachure)
    .fillSpacing(3)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(34)
    .draw(Polygon(points: [
        Point(x: 92, y: 24),
        Point(x: 160, y: 156),
        Point(x: 24, y: 156)
    ]))
    .animated(config: AnimationConfig(steps: 5, speed: .medium, variance: .medium, seed: 34))
```

### Fast jitter

High variance and the fast step, 100 ms. The GIF plays the four frames at 10 fps.

![Fast jitter](images/animation/fast-jitter.gif)

```swift
RoughView()
    .fill(Color(red: 0.45, green: 0.28, blue: 0.55))
    .fillStyle(.zigzag)
    .fillAngle(30)
    .fillSpacing(3.5)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(38)
    .circle()
    .animated(config: AnimationConfig(steps: 4, speed: .fast, variance: .high, seed: 38))
```

### Eight steps

Eight variation steps before the loop repeats. Medium variance, played at 3 fps.

![Eight steps](images/animation/long-cycle.gif)

```swift
RoughView()
    .fill(Color(red: 0.20, green: 0.45, blue: 0.52))
    .fillStyle(.dots)
    .fillSpacing(2.4)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(40)
    .circle()
    .animated(config: AnimationConfig(steps: 8, speed: .medium, variance: .medium, seed: 40))
```

### Scribble wobble

A scribble fill takes the same seeded wobble. Medium variance, five steps, played at 3 fps.

![Scribble wobble](images/animation/scribble-wobble.gif)

```swift
RoughView()
    .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
    .fillStyle(.scribble)
    .scribble(origin: 20, tightness: 12, curvature: 12)
    .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
    .strokeWidth(2)
    .seed(46)
    .circle()
    .animated(config: AnimationConfig(steps: 5, speed: .medium, variance: .medium, seed: 46))
```
