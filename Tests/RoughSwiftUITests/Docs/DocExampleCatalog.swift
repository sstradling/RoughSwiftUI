import SwiftUI
@testable import RoughSwiftUI

/// A paper-card ink color. The snippet and the rendered `Color` share one triple.
struct DocInk {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    /// `Color(red:green:blue:)` text with a fixed decimal point, independent of locale.
    var snippet: String {
        let r = Self.fixed(red)
        let g = Self.fixed(green)
        let b = Self.fixed(blue)
        return "Color(red: \(r), green: \(g), blue: \(b))"
    }

    private static func fixed(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

/// Seeded gallery rendered by `scripts/render-docs.sh`.
///
/// Explicit geometry sits in the content box inside the paper card: `tileSide`
/// minus `tileInset` on each side, 184 points, centered at 92.
enum DocExampleCatalog {
    /// Warm sketchbook card. Opaque, light only.
    static let paper = Color(red: 0.984, green: 0.965, blue: 0.925)

    static let tileSide: CGFloat = 240
    static let renderScale: CGFloat = 2
    static let tileInset: CGFloat = 28

    static let charcoal = DocInk(red: 0.12, green: 0.14, blue: 0.18)
    static let inkBlue = DocInk(red: 0.18, green: 0.46, blue: 0.67)
    static let coral = DocInk(red: 0.76, green: 0.32, blue: 0.28)
    static let leaf = DocInk(red: 0.22, green: 0.48, blue: 0.34)
    static let amber = DocInk(red: 0.85, green: 0.55, blue: 0.18)
    static let plum = DocInk(red: 0.45, green: 0.28, blue: 0.55)
    static let sea = DocInk(red: 0.20, green: 0.45, blue: 0.52)
    static let clay = DocInk(red: 0.55, green: 0.32, blue: 0.22)

    static let examples: [DocExample] =
        basicExamples
        + shapeExamples
        + fillExamples
        + strokeExamples
        + roughnessExamples
        + brushExamples
        + seedingExamples
        + svgExamples
        + textExamples
        + animationExamples

    /// Wide paper card for the top of the README. Not listed in Examples.md.
    static let hero = DocHero.shared

    static func still(
        _ id: String,
        section: String,
        title: String,
        description: String,
        snippet: String,
        _ view: @escaping () -> RoughView
    ) -> DocExample {
        DocExample(
            id: id,
            section: section,
            title: title,
            description: description,
            snippet: snippet,
            kind: .still,
            view: view,
            animation: nil
        )
    }

    static func gif(
        _ id: String,
        title: String,
        description: String,
        snippet: String,
        frames: Int,
        fps: Int,
        animation: AnimationConfig,
        _ view: @escaping () -> RoughView
    ) -> DocExample {
        DocExample(
            id: id,
            section: "Animation",
            title: title,
            description: description,
            snippet: snippet,
            kind: .gif(frameCount: frames, fps: fps),
            view: view,
            animation: animation
        )
    }
}
