import XCTest
@testable import RoughSwiftUI

/// Catalog invariants that stay on during a normal test run.
@MainActor
final class DocExampleCatalogTests: XCTestCase {
    private let galleryOrder = [
        "Basics",
        "Shapes",
        "Fills",
        "Strokes",
        "Roughness",
        "Brushes",
        "Seeding",
        "SVG",
        "Text",
        "Animation"
    ]

    func testGalleryOrderAndCounts() {
        var seen: [String] = []
        for example in DocExampleCatalog.examples {
            if seen.last != example.section {
                XCTAssertFalse(seen.contains(example.section), "section \(example.section) repeats")
                seen.append(example.section)
            }
        }
        XCTAssertEqual(seen, galleryOrder)

        let stills = DocExampleCatalog.examples.filter { example in
            if case .still = example.kind { return true }
            return false
        }
        let gifs = DocExampleCatalog.examples.filter { example in
            if case .gif = example.kind { return true }
            return false
        }
        XCTAssertEqual(stills.count, 53)
        XCTAssertEqual(gifs.count, 7)
    }

    func testPilotExamplesStayInTheCatalog() {
        let ids = Set(DocExampleCatalog.examples.map(\.id))
        XCTAssertTrue(ids.contains("hachure-rectangle"))
        XCTAssertTrue(ids.contains("horizontal-hachure"))
        XCTAssertTrue(ids.contains("breathing-circle"))

        let breathing = example("breathing-circle")
        guard case let .gif(frameCount, fps) = breathing.kind else {
            return XCTFail("breathing-circle should stay a GIF")
        }
        XCTAssertEqual(frameCount, 6)
        XCTAssertEqual(fps, 8)
        XCTAssertEqual(breathing.animation?.seed, 42)
    }

    func testFillAnglesCoverHorizontalDiagonalAndVertical() {
        XCTAssertEqual(example("hachure-rectangle").view().options.fillAngle, 45)
        XCTAssertEqual(example("horizontal-hachure").view().options.fillAngle, 0)
        XCTAssertEqual(example("clockwise-hachure").view().options.fillAngle, 20)
        XCTAssertEqual(example("vertical-hachure").view().options.fillAngle, 90)
        XCTAssertTrue(example("horizontal-hachure").snippet.contains(".fillAngle(0)"))
    }

    func testSameSeedIsRepeatedAndADifferentSeedDiverges() {
        let first = example("seed-seven")
        let second = example("seed-seven-again")
        let other = example("seed-ninety-nine")
        XCTAssertEqual(first.view().options.seed, 7)
        XCTAssertEqual(second.view().options.seed, 7)
        XCTAssertEqual(other.view().options.seed, 99)
        XCTAssertEqual(first.view().options.roughness, second.view().options.roughness)
        XCTAssertEqual(first.view().options.roughness, other.view().options.roughness)
        XCTAssertEqual(first.view().options.fillAngle, second.view().options.fillAngle)
    }

    func testCrayonExamplesCarryACrayonProfile() {
        XCTAssertNotNil(example("crayon").view().options.brushProfile.crayon)
        XCTAssertNotNil(example("crayon-fill").view().options.brushProfile.crayon)
        XCTAssertEqual(example("crayon").view().options.brushProfile.crayon?.seed, 4)
    }

    func testHeroIsAWideSeededPaperCard() {
        let hero = DocExampleCatalog.hero
        XCTAssertEqual(hero.outputRelativePath, "hero.png")
        XCTAssertGreaterThan(hero.width, DocExampleCatalog.tileSide)
        XCTAssertEqual(hero.height, DocExampleCatalog.tileSide)
        XCTAssertTrue(hero.snippet.hasPrefix("HStack(spacing: 16)"))
        XCTAssertEqual(hero.snippet.components(separatedBy: ".seed(").count - 1, 4)
        let seeds = DocHeroParts.sketches().compactMap(\.options.seed)
        XCTAssertEqual(seeds, [42, 11, 18, 4])
        XCTAssertNotNil(DocHeroParts.crayonCircle().options.brushProfile.crayon)
    }

    func testTextPlacementExamplesKeepTheirArguments() {
        let leading = example("leading-text").view().drawables.first as? FullText
        XCTAssertEqual(leading?.horizontalAlignment, .leading)
        XCTAssertEqual(leading?.verticalAlignment, .top)

        let offset = example("offset-text").view().drawables.first as? FullText
        XCTAssertEqual(offset?.offsetX, 24)
        XCTAssertEqual(offset?.offsetY, 32)

        XCTAssertTrue(example("attributed-text").view().drawables.first is FullText)
        XCTAssertEqual(example("rough-text").picture, .roughTextBesideCircle)
        XCTAssertEqual(example("rough-text").view().options.seed, 173)
    }

    func testEveryExampleIsSeededAndAddressable() {
        var seen = Set<String>()
        for example in DocExampleCatalog.examples {
            XCTAssertTrue(seen.insert(example.id).inserted, "duplicate id \(example.id)")
            XCTAssertFalse(example.section.isEmpty)
            XCTAssertFalse(example.title.isEmpty)
            XCTAssertFalse(example.description.isEmpty)
            XCTAssertFalse(example.snippet.isEmpty)
            XCTAssertNotNil(example.view().options.seed, "\(example.id) is missing Options.seed")
            XCTAssertTrue(
                example.snippet.contains(".seed("),
                "\(example.id) snippet should show the seed"
            )
            XCTAssertFalse(
                example.snippet.hasPrefix(" ") || example.snippet.hasPrefix("\n"),
                "\(example.id) snippet should be unindented source"
            )
            XCTAssertTrue(
                example.snippet.hasPrefix("RoughView()")
                    || example.snippet.hasPrefix("HStack(")
                    || example.snippet.hasPrefix("let "),
                "\(example.id) snippet should start with the drawing source"
            )
            XCTAssertEqual(example.canvasWidth, DocExampleCatalog.tileSide)
            XCTAssertEqual(example.canvasHeight, DocExampleCatalog.tileSide)

            switch example.kind {
            case .still:
                XCTAssertNil(example.animation)
            case let .gif(frameCount, fps):
                XCTAssertGreaterThanOrEqual(frameCount, 2)
                XCTAssertGreaterThan(fps, 0)
                XCTAssertEqual(example.animation?.steps, frameCount)
                XCTAssertNotNil(example.animation?.seed, "\(example.id) is missing AnimationConfig.seed")
                XCTAssertTrue(example.snippet.contains("AnimationConfig"))
            }
        }
    }

    private func example(_ id: String) -> DocExample {
        guard let found = DocExampleCatalog.examples.first(where: { $0.id == id }) else {
            XCTFail("missing example \(id)")
            fatalError("missing example \(id)")
        }
        return found
    }
}
