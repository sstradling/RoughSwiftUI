import XCTest
import SwiftUI
@testable import Sketchy

@MainActor
final class CurvedBevelJoinTests: XCTestCase {
    private func sharpPeak() -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 100))
        path.addLine(to: CGPoint(x: 50, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        return path
    }

    private func smoothCurve() -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 50))
        path.addCurve(
            to: CGPoint(x: 120, y: 50),
            control1: CGPoint(x: 30, y: 0),
            control2: CGPoint(x: 90, y: 110)
        )
        return path
    }

    private func outline(_ path: SwiftUI.Path, join: BrushJoin, miterLimit: CGFloat = 10) -> SwiftUI.Path {
        NativeStrokeOutline.path(
            from: path,
            width: 16,
            cap: .butt,
            join: join,
            miterLimit: miterLimit
        )
    }

    private func variableOutline(
        _ path: SwiftUI.Path,
        join: BrushJoin,
        miterLimit: CGFloat = 10,
        profile: BrushProfile? = nil
    ) -> SwiftUI.Path {
        let brush = profile ?? BrushProfile(
            tip: .circular,
            thicknessProfile: .taperBoth(start: 0.15, end: 0.15),
            cap: .butt,
            join: join
        )
        var adjusted = brush
        adjusted.join = join
        adjusted.cap = .butt
        return StrokeToFillConverter.convert(
            path: path,
            baseWidth: 18,
            profile: adjusted,
            miterLimit: miterLimit
        )
    }

    func testCurvedBevelExtendsPastBevelAndStaysInsideMiter() {
        let peak = sharpPeak()
        let bevel = outline(peak, join: .bevel)
        let curved = outline(peak, join: .standardCurvedBevel)
        let miter = outline(peak, join: .miter, miterLimit: 10)

        XCTAssertLessThan(curved.boundingRect.minY, bevel.boundingRect.minY)
        XCTAssertLessThan(miter.boundingRect.minY, curved.boundingRect.minY)
    }

    func testZeroBulgeMatchesBevel() {
        let peak = sharpPeak()
        let bevel = outline(peak, join: .bevel)
        let flat = outline(peak, join: .curvedBevel(bulge: 0))
        XCTAssertEqual(flat.boundingRect.minY, bevel.boundingRect.minY, accuracy: 1.5)
    }

    func testRoundJoinIsNotTheCurvedBevel() {
        // A narrow peak makes the miter much longer than the round arc's radius.
        var needle = SwiftUI.Path()
        needle.move(to: CGPoint(x: 35, y: 140))
        needle.addLine(to: CGPoint(x: 50, y: 0))
        needle.addLine(to: CGPoint(x: 65, y: 140))
        let round = outline(needle, join: .round)
        let curved = outline(needle, join: .curvedBevel(bulge: 1))
        XCTAssertLessThan(curved.boundingRect.minY, round.boundingRect.minY - 2)
    }

    func testLowMiterLimitPullsTheUniformPeakIn() {
        let peak = sharpPeak()
        let high = outline(peak, join: .miter, miterLimit: 10)
        let low = outline(peak, join: .miter, miterLimit: 1)
        XCTAssertGreaterThan(low.boundingRect.minY, high.boundingRect.minY)
    }

    func testVariableWidthMiterExtendsPastBevel() {
        let peak = sharpPeak()
        let bevel = variableOutline(peak, join: .bevel)
        let miter = variableOutline(peak, join: .miter, miterLimit: 10)
        XCTAssertLessThan(miter.boundingRect.minY, bevel.boundingRect.minY - 0.5)
    }

    func testVariableWidthCurvedBevelSitsBetweenBevelAndMiter() {
        let peak = sharpPeak()
        let bevel = variableOutline(peak, join: .bevel)
        let curved = variableOutline(peak, join: .standardCurvedBevel)
        let miter = variableOutline(peak, join: .miter, miterLimit: 10)
        XCTAssertLessThan(curved.boundingRect.minY, bevel.boundingRect.minY)
        XCTAssertLessThan(miter.boundingRect.minY, curved.boundingRect.minY)
    }

    func testVariableWidthLowMiterLimitClampsThePeak() {
        let peak = sharpPeak()
        let high = variableOutline(peak, join: .miter, miterLimit: 10)
        let low = variableOutline(peak, join: .miter, miterLimit: 1)
        XCTAssertGreaterThan(low.boundingRect.minY, high.boundingRect.minY)
    }

    func testVariableWidthRoundExtendsPastBevel() {
        let peak = sharpPeak()
        let bevel = variableOutline(peak, join: .bevel)
        let round = variableOutline(peak, join: .round)
        XCTAssertLessThan(round.boundingRect.minY, bevel.boundingRect.minY)
    }

    func testSmoothCurveIgnoresJoinStyle() {
        let curve = smoothCurve()
        let miter = variableOutline(curve, join: .miter)
        let bevel = variableOutline(curve, join: .bevel)
        let curved = variableOutline(curve, join: .standardCurvedBevel)
        XCTAssertEqual(miter.boundingRect, bevel.boundingRect)
        XCTAssertEqual(miter.boundingRect, curved.boundingRect)
    }

    func testClosedCurvedBevelCoversTheCenterline() {
        var rect = SwiftUI.Path()
        rect.addRect(CGRect(x: 20, y: 20, width: 80, height: 60))
        let outline = NativeStrokeOutline.path(
            from: rect,
            width: 12,
            cap: .butt,
            join: .standardCurvedBevel,
            miterLimit: 10
        )
        XCTAssertLessThan(outline.boundingRect.minX, 16)
        XCTAssertTrue(outline.contains(CGPoint(x: 20, y: 50), eoFill: false))
        XCTAssertFalse(outline.contains(CGPoint(x: 50, y: 50), eoFill: false))
    }

    func testCalligraphicCornerStaysDrawable() {
        let peak = sharpPeak()
        let profile = BrushProfile(
            tip: .calligraphic,
            thicknessProfile: .uniform,
            cap: .butt,
            join: .miter
        )
        let miter = variableOutline(peak, join: .miter, profile: profile)
        let bevel = variableOutline(peak, join: .bevel, profile: profile)
        XCTAssertFalse(miter.isEmpty)
        XCTAssertFalse(bevel.isEmpty)
        XCTAssertGreaterThanOrEqual(miter.boundingRect.height, bevel.boundingRect.height - 1)
    }
}
