import SwiftUI
@testable import Sketchy

extension DocExampleCatalog {
    /// Five-point star inside the 184-point card. The slate mat is gallery chrome.
    private static let stickerStarPoints = """
        Point(x: 92, y: 36),
        Point(x: 106, y: 73),
        Point(x: 145, y: 75),
        Point(x: 115, y: 99),
        Point(x: 125, y: 137),
        Point(x: 92, y: 116),
        Point(x: 59, y: 137),
        Point(x: 69, y: 99),
        Point(x: 39, y: 75),
        Point(x: 78, y: 73)
    """

    private static func stickerStar() -> Polygon {
        Polygon(points: [
            Point(x: 92, y: 36),
            Point(x: 106, y: 73),
            Point(x: 145, y: 75),
            Point(x: 115, y: 99),
            Point(x: 125, y: 137),
            Point(x: 92, y: 116),
            Point(x: 59, y: 137),
            Point(x: 69, y: 99),
            Point(x: 39, y: 75),
            Point(x: 78, y: 73)
        ])
    }

    static let stickerExamples: [DocExample] = [
        still(
            "sticker-star",
            section: "Stickers",
            title: "Sticker star",
            description: "White paper past the stroke. Smoothness 0.85 follows the star and drops the sketch wobble. The slate mat is only in the gallery so the white margin shows.",
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .roughness(1.4)
                .seed(42)
                .stickerBacking(width: 14, smoothness: 0.85)
                .draw(Polygon(points: [
                    \(stickerStarPoints)
                ]))
            """,
            picture: .stickerMat
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .roughness(1.4)
                .seed(42)
                .stickerBacking(width: 14, smoothness: 0.85)
                .draw(stickerStar())
        },
        still(
            "sticker-torn",
            section: "Stickers",
            title: "Torn sticker",
            description: "The same star with a chopped edge. Depth, facet length, and jaggedness are seeded, so the tear repeats.",
            snippet: """
            RoughView()
                .fill(\(coral.snippet))
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .roughness(1.4)
                .seed(42)
                .stickerBacking(
                    width: 16,
                    smoothness: 0.55,
                    edge: .torn(StickerTear(depth: 7, length: 14, jaggedness: 0.45))
                )
                .draw(Polygon(points: [
                    \(stickerStarPoints)
                ]))
            """,
            picture: .stickerMat
        ) {
            RoughView()
                .fill(coral.color)
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .roughness(1.4)
                .seed(42)
                .stickerBacking(
                    width: 16,
                    smoothness: 0.55,
                    edge: .torn(StickerTear(depth: 7, length: 14, jaggedness: 0.45))
                )
                .draw(stickerStar())
        },
        still(
            "sticker-crayon",
            section: "Stickers",
            title: "Crayon on paper",
            description: "The wax stroke paints on top of the sheet. A wider margin keeps most of the grit on the paper.",
            snippet: """
            RoughView()
                .fill(\(plum.snippet))
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(3.5)
                .stroke(\(plum.snippet))
                .strokeWidth(12)
                .brushProfile(.crayon(seed: 4))
                .seed(4)
                .stickerBacking(width: 18, smoothness: 0.7)
                .circle()
            """,
            picture: .stickerMat
        ) {
            RoughView()
                .fill(plum.color)
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(3.5)
                .stroke(plum.color)
                .strokeWidth(12)
                .brushProfile(.crayon(seed: 4))
                .seed(4)
                .stickerBacking(width: 18, smoothness: 0.7)
                .circle()
        }
    ]
}