import XCTest
import SwiftUI
@testable import Sketchy

@MainActor
final class BrushJoinPainterTests: XCTestCase {
    func testCrayonSmoothCurveIgnoresJoin() {
        let curve = smoothCurve()
        let miter = crayonBounds(curve, join: .miter)
        let bevel = crayonBounds(curve, join: .bevel)
        let curved = crayonBounds(curve, join: .standardCurvedBevel)
        XCTAssertEqual(miter, bevel)
        XCTAssertEqual(miter, curved)
    }

    func testCrayonSharpMiterExtendsPastBevel() {
        let peak = sharpPeak()
        let miter = crayonBounds(peak, join: .miter, miterLimit: 10)
        let bevel = crayonBounds(peak, join: .bevel)
        XCTAssertLessThan(miter.minY, bevel.minY - 0.5)
    }

    func testCrayonCurvedBevelSitsBetweenBevelAndMiter() {
        let peak = sharpPeak()
        let bevel = crayonBounds(peak, join: .bevel)
        let curved = crayonBounds(peak, join: .standardCurvedBevel)
        let miter = crayonBounds(peak, join: .miter, miterLimit: 10)
        XCTAssertLessThan(curved.minY, bevel.minY)
        XCTAssertLessThan(miter.minY, curved.minY)
    }

    func testWatercolorSmoothCurveIgnoresJoin() {
        let curve = smoothCurve()
        let miter = watercolorBounds(curve, join: .miter)
        let bevel = watercolorBounds(curve, join: .bevel)
        XCTAssertEqual(miter, bevel)
    }

    func testWatercolorSharpMiterExtendsPastBevel() {
        let peak = sharpPeak()
        let miter = watercolorBounds(peak, join: .miter, miterLimit: 10)
        let bevel = watercolorBounds(peak, join: .bevel)
        XCTAssertLessThan(miter.minY, bevel.minY - 0.5)
    }

    func testWatercolorRoundExtendsPastBevel() {
        let peak = sharpPeak()
        let round = watercolorBounds(peak, join: .round)
        let bevel = watercolorBounds(peak, join: .bevel)
        XCTAssertLessThan(round.minY, bevel.minY)
    }

    private func crayonBounds(
        _ operations: [Sketchy.Operation],
        join: BrushJoin,
        miterLimit: CGFloat = 10
    ) -> CGRect {
        let passes = CrayonStroke.passes(
            operations: operations,
            width: 18,
            style: CrayonStyle(seed: 4),
            join: join,
            miterLimit: miterLimit
        )
        return union(passes.map(\.path))
    }

    private func watercolorBounds(
        _ operations: [Sketchy.Operation],
        join: BrushJoin,
        miterLimit: CGFloat = 10
    ) -> CGRect {
        var brush = BrushProfile.watercolor(
            pigment: 0.8,
            wetness: 0.2,
            edgeDarkening: 0.4,
            layers: 1,
            variation: 0,
            bleed: 0,
            seed: 4
        )
        brush.join = join
        var group = 1
        let commands = WatercolorStroke.commands(
            sets: [operations],
            transform: .identity,
            width: 20,
            brush: brush,
            style: brush.watercolor ?? WatercolorStyle(variation: 0, bleed: 0, seed: 4),
            strokeOpacity: 1,
            color: .blue,
            nextGroup: &group,
            miterLimit: miterLimit
        )
        return union(commands.map(\.path))
    }

    private func union(_ paths: [SwiftUI.Path]) -> CGRect {
        paths.reduce(CGRect.null) { rect, path in
            rect.isNull ? path.boundingRect : rect.union(path.boundingRect)
        }
    }

    private func sharpPeak() -> [Sketchy.Operation] {
        [
            Move(data: [0, 120]),
            LineTo(data: [50, 0]),
            LineTo(data: [100, 120])
        ]
    }

    private func smoothCurve() -> [Sketchy.Operation] {
        [
            Move(data: [0, 60]),
            BezierCurveTo(data: [30, 10, 90, 110, 140, 60])
        ]
    }
}
