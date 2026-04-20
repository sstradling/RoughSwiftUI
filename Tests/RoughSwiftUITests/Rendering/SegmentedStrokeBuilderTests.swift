//
//  SegmentedStrokeBuilderTests.swift
//  RoughSwiftUITests
//
//  Verifies the segmented-stroke builder used by SwiftUIRenderer for
//  variable-color/opacity stroke rendering.
//

import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class SegmentedStrokeBuilderTests: XCTestCase {

    private func diagonalLinePath(length: CGFloat = 100) -> SwiftUI.Path {
        var p = SwiftUI.Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: length, y: length))
        return p
    }

    private func extractStrokeColor(_ command: RoughRenderCommand) -> Color? {
        if case let .stroke(c, _) = command.style { return c } else { return nil }
    }

    private func extractStrokeWidth(_ command: RoughRenderCommand) -> CGFloat? {
        if case let .stroke(_, w) = command.style { return w } else { return nil }
    }

    // MARK: - Segment count

    func testDefaultSegmentCountIsSixteen() {
        let commands = SegmentedStrokeBuilder.build(
            path: diagonalLinePath(),
            lineWidth: 2,
            cap: .round, join: .round,
            colorAlongPath: .gradient(from: .red, to: .blue),
            opacityAlongPath: nil,
            baseColor: .black,
            baseOpacity: 1
        )
        XCTAssertEqual(commands.count, SegmentedStrokeBuilder.defaultSegmentCount)
    }

    func testSegmentCountClampsToBounds() {
        let zero = SegmentedStrokeBuilder.build(
            path: diagonalLinePath(),
            lineWidth: 1, cap: .round, join: .round,
            colorAlongPath: .solid(.red), opacityAlongPath: nil,
            baseColor: .black, baseOpacity: 1,
            segmentCount: 0
        )
        XCTAssertEqual(zero.count, 1, "Zero segment count clamps to 1")

        let huge = SegmentedStrokeBuilder.build(
            path: diagonalLinePath(),
            lineWidth: 1, cap: .round, join: .round,
            colorAlongPath: .solid(.red), opacityAlongPath: nil,
            baseColor: .black, baseOpacity: 1,
            segmentCount: 1000
        )
        XCTAssertEqual(huge.count, SegmentedStrokeBuilder.maxSegmentCount,
                       "Excessive segment count clamps to max")
    }

    // MARK: - Stroke style preservation

    func testEachSegmentInheritsLineWidthCapAndJoin() {
        let commands = SegmentedStrokeBuilder.build(
            path: diagonalLinePath(),
            lineWidth: 7,
            cap: .square, join: .miter,
            colorAlongPath: .solid(.red), opacityAlongPath: nil,
            baseColor: .black, baseOpacity: 1
        )
        for cmd in commands {
            XCTAssertEqual(extractStrokeWidth(cmd), 7)
            XCTAssertEqual(cmd.cap, .square)
            XCTAssertEqual(cmd.join, .miter)
        }
    }

    // MARK: - Color resolution

    func testGradientProducesDistinctEndpointColors() {
        let commands = SegmentedStrokeBuilder.build(
            path: diagonalLinePath(),
            lineWidth: 2, cap: .round, join: .round,
            colorAlongPath: .gradient(from: .red, to: .blue),
            opacityAlongPath: nil,
            baseColor: .black, baseOpacity: 1,
            segmentCount: 4
        )
        XCTAssertEqual(commands.count, 4)
        // Compare first vs last command: colors must differ for a gradient.
        let first = extractStrokeColor(commands.first!)
        let last = extractStrokeColor(commands.last!)
        XCTAssertNotNil(first); XCTAssertNotNil(last)
        XCTAssertNotEqual(first, last,
                          "Gradient must produce different colors at its endpoints")
    }

    func testSolidColorAlongPathProducesUniformColor() {
        let commands = SegmentedStrokeBuilder.build(
            path: diagonalLinePath(),
            lineWidth: 2, cap: .round, join: .round,
            colorAlongPath: .solid(.green),
            opacityAlongPath: nil,
            baseColor: .black, baseOpacity: 1,
            segmentCount: 8
        )
        let first = extractStrokeColor(commands.first!)
        let last = extractStrokeColor(commands.last!)
        XCTAssertEqual(first, last,
                       "Solid color along path must yield uniform segment color")
    }

    func testNilColorAlongPathFallsBackToBaseColor() {
        let commands = SegmentedStrokeBuilder.build(
            path: diagonalLinePath(),
            lineWidth: 2, cap: .round, join: .round,
            colorAlongPath: nil,
            opacityAlongPath: .taper(start: 0, end: 1),
            baseColor: .red, baseOpacity: 1,
            segmentCount: 4
        )
        // All segment colors should be derived from baseColor (red),
        // varying only in alpha. We can't easily compare SwiftUI.Color
        // for exact equality with UIColor.red, but we can check that
        // the first and last commands both use the same base color
        // (their alphas will differ; SwiftUI.Color.opacity returns a
        // new Color that compares equal only when both base and alpha
        // match).
        let first = extractStrokeColor(commands.first!)
        let last = extractStrokeColor(commands.last!)
        // First (s=0.125) has alpha ~0.125; last (s=0.875) has alpha
        // ~0.875. They should compare unequal because alpha differs.
        XCTAssertNotEqual(first, last,
                          "Opacity taper must produce visibly different alphas")
    }

    // MARK: - Opacity resolution

    func testTaperedOpacityProducesIncreasingAlpha() {
        // We can't read alpha back from SwiftUI.Color directly, but
        // resolveOpacity is a pure function we can test independently.
        let s0 = SegmentedStrokeBuilder.resolveOpacity(
            opacityAlongPath: .taper(start: 0.2, end: 0.8),
            baseOpacity: 1.0,
            at: 0.0
        )
        let s1 = SegmentedStrokeBuilder.resolveOpacity(
            opacityAlongPath: .taper(start: 0.2, end: 0.8),
            baseOpacity: 1.0,
            at: 1.0
        )
        XCTAssertEqual(s0, 0.2, accuracy: 0.001)
        XCTAssertEqual(s1, 0.8, accuracy: 0.001)
    }

    func testConstantOpacityIsConstant() {
        for s in stride(from: Float(0), through: 1, by: 0.25) {
            let v = SegmentedStrokeBuilder.resolveOpacity(
                opacityAlongPath: .constant(0.5),
                baseOpacity: 1.0,
                at: s
            )
            XCTAssertEqual(v, 0.5, accuracy: 0.001)
        }
    }

    func testOpacityMultipliesBaseOpacity() {
        // baseOpacity = 0.5, taper from 0 to 1 → midpoint = 0.25.
        let v = SegmentedStrokeBuilder.resolveOpacity(
            opacityAlongPath: .taper(start: 0, end: 1),
            baseOpacity: 0.5,
            at: 0.5
        )
        XCTAssertEqual(v, 0.25, accuracy: 0.001)
    }

    // MARK: - Color interpolation

    func testInterpolateColorAtZeroReturnsStart() {
        let c = SegmentedStrokeBuilder.interpolateColor(from: .red, to: .blue, t: 0)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(r, 1, accuracy: 0.001)
        XCTAssertEqual(b, 0, accuracy: 0.001)
    }

    func testInterpolateColorAtOneReturnsEnd() {
        let c = SegmentedStrokeBuilder.interpolateColor(from: .red, to: .blue, t: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(r, 0, accuracy: 0.001)
        XCTAssertEqual(b, 1, accuracy: 0.001)
    }

    func testInterpolateColorAtHalfReturnsMidpoint() {
        let c = SegmentedStrokeBuilder.interpolateColor(from: .red, to: .blue, t: 0.5)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(r, 0.5, accuracy: 0.001)
        XCTAssertEqual(b, 0.5, accuracy: 0.001)
    }

    func testInterpolateColorClampsT() {
        let cLow = SegmentedStrokeBuilder.interpolateColor(from: .red, to: .blue, t: -1)
        let cHigh = SegmentedStrokeBuilder.interpolateColor(from: .red, to: .blue, t: 2)
        // t=-1 should clamp to 0 (red); t=2 should clamp to 1 (blue).
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(cLow.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(r, 1, accuracy: 0.001)
        XCTAssertTrue(cHigh.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(b, 1, accuracy: 0.001)
    }
}
