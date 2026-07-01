//
//  StrokeContinuityIntegrationTests.swift
//  RoughSwiftUITests
//
//  Verifies that `NativeGenerator` correctly dispatches to either
//  `RoughMath` (legacy) or `RoughCurves` (continuous) based on
//  `Options.strokeContinuity`. These tests exercise the integration path
//  rather than the math itself.
//

import XCTest
@testable import RoughSwiftUI

@MainActor
final class StrokeContinuityIntegrationTests: XCTestCase {

    private func legacyOptions() -> Options {
        var o = Options()
        o.strokeContinuity = .legacy
        return o
    }

    private func continuousOptions() -> Options {
        var o = Options()
        o.strokeContinuity = .continuous
        return o
    }

    // MARK: - Defaults

    func testDefaultIsContinuous() {
        let o = Options()
        XCTAssertEqual(o.strokeContinuity, .continuous,
                       "Default should favor continuous-Bezier stroke generation")
    }

    // MARK: - Circle dispatch

    func testCircleContinuousProducesFewerOpsThanLegacy() {
        // Legacy: ~9 cubics per pass × 2 passes = ~18 cubics.
        // Continuous: 4 cubics per pass × 2 passes = 8 cubics.
        // We assert the strict inequality rather than exact counts so
        // future tweaks to curveStepCount don't break this test.
        let gen = Generator(size: CGSize(width: 200, height: 200))

        let legacy = gen.generate(
            drawable: Circle(x: 100, y: 100, diameter: 80),
            options: legacyOptions()
        )
        let continuous = gen.generate(
            drawable: Circle(x: 100, y: 100, diameter: 80),
            options: continuousOptions()
        )

        let legacyOps = legacy?.sets.flatMap { $0.operations } ?? []
        let continuousOps = continuous?.sets.flatMap { $0.operations } ?? []

        let legacyCubics = legacyOps.filter { $0 is BezierCurveTo }.count
        let continuousCubics = continuousOps.filter { $0 is BezierCurveTo }.count

        XCTAssertGreaterThan(legacyCubics, continuousCubics,
                             "Continuous mode should emit fewer cubic Beziers per circle")
        XCTAssertEqual(continuousCubics, 8,
                       "Continuous circle: 4 cubics per pass × 2 passes")
    }

    func testCircleContinuousHasNoLineOps() {
        let gen = Generator(size: CGSize(width: 200, height: 200))
        let drawing = gen.generate(
            drawable: Circle(x: 100, y: 100, diameter: 80),
            options: continuousOptions()
        )
        let ops = drawing?.sets.flatMap { $0.operations } ?? []
        XCTAssertFalse(ops.contains { $0 is LineTo },
                       "Continuous circles must not contain any LineTo operations")
    }

    // MARK: - Rectangle dispatch

    func testRectangleContinuousIsOneSubpathPerPass() {
        let gen = Generator(size: CGSize(width: 200, height: 200))
        let drawing = gen.generate(
            drawable: Rectangle(x: 10, y: 10, width: 100, height: 50),
            options: continuousOptions()
        )
        // Find the stroke set (.path).
        guard let strokeSet = drawing?.sets.first(where: { $0.type == .path }) else {
            return XCTFail("Expected a stroke OperationSet")
        }
        let moves = strokeSet.operations.filter { $0 is Move }.count
        let closes = strokeSet.operations.filter { $0 is Close }.count
        XCTAssertEqual(moves, 2, "Two passes, each one subpath")
        XCTAssertEqual(closes, 2, "Each pass terminates with Close")
    }

    func testRectangleLegacyMatchesPreviousBehavior() {
        // Legacy rectangles emit doubleLineOps per edge: 4 edges × 2
        // passes × 1 cubic each = 8 cubics, with 8 Moves (each pass has
        // its own move).
        let gen = Generator(size: CGSize(width: 200, height: 200))
        let drawing = gen.generate(
            drawable: Rectangle(x: 10, y: 10, width: 100, height: 50),
            options: legacyOptions()
        )
        guard let strokeSet = drawing?.sets.first(where: { $0.type == .path }) else {
            return XCTFail("Expected a stroke OperationSet")
        }
        let moves = strokeSet.operations.filter { $0 is Move }.count
        XCTAssertEqual(moves, 8,
                       "Legacy rectangle has one Move per doubleLineOps edge × 2 passes")
    }

    // MARK: - Caching

    func testStrokeContinuityIsPartOfCacheHash() {
        // Two options that differ only in strokeContinuity must hash
        // differently, otherwise the DrawingCache will return stale results.
        var legacy = Options()
        legacy.strokeContinuity = .legacy
        var continuous = Options()
        continuous.strokeContinuity = .continuous

        XCTAssertNotEqual(legacy.cacheHash, continuous.cacheHash,
                          "cacheHash must include strokeContinuity to avoid stale cache hits")
    }

    func testOptionsEqualityIncludesStrokeContinuity() {
        var a = Options()
        var b = Options()
        XCTAssertEqual(a, b)

        a.strokeContinuity = .legacy
        XCTAssertNotEqual(a, b,
                          "Options equality must distinguish between continuity modes")

        b.strokeContinuity = .legacy
        XCTAssertEqual(a, b)
    }

    // MARK: - Modifier API

    func testRoughViewModifierSetsStrokeContinuity() {
        let view = RoughView().strokeContinuity(.legacy)
        XCTAssertEqual(view.options.strokeContinuity, .legacy)
    }
}
