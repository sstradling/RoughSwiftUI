import SwiftUI
@testable import RoughSwiftUI

extension DocExampleCatalog {
    static let animationExamples: [DocExample] = [
        gif(
            "breathing-circle",
            title: "Breathing circle",
            description: "A seeded cross-hatch circle. AnimationConfig.seed replays the same wobble.",
            snippet: """
            RoughView()
                .fill(\(leaf.snippet))
                .fillStyle(.crossHatch)
                .fillAngle(30)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(42)
                .circle()
                .animated(config: AnimationConfig(steps: 6, speed: .medium, variance: .high, seed: 42))
            """,
            frames: 6,
            fps: 8,
            animation: AnimationConfig(steps: 6, speed: .medium, variance: .high, seed: 42)
        ) {
            RoughView()
                .fill(leaf.color)
                .fillStyle(.crossHatch)
                .fillAngle(30)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(42)
                .circle()
        },
        gif(
            "slow-breath",
            title: "Slow breath",
            description: "Very low variance and the slow step, 600 ms. The GIF plays the four frames at 2 fps.",
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(30)
                .rectangle()
                .animated(config: AnimationConfig(steps: 4, speed: .slow, variance: .veryLow, seed: 30))
            """,
            frames: 4,
            fps: 2,
            animation: AnimationConfig(steps: 4, speed: .slow, variance: .veryLow, seed: 30)
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(30)
                .rectangle()
        },
        gif(
            "low-wobble",
            title: "Low wobble",
            description: "Low variance (1%) on a seeded ellipse, played at 3 fps for the medium step.",
            snippet: """
            RoughView()
                .fill(\(coral.snippet))
                .fillStyle(.solid)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .roughness(1.4)
                .seed(32)
                .draw(Ellipse(x: 92, y: 92, width: 150, height: 110))
                .animated(config: AnimationConfig(steps: 4, speed: .medium, variance: .low, seed: 32))
            """,
            frames: 4,
            fps: 3,
            animation: AnimationConfig(steps: 4, speed: .medium, variance: .low, seed: 32)
        ) {
            RoughView()
                .fill(coral.color)
                .fillStyle(.solid)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .roughness(1.4)
                .seed(32)
                .draw(Ellipse(x: 92, y: 92, width: 150, height: 110))
        },
        gif(
            "sketch-cycle",
            title: "Sketch cycle",
            description: "Medium variance on a triangle, five steps, played at 3 fps.",
            snippet: """
            RoughView()
                .fill(\(amber.snippet))
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(34)
                .draw(Polygon(points: [
                    Point(x: 92, y: 24),
                    Point(x: 160, y: 156),
                    Point(x: 24, y: 156)
                ]))
                .animated(config: AnimationConfig(steps: 5, speed: .medium, variance: .medium, seed: 34))
            """,
            frames: 5,
            fps: 3,
            animation: AnimationConfig(steps: 5, speed: .medium, variance: .medium, seed: 34)
        ) {
            RoughView()
                .fill(amber.color)
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(34)
                .draw(Polygon(points: [
                    Point(x: 92, y: 24),
                    Point(x: 160, y: 156),
                    Point(x: 24, y: 156)
                ]))
        },
        gif(
            "fast-jitter",
            title: "Fast jitter",
            description: "High variance and the fast step, 100 ms. The GIF plays the four frames at 10 fps.",
            snippet: """
            RoughView()
                .fill(\(plum.snippet))
                .fillStyle(.zigzag)
                .fillAngle(30)
                .fillSpacing(3.5)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(38)
                .circle()
                .animated(config: AnimationConfig(steps: 4, speed: .fast, variance: .high, seed: 38))
            """,
            frames: 4,
            fps: 10,
            animation: AnimationConfig(steps: 4, speed: .fast, variance: .high, seed: 38)
        ) {
            RoughView()
                .fill(plum.color)
                .fillStyle(.zigzag)
                .fillAngle(30)
                .fillSpacing(3.5)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(38)
                .circle()
        },
        gif(
            "long-cycle",
            title: "Eight steps",
            description: "Eight variation steps before the loop repeats. Medium variance, played at 3 fps.",
            snippet: """
            RoughView()
                .fill(\(sea.snippet))
                .fillStyle(.dots)
                .fillSpacing(2.4)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(40)
                .circle()
                .animated(config: AnimationConfig(steps: 8, speed: .medium, variance: .medium, seed: 40))
            """,
            frames: 8,
            fps: 3,
            animation: AnimationConfig(steps: 8, speed: .medium, variance: .medium, seed: 40)
        ) {
            RoughView()
                .fill(sea.color)
                .fillStyle(.dots)
                .fillSpacing(2.4)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(40)
                .circle()
        },
        gif(
            "scribble-wobble",
            title: "Scribble wobble",
            description: "A scribble fill takes the same seeded wobble. Medium variance, five steps, played at 3 fps.",
            snippet: """
            RoughView()
                .fill(\(leaf.snippet))
                .fillStyle(.scribble)
                .scribble(origin: 20, tightness: 12, curvature: 12)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(46)
                .circle()
                .animated(config: AnimationConfig(steps: 5, speed: .medium, variance: .medium, seed: 46))
            """,
            frames: 5,
            fps: 3,
            animation: AnimationConfig(steps: 5, speed: .medium, variance: .medium, seed: 46)
        ) {
            RoughView()
                .fill(leaf.color)
                .fillStyle(.scribble)
                .scribble(origin: 20, tightness: 12, curvature: 12)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(46)
                .circle()
        }
    ]
}
