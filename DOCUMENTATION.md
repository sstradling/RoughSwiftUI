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
10. [Engine & Caching](#engine--caching)
11. [Common Patterns](#common-patterns)
12. [Troubleshooting](#troubleshooting)

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

