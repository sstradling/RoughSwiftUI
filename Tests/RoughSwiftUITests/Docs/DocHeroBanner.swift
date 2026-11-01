import SwiftUI
@testable import RoughSwiftUI

/// The four drawings in the README banner. Each one carries its own seed.
enum DocHeroParts {
    static func hachureRectangle() -> RoughView {
        RoughView()
            .fill(DocExampleCatalog.inkBlue.color)
            .fillStyle(.hachure)
            .fillAngle(45)
            .fillSpacing(3)
            .stroke(DocExampleCatalog.charcoal.color)
            .strokeWidth(2)
            .seed(42)
            .rectangle()
    }

    static func crossHatchCircle() -> RoughView {
        RoughView()
            .fill(DocExampleCatalog.coral.color)
            .fillStyle(.crossHatch)
            .fillAngle(30)
            .fillSpacing(3)
            .stroke(DocExampleCatalog.charcoal.color)
            .strokeWidth(2)
            .seed(11)
            .circle()
    }

    static func sunburstEgg() -> RoughView {
        RoughView()
            .fill(DocExampleCatalog.amber.color)
            .fillStyle(.sunBurst)
            .fillSpacing(2.5)
            .stroke(DocExampleCatalog.charcoal.color)
            .strokeWidth(2)
            .seed(18)
            .egg(tilt: 0.4)
    }

    static func crayonCircle() -> RoughView {
        RoughView()
            .stroke(DocExampleCatalog.plum.color)
            .strokeWidth(10)
            .brushProfile(.crayon(grit: 0.95, flakeSize: 1.5, seed: 4))
            .seed(4)
            .circle()
    }

    static func sketches() -> [RoughView] {
        [hachureRectangle(), crossHatchCircle(), sunburstEgg(), crayonCircle()]
    }
}

/// Paper-card row. The gallery renderer adds the card chrome around this stack.
struct DocHeroBanner: View {
    var body: some View {
        HStack(spacing: 16) {
            DocHeroParts.hachureRectangle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            DocHeroParts.crossHatchCircle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            DocHeroParts.sunburstEgg()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            DocHeroParts.crayonCircle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Wide still published as `docs/images/hero.png`.
struct DocHero {
    let id = "hero"
    let title = "RoughSwiftUI"
    let description = "Hachure, cross-hatch, sunburst, and crayon on one light paper card."
    let snippet: String
    let width: CGFloat
    let height: CGFloat
    let banner: () -> DocHeroBanner

    var outputRelativePath: String { "hero.png" }

    static let shared = DocHero(
        snippet: """
        HStack(spacing: 16) {
            RoughView()
                .fill(Color(red: 0.18, green: 0.46, blue: 0.67))
                .fillStyle(.hachure)
                .fillAngle(45)
                .fillSpacing(3)
                .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
                .strokeWidth(2)
                .seed(42)
                .rectangle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            RoughView()
                .fill(Color(red: 0.76, green: 0.32, blue: 0.28))
                .fillStyle(.crossHatch)
                .fillAngle(30)
                .fillSpacing(3)
                .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
                .strokeWidth(2)
                .seed(11)
                .circle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            RoughView()
                .fill(Color(red: 0.85, green: 0.55, blue: 0.18))
                .fillStyle(.sunBurst)
                .fillSpacing(2.5)
                .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
                .strokeWidth(2)
                .seed(18)
                .egg(tilt: 0.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            RoughView()
                .stroke(Color(red: 0.45, green: 0.28, blue: 0.55))
                .strokeWidth(10)
                .brushProfile(.crayon(grit: 0.95, flakeSize: 1.5, seed: 4))
                .seed(4)
                .circle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        """,
        width: 640,
        height: 240,
        banner: { DocHeroBanner() }
    )
}
