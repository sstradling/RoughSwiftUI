import XCTest
@testable import RoughSwiftUI

/// Catalog invariants that stay on during a normal test run.
@MainActor
final class DocExampleCatalogTests: XCTestCase {
    func testPhaseTwoPilotsAreTheThreeAgreedExamples() {
        XCTAssertEqual(
            DocExampleCatalog.examples.map(\.id),
            ["hachure-rectangle", "horizontal-hachure", "breathing-circle"]
        )
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
            XCTAssertTrue(
                example.snippet.hasPrefix("RoughView()"),
                "\(example.id) snippet should be unindented source"
            )

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

    func testHorizontalHachureSnippetUsesZeroDegrees() {
        let example = DocExampleCatalog.examples.first { $0.id == "horizontal-hachure" }
        XCTAssertEqual(example?.view().options.fillAngle, 0)
        XCTAssertTrue(example?.snippet.contains(".fillAngle(0)") == true)
    }
}
