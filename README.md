## Based entirely on https://github.com/onmyway133/RoughSwift, modified via Cursor

![](Screenshots/s.png)

Checkout https://indiegoodies.com/

![](Screenshots/s1.png)

## Description

RoughSwift allows us to easily make shapes in hand drawn, sketchy, comic style in SwiftUI.

- [x] Support iOS, tvOS
- [x] Support all shapes: line, rectangle, circle, ellipse, linear path, arc, curve, polygon, svg path
- [x] Native SwiftUI rendering via `Canvas`, backed by `rough.js` in JavaScriptCore
- [x] Easy customizations with Options
- [x] Easy composable APIs
- [x] Convenient draw functions
- [x] Platform independent APIs which can easily support new platforms
- [x] Test coverage
- [x] Immutable and type safe data structure
- [x] SVG path scaling and alignment
- [x] Animated strokes and fills with configurable variations
- [ ] SVG elliptical arc

There are [Example](https://github.com/onmyway133/RoughSwift/tree/master/Example) project where you can explore further.

## Basic

The easiest way to use RoughSwift is via `RoughView`, a SwiftUI `View` that renders
hand‑drawn primitives using SwiftUI `Canvas` under the hood.

Here's how to draw a green rectangle:

![](Screenshots/green_rectangle.png)

```swift
RoughView()
    .fill(.yellow)
    .fillStyle(.hachure)
    .hachureAngle(-41)
    .hachureGap(-1)
    .fillWeight(-1)
    .stroke(.systemTeal)
    .strokeWidth(2)
    .curveTightness(0)
    .curveStepCount(9)
    .dashOffset(-1)
    .dashGap(-1)
    .zigzagOffset(-9)
```

Because `RoughView` is a normal SwiftUI view, you can compose it with other SwiftUI
views, apply transforms (scale, rotate, offset), and animate it using standard
SwiftUI modifiers.

## Options

`Options` is used to custimize shape. It is immutable struct and apply to one shape at a time. The following properties are configurable

- maxRandomnessOffset
- toughness
- bowing
- fill
- stroke
- strokeWidth
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

## Shapes

RoughSwift supports all primitive shapes, including SVG path

- line
- rectangle
- ellipse
- circle
- linearPath
- arc
- curve
- polygon
- path

## Fill style

Most of the time, we use `fill` for solid fill color inside shape, `stroke` for shape border, and `fillStyle` for sketchy fill style.

Available fill styles

- crossHatch
- dashed
- dots
- hachure
- solid
- starBurst
- zigzag
- zigzagLine

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

Here's how to draw circles in different fill styles. The default fill style is hachure

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
        }
    }
}
```

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

## Animation

RoughSwift supports animated strokes and fills that introduce subtle variations on a loop, creating a "breathing" or "sketchy" animation effect that brings your hand-drawn graphics to life.

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
| `variance` | `.low`, `.medium`, `.high` | Amount of variation: 1%, 5%, or 10% |

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

## Creative shapes

With all the primitive shapes, we can create more beautiful things. The only limit is your imagination.

Here's how to create chart

![](Screenshots/chart.png)

```swift
struct Chartview: View {
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


## Advance with Drawable, Generator and SwiftUIRenderer

Behind the scenes, RoughSwift composes a `Generator` (powered by `rough.js`) and a
SwiftUI renderer.

We can instantiate `Engine` or use a shared `Engine` for memory efficiency to make
`Generator`. Every time we instruct `Generator` to draw a shape, the engine works
to figure out information about the sketchy shape in `Drawable`.

The name of these concepts follow `rough.js` for better code reasoning.

For SwiftUI, there is a `SwiftUIRenderer` that can handle `Drawable` data and
transform it into SwiftUI `Path`/`Canvas` drawing commands.

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

RoughSwift uses internal caching to optimize rendering performance:

- **Generator caching**: Generators are cached by canvas size, avoiding repeated JavaScript context calls when the view size hasn't changed.
- **Drawing caching**: Generated drawings are cached by drawable + options, avoiding repeated rough.js computations for the same shapes.

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

## Installation

Add the following line to the dependencies in your `Package.swift` file

```swift
.package(url: "https://github.com/onmyway133/RoughSwift"),
```

Then add `RoughSwift` as a dependency of your app target. On iOS/tvOS, you can
import the package and use `RoughView` directly inside SwiftUI:

```swift
import SwiftUI
import RoughSwift

struct ContentView: View {
    var body: some View {
        RoughView()
            .rectangle()
            .fill(.yellow)
            .stroke(.systemTeal)
            .frame(width: 200, height: 200)
    }
}
```

## Author

Khoa Pham, onmyway133@gmail.com

## Credit

- [rough](https://github.com/pshihn/rough) for the generator that powers RoughSwift. All the hard work is done via rough in JavascriptCore.
- [SVGPath](https://github.com/timrwood/SVGPath) for constructing UIBezierPath from SVG path

## Contributing

We would love you to contribute to **RoughSwift**, check the [CONTRIBUTING](https://github.com/onmyway133/RoughSwift/blob/master/CONTRIBUTING.md) file for more info.

## License

**RoughSwiftUI** is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
