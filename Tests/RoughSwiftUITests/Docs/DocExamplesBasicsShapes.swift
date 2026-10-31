import SwiftUI
@testable import RoughSwiftUI

extension DocExampleCatalog {
    static let basicExamples: [DocExample] = [
        still(
            "hachure-rectangle",
            section: "Basics",
            title: "Hachure rectangle",
            description: "A seeded rectangle with hachure at 45°, the default fill angle.",
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(42)
                .rectangle()
            """
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(42)
                .rectangle()
        }
    ]

    static let shapeExamples: [DocExample] = [
        still(
            "ellipse",
            section: "Shapes",
            title: "Ellipse",
            description: "An ellipse placed by center, width, and height inside the card.",
            snippet: """
            RoughView()
                .fill(\(inkBlue.snippet))
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(14)
                .draw(Ellipse(x: 92, y: 92, width: 150, height: 108))
            """
        ) {
            RoughView()
                .fill(inkBlue.color)
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(14)
                .draw(Ellipse(x: 92, y: 92, width: 150, height: 108))
        },
        still(
            "circle",
            section: "Shapes",
            title: "Circle",
            description: "A circle that fills the card. The diameter follows the shorter side.",
            snippet: """
            RoughView()
                .fill(\(plum.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(15)
                .circle()
            """
        ) {
            RoughView()
                .fill(plum.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(15)
                .circle()
        },
        still(
            "line",
            section: "Shapes",
            title: "Line",
            description: "A single line from one point to another. The outline is two offset passes.",
            snippet: """
            RoughView()
                .stroke(\(charcoal.snippet))
                .strokeWidth(3)
                .roughness(1.3)
                .seed(16)
                .draw(Line(from: Point(x: 24, y: 140), to: Point(x: 160, y: 44)))
            """
        ) {
            RoughView()
                .stroke(charcoal.color)
                .strokeWidth(3)
                .roughness(1.3)
                .seed(16)
                .draw(Line(from: Point(x: 24, y: 140), to: Point(x: 160, y: 44)))
        },
        still(
            "open-arc",
            section: "Shapes",
            title: "Open arc",
            description: "An arc in radians. This one stays open, so it is a stroke without a pie fill.",
            snippet: """
            RoughView()
                .stroke(\(inkBlue.snippet))
                .strokeWidth(3)
                .seed(17)
                .draw(Arc(
                    x: 92,
                    y: 96,
                    width: 140,
                    height: 140,
                    start: Float.pi * 0.15,
                    stop: Float.pi * 0.85,
                    closed: false
                ))
            """
        ) {
            RoughView()
                .stroke(inkBlue.color)
                .strokeWidth(3)
                .seed(17)
                .draw(Arc(
                    x: 92,
                    y: 96,
                    width: 140,
                    height: 140,
                    start: Float.pi * 0.15,
                    stop: Float.pi * 0.85,
                    closed: false
                ))
        },
        still(
            "closed-arc",
            section: "Shapes",
            title: "Closed arc",
            description: "A closed arc draws the chord back to the center and fills the wedge.",
            snippet: """
            RoughView()
                .fill(\(coral.snippet))
                .fillStyle(.hachure)
                .fillSpacing(2.5)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(19)
                .draw(Arc(
                    x: 92,
                    y: 100,
                    width: 140,
                    height: 140,
                    start: -Float.pi / 2,
                    stop: Float.pi / 2,
                    closed: true
                ))
            """
        ) {
            RoughView()
                .fill(coral.color)
                .fillStyle(.hachure)
                .fillSpacing(2.5)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(19)
                .draw(Arc(
                    x: 92,
                    y: 100,
                    width: 140,
                    height: 140,
                    start: -Float.pi / 2,
                    stop: Float.pi / 2,
                    closed: true
                ))
        },
        still(
            "polygon",
            section: "Shapes",
            title: "Polygon",
            description: "A closed polygon through the given points. The last edge joins back to the first.",
            snippet: """
            RoughView()
                .fill(\(leaf.snippet))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(21)
                .draw(Polygon(points: [
                    Point(x: 92, y: 22),
                    Point(x: 162, y: 158),
                    Point(x: 22, y: 158)
                ]))
            """
        ) {
            RoughView()
                .fill(leaf.color)
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(21)
                .draw(Polygon(points: [
                    Point(x: 92, y: 22),
                    Point(x: 162, y: 158),
                    Point(x: 22, y: 158)
                ]))
        },
        still(
            "linear-path",
            section: "Shapes",
            title: "Linear path",
            description: "An open polyline. Unlike a polygon, the ends are not joined and there is no fill.",
            snippet: """
            RoughView()
                .stroke(\(charcoal.snippet))
                .strokeWidth(2.5)
                .seed(23)
                .draw(LinearPath(points: [
                    Point(x: 16, y: 140),
                    Point(x: 52, y: 44),
                    Point(x: 92, y: 112),
                    Point(x: 132, y: 36),
                    Point(x: 168, y: 140)
                ]))
            """
        ) {
            RoughView()
                .stroke(charcoal.color)
                .strokeWidth(2.5)
                .seed(23)
                .draw(LinearPath(points: [
                    Point(x: 16, y: 140),
                    Point(x: 52, y: 44),
                    Point(x: 92, y: 112),
                    Point(x: 132, y: 36),
                    Point(x: 168, y: 140)
                ]))
        },
        still(
            "curve",
            section: "Shapes",
            title: "Curve",
            description: "A spline through the points. curveTightness(0.8) pulls it toward those points.",
            snippet: """
            RoughView()
                .stroke(\(inkBlue.snippet))
                .strokeWidth(3)
                .curveTightness(0.8)
                .seed(24)
                .draw(Curve(points: [
                    Point(x: 20, y: 124),
                    Point(x: 60, y: 36),
                    Point(x: 112, y: 150),
                    Point(x: 164, y: 60)
                ]))
            """
        ) {
            RoughView()
                .stroke(inkBlue.color)
                .strokeWidth(3)
                .curveTightness(0.8)
                .seed(24)
                .draw(Curve(points: [
                    Point(x: 20, y: 124),
                    Point(x: 60, y: 36),
                    Point(x: 112, y: 150),
                    Point(x: 164, y: 60)
                ]))
        },
        still(
            "rounded-rectangle",
            section: "Shapes",
            title: "Rounded rectangle",
            description: "A full-card rectangle with a shared corner radius of 36 points.",
            snippet: """
            RoughView()
                .fill(\(amber.snippet))
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .seed(27)
                .roundedRectangle(cornerRadius: 36)
            """
        ) {
            RoughView()
                .fill(amber.color)
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .seed(27)
                .roundedRectangle(cornerRadius: 36)
        },
        still(
            "egg",
            section: "Shapes",
            title: "Egg",
            description: "tilt 0.4 narrows the top. curveStepCount(16) sets how many samples build the outline.",
            snippet: """
            RoughView()
                .fill(\(plum.snippet))
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(\(charcoal.snippet))
                .strokeWidth(2)
                .curveStepCount(16)
                .seed(28)
                .egg(tilt: 0.4)
            """
        ) {
            RoughView()
                .fill(plum.color)
                .fillStyle(.hachure)
                .fillSpacing(3)
                .stroke(charcoal.color)
                .strokeWidth(2)
                .curveStepCount(16)
                .seed(28)
                .egg(tilt: 0.4)
        }
    ]
}
