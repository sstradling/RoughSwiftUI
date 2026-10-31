import SwiftUI
@testable import RoughSwiftUI

extension DocExampleCatalog {
    static let strokeExamples: [DocExample] = [
        still(
            "several-lines",
            section: "Strokes",
            title: "Several strokes",
            description: "One view can draw several lines. Each outline is itself two offset passes.",
            snippet: """
            RoughView()
                .stroke(\(charcoal.snippet))
                .strokeWidth(2.5)
                .roughness(1.4)
                .seed(91)
                .draw(Line(from: Point(x: 28, y: 48), to: Point(x: 156, y: 48)))
                .draw(Line(from: Point(x: 28, y: 92), to: Point(x: 156, y: 92)))
                .draw(Line(from: Point(x: 28, y: 136), to: Point(x: 156, y: 136)))
            """
        ) {
            RoughView()
                .stroke(charcoal.color)
                .strokeWidth(2.5)
                .roughness(1.4)
                .seed(91)
                .draw(Line(from: Point(x: 28, y: 48), to: Point(x: 156, y: 48)))
                .draw(Line(from: Point(x: 28, y: 92), to: Point(x: 156, y: 92)))
                .draw(Line(from: Point(x: 28, y: 136), to: Point(x: 156, y: 136)))
        },
        still(
            "thick-stroke",
            section: "Strokes",
            title: "Thick stroke",
            description: "strokeWidth(12) with square caps and bevel joins on an open polyline.",
            snippet: """
            RoughView()
                .stroke(\(inkBlue.snippet))
                .strokeWidth(12)
                .strokeCap(.square)
                .strokeJoin(.bevel)
                .seed(97)
                .draw(LinearPath(points: [
                    Point(x: 28, y: 132),
                    Point(x: 70, y: 48),
                    Point(x: 114, y: 120),
                    Point(x: 156, y: 52)
                ]))
            """
        ) {
            RoughView()
                .stroke(inkBlue.color)
                .strokeWidth(12)
                .strokeCap(.square)
                .strokeJoin(.bevel)
                .seed(97)
                .draw(LinearPath(points: [
                    Point(x: 28, y: 132),
                    Point(x: 70, y: 48),
                    Point(x: 114, y: 120),
                    Point(x: 156, y: 52)
                ]))
        },
        still(
            "stroke-opacity",
            section: "Strokes",
            title: "Stroke opacity",
            description: "strokeOpacity takes 0 to 100. Here the outline is 40, over a solid fill.",
            snippet: """
            RoughView()
                .fill(\(coral.snippet))
                .fillStyle(.solid)
                .stroke(\(charcoal.snippet))
                .strokeWidth(8)
                .strokeOpacity(40)
                .seed(101)
                .circle()
            """
        ) {
            RoughView()
                .fill(coral.color)
                .fillStyle(.solid)
                .stroke(charcoal.color)
                .strokeWidth(8)
                .strokeOpacity(40)
                .seed(101)
                .circle()
        },
        still(
            "fill-opacity",
            section: "Strokes",
            title: "Fill opacity",
            description: "fillOpacity(35) lets the paper show through a solid interior.",
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.solid)
                .fillOpacity(35)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(104)
                .roundedRectangle(cornerRadius: 28)
            """
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.solid)
                .fillOpacity(35)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(104)
                .roundedRectangle(cornerRadius: 28)
        }
    ]

    static let roughnessExamples: [DocExample] = [
        still(
            "smooth",
            section: "Roughness",
            title: "Even outline",
            description: "Roughness, bowing, and maxRandomnessOffset at zero leave a nearly even double outline.",
            snippet: """
            RoughView()
                .fill(\(sea.snippet))
                .fillStyle(.solid)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .roughness(0)
                .bowing(0)
                .maxRandomnessOffset(0)
                .seed(108)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(sea.color)
                .fillStyle(.solid)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .roughness(0)
                .bowing(0)
                .maxRandomnessOffset(0)
                .seed(108)
                .rectangle()
        },
        still(
            "rough",
            section: "Roughness",
            title: "Rough outline",
            description: "roughness(2.8) scales the jitter on the outline and the fill.",
            snippet: """
            RoughView()
                .fill(\(amber.snippet))
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .roughness(2.8)
                .seed(111)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(amber.color)
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .roughness(2.8)
                .seed(111)
                .rectangle()
        },
        still(
            "bowed",
            section: "Roughness",
            title: "Bowed edges",
            description: "bowing(7) bends the long edges. Roughness stays low so the bend stays readable.",
            snippet: """
            RoughView()
                .fill(\(leaf.snippet))
                .fillStyle(.solid)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .roughness(0.4)
                .bowing(7)
                .maxRandomnessOffset(1.5)
                .seed(115)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(leaf.color)
                .fillStyle(.solid)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .roughness(0.4)
                .bowing(7)
                .maxRandomnessOffset(1.5)
                .seed(115)
                .rectangle()
        },
        still(
            "loose-wobble",
            section: "Roughness",
            title: "Loose double stroke",
            description: "maxRandomnessOffset(6) sets how far the two outline passes wander from the true edge.",
            snippet: """
            RoughView()
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .roughness(1.6)
                .bowing(1)
                .maxRandomnessOffset(6)
                .seed(120)
                .draw(Line(from: Point(x: 20, y: 92), to: Point(x: 164, y: 92)))
            """
        ) {
            RoughView()
                .stroke(charcoal.color)
                .strokeWidth(2)
                .roughness(1.6)
                .bowing(1)
                .maxRandomnessOffset(6)
                .seed(120)
                .draw(Line(from: Point(x: 20, y: 92), to: Point(x: 164, y: 92)))
        }
    ]

    static let brushExamples: [DocExample] = [
        still(
            "calligraphic",
            section: "Brushes",
            title: "Calligraphic brush",
            description: "The calligraphic preset uses a flat tip at 45° and tapered ends.",
            snippet: """
            RoughView()
                .stroke(\(inkBlue.snippet))
                .strokeWidth(8)
                .brushProfile(.calligraphic)
                .seed(123)
                .draw(Curve(points: [
                    Point(x: 24, y: 132),
                    Point(x: 64, y: 40),
                    Point(x: 116, y: 148),
                    Point(x: 160, y: 56)
                ]))
            """
        ) {
            RoughView()
                .stroke(inkBlue.color)
                .strokeWidth(8)
                .brushProfile(.calligraphic)
                .seed(123)
                .draw(Curve(points: [
                    Point(x: 24, y: 132),
                    Point(x: 64, y: 40),
                    Point(x: 116, y: 148),
                    Point(x: 160, y: 56)
                ]))
        },
        still(
            "marker",
            section: "Brushes",
            title: "Marker",
            description: "The marker preset is a flat tip with butt caps and bevel joins.",
            snippet: """
            RoughView()
                .stroke(\(coral.snippet))
                .strokeWidth(16)
                .brushProfile(.marker)
                .seed(127)
                .draw(Line(from: Point(x: 24, y: 140), to: Point(x: 160, y: 44)))
            """
        ) {
            RoughView()
                .stroke(coral.color)
                .strokeWidth(16)
                .brushProfile(.marker)
                .seed(127)
                .draw(Line(from: Point(x: 24, y: 140), to: Point(x: 160, y: 44)))
        },
        still(
            "pen",
            section: "Brushes",
            title: "Pen pressure",
            description: "The pen preset swells through the middle of the stroke.",
            snippet: """
            RoughView()
                .stroke(\(charcoal.snippet))
                .strokeWidth(7)
                .brushProfile(.pen)
                .seed(131)
                .draw(Curve(points: [
                    Point(x: 20, y: 110),
                    Point(x: 70, y: 36),
                    Point(x: 120, y: 150),
                    Point(x: 164, y: 72)
                ]))
            """
        ) {
            RoughView()
                .stroke(charcoal.color)
                .strokeWidth(7)
                .brushProfile(.pen)
                .seed(131)
                .draw(Curve(points: [
                    Point(x: 20, y: 110),
                    Point(x: 70, y: 36),
                    Point(x: 120, y: 150),
                    Point(x: 164, y: 72)
                ]))
        },
        still(
            "crayon",
            section: "Brushes",
            title: "Crayon stroke",
            description: "A wax ring. The crayon seed pins the grit, and strokeWidth is the wax width in points.",
            snippet: """
            RoughView()
                .stroke(\(plum.snippet))
                .strokeWidth(11)
                .brushProfile(.crayon(grit: 0.95, flakeSize: 1.5, seed: 4))
                .seed(4)
                .circle()
            """
        ) {
            RoughView()
                .stroke(plum.color)
                .strokeWidth(11)
                .brushProfile(.crayon(grit: 0.95, flakeSize: 1.5, seed: 4))
                .seed(4)
                .circle()
        },
        still(
            "crayon-fill",
            section: "Brushes",
            title: "Crayon fill",
            description: "Hachure lines use the same wax. fillWeight is the width of each line. The preset crayon seed follows Options.seed.",
            snippet: """
            RoughView()
                .fill(\(clay.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillWeight(3.5)
                .fillSpacing(2.4)
                .stroke(\(clay.snippet))
                .strokeWidth(5)
                .brushProfile(.crayon)
                .seed(12)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(clay.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillWeight(3.5)
                .fillSpacing(2.4)
                .stroke(clay.color)
                .strokeWidth(5)
                .brushProfile(.crayon)
                .seed(12)
                .rectangle()
        },
        still(
            "tapered-stroke",
            section: "Brushes",
            title: "Tapered pen",
            description: "thicknessProfile(.naturalPen) tapers both ends of an open curve.",
            snippet: """
            RoughView()
                .stroke(\(leaf.snippet))
                .strokeWidth(10)
                .thicknessProfile(.naturalPen)
                .seed(137)
                .draw(Curve(points: [
                    Point(x: 22, y: 120),
                    Point(x: 68, y: 40),
                    Point(x: 118, y: 146),
                    Point(x: 162, y: 64)
                ]))
            """
        ) {
            RoughView()
                .stroke(leaf.color)
                .strokeWidth(10)
                .thicknessProfile(.naturalPen)
                .seed(137)
                .draw(Curve(points: [
                    Point(x: 22, y: 120),
                    Point(x: 68, y: 40),
                    Point(x: 118, y: 146),
                    Point(x: 162, y: 64)
                ]))
        }
    ]
}
