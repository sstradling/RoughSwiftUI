import SwiftUI
@testable import RoughSwiftUI

/// Phase 2 pilots. Later phases append examples here; this pass stays at three.
enum DocExampleCatalog {
    /// Warm sketchbook card. Opaque, light only.
    static let paper = Color(red: 0.984, green: 0.965, blue: 0.925)

    static let tileSide: CGFloat = 240
    static let renderScale: CGFloat = 2
    static let tileInset: CGFloat = 28

    static let examples: [DocExample] = [
        hachureRectangle,
        horizontalHachure,
        breathingCircle
    ]

    private static let charcoal = "Color(red: 0.12, green: 0.14, blue: 0.18)"
    private static let inkBlue = "Color(red: 0.18, green: 0.46, blue: 0.67)"
    private static let coral = "Color(red: 0.76, green: 0.32, blue: 0.28)"
    private static let leaf = "Color(red: 0.22, green: 0.48, blue: 0.34)"

    private static let hachureRectangle = DocExample(
        id: "hachure-rectangle",
        section: "Basics",
        title: "Hachure rectangle",
        description: "A seeded rectangle with hachure at 45°, the default fill angle.",
        snippet: """
        RoughView()
            .fill(\(inkBlue))
            .fillStyle(.hachure)
            .fillAngle(45)
            .fillSpacing(3)
            .stroke(\(charcoal))
            .strokeWidth(2)
            .seed(42)
            .rectangle()
        """,
        kind: .still,
        view: {
            RoughView()
                .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
                .strokeWidth(2)
                .seed(42)
                .rectangle()
        },
        animation: nil
    )

    private static let horizontalHachure = DocExample(
        id: "horizontal-hachure",
        section: "Fills",
        title: "Horizontal hachure",
        description: "Hachure at 0° runs horizontally. Positive angles rotate clockwise.",
        snippet: """
        RoughView()
            .fill(\(coral))
            .fillStyle(.hachure)
            .fillAngle(0)
            .fillSpacing(2.5)
            .stroke(\(charcoal))
            .strokeWidth(2)
            .seed(11)
            .circle()
        """,
        kind: .still,
        view: {
            RoughView()
                .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(2.5)
                .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
                .strokeWidth(2)
                .seed(11)
                .circle()
        },
        animation: nil
    )

    private static let breathingCircle = DocExample(
        id: "breathing-circle",
        section: "Animation",
        title: "Breathing circle",
        description: "A seeded cross-hatch circle. AnimationConfig.seed replays the same wobble.",
        snippet: """
        RoughView()
            .fill(\(leaf))
            .fillStyle(.crossHatch)
            .fillAngle(30)
            .fillSpacing(3)
            .stroke(\(charcoal))
            .strokeWidth(2)
            .seed(42)
            .circle()
            .animated(config: AnimationConfig(steps: 6, speed: .medium, variance: .high, seed: 42))
        """,
        kind: .gif(frameCount: 6, fps: 8),
        view: {
            RoughView()
                .fill(Color(red: 0.22, green: 0.48, blue: 0.34))
                .fillStyle(.crossHatch)
                .fillAngle(30)
                .fillSpacing(3)
                .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
                .strokeWidth(2)
                .seed(42)
                .circle()
        },
        animation: AnimationConfig(steps: 6, speed: .medium, variance: .high, seed: 42)
    )
}
