import CoreGraphics
import UIKit
import XCTest
@testable import RoughSwiftUI

@MainActor
final class SeedDeterminismTests: XCTestCase {
    func testSplitMix64MatchesReferenceSequence() {
        var generator = SplitMix64(seed: 42)
        XCTAssertEqual(generator.next(), 13_679_457_532_755_275_413)
        XCTAssertEqual(generator.next(), 2_949_826_092_126_892_291)
        XCTAssertEqual(generator.next(), 5_139_283_748_462_763_858)
        XCTAssertEqual(generator.next(), 6_349_198_060_258_255_764)
    }

    func testSameSeedProducesIdenticalRectangle() {
        let first = coordinates(of: drawing(seed: 42))
        let second = coordinates(of: drawing(seed: 42))
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, second)
    }

    func testDifferentSeedsProduceDifferentRectangles() {
        let first = coordinates(of: drawing(seed: 42))
        let second = coordinates(of: drawing(seed: 99))
        XCTAssertNotEqual(first, second)
    }

    func testNilSeedKeepsUnstableRandomness() {
        let first = coordinates(of: drawing(seed: nil))
        let second = coordinates(of: drawing(seed: nil))
        XCTAssertNotEqual(first, second)
    }

    func testSeededHachureDotsAndSolidMatchAcrossCalls() {
        let square: [[Float]] = [[0, 0], [120, 0], [120, 90], [0, 90]]
        for style in [FillStyle.hachure, .dots, .solid, .dashed, .zigzag, .crossHatch, .zigzagLine] {
            var options = seededOptions()
            options.fillStyle = style
            let filler = FillPatternFactory.filler(for: style)
            let first = coordinates(of: filler.fillPolygon(points: square, options: options)?.operations ?? [])
            let second = coordinates(of: filler.fillPolygon(points: square, options: options)?.operations ?? [])
            XCTAssertFalse(first.isEmpty, "\(style) should draw")
            XCTAssertEqual(first, second, "\(style) should repeat for one seed")

            var other = options
            other.seed = 7
            let different = coordinates(of: filler.fillPolygon(points: square, options: other)?.operations ?? [])
            XCTAssertNotEqual(first, different, "\(style) should change with the seed")
        }
    }

    func testSeededScribbleIsStable() {
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: 140, height: 90), transform: nil)
        var options = seededOptions()
        options.scribbleTightness = 8
        options.scribbleCurvature = 12
        let first = ScribbleFillGenerator.generate(for: path, options: options)
        let second = ScribbleFillGenerator.generate(for: path, options: options)
        XCTAssertEqual(coordinates(of: first), coordinates(of: second))
    }

    func testSeedModifierWritesOptions() {
        let view = RoughView().seed(11)
        XCTAssertEqual(view.options.seed, 11)
        let text = RoughText("Seed", font: UIFont.systemFont(ofSize: 24)).seed(12)
        XCTAssertNotNil(text)
    }

    func testCacheHashIncludesSeedColorOpacityAndBrush() {
        let base = Options()
        var seeded = base
        seeded.seed = 5
        var stroked = base
        stroked.stroke = .red
        var filled = base
        filled.fill = .blue
        var faded = base
        faded.strokeOpacity = 0.4
        var brushed = base
        brushed.brushProfile = .pen

        XCTAssertEqual(base.cacheHash, Options().cacheHash)
        XCTAssertNotEqual(base.cacheHash, seeded.cacheHash)
        XCTAssertNotEqual(base.cacheHash, stroked.cacheHash)
        XCTAssertNotEqual(base.cacheHash, filled.cacheHash)
        XCTAssertNotEqual(base.cacheHash, faded.cacheHash)
        XCTAssertNotEqual(base.cacheHash, brushed.cacheHash)
    }

    func testDrawingCacheKeyIncludesSeed() {
        let drawable = Rectangle(x: 0, y: 0, width: 40, height: 30)
        let size = CGSize(width: 80, height: 60)
        var first = Options()
        first.seed = 1
        var second = Options()
        second.seed = 2
        let keyA = DrawingCacheKey(drawable: drawable, size: size, options: first)
        let keyB = DrawingCacheKey(drawable: drawable, size: size, options: second)
        XCTAssertNotEqual(keyA, keyB)
    }

    func testOptionsSeedRoundTripsThroughDictionary() {
        var options = Options()
        options.seed = 88
        let decoded = Options(dictionary: options.toRoughDictionary())
        XCTAssertEqual(decoded.seed, 88)
        XCTAssertNil(Options(dictionary: Options().toRoughDictionary()).seed)
    }

    func testDefaultCrayonSeedDerivesFromOptionsSeed() {
        var options = Options()
        options.seed = 42
        options.brushProfile = .crayon()
        XCTAssertEqual(options.resolvedCrayonStyle?.seed, 42)
    }

    func testExplicitCrayonSeedWinsOverOptionsSeed() {
        var options = Options()
        options.seed = 42
        options.brushProfile = .crayon(seed: 7)
        XCTAssertEqual(options.resolvedCrayonStyle?.seed, 7)

        options.brushProfile = .crayon()
        options.seed = nil
        XCTAssertEqual(options.resolvedCrayonStyle?.seed, CrayonStyle.defaultSeed)
    }

    func testAnimationSeedReplaysPathVariance() {
        let config = AnimationConfig(steps: 4, speed: .fast, variance: .high, seed: 99)
        let first = PathVarianceGenerator(config: config, baseSeed: config.seed)
        let second = PathVarianceGenerator(config: config)
        let point = CGPoint(x: 40, y: 25)
        XCTAssertEqual(
            first.computeOffset(for: point, step: 1, index: 3),
            second.computeOffset(for: point, step: 1, index: 3)
        )

        let other = PathVarianceGenerator(config: AnimationConfig(steps: 4, variance: .high, seed: 3))
        XCTAssertNotEqual(
            first.computeOffset(for: point, step: 1, index: 3),
            other.computeOffset(for: point, step: 1, index: 3)
        )
    }

    private func seededOptions() -> Options {
        var options = Options()
        options.seed = 42
        options.roughness = 1.6
        options.bowing = 1
        options.maxRandomnessOffset = 2
        options.fillSpacing = 6
        options.fillWeight = 1.5
        return options
    }

    private func drawing(seed: UInt64?) -> Drawing? {
        var options = seededOptions()
        options.seed = seed
        options.fillStyle = .hachure
        return NativeGenerator(size: CGSize(width: 200, height: 160)).generate(
            drawable: Rectangle(x: 10, y: 8, width: 170, height: 120),
            options: options
        )
    }

    private func coordinates(of drawing: Drawing?) -> [Float] {
        guard let drawing else { return [] }
        return drawing.sets.flatMap { coordinates(of: $0.operations) }
    }

    private func coordinates(of sets: [OperationSet]) -> [Float] {
        sets.flatMap { coordinates(of: $0.operations) }
    }

    private func coordinates(of operations: [RoughSwiftUI.Operation]) -> [Float] {
        operations.flatMap { operation -> [Float] in
            switch operation {
            case let move as Move:
                return [move.point.x, move.point.y]
            case let line as LineTo:
                return [line.point.x, line.point.y]
            case let curve as BezierCurveTo:
                return [
                    curve.controlPoint1.x, curve.controlPoint1.y,
                    curve.controlPoint2.x, curve.controlPoint2.y,
                    curve.point.x, curve.point.y
                ]
            case let quad as QuadraticCurveTo:
                return [quad.controlPoint.x, quad.controlPoint.y, quad.point.x, quad.point.y]
            default:
                return []
            }
        }
    }
}
