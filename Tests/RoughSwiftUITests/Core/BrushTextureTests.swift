//
//  BrushTextureTests.swift
//  RoughSwiftUITests
//
//  Verifies the BrushTexture enum, the new Options.brushTexture field,
//  cache-hash inclusion, equality, and the RoughView/RoughText modifiers.
//

import XCTest
@testable import RoughSwiftUI

@MainActor
final class BrushTextureTests: XCTestCase {

    // MARK: Defaults

    func testBrushTextureDefaultsToSmooth() {
        XCTAssertEqual(Options().brushTexture, .smooth)
        XCTAssertTrue(Options().brushTexture.isSmooth)
    }

    func testIsSmoothIsFalseForOtherCases() {
        XCTAssertFalse(BrushTexture.pencil().isSmooth)
        XCTAssertFalse(BrushTexture.chalk().isSmooth)
        XCTAssertFalse(BrushTexture.ink().isSmooth)
        XCTAssertFalse(BrushTexture.watercolor().isSmooth)
    }

    // MARK: Equality

    func testEqualityDistinguishesParameters() {
        XCTAssertEqual(BrushTexture.pencil(grain: 1.5, density: 0.7),
                       BrushTexture.pencil(grain: 1.5, density: 0.7))
        XCTAssertNotEqual(BrushTexture.pencil(grain: 1.5, density: 0.7),
                          BrushTexture.pencil(grain: 1.5, density: 0.5))
        XCTAssertNotEqual(BrushTexture.pencil(grain: 2.0, density: 0.7),
                          BrushTexture.chalk(grain: 2.0, density: 0.7))
    }

    // MARK: cacheHash

    func testBrushTextureIsPartOfCacheHash() {
        var a = Options()
        var b = Options()
        XCTAssertEqual(a.cacheHash, b.cacheHash)

        a.brushTexture = .pencil()
        XCTAssertNotEqual(a.cacheHash, b.cacheHash,
                          "Cache hash must include brushTexture")
    }

    func testDifferentTextureParamsHashDifferently() {
        var a = Options()
        var b = Options()
        a.brushTexture = .pencil(grain: 1.0, density: 0.5)
        b.brushTexture = .pencil(grain: 2.0, density: 0.5)
        XCTAssertNotEqual(a.cacheHash, b.cacheHash,
                          "Different texture parameters must produce different cache hashes")
    }

    // MARK: Options equality

    func testOptionsEqualityIncludesBrushTexture() {
        var a = Options()
        var b = Options()
        XCTAssertEqual(a, b)

        a.brushTexture = .pencil()
        XCTAssertNotEqual(a, b)
        b.brushTexture = .pencil()
        XCTAssertEqual(a, b)
    }

    // MARK: Modifier wiring on RoughView

    func testBrushTextureModifierSetsOption() {
        let view = RoughView().brushTexture(.chalk(grain: 2, density: 0.4))
        XCTAssertEqual(view.options.brushTexture,
                       .chalk(grain: 2, density: 0.4))
    }

    func testPencilTextureConvenienceUsesDefaults() {
        let view = RoughView().pencilTexture()
        XCTAssertEqual(view.options.brushTexture,
                       .pencil(grain: 1.5, density: 0.7))
    }

    func testPencilTextureConvenienceForwardsExplicitArgs() {
        let view = RoughView().pencilTexture(grain: 3, density: 0.2)
        XCTAssertEqual(view.options.brushTexture,
                       .pencil(grain: 3, density: 0.2))
    }

    func testInkTextureConvenienceUsesDefaults() {
        let view = RoughView().inkTexture()
        XCTAssertEqual(view.options.brushTexture, .ink(bleed: 0.6))
    }

    func testWatercolorTextureConvenienceUsesDefaults() {
        let view = RoughView().watercolorTexture()
        XCTAssertEqual(view.options.brushTexture,
                       .watercolor(edgeDarkness: 0.5, bleed: 0.4))
    }

    func testChalkTextureConvenienceUsesDefaults() {
        let view = RoughView().chalkTexture()
        XCTAssertEqual(view.options.brushTexture,
                       .chalk(grain: 0.8, density: 0.55))
    }
}
