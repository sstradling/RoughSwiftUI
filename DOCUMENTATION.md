# RoughSwiftUI API Documentation

> **Optimized for coding agents and LLMs.** This document provides structured, comprehensive API reference for the RoughSwiftUI package.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Types](#core-types)
3. [RoughView API](#roughview-api)
4. [Drawable Types](#drawable-types)
5. [Options Reference](#options-reference)
6. [Fill Styles](#fill-styles)
7. [Text Rendering](#text-rendering)
8. [Brush Profiles](#brush-profiles)
9. [Animation](#animation)
10. [Renderers](#renderers)
11. [Engine & Caching](#engine--caching)
12. [Common Patterns](#common-patterns)
13. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Minimal Example

```swift
import SwiftUI
import RoughSwiftUI

struct ContentView: View {
    var body: some View {
        RoughView()
            .fill(.yellow)
            .stroke(.black)
            .strokeWidth(2)
            .rectangle()
            .frame(width: 200, height: 100)
    }
}
```

### Import Statement

```swift
import RoughSwiftUI
```

### Platform Requirements

- **iOS 17.0+**
- **tvOS 17.0+**
- Swift 5.9+

---

## Core Types

### Type Summary Table

| Type | Purpose | Usage |
|------|---------|-------|
| `RoughView` | Main SwiftUI view for rendering rough shapes | Builder pattern with modifiers |
| `Options` | Rendering configuration | Set via modifiers or directly |
| `Drawable` | Protocol for all drawable shapes | Passed to `.draw()` |
| `Point` | 2D coordinate | `Point(x: Float, y: Float)` |
| `Size` | Dimensions | `Size(width: Float, height: Float)` |
| `FillStyle` | Fill pattern enumeration | `.hachure`, `.solid`, etc. |
| `BrushProfile` | Stroke styling configuration | Calligraphic effects |
| `AnimationConfig` | Animation settings | Steps, speed, variance |

### Point

```swift
public struct Point: Equatable {
    public let x: Float
    public let y: Float
    
    public init(x: Float, y: Float)
}
```

---

## RoughView API

### Constructor

```swift
public struct RoughView: View {
    public init()
}
```

### Shape Modifiers (Auto-Sizing)

These modifiers add shapes that automatically fill the available space:

| Modifier | Parameters | Description |
|----------|------------|-------------|
| `.rectangle()` | None | Full-size rectangle |
| `.circle()` | None | Full-size circle (uses min dimension) |
| `.roundedRectangle(cornerRadius:)` | `cornerRadius: Float = 8` | Rounded rectangle |
| `.egg(tilt:)` | `tilt: Float = 0.3` | Egg/ovoid shape |

### Custom Shape Modifier

```swift
func draw(_ drawable: Drawable) -> Self
```

Pass any `Drawable` type for precise positioning.

### Color Modifiers

| Modifier | Parameter Type | Description |
|----------|----------------|-------------|
| `.fill(_ value:)` | `UIColor` or `Color` | Interior fill color |
| `.stroke(_ value:)` | `UIColor` or `Color` | Border stroke color |
| `.fillOpacity(_ value:)` | `Float` (0-100) | Fill transparency |
| `.strokeOpacity(_ value:)` | `Float` (0-100) | Stroke transparency |

### Stroke Modifiers

| Modifier | Parameter | Default | Description |
|----------|-----------|---------|-------------|
| `.strokeWidth(_ value:)` | `Float` | 1 | Line width in points |
| `.strokeCap(_ cap:)` | `BrushCap` | `.round` | Line ending style |
| `.strokeJoin(_ join:)` | `BrushJoin` | `.round` | Corner style |

### Roughness Modifiers

| Modifier | Parameter | Default | Range | Description |
|----------|-----------|---------|-------|-------------|
| `.roughness(_ value:)` | `Float` | 1 | 0+ | Hand-drawn wobble amount |
| `.bowing(_ value:)` | `Float` | 1 | 0+ | Line bending amount |
| `.maxRandomnessOffset(_ value:)` | `Float` | 2 | 0+ | Maximum random offset |

### Fill Style Modifiers

| Modifier | Parameter | Description |
|----------|-----------|-------------|
| `.fillStyle(_ value:)` | `FillStyle` | Pattern type (hachure, solid, etc.) |
| `.fillWeight(_ value:)` | `Float` | Fill line thickness |
| `.fillAngle(_ value:)` | `Float` (0-360) | Fill line angle in degrees |
| `.fillSpacing(_ value:)` | `Float` (0.5-100) | Gap between fill lines |
| `.fillSpacingPattern(_ pattern:)` | `[Float]` | Variable spacing for gradients |

### Curve Modifiers

| Modifier | Parameter | Default | Description |
|----------|-----------|---------|-------------|
| `.curveTightness(_ value:)` | `Float` | 0 | Curve tension |
| `.curveStepCount(_ value:)` | `Float` | 9 | Curve smoothness |

### Dash Modifiers

| Modifier | Parameter | Description |
|----------|-----------|-------------|
| `.dashOffset(_ value:)` | `Float` | Dash pattern offset |
| `.dashGap(_ value:)` | `Float` | Gap between dashes |
| `.zigzagOffset(_ value:)` | `Float` | Zigzag pattern offset |

### Text Modifiers

```swift
// Basic text (auto-centered)
func text(
    _ string: String,
    font: UIFont,
    horizontalAlignment: RoughTextHorizontalAlignment = .center,
    verticalAlignment: RoughTextVerticalAlignment = .center,
    offsetX: CGFloat = 0,
    offsetY: CGFloat = 0
) -> Self

// Attributed text
func text(
    attributedString: NSAttributedString,
    horizontalAlignment: RoughTextHorizontalAlignment = .center,
    verticalAlignment: RoughTextVerticalAlignment = .center,
    offsetX: CGFloat = 0,
    offsetY: CGFloat = 0
) -> Self

// Named font
func text(
    _ string: String,
    fontName: String,
    fontSize: CGFloat,
    horizontalAlignment: RoughTextHorizontalAlignment = .center,
    verticalAlignment: RoughTextVerticalAlignment = .center,
    offsetX: CGFloat = 0,
    offsetY: CGFloat = 0
) -> Self
```

### SVG Modifiers

| Modifier | Parameter | Description |
|----------|-----------|-------------|
| `.svgStrokeWidth(_ value:)` | `Float` | Override stroke width for SVG |
| `.svgFillWeight(_ value:)` | `Float` | Override fill weight for SVG |
| `.svgFillStrokeAlignment(_ value:)` | `SVGFillStrokeAlignment` | Fill stroke position |

### Scribble Fill Modifiers

```swift
// Individual parameters
func scribbleOrigin(_ degrees: Float) -> Self
func scribbleTightness(_ count: Int) -> Self
func scribbleCurvature(_ percent: Float) -> Self
func scribbleUseBrushStroke(_ enabled: Bool) -> Self
func scribbleTightnessPattern(_ pattern: [Int]) -> Self

// Combined configuration
func scribble(
    origin: Float = 0,
    tightness: Int = 10,
    curvature: Float = 0,
    useBrushStroke: Bool = false
) -> Self

func scribble(
    origin: Float = 0,
    tightnessPattern: [Int],
    curvature: Float = 0,
    useBrushStroke: Bool = false
) -> Self
```

### Brush Profile Modifiers

```swift
func brushProfile(_ profile: BrushProfile) -> Self

func brushTip(
    roundness: CGFloat = 1.0,
    angle: CGFloat = 0,
    directionSensitive: Bool = true
) -> Self

func brushTip(_ tip: BrushTip) -> Self
func thicknessProfile(_ profile: ThicknessProfile) -> Self
```

### Animation Modifier

```swift
func animated(config: AnimationConfig = .default) -> AnimatedRoughView

func animated(
    steps: Int = 4,
    speed: AnimationSpeed = .medium,
    variance: AnimationVariance = .medium
) -> AnimatedRoughView
```

---

## Drawable Types

### Drawable Protocol

```swift
public protocol Drawable {
    var method: String { get }
    var arguments: [Any] { get }
}
```

### Line

```swift
public struct Line: Drawable {
    public init(from: Point, to: Point)
}
```

**Example:**
```swift
RoughView()
    .stroke(.black)
    .draw(Line(from: Point(x: 10, y: 10), to: Point(x: 190, y: 90)))
```

### Rectangle

```swift
public struct Rectangle: Drawable {
    public init(x: Float, y: Float, width: Float, height: Float)
}
```

**Example:**
```swift
RoughView()
    .fill(.yellow)
    .draw(Rectangle(x: 10, y: 10, width: 180, height: 80))
```

### RoundedRectangle

```swift
public struct RoundedRectangle: Drawable {
    public init(x: Float, y: Float, width: Float, height: Float, cornerRadius: Float)
}
```

### Circle

```swift
public struct Circle: Drawable {
    public init(x: Float, y: Float, diameter: Float)
}
```

**Note:** `x`, `y` is the center point.

### Ellipse

```swift
public struct Ellipse: Drawable {
    public init(x: Float, y: Float, width: Float, height: Float)
}
```

**Note:** `x`, `y` is the center point.

### EggShape

```swift
public struct EggShape: Drawable {
    public init(x: Float, y: Float, width: Float, height: Float, tilt: Float = 0.3)
}
```

**Tilt values:**
- Positive (0.3 default): Narrower top, wider bottom
- Zero: Symmetric ellipse
- Negative: Narrower bottom, wider top

### Arc

```swift
public struct Arc: Drawable {
    public init(
        x: Float,           // Center X
        y: Float,           // Center Y
        width: Float,       // Full width
        height: Float,      // Full height
        start: Float,       // Start angle in radians
        stop: Float,        // End angle in radians
        closed: Bool = false
    )
}
```

### LinearPath

```swift
public struct LinearPath: Drawable {
    public init(points: [Point])
}
```

### Curve

```swift
public struct Curve: Drawable {
    public init(points: [Point])
}
```

### Polygon

```swift
public struct Polygon: Drawable {
    public init(points: [Point])
}
```

### Path (SVG)

```swift
public struct Path: Drawable {
    public init(d: String)  // SVG path data string
}
```

**Example:**
```swift
let svgPath = "M10 10 L100 10 L100 100 L10 100 Z"
RoughView()
    .fill(.red)
    .draw(Path(d: svgPath))
```

### Text

```swift
public struct Text: Drawable {
    public init(_ string: String, font: UIFont)
    public init(attributedString: NSAttributedString)
    public init(svgPath: String)
}
```

**Note:** For auto-centering, use `.text()` modifier instead of `Text` drawable directly.

---

## Options Reference

### Options Struct

```swift
public struct Options: Equatable, Hashable {
    // Roughness
    public var maxRandomnessOffset: Float = 2
    public var roughness: Float = 1
    public var bowing: Float = 1
    
    // Stroke
    public var stroke: UIColor = .black
    public var strokeWidth: Float = 1
    public var strokeOpacity: Float = 1.0  // 0.0 - 1.0
    
    // Fill
    public var fill: UIColor = .clear
    public var fillOpacity: Float = 1.0    // 0.0 - 1.0
    public var fillStyle: FillStyle = .hachure
    public var fillWeight: Float = -1      // -1 = auto (strokeWidth/2)
    public var fillAngle: Float = 45       // degrees
    public var fillSpacing: Float = 4.0    // multiplier of fillWeight
    public var fillSpacingPattern: [Float]? = nil
    
    // Curves
    public var curveTightness: Float = 0
    public var curveStepCount: Float = 9
    
    // Dashes
    public var dashOffset: Float = -1
    public var dashGap: Float = -1
    public var zigzagOffset: Float = -1
    
    // Scribble
    public var scribbleOrigin: Float = 0
    public var scribbleTightness: Int = 10
    public var scribbleCurvature: Float = 0
    public var scribbleUseBrushStroke: Bool = false
    public var scribbleTightnessPattern: [Int]? = nil
    
    // SVG
    public var svgStrokeWidth: Float? = nil
    public var svgFillWeight: Float? = nil
    public var svgFillStrokeAlignment: SVGFillStrokeAlignment = .center
    
    // Brush
    public var brushProfile: BrushProfile = .default
}
```

---

## Fill Styles

### FillStyle Enum

```swift
public enum FillStyle: String {
    case hachure        // Diagonal lines (default)
    case solid          // Solid fill
    case zigzag         // Zigzag lines
    case crossHatch     // Cross-hatched lines
    case dots           // Dot pattern
    case sunBurst       // Radial lines from center
    case starBurst      // Star burst pattern
    case dashed         // Dashed lines
    case zigzagLine     // Single zigzag line
    case scribble       // Continuous zig-zag traversal
}
```

### Fill Style Examples

```swift
// Hachure (default diagonal lines)
RoughView().fill(.blue).fillStyle(.hachure).circle()

// Solid fill
RoughView().fill(.red).fillStyle(.solid).circle()

// Cross-hatch
RoughView().fill(.green).fillStyle(.crossHatch).rectangle()

// Dots
RoughView().fill(.purple).fillStyle(.dots).circle()

// Scribble (continuous zig-zag)
RoughView().fill(.orange).fillStyle(.scribble).scribbleTightness(15).circle()
```

---

## Text Rendering

### Text Alignment Enums

```swift
public enum RoughTextHorizontalAlignment: Sendable {
    case leading   // Left edge
    case center    // Centered (default)
    case trailing  // Right edge
}

public enum RoughTextVerticalAlignment: Sendable {
    case top       // Top edge
    case center    // Centered (default)
    case bottom    // Bottom edge
}
```

### Text Examples

```swift
// Centered text (default)
RoughView()
    .fill(.orange)
    .stroke(.black)
    .text("Hello!", font: .systemFont(ofSize: 48, weight: .bold))
    .frame(width: 300, height: 100)

// Top-left aligned
RoughView()
    .fill(.blue)
    .text("Top Left", font: .systemFont(ofSize: 32),
          horizontalAlignment: .leading,
          verticalAlignment: .top)
    .frame(width: 200, height: 100)

// Centered with offset
RoughView()
    .fill(.green)
    .text("Offset", font: .systemFont(ofSize: 32),
          offsetX: 10, offsetY: -5)
    .frame(width: 200, height: 100)
```

---

## Brush Profiles

### BrushTip

```swift
public struct BrushTip: Equatable, Hashable, Sendable {
    public var roundness: CGFloat  // 0.01 - 1.0 (1.0 = circle)
    public var angle: CGFloat      // Rotation in radians
    public var directionSensitive: Bool
    
    public init(
        roundness: CGFloat = 1.0,
        angle: CGFloat = 0,
        directionSensitive: Bool = true
    )
    
    // Presets
    public static let circular      // Uniform width
    public static let calligraphic  // 45° flat tip
    public static let flat          // Horizontal flat tip
}
```

### ThicknessProfile

```swift
public enum ThicknessProfile: Equatable, Hashable, Sendable {
    case uniform
    case taperIn(start: CGFloat)
    case taperOut(end: CGFloat)
    case taperBoth(start: CGFloat, end: CGFloat)
    case pressure([CGFloat])
    case custom([CGFloat])
    
    // Presets
    public static let naturalPen    // taperBoth(start: 0.15, end: 0.15)
    public static let brushStart    // taperIn(start: 0.25)
    public static let brushEnd      // taperOut(end: 0.25)
    public static let penPressure   // Simulated pressure curve
}
```

### BrushCap

```swift
public enum BrushCap: Equatable, Hashable, Sendable {
    case butt    // Square end at endpoint
    case round   // Rounded end (default)
    case square  // Square end past endpoint
}
```

### BrushJoin

```swift
public enum BrushJoin: Equatable, Hashable, Sendable {
    case miter   // Sharp corner
    case round   // Rounded corner (default)
    case bevel   // Flat corner
}
```

### BrushProfile

```swift
public struct BrushProfile: Equatable, Hashable, Sendable {
    public var tip: BrushTip
    public var thicknessProfile: ThicknessProfile
    public var cap: BrushCap
    public var join: BrushJoin
    
    // Presets
    public static let `default`     // Circular, uniform
    public static let calligraphic  // Flat tip, tapered
    public static let marker        // Flat tip, uniform, butt caps
    public static let pen           // Pressure simulation
}
```

### Brush Examples

```swift
// Calligraphic effect
RoughView()
    .stroke(.black)
    .strokeWidth(4)
    .brushTip(roundness: 0.3, angle: .pi / 4, directionSensitive: true)
    .draw(Line(from: Point(x: 10, y: 10), to: Point(x: 190, y: 190)))

// Tapered stroke
RoughView()
    .stroke(.blue)
    .thicknessProfile(.naturalPen)
    .circle()

// Using preset profile
RoughView()
    .stroke(.green)
    .brushProfile(.calligraphic)
    .rectangle()
```

---

## Animation

### AnimationSpeed

```swift
public enum AnimationSpeed: Sendable {
    case slow    // 600ms between steps
    case medium  // 300ms between steps
    case fast    // 100ms between steps
}
```

### AnimationVariance

```swift
public enum AnimationVariance: Sendable {
    case veryLow  // 0.5% variation
    case low      // 1% variation
    case medium   // 5% variation
    case high     // 10% variation
}
```

### AnimationConfig

```swift
public struct AnimationConfig: Sendable {
    public let steps: Int
    public let speed: AnimationSpeed
    public let variance: AnimationVariance
    
    public init(
        steps: Int = 4,          // Minimum 2
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium
    )
    
    public static let `default`
}
```

### AnimatedRoughView

```swift
public struct AnimatedRoughView: View {
    public init(
        config: AnimationConfig = .default,
        @ViewBuilder content: () -> RoughView
    )
    
    public init(
        config: AnimationConfig = .default,
        roughView: RoughView
    )
    
    public init(
        steps: Int = 4,
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium,
        @ViewBuilder content: () -> RoughView
    )
}
```

### Animation Examples

```swift
// Using .animated() modifier
RoughView()
    .fill(.red)
    .fillStyle(.hachure)
    .circle()
    .animated()
    .frame(width: 100, height: 100)

// Custom animation
RoughView()
    .fill(.green)
    .circle()
    .animated(steps: 6, speed: .slow, variance: .high)
    .frame(width: 100, height: 100)

// Using AnimatedRoughView directly
AnimatedRoughView(
    config: AnimationConfig(steps: 8, speed: .medium, variance: .low)
) {
    RoughView()
        .fill(.blue)
        .fillStyle(.crossHatch)
        .rectangle()
}
.frame(width: 150, height: 100)
```

---

## Renderers

### Overview

`RoughSwiftUI` ships a single required renderer (`SwiftUIRenderer`, the
default used by `RoughView` and `RoughText`) and an optional Metal-backed
renderer in a separate library product (`RoughSwiftUIMetal`). Both conform
to the `RoughRenderer` protocol so callers can substitute them in places
that take a renderer reference.

```swift
public protocol RoughRenderer {
    func commands(
        for drawing: Drawing,
        options: Options,
        in size: CGSize
    ) -> [RoughRenderCommand]

    func render(
        drawing: Drawing,
        options: Options,
        in context: inout GraphicsContext,
        size: CGSize
    )
}
```

### SwiftUIRenderer (default)

The default renderer targets `SwiftUI.Canvas`. It integrates fully with
SwiftUI compositing (`.opacity`, `.blendMode`, `.mask`, `ImageRenderer`,
animations, accessibility) and is used automatically by `RoughView`. You
do not need to construct it directly except for advanced custom-canvas
use cases (see *Advanced Usage* in the README).

### MetalRoughRenderer (opt-in)

A separate library product exposes `MetalRoughRenderer` and a
`RoughView.metalAccelerated()` modifier. Importing the product is opt-in:

```swift
import RoughSwiftUI
import RoughSwiftUIMetal

RoughView()
    .stroke(.systemTeal)
    .strokeWidth(4)
    .circle()
    .metalAccelerated()           // wraps in MetalRoughView
    .frame(width: 200, height: 200)
```

`MetalRoughView` internally renders fills via SwiftUI `Canvas` and stroke
ribbons via a Metal fragment shader. For default appearances the visible
output matches the SwiftUI renderer; the value of opting in comes from
per-pixel along-path effects (gradient color, opacity envelopes,
procedural grain) that are layered on top of the same triangle-strip mesh
in future work.

#### Tradeoffs

- **Loss of SwiftUI compositing on the stroke layer.** The Metal layer is
  hosted via `MTKView`/`UIViewRepresentable` and is opaque to SwiftUI
  modifiers applied above the call to `.metalAccelerated()`. Apply
  `.opacity`, `.blur`, `.mask`, etc. *to children of the wrapped `RoughView`*
  for predictable behavior, or omit `.metalAccelerated()` entirely for full
  fidelity.
- **`ImageRenderer` snapshot fidelity.** SwiftUI's `ImageRenderer` may not
  capture the Metal stroke layer on all platforms. Prefer
  `UIGraphicsImageRenderer` for snapshotting Metal-accelerated views.
- **No GPU device, no GPU output.** Devices without Metal silently fall
  back to fills only (strokes do not render). This is rare on real iOS
  hardware but can occur in some CI simulator configurations.
- **Two renderers, two test surfaces.** Behavior is exercised by
  `RoughSwiftUITests` (SwiftUI) and `RoughSwiftUIMetalTests` (Metal mesh
  builder + renderer split). The Metal pipeline state itself requires a
  GPU device and is exercised only on hosts that have one.

#### When to opt in

| You want… | Use |
|---|---|
| Default look, full SwiftUI integration | `RoughView` (no opt-in) |
| Per-pixel along-path color/opacity gradients on strokes | `.metalAccelerated()` |
| Hundreds of stroked shapes per frame (charts, dense diagrams) | `.metalAccelerated()` |
| Snapshot via `ImageRenderer`, accessibility-first content | `RoughView` (no opt-in) |

### Variable stroke appearance

The Metal renderer reads three optional fields on `Options` to drive its
gradient/opacity/edge-softness fragment shader. All three default to
"unset" so opting into Metal without configuring them produces a flat
solid stroke that matches the SwiftUI renderer pixel-for-pixel.

| Option | Type | Effect |
|---|---|---|
| `strokeColorAlongPath` | `ColorAlongPath?` | Linear color gradient or solid color along each stroke. Overrides `stroke`. |
| `strokeOpacityAlongPath` | `OpacityAlongPath?` | Linear taper or constant alpha multiplier along each stroke. Multiplies with `stroke.alpha`. |
| `strokeEdgeSoftness` | `Float` (0…1) | Cross-stroke alpha falloff toward the boundary. |
| `brushTexture` | `BrushTexture` | Procedural texture style: `.smooth` (default), `.pencil`, `.chalk`, `.ink`, or `.watercolor`. |

#### Modifiers

```swift
// Convenience: gradient stroke from red to blue
RoughView()
    .strokeGradient(from: .red, to: .blue)
    .strokeWidth(6)
    .circle()
    .metalAccelerated()

// Convenience: taper opacity from invisible to fully opaque
RoughView()
    .strokeOpacityTaper(from: 0, to: 1)
    .stroke(.black)
    .strokeWidth(4)
    .rectangle()
    .metalAccelerated()

// Soft ink-like edges
RoughView()
    .stroke(.darkGray)
    .strokeWidth(8)
    .strokeEdgeSoftness(0.6)
    .ellipse(...)
    .metalAccelerated()

// Pencil grain
RoughView()
    .stroke(.black)
    .strokeWidth(4)
    .pencilTexture()                      // grain = 1.5, density = 0.7
    .circle()
    .metalAccelerated()

// Chalk (chunkier grain, edge drop-out)
RoughView()
    .stroke(.white)
    .strokeWidth(6)
    .chalkTexture(grain: 1.0, density: 0.5)
    .roundedRectangle(cornerRadius: 12)
    .metalAccelerated()

// Ink bleed (smooth across-stroke falloff, no gaps)
RoughView()
    .stroke(.darkGray)
    .strokeWidth(8)
    .inkTexture(bleed: 0.8)
    .ellipse(...)
    .metalAccelerated()

// Watercolor (edge-darkened wash with uneven alpha)
RoughView()
    .stroke(.blue)
    .strokeWidth(10)
    .watercolorTexture(edgeDarkness: 0.5, bleed: 0.4)
    .rectangle()
    .metalAccelerated()
```

#### Reference

```swift
public struct ColorAlongPath: Equatable, Hashable {
    public enum Kind: Equatable, Hashable, Sendable { case solid, gradient }
    public let kind: Kind
    public let startColor: UIColor
    public let endColor: UIColor
    public static func solid(_ color: UIColor) -> ColorAlongPath
    public static func gradient(from start: UIColor, to end: UIColor) -> ColorAlongPath
}

public enum OpacityAlongPath: Equatable, Hashable, Sendable {
    case constant(Float)
    case taper(start: Float, end: Float)
}

public typealias StrokeEdgeSoftness = Float

public enum BrushTexture: Equatable, Hashable, Sendable {
    case smooth
    case pencil(grain: Float = 1.5, density: Float = 0.7)
    case chalk(grain: Float = 0.8, density: Float = 0.55)
    case ink(bleed: Float = 0.6)
    case watercolor(edgeDarkness: Float = 0.5, bleed: Float = 0.4)

    public static let pencilDefault: BrushTexture
    public static let chalkDefault: BrushTexture
    public static let inkDefault: BrushTexture
    public static let watercolorDefault: BrushTexture
    public var isSmooth: Bool { get }
}
```

All four fields are part of `Options.cacheHash`, so toggling them at
runtime correctly invalidates cached drawings.

#### Renderer support matrix

| Field | SwiftUI renderer | Metal renderer |
|---|---|---|
| `strokeColorAlongPath` | Per-segment stroke commands (16 segments per stroke by default) | Per-pixel fragment-shader interpolation |
| `strokeOpacityAlongPath` | Per-segment alpha modulation | Per-pixel alpha modulation |
| `strokeEdgeSoftness` | **Ignored** (SwiftUI `Canvas` has no per-pixel control) | Per-pixel `smoothstep` falloff |
| `brushTexture` | **Ignored** (no procedural noise primitive in `Canvas`) | Per-pixel procedural texture |

The first two fields reach feature parity between renderers — opting
into Metal is no longer required to get gradient or tapered strokes;
the SwiftUI renderer's segmented-stroke emission produces the same
visible result at a slightly higher CPU cost (one `context.stroke` call
per segment vs. one quad). The Metal-only fields require shader-level
control that SwiftUI `Canvas` does not expose.

#### Texture parameter reference

| Texture | Parameter | Range | Default | Effect |
|---|---|---|---|---|
| `.pencil` | `grain` | typically 0.5…3 | `1.5` | Spatial frequency of the noise lattice; higher = finer grain. |
| `.pencil` | `density` | `[0, 1]` | `0.7` | Fraction of pixels rendered; lower = sparser. |
| `.chalk` | `grain` | typically 0.5…2 | `0.8` | Coarser noise lattice than pencil. |
| `.chalk` | `density` | `[0, 1]` | `0.55` | Fraction of pixels rendered; chalk has extra edge drop-out. |
| `.ink` | `bleed` | `[0, 1]` | `0.6` | Width of soft alpha falloff toward the stroke boundary; no gaps. |
| `.watercolor` | `edgeDarkness` | `[0, 1]` | `0.5` | How much the boundary is darkened relative to the interior. |
| `.watercolor` | `bleed` | `[0, 1]` | `0.4` | Width of the soft falloff inside the boundary. |

#### SwiftUI renderer behavior

The SwiftUI renderer honors `strokeColorAlongPath` and
`strokeOpacityAlongPath` directly via per-segment stroke emission (see
the support matrix above). It does **not** honor `strokeEdgeSoftness`
or `brushTexture`; for those, opt into the Metal renderer.

### RibbonMesh

The Metal renderer's intermediate representation. Each stroke is a
triangle-strip mesh with per-vertex `(s, t)` parameters where `s ∈ [0, 1]`
runs along the stroke and `t ∈ [-1, +1]` runs across it. This is the
data structure consumed by `RibbonShaders.metal`.

```swift
public struct RibbonVertex {
    public var position: SIMD2<Float>     // canvas points
    public var parametric: SIMD2<Float>   // (s, t)
}

public struct RibbonMesh {
    public var vertices: [RibbonVertex]
    public let isClosed: Bool
    public let totalLength: CGFloat
}
```

Build one from the engine's operations:

```swift
import RoughSwiftUIMetal

if let mesh = RibbonMeshBuilder.build(
    operations: operationSet.operations,
    baseWidth: 4
) {
    // Hand off to a custom Metal pass
}
```

---

## Engine & Caching

### Engine

```swift
@MainActor
public final class Engine {
    public static let shared: Engine
    
    public init()
    
    // Get/create generator for size
    public func generator(size: CGSize) -> NativeGenerator
    
    // Generate drawing with caching
    public func generate(
        drawable: Drawable,
        options: Options,
        size: CGSize
    ) -> Drawing?
    
    // Clear all caches
    public func clearCaches()
    
    // Cache statistics
    public var cacheStats: (generators: Int, drawings: Int, hitRate: Double)
}
```

### Cache Management

```swift
// Clear caches when needed
Engine.shared.clearCaches()

// Monitor cache performance
let stats = Engine.shared.cacheStats
print("Generators: \(stats.generators)")
print("Drawings: \(stats.drawings)")
print("Hit rate: \(String(format: "%.1f%%", stats.hitRate * 100))")

// Clear on memory warning
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    Engine.shared.clearCaches()
}
```

---

## Common Patterns

### Pattern 1: Simple Centered Shape

```swift
RoughView()
    .fill(.yellow)
    .stroke(.black)
    .strokeWidth(2)
    .rectangle()
    .frame(width: 200, height: 100)
```

### Pattern 2: Styled Button Background

```swift
ZStack {
    RoughView()
        .fill(.blue)
        .stroke(.darkGray)
        .strokeWidth(2)
        .roundedRectangle(cornerRadius: 12)
    
    Text("Button")
        .foregroundColor(.white)
}
.frame(width: 120, height: 44)
```

### Pattern 3: Hand-Drawn Text Button

```swift
ZStack {
    RoughView()
        .fill(.white)
        .stroke(.black)
        .strokeWidth(2.5)
        .roundedRectangle(cornerRadius: 8)
    
    RoughView()
        .fill(.orange)
        .stroke(.black)
        .strokeWidth(2)
        .text("CLICK!", font: .systemFont(ofSize: 24, weight: .heavy))
}
.frame(width: 150, height: 60)
```

### Pattern 4: Custom SVG Shape

```swift
let heartPath = "M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"

RoughView()
    .fill(.red)
    .stroke(.darkRed)
    .fillStyle(.solid)
    .draw(Path(d: heartPath))
    .frame(width: 100, height: 100)
```

### Pattern 5: Animated Loading Indicator

```swift
RoughView()
    .fill(.blue)
    .fillStyle(.hachure)
    .circle()
    .animated(steps: 8, speed: .medium, variance: .medium)
    .frame(width: 60, height: 60)
```

### Pattern 6: Gradient Fill Effect

```swift
RoughView()
    .fill(.purple)
    .fillStyle(.hachure)
    .fillSpacing(2)
    .fillSpacingPattern([1, 1, 2, 3, 5, 8, 13])  // Fibonacci
    .circle()
    .frame(width: 150, height: 150)
```

### Pattern 7: Scribble Fill with Variable Density

```swift
RoughView()
    .fill(.green)
    .fillStyle(.scribble)
    .scribble(
        origin: 45,
        tightnessPattern: [5, 15, 30, 15, 5],  // Sparse-dense-sparse
        curvature: 20
    )
    .rectangle()
    .frame(width: 200, height: 150)
```

### Pattern 8: Calligraphic Stroke

```swift
RoughView()
    .stroke(.black)
    .strokeWidth(6)
    .brushProfile(.calligraphic)
    .draw(Curve(points: [
        Point(x: 10, y: 50),
        Point(x: 50, y: 10),
        Point(x: 100, y: 90),
        Point(x: 150, y: 50)
    ]))
    .frame(width: 160, height: 100)
```

---

## Troubleshooting

### Issue: Shape Not Visible

**Causes & Solutions:**
1. Missing `.frame()` - Add explicit frame size
2. Clear fill/stroke colors - Set `.fill()` or `.stroke()` to visible colors
3. Zero dimensions - Ensure width and height > 0

### Issue: Text Not Centered

**Solution:** Use the `.text()` modifier (not `Text` drawable):
```swift
// ✅ Correct - auto-centered
RoughView().text("Hello", font: .systemFont(ofSize: 32))

// ❌ Wrong - positioned at origin
RoughView().draw(Text("Hello", font: .systemFont(ofSize: 32)))
```

### Issue: Animation Not Smooth

**Solutions:**
1. Reduce animation steps (4-6 is usually optimal)
2. Use `.veryLow` or `.low` variance
3. Simplify shapes (fewer fill lines)

### Issue: Memory Usage High

**Solution:** Clear caches periodically:
```swift
Engine.shared.clearCaches()
```

### Issue: Fill Pattern Too Dense/Sparse

**Adjust:**
- `.fillSpacing()` - Higher = sparser
- `.fillWeight()` - Higher = thicker lines
- `.fillAngle()` - Change line direction

### Issue: SVG Path Not Rendering

**Check:**
1. Valid SVG path syntax
2. Path has content (not just whitespace)
3. Use `.draw(Path(d: svgString))` not `.draw(Path(d: ""))`

---

## Version Information

- **Package:** RoughSwiftUI
- **Minimum iOS:** 17.0
- **Swift:** 5.9+
- **Rendering:** Native Swift (no JavaScript bridge)

---

## License

MIT License - See LICENSE file for details.

