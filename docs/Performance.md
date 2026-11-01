# Performance

RoughSwiftUI draws with a native Swift generator. There is no JavaScript bridge. The engine caches generators and drawings so a view that has not changed does not rebuild its strokes.

- **Generator caching.** Generators are cached by canvas size.
- **Drawing caching.** Drawings are cached by drawable, size, and the options that affect geometry, including `seed`.

Caches evict old entries when they fill up. Colour, opacity, and brush are applied at render time.

This page is the performance material that used to live in the README. The drawing API and the example catalog are in [README.md](../README.md) and [Examples.md](Examples.md).

## Cache management

Clear the caches when you need a fresh drawing or when memory is tight:

```swift
Engine.shared.clearCaches()
```

Cache counters are for debugging:

```swift
let stats = Engine.shared.cacheStats
print("Cached generators: \(stats.generators)")
print("Cached drawings: \(stats.drawings)")
print("Cache hit rate: \(stats.hitRate.formatted(.percent.precision(.fractionLength(1))))")
```

Clear them on a memory warning, between major scenes, or when you are generating many shapes that will not be drawn again:

```swift
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    Engine.shared.clearCaches()
}
```

## Instrumentation

Signposts use `os_signpost` so you can profile rendering in Instruments. They are on in DEBUG builds and off in release builds. To turn them on in another configuration, add this Swift compiler flag:

```
-DROUGH_PERFORMANCE_INSTRUMENTATION
```

In Xcode, add that flag under Build Settings → Swift Compiler - Custom Flags → Other Swift Flags.

To view them:

1. Open Instruments and choose the Blank template.
2. Add the os_signpost instrument.
3. Filter for `com.roughswiftui`.
4. Run the app and read the timeline.

| Category | Operations |
| --- | --- |
| `rendering` | Canvas render, build commands, command execution, SVG transform |
| `generation` | Create generator, generate drawing |
| `pathOps` | Scribble fill, ray intersection, stroke to fill, duplicate removal |
| `animation` | Frame render, variance compute, precompute variance |
| `parsing` | SVG parse |

`PerformanceStatistics` collects the same timings without Instruments:

```swift
import RoughSwiftUI

PerformanceStatistics.shared.printReport()
```

A report looks like this:

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

## Tips

- Scribble fills with a high tightness do more ray tests. Tightness between 10 and 30 is enough for most shapes.
- Brush profiles that vary width sample the path. A plain stroke is cheaper when you do not need the texture.
- Animation builds every frame before it plays. A drawing with many steps can pause on the first frame.
