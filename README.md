# RoughSwiftUI

![](Screenshots/s.png)

![](Screenshots/s1.png)

## Description

RoughSwiftUI allows you to easily create shapes in a hand-drawn, sketchy, comic style in SwiftUI. This library provides a native Swift implementation of rough.js-style rendering, optimized for iOS and tvOS.

- [x] Support iOS, tvOS
- [x] Support all shapes: line, rectangle, circle, ellipse, linear path, arc, curve, polygon, SVG path, text
- [x] **Native Swift rendering engine** - no JavaScript bridge required
- [x] Native SwiftUI rendering via `Canvas`
- [x] Easy customizations with Options
- [x] Easy composable APIs
- [x] Convenient draw functions
- [x] Platform independent APIs which can easily support new platforms
- [x] Test coverage
- [x] Immutable and type safe data structure
- [x] SVG path scaling and alignment
- [x] Animated strokes and fills with configurable variations
- [x] Custom brush profiles for calligraphic effects
- [x] Text rendering with rough styling
- [x] Scribble fill pattern for continuous zig-zag fills
- [ ] SVG elliptical arc

## Basic

The easiest way to use RoughSwiftUI is via `RoughView`, a SwiftUI `View` that renders hand-drawn primitives using SwiftUI `Canvas` under the hood.

Here's how to draw a green rectangle:

![](Screenshots/green_rectangle.png)

```swift
RoughView()
    .fill(.yellow)
    .fillStyle(.hachure)
    .fillAngle(45)
    .fillSpacing(4)
    .fillWeight(1)
    .stroke(.systemTeal)
    .strokeWidth(2)
    .curveTightness(0)
    .curveStepCount(9)
    .rectangle()
```

Because `RoughView` is a normal SwiftUI view, you can compose it with other SwiftUI views, apply transforms (scale, rotate, offset), and animate it using standard SwiftUI modifiers.

## Options

`Options` is used to customize shape rendering. It is an immutable struct applied to one shape at a time. The following properties are configurable:

- maxRandomnessOffset
- roughness
- bowing
- fill
- stroke
- strokeWidth
- strokeOpacity
- fillOpacity
- curveTightness
- curveStepCount
- fillStyle
- fillWeight
- fillAngle
- fillSpacing
- fillSpacingPattern
- dashOffset
- dashGap
- zigzagOffset

### SVG-Specific Options

For SVG paths, additional options are available to fine-tune rendering:

- `svgStrokeWidth` - Override stroke width specifically for SVG paths
- `svgFillWeight` - Override fill weight specifically for SVG paths
- `svgFillStrokeAlignment` - Control how fill strokes align to the path

### Scribble Fill Options

For the scribble fill style, additional parameters control the continuous zig-zag pattern:

- `scribbleOrigin` - Starting angle in degrees (0-360)
- `scribbleTightness` - Number of zig-zags (1-100)
- `scribbleCurvature` - Vertex curvature (0-50)
- `scribbleUseBrushStroke` - Enable brush stroke rendering
- `scribbleTightnessPattern` - Variable density pattern array

## Shapes

RoughSwiftUI supports all primitive shapes, including SVG paths and text:

- line
- rectangle
- roundedRectangle
- ellipse
- circle
- egg
- linearPath
- arc
- curve
- polygon
- path (SVG)
- text

## Fill Styles

Most of the time, we use `fill` for solid fill color inside shape, `stroke` for shape border, and `fillStyle` for sketchy fill style.

Available fill styles:

- crossHatch
- dashed
- dots
- hachure (default)
- solid
- starBurst
- zigzag
- zigzagLine
- **scribble** (continuous zig-zag traversing the shape)

### Fill Angle

Use `fillAngle` to rotate the direction of fill lines (0-360 degrees):

```swift
RoughView()
    .fill(.blue)
    .fillStyle(.hachure)
    .fillAngle(0)    // Horizontal lines
    .circle()

RoughView()
    .fill(.green)
    .fillStyle(.hachure)
    .fillAngle(45)   // Diagonal lines (default)
    .circle()

RoughView()
    .fill(.red)
    .fillStyle(.hachure)
    .fillAngle(90)   // Vertical lines
    .circle()
```

### Fill Spacing

Use `fillSpacing` to control the gap between fill lines as a factor of the fill line weight (0.5x to 100x):

```swift
RoughView()
    .fill(.blue)
    .fillStyle(.hachure)
    .fillSpacing(1)   // Dense fill (1x line weight)
    .circle()

RoughView()
    .fill(.green)
    .fillStyle(.hachure)
    .fillSpacing(4)   // Normal fill (4x, default)
    .circle()

RoughView()
    .fill(.red)
    .fillStyle(.hachure)
    .fillSpacing(10)  // Sparse fill (10x line weight)
    .circle()
```

### Fill Spacing Pattern (Gradients)

Use `fillSpacingPattern` to create gradient-like effects with varying line density:

```swift
// Fibonacci-style gradient - lines get progressively sparser
RoughView()
    .fill(.purple)
    .fillStyle(.hachure)
    .fillSpacing(2)
    .fillSpacingPattern([1, 1, 2, 3, 5, 8, 13])
    .circle()

// Dense-to-sparse-to-dense pattern
RoughView()
    .fill(.orange)
    .fillStyle(.hachure)
    .fillSpacing(1)
    .fillSpacingPattern([1, 2, 4, 8, 4, 2, 1])
    .rectangle()
```

### Scribble Fill

The scribble fill style creates a continuous zig-zag line that traverses from one edge of a shape to the opposite edge:

```swift
// Basic scribble fill
RoughView()
    .fill(.purple)
    .fillStyle(.scribble)
    .scribbleTightness(15)
    .circle()

// Curved scribble with brush strokes
RoughView()
    .fill(.blue)
    .fillStyle(.scribble)
    .scribble(
        origin: 45,           // Start from 45° angle
        tightness: 20,        // 20 zig-zags
        curvature: 30,        // Curved vertices
        useBrushStroke: true  // Variable-width strokes
    )
    .rectangle()

// Variable density scribble
RoughView()
    .fill(.green)
    .fillStyle(.scribble)
    .scribble(
        origin: 0,
        tightnessPattern: [5, 15, 30, 15, 5],  // Sparse-dense-sparse
        curvature: 10
    )
    .circle()
```

Here's how to draw circles in different fill styles. The default fill style is hachure:

![](Screenshots/circles.png)

```swift
struct StylesView: View {
    var body: some View {
        LazyVGrid(columns: [.init(), .init(), .init()], spacing: 12) {
            RoughView()
                .fill(.red)
                .fillStyle(.crossHatch)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(.green)
                .fillStyle(.dashed)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(.purple)
                .fillStyle(.dots)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(.cyan)
                .fillStyle(.hachure)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(.orange)
                .fillStyle(.solid)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(.gray)
                .fillStyle(.starBurst)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(.yellow)
                .fillStyle(.zigzag)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(.systemTeal)
                .fillStyle(.zigzagLine)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(.pink)
                .fillStyle(.scribble)
                .scribbleTightness(12)
                .circle()
                .frame(width: 100, height: 100)
        }
    }
}
```

## Text Rendering

RoughSwiftUI can render text with hand-drawn styling using CoreText glyph extraction. Text is automatically centered within the view bounds by default, making it easy to create centered labels, buttons, and other UI components.

### Basic Text Rendering

```swift
// Basic text with system font (centered by default)
RoughView()
    .fill(.blue)
    .fillStyle(.hachure)
    .text("Hello", font: .systemFont(ofSize: 48, weight: .bold))
    .frame(width: 200, height: 100)

// Text with custom font
RoughView()
    .stroke(.black)
    .fill(.yellow)
    .fillStyle(.crossHatch)
    .text("Rough", fontName: "Helvetica-Bold", fontSize: 64)
    .frame(width: 300, height: 100)

// Attributed string support
let attributed = NSAttributedString(
    string: "Styled",
    attributes: [
        .font: UIFont.systemFont(ofSize: 48, weight: .heavy),
        .foregroundColor: UIColor.red
    ]
)
RoughView()
    .fill(.red)
    .text(attributedString: attributed)
    .frame(width: 300, height: 100)
```

### Text Positioning and Alignment

Text is automatically centered within the view bounds by default. You can customize the positioning using alignment and offset parameters:

```swift
// Centered text (default)
RoughView()
    .fill(.orange)
    .stroke(.black)
    .strokeWidth(2.0)
    .text("SLAP!", font: .systemFont(ofSize: 100, weight: .heavy))
    .frame(width: 300, height: 160)

// Leading (left) aligned, top aligned
RoughView()
    .fill(.blue)
    .text("Hello", font: .systemFont(ofSize: 32),
          horizontalAlignment: .leading,
          verticalAlignment: .top)
    .frame(width: 200, height: 100)

// Trailing (right) aligned, bottom aligned
RoughView()
    .fill(.green)
    .text("World", font: .systemFont(ofSize: 32),
          horizontalAlignment: .trailing,
          verticalAlignment: .bottom)
    .frame(width: 200, height: 100)

// Centered with offset adjustment
RoughView()
    .fill(.purple)
    .text("Offset", font: .systemFont(ofSize: 32),
          offsetX: 10, offsetY: -5)
    .frame(width: 200, height: 100)

// Combined alignment and offset
RoughView()
    .fill(.red)
    .text("Custom", font: .systemFont(ofSize: 28),
          horizontalAlignment: .leading,
          verticalAlignment: .top,
          offsetX: 8, offsetY: 4)
    .frame(width: 250, height: 120)
```

### Text Alignment Options

| Parameter | Options | Description |
|-----------|---------|-------------|
| `horizontalAlignment` | `.leading`, `.center` (default), `.trailing` | Horizontal position within the view |
| `verticalAlignment` | `.top`, `.center` (default), `.bottom` | Vertical position within the view |
| `offsetX` | Any `CGFloat` (default: `0`) | Additional horizontal offset in points. Positive moves right. |
| `offsetY` | Any `CGFloat` (default: `0`) | Additional vertical offset in points. Positive moves down. |

**Note:** Offsets are applied *after* alignment, allowing you to fine-tune the position relative to the aligned anchor point.

## SVG

![](Screenshots/svg.png)

SVG shapes are automatically scaled to fit within the specified frame while maintaining aspect ratio. The stroke and fill are aligned using a single transform calculated from the original SVG bounds, ensuring perfect alignment.

### Basic SVG Usage

```swift
struct SVGView: View {
    var apple: String {
        "M85 32C115 68 239 170 281 192 311 126 274 43 244 0c97 58 146 167 121 254 28 28 40 89 29 108 -25-45-67-39-93-24C176 409 24 296 0 233c68 56 170 65 226 27C165 217 56 89 36 54c42 38 116 96 161 122C159 137 108 72 85 32z"
    }

    var body: some View {
        VStack {
            RoughView()
                .stroke(.systemTeal)
                .fill(.red)
                .draw(Path(d: apple))
                .frame(width: 300, height: 300)
        }
    }
}
```

### SVG-Specific Customization

For finer control over SVG rendering, use the SVG-specific modifiers:

```swift
RoughView()
    .stroke(Color(.systemTeal))
    .fill(Color.red)
    .svgStrokeWidth(3)              // Thicker outline for SVG
    .svgFillWeight(1.5)             // Custom fill pattern line weight
    .svgFillStrokeAlignment(.inside) // Fill strokes on inside edge
    .draw(Path(d: apple))
    .frame(width: 300, height: 300)
```

### SVG Fill Stroke Alignment

The `svgFillStrokeAlignment` modifier controls how fill pattern strokes are positioned relative to the SVG path:

| Alignment | Description |
|-----------|-------------|
| `.center` | Stroke is centered on the path (default) |
| `.inside` | Stroke is applied to the inner edge of the path |
| `.outside` | Stroke is applied to the outer edge of the path |

```swift
// Fill strokes centered on path (default)
RoughView()
    .fill(.red)
    .svgFillStrokeAlignment(.center)
    .draw(Path(d: svgPath))

// Fill strokes on inside edge only
RoughView()
    .fill(.red)
    .svgFillStrokeAlignment(.inside)
    .draw(Path(d: svgPath))

// Fill strokes on outside edge only
RoughView()
    .fill(.red)
    .svgFillStrokeAlignment(.outside)
    .draw(Path(d: svgPath))
```

## Brush Profiles

RoughSwiftUI supports custom brush profiles for calligraphic and artistic stroke effects:

```swift
// Calligraphic brush with flat tip
RoughView()
    .stroke(.black)
    .strokeWidth(4)
    .brushTip(roundness: 0.3, angle: .pi / 4, directionSensitive: true)
    .draw(Line(from: Point(x: 10, y: 10), to: Point(x: 190, y: 190)))

// Tapered stroke
RoughView()
    .stroke(.blue)
    .thicknessProfile(.tapered)
    .circle()

// Custom thickness profile
RoughView()
    .stroke(.green)
    .thicknessProfile(.custom { t in
        // Bulge in the middle
        1.0 - abs(t - 0.5) * 0.5
    })
    .rectangle()
```

## Animation

RoughSwiftUI supports animated strokes and fills that introduce subtle variations on a loop, creating a "breathing" or "sketchy" animation effect that brings your hand-drawn graphics to life.

### Basic Animation

Use the `.animated()` modifier to add animation to any `RoughView`:

```swift
RoughView()
    .fill(.red)
    .fillStyle(.hachure)
    .circle()
    .animated()
    .frame(width: 100, height: 100)
```

### Animation Parameters

The animation can be customized with three parameters:

| Parameter | Options | Description |
|-----------|---------|-------------|
| `steps` | 2+ (default: 4) | Number of variation steps before looping back to initial state |
| `speed` | `.slow`, `.medium`, `.fast` | Transition speed: 600ms, 300ms, or 100ms between steps |
| `variance` | `.veryLow`, `.low`, `.medium`, `.high` | Amount of variation: 0.5%, 1%, 5%, or 10% |

```swift
// Custom animation settings
RoughView()
    .fill(.green)
    .fillStyle(.crossHatch)
    .circle()
    .animated(steps: 6, speed: .slow, variance: .high)
    .frame(width: 100, height: 100)
```

### Using AnimationConfig

For reusable animation settings, use `AnimationConfig`:

```swift
let config = AnimationConfig(
    steps: 8,
    speed: .medium,
    variance: .medium
)

RoughView()
    .fill(.blue)
    .fillStyle(.dots)
    .rectangle()
    .animated(config: config)
    .frame(width: 100, height: 100)
```

### AnimatedRoughView

You can also use `AnimatedRoughView` directly:

```swift
AnimatedRoughView(steps: 4, speed: .medium, variance: .low) {
    RoughView()
        .fill(.purple)
        .fillStyle(.zigzag)
        .circle()
}
.frame(width: 100, height: 100)
```

### Animation Speed Reference

| Speed | Duration |
|-------|----------|
| `.slow` | 600ms between steps |
| `.medium` | 300ms between steps |
| `.fast` | 100ms between steps |

### Animation Variance Reference

| Variance | Amount |
|----------|--------|
| `.veryLow` | 0.5% variation |
| `.low` | 1% variation |
| `.medium` | 5% variation |
| `.high` | 10% variation |

### Animated SVG Paths

Animation works with SVG paths too. **Important:** The `.animated()` modifier must be called **after** all RoughView configuration including `.draw()`:

```swift
RoughView()
    .stroke(Color(.systemTeal))
    .fill(Color.red)
    .svgStrokeWidth(1)
    .svgFillWeight(10)
    .svgFillStrokeAlignment(.outside)
    .draw(Path(d: svgPathString))  // Configure RoughView first
    .animated(steps: 10, speed: .medium, variance: .veryLow)  // Then animate
    .frame(width: 300, height: 300)
```

### Animation Performance

`AnimatedRoughView` uses an optimized **pre-generated frames** architecture for smooth, efficient animations:

1. **Pre-computation**: When the view size changes, all animation frames are computed upfront in a single batch
2. **O(1) frame access**: During animation, frames are retrieved via direct array lookup with zero computation
3. **Path extraction optimization**: Path elements are extracted once and reused to build all variation frames

This means the expensive work (path generation, variance calculation) only happens when:
- The view first appears
- The canvas size changes
- The animation configuration changes

During the actual animation loop, the cost is essentially zero - just swapping between pre-computed paths.

## Rounded Rectangle

RoughSwiftUI supports rounded rectangles with customizable corner radius:

```swift
// Rounded rectangle with default corner radius (8 points)
RoughView()
    .fill(.blue)
    .stroke(.black)
    .strokeWidth(2)
    .roundedRectangle()
    .frame(width: 200, height: 100)

// Custom corner radius
RoughView()
    .fill(.green)
    .fillStyle(.hachure)
    .roundedRectangle(cornerRadius: 20)
    .frame(width: 150, height: 80)

// Large corner radius for pill-shaped rectangles
RoughView()
    .fill(.purple)
    .roundedRectangle(cornerRadius: 50)
    .frame(width: 200, height: 60)
```

Rounded rectangles automatically fill the available space, similar to `rectangle()` and `circle()`. The corner radius is applied uniformly to all four corners.

## Egg Shape

RoughSwiftUI includes an egg-shaped (ovoid) drawable with natural asymmetry:

```swift
// Basic egg shape with default tilt
RoughView()
    .fill(.yellow)
    .stroke(.orange)
    .strokeWidth(2)
    .egg()
    .frame(width: 100, height: 140)

// Custom tilt for different egg orientations
RoughView()
    .fill(.pink)
    .egg(tilt: 0.5)  // More pronounced asymmetry
    .frame(width: 120, height: 160)

// Symmetric ellipse (tilt = 0)
RoughView()
    .fill(.cyan)
    .egg(tilt: 0)
    .frame(width: 100, height: 100)

// Negative tilt (wider top, narrower bottom)
RoughView()
    .fill(.green)
    .egg(tilt: -0.3)
    .frame(width: 100, height: 140)
```

The `tilt` parameter controls the asymmetry:
- **Positive values** (default: `0.3`): Narrower top, wider bottom (natural egg shape)
- **Zero**: Symmetric ellipse
- **Negative values**: Narrower bottom, wider top

Egg shapes automatically fill the available space and are centered within the view bounds.

## Creative Shapes

With all the primitive shapes, we can create more beautiful things. The only limit is your imagination.

Here's how to create a chart:

![](Screenshots/chart.png)

```swift
struct ChartView: View {
    var heights: [CGFloat] {
        Array(0 ..< 10).map { _ in CGFloat.random(in: 0 ..< 150) }
    }

    var body: some View {
        HStack {
            ForEach(0 ..< 10) { index in
                VStack {
                    Spacer()
                    RoughView()
                        .fill(.yellow)
                        .rectangle()
                        .frame(height: heights[index])
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
}
```

## Advanced Usage with Drawable, Generator and SwiftUIRenderer

Behind the scenes, RoughSwiftUI uses a `NativeGenerator` (pure Swift implementation inspired by rough.js) and a SwiftUI renderer.

We can instantiate `Engine` or use a shared `Engine` for memory efficiency to create a `NativeGenerator`. Every time we instruct the generator to draw a shape, the engine figures out information about the sketchy shape in `Drawing`.

For SwiftUI, there is a `SwiftUIRenderer` that can handle `Drawing` data and transform it into SwiftUI `Path`/`Canvas` drawing commands.

```swift
struct CustomCanvasView: View {
    var body: some View {
        Canvas { context, size in
            let engine = Engine.shared
            let generator = engine.generator(size: size)

            var options = Options()
            options.fill = .yellow
            options.stroke = .systemTeal

            let drawable: Drawable = Rectangle(x: 10, y: 10, width: 100, height: 50)

            if let drawing = generator.generate(drawable: drawable, options: options) {
                let renderer = SwiftUIRenderer()
                renderer.render(drawing: drawing, options: options, in: &context, size: size)
            }
        }
    }
}
```

## Performance

RoughSwiftUI uses a **native Swift generator engine** for optimal performance - no JavaScript bridge or JavaScriptCore required. The engine also employs internal caching to further optimize rendering:

- **Generator caching**: Generators are cached by canvas size, avoiding repeated allocations when the view size hasn't changed.
- **Drawing caching**: Generated drawings are cached by drawable + options, avoiding repeated computations for the same shapes.

The caches are automatically managed and evict old entries when capacity is reached.

### Cache Management

For memory-sensitive scenarios or when you need to force fresh renders, you can manually clear the caches:

```swift
// Clear all cached generators and drawings
Engine.shared.clearCaches()
```

You can also monitor cache performance for debugging:

```swift
let stats = Engine.shared.cacheStats
print("Cached generators: \(stats.generators)")
print("Cached drawings: \(stats.drawings)")
print("Cache hit rate: \(String(format: "%.1f%%", stats.hitRate * 100))")
```

### When to Clear Caches

- **Memory warnings**: Clear caches when your app receives memory pressure notifications
- **Scene transitions**: Consider clearing when moving between major app sections
- **Dynamic content**: If you're generating many unique shapes that won't be reused

```swift
// Example: Clear caches on memory warning
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    Engine.shared.clearCaches()
}
```

## Performance Instrumentation

RoughSwiftUI includes built-in performance instrumentation using Apple's `os_signpost` API. This allows you to profile rendering performance using Instruments.app.

### Enabling Instrumentation

Instrumentation is **enabled by default in DEBUG builds** and disabled in release builds for zero overhead. To enable it explicitly in other build configurations, add the following Swift compiler flag:

```
-DROUGH_PERFORMANCE_INSTRUMENTATION
```

In Xcode:
1. Select your target
2. Go to Build Settings → Swift Compiler - Custom Flags
3. Add `-DROUGH_PERFORMANCE_INSTRUMENTATION` to "Other Swift Flags"

### Viewing Performance Data in Instruments

1. Open **Instruments.app**
2. Choose the **Blank** template
3. Click **+** and add the **os_signpost** instrument
4. In the filter field, type: `com.roughswiftui`
5. Run your app and observe the timeline

### Instrumented Operations

The following operations are measured with signposts:

| Category | Operations |
|----------|------------|
| `rendering` | Canvas Render, Build Commands, Command Execution, SVG Transform |
| `generation` | Create Generator, Generate Drawing |
| `pathOps` | Scribble Fill, Ray Intersection, Stroke to Fill, Duplicate Removal |
| `animation` | Frame Render, Variance Compute, Precompute Variance |
| `parsing` | SVG Parse |

### Aggregate Statistics

For quick debugging without Instruments, you can collect aggregate statistics:

```swift
import RoughSwiftUI

// After rendering operations...
PerformanceStatistics.shared.printReport()
```

This outputs a summary like:

```
=== RoughSwiftUI Performance Report ===

Duration Measurements:
  Generate Drawing:
    Count: 10
    Total: 45.230ms
    Average: 4.523ms
    Max: 8.102ms
  Canvas Render:
    Count: 60
    Total: 120.500ms
    Average: 2.008ms
    Max: 5.234ms
```

### Performance Tips

Based on signpost data, common bottlenecks include:

1. **Scribble Fill**: High tightness values create many ray intersections. Use moderate tightness (10-30) for complex shapes.

2. **Stroke-to-Fill Conversion**: Brush profiles with custom tips require path sampling. Use standard brush profiles when performance is critical.

3. **Animation Frame Pre-computation**: Initial frame generation can take time for complex shapes. Consider showing a loading state for animations with many steps and complex drawings.

## Installation

Add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/sstradling/RoughSwiftUI", from: "1.0.0"),
```

Then add `RoughSwiftUI` as a dependency of your target. On iOS/tvOS, you can import the package and use `RoughView` directly inside SwiftUI:

```swift
import SwiftUI
import RoughSwiftUI

struct ContentView: View {
    var body: some View {
        RoughView()
            .fill(.yellow)
            .stroke(.systemTeal)
            .rectangle()
            .frame(width: 200, height: 200)
    }
}
```

## Author

**Seth Stradling** - [@sstradling](https://github.com/sstradling)

## Credits

- [**RoughSwift**](https://github.com/onmyway133/RoughSwift) by [Khoa Pham](https://github.com/onmyway133) - The original Swift wrapper for rough.js that this project is based on. RoughSwiftUI builds upon Khoa's excellent foundation with a native Swift generator engine and SwiftUI-first API.

- [**rough.js**](https://github.com/pshihn/rough) by Prashant Sharma - The original JavaScript library that serves as the basis and inspiration for the native Swift generator engine powering RoughSwiftUI. The algorithms for creating hand-drawn, sketchy graphics are adapted from rough.js.

- [**SVGPath**](https://github.com/timrwood/SVGPath) by Tim Wood - For the SVG path parsing implementation.

## License

**RoughSwiftUI** is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
