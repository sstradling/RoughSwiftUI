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
- hachureAngle
- hachureGap
- dashOffset
- dashGap
- zigzagOffset

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

SVG shape can be bigger or smaller than the specifed layer size, so RoughSwift scales them to your requested `size`. This way we can compose and transform the SVG shape.

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
                renderer.render(drawing: drawing, in: &context, size: size)
            }
        }
    }
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

**RoughSwift** is available under the MIT license. See the [LICENSE](https://github.com/onmyway133/RoughSwift/blob/master/LICENSE.md) file for more info.
