import SwiftUI
@testable import RoughSwiftUI

extension DocExampleCatalog {
    static let fillExamples: [DocExample] = [
        still(
            "horizontal-hachure",
            section: "Fills",
            title: "Horizontal hachure",
            description: "Hachure at 0° runs horizontally. Positive angles rotate clockwise.",
            snippet: """
            RoughView()
                .fill(\(coral.snippet))
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(2.5)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(11)
                .circle()
            """
        ) {
            RoughView()
                .fill(coral.color)
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(2.5)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(11)
                .circle()
        },
        still(
            "vertical-hachure",
            section: "Fills",
            title: "Vertical hachure",
            description: "Hachure at 90° runs from top to bottom.",
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.hachure)
                .fillAngle(90)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(31)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.hachure)
                .fillAngle(90)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(31)
                .rectangle()
        },
        still(
            "clockwise-hachure",
            section: "Fills",
            title: "Clockwise hachure",
            description: "20° is a shallow clockwise slope from the horizontal axis.",
            snippet: """
            RoughView()
                .fill(\(leaf.snippet))
                .fillStyle(.hachure)
                .fillAngle(20)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(33)
                .circle()
            """
        ) {
            RoughView()
                .fill(leaf.color)
                .fillStyle(.hachure)
                .fillAngle(20)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(33)
                .circle()
        },
        still(
            "solid-fill",
            section: "Fills",
            title: "Solid fill",
            description: "A solid interior. The outline stays sketchy.",
            snippet: """
            RoughView()
                .fill(\(amber.snippet))
                .fillStyle(.solid)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(36)
                .circle()
            """
        ) {
            RoughView()
                .fill(amber.color)
                .fillStyle(.solid)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(36)
                .circle()
        },
        still(
            "zigzag-fill",
            section: "Fills",
            title: "Zigzag fill",
            description: "Hachure lines joined at the ends, so the fill is one zigzagging stroke.",
            snippet: """
            RoughView()
                .fill(\(plum.snippet))
                .fillStyle(.zigzag)
                .fillAngle(40)
                .fillSpacing(3.5)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(37)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(plum.color)
                .fillStyle(.zigzag)
                .fillAngle(40)
                .fillSpacing(3.5)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(37)
                .rectangle()
        },
        still(
            "cross-hatch",
            section: "Fills",
            title: "Cross-hatch",
            description: "Two hachure passes. The second sits across the first.",
            snippet: """
            RoughView()
                .fill(\(sea.snippet))
                .fillStyle(.crossHatch)
                .fillAngle(30)
                .fillSpacing(3.5)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(41)
                .circle()
            """
        ) {
            RoughView()
                .fill(sea.color)
                .fillStyle(.crossHatch)
                .fillAngle(30)
                .fillSpacing(3.5)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(41)
                .circle()
        },
        still(
            "dots",
            section: "Fills",
            title: "Dots",
            description: "A dot grid. Dots stay on the horizontal lattice and ignore fillAngle.",
            snippet: """
            RoughView()
                .fill(\(clay.snippet))
                .fillStyle(.dots)
                .fillSpacing(2.2)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(44)
                .circle()
            """
        ) {
            RoughView()
                .fill(clay.color)
                .fillStyle(.dots)
                .fillSpacing(2.2)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(44)
                .circle()
        },
        still(
            "dashed-fill",
            section: "Fills",
            title: "Dashed fill",
            description: "Hachure broken into dashes. dashOffset is the dash length and dashGap is the skip.",
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.dashed)
                .fillAngle(45)
                .fillSpacing(3)
                .dashOffset(12)
                .dashGap(8)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(48)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.dashed)
                .fillAngle(45)
                .fillSpacing(3)
                .dashOffset(12)
                .dashGap(8)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(48)
                .rectangle()
        },
        still(
            "zigzag-line",
            section: "Fills",
            title: "Zigzag line",
            description: "Each hachure line is itself a zigzag. zigzagOffset(14) sets the size of those peaks.",
            snippet: """
            RoughView()
                .fill(\(leaf.snippet))
                .fillStyle(.zigzagLine)
                .fillAngle(0)
                .fillSpacing(4)
                .zigzagOffset(14)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(52)
                .circle()
            """
        ) {
            RoughView()
                .fill(leaf.color)
                .fillStyle(.zigzagLine)
                .fillAngle(0)
                .fillSpacing(4)
                .zigzagOffset(14)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(52)
                .circle()
        },
        still(
            "sunburst",
            section: "Fills",
            title: "Sunburst",
            description: "Rays from the center. .starBurst draws this same radial filler.",
            snippet: """
            RoughView()
                .fill(\(amber.snippet))
                .fillStyle(.sunBurst)
                .fillSpacing(2.2)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(55)
                .circle()
            """
        ) {
            RoughView()
                .fill(amber.color)
                .fillStyle(.sunBurst)
                .fillSpacing(2.2)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(55)
                .circle()
        },
        still(
            "scribble",
            section: "Fills",
            title: "Scribble",
            description: "One continuous zig-zag that crosses the shape. The bearing comes from scribbleOrigin.",
            snippet: """
            RoughView()
                .fill(\(plum.snippet))
                .fillStyle(.scribble)
                .scribble(origin: 18, tightness: 14, curvature: 0)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(61)
                .circle()
            """
        ) {
            RoughView()
                .fill(plum.color)
                .fillStyle(.scribble)
                .scribble(origin: 18, tightness: 14, curvature: 0)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(61)
                .circle()
        },
        still(
            "heavy-fill",
            section: "Fills",
            title: "Heavy fill lines",
            description: "fillWeight(5) thickens each hachure line. fillSpacing(1.6) keeps them close.",
            snippet: """
            RoughView()
                .fill(\(coral.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillWeight(5)
                .fillSpacing(1.6)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(64)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(coral.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillWeight(5)
                .fillSpacing(1.6)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(64)
                .rectangle()
        },
        still(
            "wide-gap",
            section: "Fills",
            title: "Wide fill gap",
            description: "fillSpacing(9) opens the gap between thin hachure lines. The factor multiplies fillWeight.",
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillWeight(1.5)
                .fillSpacing(9)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(67)
                .circle()
            """
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillWeight(1.5)
                .fillSpacing(9)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(67)
                .circle()
        },
        still(
            "spacing-pattern",
            section: "Fills",
            title: "Spacing pattern",
            description: "fillSpacingPattern stacks a hachure pass for each multiplier of fillSpacing. The tightest pass covers the shape.",
            snippet: """
            RoughView()
                .fill(\(leaf.snippet))
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillWeight(2)
                .fillSpacing(2)
                .fillSpacingPattern([1, 1, 2, 3, 5, 8])
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(71)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(leaf.color)
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillWeight(2)
                .fillSpacing(2)
                .fillSpacingPattern([1, 1, 2, 3, 5, 8])
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(71)
                .rectangle()
        },
        still(
            "curved-scribble",
            section: "Fills",
            title: "Curved scribble",
            description: "scribbleOrigin(110) aims the strokes, tightness(11) sets the count, and curvature(36) rounds the corners.",
            snippet: """
            RoughView()
                .fill(\(amber.snippet))
                .fillStyle(.scribble)
                .scribble(origin: 110, tightness: 11, curvature: 36)
                .fillWeight(2)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(77)
                .roundedRectangle(cornerRadius: 28)
            """
        ) {
            RoughView()
                .fill(amber.color)
                .fillStyle(.scribble)
                .scribble(origin: 110, tightness: 11, curvature: 36)
                .fillWeight(2)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(77)
                .roundedRectangle(cornerRadius: 28)
        },
        still(
            "scribble-bands",
            section: "Fills",
            title: "Scribble bands",
            description: "A tightness pattern splits the traversal into sparse and dense bands.",
            snippet: """
            RoughView()
                .fill(\(sea.snippet))
                .fillStyle(.scribble)
                .scribble(origin: 90, tightnessPattern: [6, 24, 8, 28], curvature: 10)
                .fillWeight(1.8)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(81)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(sea.color)
                .fillStyle(.scribble)
                .scribble(origin: 90, tightnessPattern: [6, 24, 8, 28], curvature: 10)
                .fillWeight(1.8)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(81)
                .rectangle()
        },
        still(
            "brush-scribble",
            section: "Fills",
            title: "Brush scribble",
            description: "scribbleUseBrushStroke draws the zig-zag with the current brush. This one uses the calligraphic preset.",
            snippet: """
            RoughView()
                .fill(\(plum.snippet))
                .fillStyle(.scribble)
                .scribble(origin: 75, tightness: 12, curvature: 8, useBrushStroke: true)
                .fillWeight(6)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .brushProfile(.calligraphic)
                .seed(88)
                .circle()
            """
        ) {
            RoughView()
                .fill(plum.color)
                .fillStyle(.scribble)
                .scribble(origin: 75, tightness: 12, curvature: 8, useBrushStroke: true)
                .fillWeight(6)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .brushProfile(.calligraphic)
                .seed(88)
                .circle()
        }
    ]
}
