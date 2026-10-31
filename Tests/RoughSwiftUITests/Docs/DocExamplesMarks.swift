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
            description: "A PostScript font name, drawn at that size and centered in the card.",
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
        },
        still(
            "leading-text",
            section: "Text",
            title: "Leading top",
            description: "Leading and top pin the glyphs to the corner of the card, at the font size you set.",
            snippet: """
            RoughView()
                .fill(\(amber.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(1.8)
                .stroke(\(charcoal.snippet))
                .strokeWidth(1.5)
                .seed(160)
                .text(
                    "Top",
                    font: .systemFont(ofSize: 32, weight: .bold),
                    horizontalAlignment: .leading,
                    verticalAlignment: .top
                )
            """
        ) {
            RoughView()
                .fill(amber.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(1.8)
                .stroke(charcoal.color)
                .strokeWidth(1.5)
                .seed(160)
                .text(
                    "Top",
                    font: .systemFont(ofSize: 32, weight: .bold),
                    horizontalAlignment: .leading,
                    verticalAlignment: .top
                )
        },
        still(
            "offset-text",
            section: "Text",
            title: "Offset text",
            description: "offsetX and offsetY move a centered word. Positive x goes right and positive y goes down.",
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(1.8)
                .stroke(\(charcoal.snippet))
                .strokeWidth(1.5)
                .seed(164)
                .text(
                    "Hi",
                    font: .systemFont(ofSize: 40, weight: .bold),
                    offsetX: 24,
                    offsetY: 32
                )
            """
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(1.8)
                .stroke(charcoal.color)
                .strokeWidth(1.5)
                .seed(164)
                .text(
                    "Hi",
                    font: .systemFont(ofSize: 40, weight: .bold),
                    offsetX: 24,
                    offsetY: 32
                )
        },
        still(
            "attributed-text",
            section: "Text",
            title: "Attributed text",
            description: "An attributed string can mix sizes in one run. The bang uses a smaller font than the letters.",
            snippet: """
            let title = NSMutableAttributedString(
                string: "Hi!",
                attributes: [.font: UIFont.systemFont(ofSize: 64, weight: .heavy)]
            )
            title.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: 28, weight: .regular),
                range: NSRange(location: 2, length: 1)
            )
            RoughView()
                .fill(\(plum.snippet))
                .fillStyle(.solid)
                .stroke(\(charcoal.snippet))
                .strokeWidth(1.5)
                .seed(168)
                .text(attributedString: title)
            """
        ) {
            let title = NSMutableAttributedString(
                string: "Hi!",
                attributes: [.font: UIFont.systemFont(ofSize: 64, weight: .heavy)]
            )
            title.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: 28, weight: .regular),
                range: NSRange(location: 2, length: 1)
            )
            return RoughView()
                .fill(plum.color)
                .fillStyle(.solid)
                .stroke(charcoal.color)
                .strokeWidth(1.5)
                .seed(168)
                .text(attributedString: title)
        },
        still(
            "rough-text",
            section: "Text",
            title: "RoughText",
            description: "RoughText sizes itself to the glyphs, so the word keeps its size beside a shape that fills the rest of the card.",
            snippet: """
            HStack(spacing: 12) {
                RoughText("Hi", font: .systemFont(ofSize: 44, weight: .heavy))
                    .fill(\(coral.snippet))
                    .fillStyle(.hachure)
                    .fillAngle(45)
                    .fillSpacing(1.6)
                    .stroke(\(charcoal.snippet))
                    .strokeWidth(1.5)
                    .seed(172)
                RoughView()
                    .fill(\(sea.snippet))
                    .fillStyle(.solid)
                    .stroke(\(charcoal.snippet))
                    .strokeWidth(2)
                    .seed(173)
                    .circle()
            }
            """,
            picture: .roughTextBesideCircle
        ) {
            roughTextCircle()
        }
    ]

    static func roughTextLabel() -> RoughText {
        RoughText("Hi", font: .systemFont(ofSize: 44, weight: .heavy))
            .fill(coral.color)
            .fillStyle(.hachure)
            .fillAngle(45)
            .fillSpacing(1.6)
            .stroke(charcoal.color)
            .strokeWidth(1.5)
            .seed(172)
    }

    static func roughTextCircle() -> RoughView {
        RoughView()
            .fill(sea.color)
            .fillStyle(.solid)
            .stroke(charcoal.color)
            .strokeWidth(2)
            .seed(173)
            .circle()
    }

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

/// Word at its own size beside a circle that fills the remaining card.
struct DocRoughTextCard: View {
    var body: some View {
        HStack(spacing: 12) {
            DocExampleCatalog.roughTextLabel()
            DocExampleCatalog.roughTextCircle()
        }
    }
}
