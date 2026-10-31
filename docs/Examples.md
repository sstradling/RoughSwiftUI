# Examples

Rendered by `scripts/render-docs.sh` from the `DocExample` catalog. Each example sets a fixed seed so the picture matches the snippet. Tiles are light paper cards.

## Contents

- [Basics](#basics)
- [Fills](#fills)
- [Animation](#animation)

## Basics

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

## Fills

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

## Animation

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
