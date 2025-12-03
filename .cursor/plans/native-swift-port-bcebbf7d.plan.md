<!-- bcebbf7d-0b6e-45c0-8759-131368adb0a3 74e28478-0639-4aca-b7f3-537389760f17 -->
# Native Swift Port of rough.js

## Architecture Overview

Replace the current JS-bridged architecture with a native Swift implementation:

```
Current: RoughView → Generator (JSValue) → rough.js → Drawing
New:     RoughView → NativeGenerator (Swift) → Drawing
```

Key files to modify/create:

- Create: `Sources/RoughSwiftUI/Engine/NativeGenerator.swift` (main generator)
- Create: `Sources/RoughSwiftUI/Engine/RoughMath.swift` (core algorithms)
- Create: `Sources/RoughSwiftUI/Engine/Fillers/` (fill pattern implementations)
- Modify: [`Engine.swift`](Sources/RoughSwiftUI/Engine/Engine.swift) (remove JSContext, use native)
- Modify: [`Generator.swift`](Sources/RoughSwiftUI/Engine/Generator.swift) (replace JS calls with native)

---

## Phase 1: Core Math and Line Generation

Port the fundamental randomization and line-drawing algorithms from rough.js.

**Files to create:**

`RoughMath.swift`:

- `randOffset(max:options:)` - random offset within range
- `randOffsetWithRange(min:max:options:)` - random in explicit range  
- `doubleLineOps(x1:y1:x2:y2:options:)` - double-stroke line effect
- `lineOps(x1:y1:x2:y2:options:move:overlay:)` - single rough line with bowing

**Key algorithms to port:**

```swift
// Bowing calculation (from rough.js)
let p = bowing * maxRandomnessOffset * (y2 - y1) / 200
let u = bowing * maxRandomnessOffset * (x1 - x2) / 200

// Bezier control points with randomness
let midX = x1 + (x2 - x1) * convergence + randOffset
let midY = y1 + (y2 - y1) * convergence + randOffset
```

---

## Phase 2: Shape Generators

Implement each shape type natively.

**NativeGenerator.swift methods:**

| Method | Complexity | Notes |

|--------|------------|-------|

| `line()` | Low | Uses doubleLineOps |

| `rectangle()` | Low | 4 lines + fill |

| `ellipse()` | Medium | Curve sampling with roughness |

| `circle()` | Low | Ellipse with equal width/height |

| `linearPath()` | Low | Connected line segments |

| `polygon()` | Medium | Closed linearPath + fill |

| `arc()` | Medium | Partial ellipse with endpoints |

| `curve()` | Medium | Catmull-Rom spline conversion |

| `path()` | High | SVG path parsing (reuse existing `SVGPath.swift`) |

**Ellipse algorithm (critical):**

```swift
func ellipseOps(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, options: Options) -> [Operation] {
    let stepCount = options.curveStepCount
    let increment = (2 * .pi) / stepCount
    var ops: [Operation] = []
    
    // Two passes for rough effect
    for pass in 0..<2 {
        let offset = pass == 0 ? 1.0 : 1.5
        var angle = randOffset(0.5, options) - .pi / 2
        // ... generate curve points with randomness
    }
    return ops
}
```

---

## Phase 3: Fill Pattern System

Port all fill pattern generators. Create a protocol-based system:

```swift
protocol FillGenerator {
    func fill(polygon: [CGPoint], options: Options) -> OperationSet
    func fillEllipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, options: Options) -> OperationSet
    func fillArc(...) -> OperationSet?
}
```

**Files in `Engine/Fillers/`:**

| File | Fill Style | Algorithm |

|------|------------|-----------|

| `HachureFiller.swift` | hachure | Scan-line intersection with angle rotation |

| `SolidFiller.swift` | solid | Simple polygon fill path |

| `ZigzagFiller.swift` | zigzag | Hachure with connected endpoints |

| `CrossHatchFiller.swift` | cross-hatch | Hachure at angle + hachure at angle+90° |

| `DotsFiller.swift` | dots | Grid of small ellipses along hachure lines |

| `DashedFiller.swift` | dashed | Hachure with gaps |

| `ZigzagLineFiller.swift` | zigzag-line | Hachure with zigzag segments |

| `StarburstFiller.swift` | starburst/sunburst | Radial lines from centroid |

**Hachure algorithm (most complex):**

```swift
struct HachureHelper {
    // Rotate polygon to hachure angle
    // Scan horizontally with gap spacing
    // Find all line-polygon intersections
    // Pair intersections into line segments
    // Rotate back to original orientation
}
```

---

## Phase 4: SVG Path Support

Leverage existing [`SVGPath.swift`](Sources/RoughSwiftUI/Render/SVGPath.swift) for parsing. Add rough rendering:

```swift
func pathOps(svgPathString: String, options: Options) -> [Operation] {
    let svgPath = SVGPath(svgPathString)
    var ops: [Operation] = []
    var state = PathState()
    
    for segment in svgPath.segments {
        ops.append(contentsOf: processSegment(segment, state: &state, options: options))
    }
    return ops
}
```

Handle all SVG commands: M, L, H, V, C, S, Q, T, A, Z

---

## Phase 5: Integration and Migration

1. **Create `NativeEngine.swift`** - drop-in replacement for `Engine.swift`
2. **Update `RoughView.swift`** - use native generator
3. **Add caching layer** - cache generated drawings by options hash
4. **Remove JavaScriptCore** - delete `rough.js`, remove JSContext code
5. **Update Package.swift** - remove JS resource bundle

**Migration in RoughView:**

```swift
// Before
let generator = Engine.shared.generator(size: renderSize)

// After  
let generator = NativeGenerator(size: renderSize)
// With caching:
let drawing = DrawingCache.shared.getOrGenerate(drawable, options, size)
```

---

## Phase 6: Testing and Validation

1. **Visual regression tests** - compare native vs JS output for all shapes
2. **Performance benchmarks** - measure improvement over JSContext
3. **Edge case testing** - extreme roughness, tiny/huge shapes, complex SVG paths

---

## Estimated Effort

| Phase | Effort | Dependencies |

|-------|--------|--------------|

| Phase 1: Core Math | 1-2 days | None |

| Phase 2: Shape Generators | 2-3 days | Phase 1 |

| Phase 3: Fill Patterns | 3-4 days | Phase 1 |

| Phase 4: SVG Path | 1-2 days | Phase 2 |

| Phase 5: Integration | 1 day | All above |

| Phase 6: Testing | 1-2 days | Phase 5 |

**Total: ~10-14 days**

---

## Risk Mitigation

1. **Visual parity** - Use deterministic seeds for testing to compare JS vs native output
2. **Gradual rollout** - Add feature flag to switch between native/JS during development
3. **Fallback** - Keep JS engine available until native is fully validated

### To-dos

- [ ] Implement RoughMath.swift with randomization and line algorithms
- [ ] Implement NativeGenerator.swift with all shape methods
- [ ] Implement HachureFiller with scan-line algorithm
- [ ] Implement remaining fill patterns (solid, dots, crosshatch, etc.)
- [ ] Add rough rendering for SVG path segments
- [ ] Replace Engine.swift with native, add caching
- [ ] Visual regression tests and performance benchmarks