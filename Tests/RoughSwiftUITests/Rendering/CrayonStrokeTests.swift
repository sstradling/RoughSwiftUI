import XCTest
import SwiftUI
@testable import RoughSwiftUI

final class CrayonStrokeTests: XCTestCase {

    func testDefaultProfileLeavesCrayonUnset() {
        let profile = BrushProfile.default
        XCTAssertNil(profile.crayon)
        XCTAssertFalse(profile.requiresCustomRendering)
    }

    func testCrayonPresetRequiresCustomRendering() {
        let profile = BrushProfile.crayon
        XCTAssertNotNil(profile.crayon)
        XCTAssertEqual(profile.crayon?.passes, 2)
        XCTAssertEqual(profile.crayon?.seed, 1)
        XCTAssertTrue(profile.requiresCustomRendering)
        XCTAssertEqual(profile.tip, .circular)
        XCTAssertEqual(profile.thicknessProfile, .uniform)
    }

    func testCrayonFactoryClampsParameters() {
        let profile = BrushProfile.crayon(
            grain: 4,
            edgeRoughness: -1,
            widthVariation: 2,
            opacityVariation: -3,
            passes: 9,
            seed: 42
        )
        XCTAssertEqual(profile.crayon?.grain, 1)
        XCTAssertEqual(profile.crayon?.edgeRoughness, 0)
        XCTAssertEqual(profile.crayon?.widthVariation, 1)
        XCTAssertEqual(profile.crayon?.opacityVariation, 0)
        XCTAssertEqual(profile.crayon?.passes, 3)
        XCTAssertEqual(profile.crayon?.seed, 42)
    }

    func testCrayonPassesAreEmptyWithoutCrayonStyle() {
        let passes = CrayonStroke.passes(
            operations: line(from: (0, 0), to: (80, 0)),
            width: 6,
            style: CrayonStyle()
        )
        XCTAssertFalse(passes.isEmpty)

        let plain = BrushProfile.default
        XCTAssertNil(plain.crayon)
    }

    func testOpenAndClosedPathsProduceMarks() {
        let open = CrayonStroke.passes(
            operations: line(from: (0, 0), to: (100, 0)),
            width: 6,
            style: CrayonStyle(seed: 3)
        )
        let closed = CrayonStroke.passes(
            operations: rectangle(),
            width: 6,
            style: CrayonStyle(seed: 3)
        )
        XCTAssertEqual(open.count, 2)
        XCTAssertEqual(closed.count, 2)
        XCTAssertGreaterThan(moveCount(open[0].path), 4)
        XCTAssertGreaterThan(moveCount(closed[0].path), moveCount(open[0].path))
        XCTAssertEqual(open[0].opacity, 1, accuracy: 0.001)
        XCTAssertLessThan(open[1].opacity, open[0].opacity)
    }

    func testSameSeedIsStableAndAnotherSeedChangesTheTexture() {
        let style = CrayonStyle(grain: 0.4, seed: 7)
        let first = CrayonStroke.passes(operations: line(from: (0, 10), to: (120, 40)), width: 8, style: style)
        let second = CrayonStroke.passes(operations: line(from: (0, 10), to: (120, 40)), width: 8, style: style)
        XCTAssertEqual(first, second)

        var other = style
        other.seed = 8
        let changed = CrayonStroke.passes(operations: line(from: (0, 10), to: (120, 40)), width: 8, style: other)
        XCTAssertNotEqual(first, changed)
    }

    func testWidthScalesTheMarkThickness() {
        let style = CrayonStyle(grain: 0, edgeRoughness: 0, widthVariation: 0, passes: 1, seed: 1)
        let thin = bounds(of: line(from: (0, 0), to: (90, 0)), width: 4, style: style)
        let thick = bounds(of: line(from: (0, 0), to: (90, 0)), width: 16, style: style)
        XCTAssertGreaterThan(thick.height, thin.height * 2.2)
        XCTAssertLessThan(thick.height, thin.height * 6)
    }

    func testTransformScalesPlacementWithoutScalingWidth() {
        let style = CrayonStyle(grain: 0, edgeRoughness: 0, widthVariation: 0, passes: 1, seed: 2)
        let fitted = CrayonStroke.passes(
            operations: line(from: (0, 0), to: (20, 0)),
            width: 6,
            style: style,
            transform: CGAffineTransform(scaleX: 3, y: 3)
        )
        let box = fitted[0].path.boundingRect
        XCTAssertGreaterThan(box.width, 50)
        XCTAssertLessThan(box.height, 14)
    }

    func testClosedContourStaysNearTheShape() {
        let style = CrayonStyle(grain: 0.2, edgeRoughness: 0.4, widthVariation: 0.2, passes: 2, seed: 5)
        let box = bounds(of: rectangle(), width: 6, style: style)
        XCTAssertGreaterThan(box.minX, -8)
        XCTAssertLessThan(box.maxX, 78)
        XCTAssertGreaterThan(box.minY, -8)
        XCTAssertLessThan(box.maxY, 48)
    }

    func testHigherGrainSkipsMoreMarks() {
        let solid = CrayonStyle(grain: 0, passes: 1, seed: 9)
        let broken = CrayonStyle(grain: 1, passes: 1, seed: 9)
        let solidCount = moveCount(CrayonStroke.passes(operations: line(from: (0, 0), to: (160, 0)), width: 8, style: solid)[0].path)
        let brokenCount = moveCount(CrayonStroke.passes(operations: line(from: (0, 0), to: (160, 0)), width: 8, style: broken)[0].path)
        XCTAssertGreaterThan(solidCount, brokenCount)
    }

    func testLongPathStaysBounded() {
        var operations: [RoughSwiftUI.Operation] = [Move(data: [0, 0])]
        var x: Float = 0
        for index in 0..<30 {
            x += 12
            operations.append(BezierCurveTo(data: [x - 8, Float(index % 2 == 0 ? 18 : -18), x - 4, 6, x, 0]))
        }
        let started = Date()
        let passes = CrayonStroke.passes(operations: operations, width: 5, style: CrayonStyle())
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
        XCTAssertEqual(passes.count, 2)
        XCTAssertLessThan(moveCount(passes[0].path), 4_000)
    }

    @MainActor
    func testRendererEmitsWindingCrayonFills() {
        var options = Options()
        options.brushProfile = .crayon(seed: 4)
        options.strokeWidth = 5
        options.stroke = .black
        let drawing = Drawing(
            shape: "line",
            sets: [OperationSet(type: .path, operations: line(from: (0, 0), to: (40, 20)), path: nil, size: nil)],
            options: options
        )
        let commands = SwiftUIRenderer().commands(for: drawing, options: options, in: CGSize(width: 80, height: 40))
        XCTAssertEqual(commands.count, 2)
        for command in commands {
            guard case .fill = command.style else {
                return XCTFail("Expected a crayon fill")
            }
            XCTAssertEqual(command.fillRule, .winding)
        }
    }

    // MARK: - Helpers

    private func line(from start: (Float, Float), to end: (Float, Float)) -> [RoughSwiftUI.Operation] {
        [Move(data: [start.0, start.1]), LineTo(data: [end.0, end.1])]
    }

    private func rectangle() -> [RoughSwiftUI.Operation] {
        [
            Move(data: [10, 10]),
            LineTo(data: [60, 10]),
            LineTo(data: [60, 40]),
            LineTo(data: [10, 40]),
            Close()
        ]
    }

    private func bounds(of operations: [RoughSwiftUI.Operation], width: CGFloat, style: CrayonStyle) -> CGRect {
        CrayonStroke.passes(operations: operations, width: width, style: style)
            .reduce(CGRect.null) { rect, pass in
                rect.union(pass.path.boundingRect)
            }
    }

    private func moveCount(_ path: SwiftUI.Path) -> Int {
        var count = 0
        path.forEach { element in
            if case .move = element {
                count += 1
            }
        }
        return count
    }
}
