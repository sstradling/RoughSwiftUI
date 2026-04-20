//
//  StrokeAppearanceOptionsTests.swift
//  RoughSwiftUITests
//
//  Verifies the new variable-stroke-appearance fields on Options:
//  defaults, equality, hash inclusion, and modifier wiring on
//  RoughView/RoughText.
//

import XCTest
@testable import RoughSwiftUI

@MainActor
final class StrokeAppearanceOptionsTests: XCTestCase {

    // MARK: Defaults

    func testStrokeColorAlongPathDefaultsToNil() {
        XCTAssertNil(Options().strokeColorAlongPath)
    }

    func testStrokeOpacityAlongPathDefaultsToNil() {
        XCTAssertNil(Options().strokeOpacityAlongPath)
    }

    func testStrokeEdgeSoftnessDefaultsToZero() {
        XCTAssertEqual(Options().strokeEdgeSoftness, 0)
    }

    // MARK: ColorAlongPath constructors

    func testSolidColorAlongPath() {
        let c = ColorAlongPath.solid(.red)
        XCTAssertEqual(c.kind, .solid)
        XCTAssertTrue(c.startColor.isEqual(UIColor.red))
        XCTAssertTrue(c.endColor.isEqual(UIColor.red))
    }

    func testGradientColorAlongPath() {
        let g = ColorAlongPath.gradient(from: .red, to: .blue)
        XCTAssertEqual(g.kind, .gradient)
        XCTAssertTrue(g.startColor.isEqual(UIColor.red))
        XCTAssertTrue(g.endColor.isEqual(UIColor.blue))
    }

    func testColorAlongPathEqualityIgnoresKindWhenEndpointsMatch() {
        // .solid(red) and .gradient(red, red) have the same endpoints but
        // different kinds — they should NOT compare equal because the
        // shader behavior could differ in future renderer extensions
        // (e.g. mid-segment opacity envelopes that only apply to gradients).
        let a = ColorAlongPath.solid(.red)
        let b = ColorAlongPath.gradient(from: .red, to: .red)
        XCTAssertNotEqual(a, b)
    }

    // MARK: OpacityAlongPath

    func testOpacityTaperEquality() {
        let a = OpacityAlongPath.taper(start: 0, end: 1)
        let b = OpacityAlongPath.taper(start: 0, end: 1)
        let c = OpacityAlongPath.taper(start: 0.1, end: 1)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: cacheHash

    func testStrokeColorAlongPathIsPartOfCacheHash() {
        var a = Options()
        var b = Options()
        XCTAssertEqual(a.cacheHash, b.cacheHash)

        a.strokeColorAlongPath = .gradient(from: .red, to: .blue)
        XCTAssertNotEqual(a.cacheHash, b.cacheHash,
                          "Cache hash must include strokeColorAlongPath")
    }

    func testStrokeOpacityAlongPathIsPartOfCacheHash() {
        var a = Options()
        var b = Options()
        a.strokeOpacityAlongPath = .taper(start: 0, end: 1)
        XCTAssertNotEqual(a.cacheHash, b.cacheHash,
                          "Cache hash must include strokeOpacityAlongPath")
    }

    func testStrokeEdgeSoftnessIsPartOfCacheHash() {
        var a = Options()
        var b = Options()
        a.strokeEdgeSoftness = 0.5
        XCTAssertNotEqual(a.cacheHash, b.cacheHash,
                          "Cache hash must include strokeEdgeSoftness")
    }

    // MARK: Equatable on Options

    func testOptionsEqualityIncludesNewFields() {
        var a = Options()
        var b = Options()
        XCTAssertEqual(a, b)

        a.strokeColorAlongPath = .gradient(from: .red, to: .blue)
        XCTAssertNotEqual(a, b)
        b.strokeColorAlongPath = .gradient(from: .red, to: .blue)
        XCTAssertEqual(a, b)

        a.strokeOpacityAlongPath = .constant(0.5)
        XCTAssertNotEqual(a, b)
        b.strokeOpacityAlongPath = .constant(0.5)
        XCTAssertEqual(a, b)

        a.strokeEdgeSoftness = 0.3
        XCTAssertNotEqual(a, b)
        b.strokeEdgeSoftness = 0.3
        XCTAssertEqual(a, b)
    }

    // MARK: Modifier wiring (RoughView)

    func testStrokeGradientModifierSetsOption() {
        let view = RoughView().strokeGradient(from: .red, to: .blue)
        guard let g = view.options.strokeColorAlongPath else {
            return XCTFail("strokeColorAlongPath should be set")
        }
        XCTAssertEqual(g.kind, .gradient)
        XCTAssertTrue(g.startColor.isEqual(UIColor.red))
        XCTAssertTrue(g.endColor.isEqual(UIColor.blue))
    }

    func testStrokeOpacityTaperModifierClampsValues() {
        let view = RoughView().strokeOpacityTaper(from: -0.5, to: 2.0)
        guard case let .taper(s, e) = view.options.strokeOpacityAlongPath else {
            return XCTFail("Expected .taper")
        }
        XCTAssertEqual(s, 0, accuracy: 0.001, "Start should be clamped to 0")
        XCTAssertEqual(e, 1, accuracy: 0.001, "End should be clamped to 1")
    }

    func testStrokeEdgeSoftnessModifierClampsValues() {
        let too_high = RoughView().strokeEdgeSoftness(2.0)
        XCTAssertEqual(too_high.options.strokeEdgeSoftness, 1.0)

        let too_low = RoughView().strokeEdgeSoftness(-0.5)
        XCTAssertEqual(too_low.options.strokeEdgeSoftness, 0.0)

        let valid = RoughView().strokeEdgeSoftness(0.5)
        XCTAssertEqual(valid.options.strokeEdgeSoftness, 0.5)
    }

    func testStrokeColorAlongPathModifierAcceptsNilToReset() {
        let view = RoughView()
            .strokeGradient(from: .red, to: .blue)
            .strokeColorAlongPath(nil)
        XCTAssertNil(view.options.strokeColorAlongPath)
    }
}
