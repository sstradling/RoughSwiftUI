import XCTest
import SwiftUI
@testable import Sketchy

@MainActor
final class MarkerVariableWidthTests: XCTestCase {
    func testDefaultMarkerFactoryMatchesUniformPreset() {
        let profile = BrushProfile.marker()

        XCTAssertEqual(profile, .marker)
        XCTAssertEqual(profile.tip, .flat)
        XCTAssertEqual(profile.cap, .butt)
        XCTAssertEqual(profile.join, .bevel)
        XCTAssertEqual(profile.thicknessProfile, .uniform)
        XCTAssertEqual(BrushProfile.marker(variation: 0, seed: 99), .marker)
        XCTAssertEqual(BrushProfile.marker(minimum: 1, maximum: 1), .marker)
    }

    func testMarkerFactoryKeepsTheFlatTip() {
        let profile = BrushProfile.marker(variation: 0.35, taperStart: 0.1, seed: 4)

        XCTAssertEqual(profile.tip, .flat)
        XCTAssertEqual(profile.cap, .butt)
        XCTAssertEqual(profile.join, .bevel)
        guard case .variable(let width) = profile.thicknessProfile else {
            return XCTFail("expected a variable thickness profile")
        }
        XCTAssertEqual(width.seed, 4)
        XCTAssertEqual(width.taperStart, 0.1, accuracy: 0.0001)
    }

    func testVariationStaysInsideDerivedBounds() {
        let width = VariableStrokeWidth(variation: 0.4, seed: 7)
        XCTAssertEqual(width.minimum, 0.6, accuracy: 0.0001)
        XCTAssertEqual(width.maximum, 1.4, accuracy: 0.0001)

        let samples = samples(of: width)
        assertWithin(samples, minimum: 0.6, maximum: 1.4)
        XCTAssertGreaterThan(samples.max()! - samples.min()!, 0.15)
    }

    func testExplicitBoundsContainTheBodyAndSwapWhenReversed() {
        let width = VariableStrokeWidth(minimum: 1.5, maximum: 0.4, seed: 3)
        XCTAssertEqual(width.minimum, 0.4, accuracy: 0.0001)
        XCTAssertEqual(width.maximum, 1.5, accuracy: 0.0001)
        XCTAssertEqual(width.amount, 1, accuracy: 0.0001)

        let scaled = VariableStrokeWidth(variation: 0.5, minimum: 0.2, maximum: 1.8, seed: 3)
        let samples = samples(of: scaled)
        assertWithin(samples, minimum: scaled.minimum, maximum: scaled.maximum)
        let fullSpan = scaled.maximum - scaled.minimum
        XCTAssertLessThan(samples.max()! - samples.min()!, fullSpan * 0.5 + 0.02)
    }

    func testSameSeedRepeatsAndADifferentSeedDiverges() {
        let first = samples(of: VariableStrokeWidth(variation: 0.45, seed: 11))
        let second = samples(of: VariableStrokeWidth(variation: 0.45, seed: 11))
        let other = samples(of: VariableStrokeWidth(variation: 0.45, seed: 12))

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, other)
    }

    func testTaperReachesZeroWhileTheBodyStaysInsideBounds() {
        let width = VariableStrokeWidth(
            variation: 0.25,
            taperStart: 0.2,
            taperEnd: 0.2,
            seed: 5
        )

        XCTAssertEqual(width.multiplier(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(width.multiplier(at: 1), 0, accuracy: 0.0001)

        let samples = samples(of: width)
        assertWithin(samples, minimum: 0, maximum: width.maximum)

        let body = stride(from: 0.25, through: 0.75, by: 0.05).map { width.multiplier(at: $0) }
        assertWithin(body, minimum: width.minimum, maximum: width.maximum)
    }

    func testPressureCurveIsPreservedWithoutVariation() {
        let curve: [CGFloat] = [0.2, 1.0, 0.4]
        let width = VariableStrokeWidth(pressure: curve, seed: 8)
        let profile = ThicknessProfile.pressure(curve)

        for t in stride(from: 0.0, through: 1.0, by: 0.125) {
            XCTAssertEqual(
                width.multiplier(at: t),
                profile.multiplier(at: t),
                accuracy: 0.0001,
                "pressure at \(t)"
            )
        }

        let marker = BrushProfile.marker(pressure: curve, seed: 8)
        guard case .variable = marker.thicknessProfile else {
            return XCTFail("pressure should select the variable profile")
        }
    }

    func testPressureAndVariationStayWithinTheRequestedMaximum() {
        let width = VariableStrokeWidth(
            variation: 0.2,
            minimum: 0.5,
            maximum: 1.2,
            pressure: [0.5, 2.0, 0.25],
            seed: 6
        )
        assertWithin(samples(of: width), minimum: 0.5, maximum: 1.2)
    }

    func testNegativeVariationClampsToTheUniformMarker() {
        XCTAssertEqual(BrushProfile.marker(variation: -0.4, seed: 1), .marker)
        XCTAssertFalse(VariableStrokeWidth(variation: -1).changesWidth)
    }

    func testOutlineOfTheDefaultMarkerIsUnchanged() {
        let uniform = outline(profile: .marker)
        let factory = outline(profile: .marker())
        XCTAssertEqual(points(in: uniform), points(in: factory))
    }

    func testOutlineWidthsStayInsideTheMaximumAndRepeatPerSeed() {
        let width = VariableStrokeWidth(variation: 0.45, seed: 21)
        let profile = BrushProfile.marker(variation: 0.45, seed: 21)
        let again = BrushProfile.marker(variation: 0.45, seed: 21)
        let other = BrushProfile.marker(variation: 0.45, seed: 22)

        let first = points(in: outline(profile: profile))
        let second = points(in: outline(profile: again))
        let diverged = points(in: outline(profile: other))
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, diverged)

        let halfMaximum = 20 * width.maximum / 2
        for point in first {
            XCTAssertLessThanOrEqual(abs(point.y - 80), halfMaximum + 0.01)
        }

        let uniformHeight = outline(profile: .marker).boundingRect.height
        let variedHeight = outline(profile: profile).boundingRect.height
        XCTAssertGreaterThan(variedHeight, uniformHeight + 0.5)
        XCTAssertLessThanOrEqual(variedHeight, 20 * width.maximum + 0.5)
    }

    func testOpenVariableMarkerFillsWithWindingAndTheUniformMarkerDoesNot() {
        let open = brushCommands(profile: .marker(variation: 0.4, seed: 3), closed: false)
        let uniform = brushCommands(profile: .marker, closed: false)
        let closed = brushCommands(profile: .marker(variation: 0.4, seed: 3), closed: true)

        XCTAssertEqual(open.first?.fillRule, .winding)
        XCTAssertEqual(uniform.first?.fillRule, .evenOdd)
        XCTAssertEqual(closed.first?.fillRule, .evenOdd)
    }

    func testOptionsCacheHashIncludesTheVariableMarker() {
        var uniform = Options()
        uniform.brushProfile = .marker
        var varied = Options()
        varied.brushProfile = .marker(variation: 0.3, seed: 2)
        XCTAssertNotEqual(uniform.cacheHash, varied.cacheHash)
    }

    private func samples(of width: VariableStrokeWidth, count: Int = 64) -> [CGFloat] {
        (0..<count).map { index in
            width.multiplier(at: CGFloat(index) / CGFloat(count - 1))
        }
    }

    private func assertWithin(
        _ samples: [CGFloat],
        minimum: CGFloat,
        maximum: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for sample in samples {
            XCTAssertGreaterThanOrEqual(sample, minimum - 0.0001, file: file, line: line)
            XCTAssertLessThanOrEqual(sample, maximum + 0.0001, file: file, line: line)
        }
    }

    private func brushCommands(profile: BrushProfile, closed: Bool) -> [RoughRenderCommand] {
        var operations: [Sketchy.Operation] = [
            Move(data: [10, 10]),
            LineTo(data: [80, 10])
        ]
        if closed {
            operations.append(LineTo(data: [80, 60]))
            operations.append(LineTo(data: [10, 60]))
            operations.append(Close())
        }
        var options = Options()
        options.brushProfile = profile
        options.strokeWidth = 12
        let pathSet = OperationSet(type: .path, operations: operations, path: nil, size: nil)
        let drawing = Drawing(shape: "line", sets: [pathSet], options: options)
        return SwiftUIRenderer().commands(for: drawing, options: options, in: CGSize(width: 120, height: 80))
    }

    private func outline(profile: BrushProfile) -> SwiftUI.Path {
        let operations: [Sketchy.Operation] = [
            Move(data: [0, 80]),
            LineTo(data: [240, 80])
        ]
        return StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 20,
            profile: profile
        )
    }

    private func points(in path: SwiftUI.Path) -> [CGPoint] {
        var collected: [CGPoint] = []
        path.forEach { element in
            switch element {
            case .move(let point):
                collected.append(point)
            case .line(let point):
                collected.append(point)
            case .quadCurve(let point, let control):
                collected.append(control)
                collected.append(point)
            case .curve(let point, let control1, let control2):
                collected.append(control1)
                collected.append(control2)
                collected.append(point)
            case .closeSubpath:
                break
            }
        }
        return collected
    }
}
