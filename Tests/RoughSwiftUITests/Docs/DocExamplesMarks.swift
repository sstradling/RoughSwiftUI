import SwiftUI
import UIKit
@testable import RoughSwiftUI

extension DocExampleCatalog {
    static let starPath = "M50,5 L63,40 L100,40 L70,62 L82,98 L50,78 L18,98 L30,62 L0,40 L37,40 Z"
    static let heartPath = "M50,28 C50,28 38,8 22,8 C8,8 0,20 0,34 C0,55 22,72 50,96 C78,72 100,55 100,34 C100,20 92,8 78,8 C62,8 50,28 50,28 Z"

    static let seedingExamples: [DocExample] = [
        seededCircle(
            id: "seed-seven",
            title: "Seed 7",
            description: "A circle pinned with seed 7.",
            seed: 7
        ),
        seededCircle(
            id: "seed-seven-again",
            title: "Seed 7, again",
            description: "The same circle and the same seed. The strokes match the previous tile.",
            seed: 7
        ),
        seededCircle(
            id: "seed-ninety-nine",
            title: "Seed 99",
            description: "The same circle with seed 99. The wobble is a different drawing.",
            seed: 99
        )
    ]

    static let svgExamples: [DocExample] = [
        still(
            "svg-star",
            section: "SVG",
            title: "SVG star",
            description: "An SVG path string, scaled to the card. svgStrokeWidth overrides the outline width.",
            snippet: """
            RoughView()
                .fill(\(amber.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .svgStrokeWidth(2.5)
                .seed(141)
                .draw(Path(d: "\(starPath)"))
            """
        ) {
            RoughView()
                .fill(amber.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .svgStrokeWidth(2.5)
                .seed(141)
                .draw(Path(d: starPath))
        },
        still(
            "svg-outside",
            section: "SVG",
            title: "Outside SVG stroke",
            description: "svgFillStrokeAlignment(.outside) lays the stroke on the outer edge. svgFillWeight sets the fill-line width.",
            snippet: """
            RoughView()
                .fill(\(coral.snippet))
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .svgStrokeWidth(8)
                .svgFillWeight(2)
                .svgFillStrokeAlignment(.outside)
                .seed(144)
                .draw(Path(d: "\(heartPath)"))
            """
        ) {
            RoughView()
                .fill(coral.color)
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .svgStrokeWidth(8)
                .svgFillWeight(2)
                .svgFillStrokeAlignment(.outside)
                .seed(144)
                .draw(Path(d: heartPath))
        }
    ]

    static let textExamples: [DocExample] = [
        still(
            "rough-word",
            section: "Text",
            title: "Rough text",
            description: "Text is traced to a path and centered. The letters take the same hachure as a shape.",
            snippet: """
            RoughView()
                .fill(\(coral.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(2)
                .stroke(\(charcoal.snippet))
                .strokeWidth(1.5)
                .seed(151)
                .text("Hi", font: .systemFont(ofSize: 76, weight: .heavy))
            """
        ) {
            RoughView()
                .fill(coral.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(2)
                .stroke(charcoal.color)
                .strokeWidth(1.5)
                .seed(151)
                .text("Hi", font: .systemFont(ofSize: 76, weight: .heavy))
        },
        still(
            "named-font",
            section: "Text",
            title: "Named font",
            description: "A PostScript font name. The glyphs are fitted to the card and filled solid.",
            snippet: """
            RoughView()
                .fill(\(leaf.snippet))
                .fillStyle(.solid)
                .stroke(\(charcoal.snippet))
                .strokeWidth(1.5)
                .seed(155)
                .text("Note", fontName: "Helvetica-Bold", fontSize: 48)
            """
        ) {
            RoughView()
                .fill(leaf.color)
                .fillStyle(.solid)
                .stroke(charcoal.color)
                .strokeWidth(1.5)
                .seed(155)
                .text("Note", fontName: "Helvetica-Bold", fontSize: 48)
        }
    ]

    /// Shared drawing for the seeding trio. Only `seed` changes.
    private static func seededCircle(id: String, title: String, description: String, seed: UInt64) -> DocExample {
        still(
            id,
            section: "Seeding",
            title: title,
            description: description,
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.hachure)
                .fillAngle(40)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .roughness(2.2)
                .seed(\(seed))
                .circle()
            """
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.hachure)
                .fillAngle(40)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .roughness(2.2)
                .seed(seed)
                .circle()
        }
    }
}
