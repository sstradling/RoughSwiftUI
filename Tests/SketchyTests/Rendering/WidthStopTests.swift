import XCTest
import SwiftUI
@testable import Sketchy

/// Positioned point widths, and the outline those widths produce.
@MainActor
final class WidthStopTests: XCTestCase {
    private let sethStops = [
        WidthStop(position: 0, width: 4),
        WidthStop(position: 0.1, width: 8),
        WidthStop(position: 0.9, width: 8),
        WidthStop(position: 1, width: 4)
    ]

    private let sethCustom = ThicknessProfile.custom([0.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.5])

    private let samplePositions: [CGFloat] = [0, 0.05, 0.1, 0.5, 0.9, 0.95, 1]
    private let sethWidths: [CGFloat] = [4, 6, 8, 8, 8, 6, 4]
    private let sethMultipliers: [CGFloat] = [0.5, 0.75, 1, 1, 1, 0.75, 0.5]

    func testWidthStopCurveEndCapDoesNotFoldBack() throws {
        var options = Options()
        options.strokeWidth = 2
        options.roughness = 0.25
        options.seed = 149
        options.thicknessProfile = .stops(sethStops)
        let curve = Curve(points: [
            Point(x: 10, y: 120),
            Point(x: 58, y: 28),
            Point(x: 112, y: 156),
            Point(x: 174, y: 52)
        ])
        let drawing = try XCTUnwrap(
            NativeGenerator(size: CGSize(width: 184, height: 184)).generate(drawable: curve, options: options)
        )
        let passes = subpaths(of: drawing.sets[0].operations)
        XCTAssertEqual(passes.count, 2)
        let ends = passes.map { ($0.last as! BezierCurveTo).point }
        let starts = passes.map { ($0.first as! Move).point }
        XCTAssertLessThan(
            hypot(ends[0].x - ends[1].x, ends[0].y - ends[1].y),
            1,
            "the two rough passes already share an endpoint; the notch is not a gap between them"
        )
        XCTAssertLessThan(hypot(starts[0].x - starts[1].x, starts[0].y - starts[1].y), 1)

        let outline = StrokeToFillConverter.convert(
            operations: drawing.sets[0].operations,
            baseWidth: 2,
            profile: options.brushProfile
        )
        let endControl = (passes[0].last as! BezierCurveTo).controlPoint2
        let endTangent = atan2(
            CGFloat(ends[0].y - endControl.y),
            CGFloat(ends[0].x - endControl.x)
        )
        let startCurve = passes[0][1] as! BezierCurveTo
        let startTangent = atan2(
            CGFloat(startCurve.controlPoint1.y - starts[0].y),
            CGFloat(startCurve.controlPoint1.x - starts[0].x)
        )
        assertCapNose(
            of: outline,
            at: CGPoint(x: CGFloat(ends[0].x), y: CGFloat(ends[0].y)),
            direction: endTangent,
            radius: 2
        )
        assertCapNose(
            of: outline,
            at: CGPoint(x: CGFloat(starts[0].x), y: CGFloat(starts[0].y)),
            direction: startTangent + .pi,
            radius: 2
        )
    }

    func testRoundCapOnAStraightStopBulgesOutAtBothEnds() {
        let operations: [Sketchy.Operation] = [
            Move(data: [20, 60]),
            LineTo(data: [160, 60])
        ]
        let profile = BrushProfile(
            thicknessProfile: .stops([
                WidthStop(position: 0, width: 8),
                WidthStop(position: 1, width: 8)
            ]),
            cap: .round
        )
        let outline = StrokeToFillConverter.convert(operations: operations, baseWidth: 2, profile: profile)
        assertCapNose(of: outline, at: CGPoint(x: 160, y: 60), direction: 0, radius: 4)
        assertCapNose(of: outline, at: CGPoint(x: 20, y: 60), direction: .pi, radius: 4)

        let butt = BrushProfile(tip: .flat, thicknessProfile: .uniform, cap: .butt, join: .bevel)
        let marker = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 8,
            profile: butt
        )
        XCTAssertLessThanOrEqual(marker.boundingRect.maxX, 160.5)
        XCTAssertGreaterThanOrEqual(marker.boundingRect.minX, 19.5)
    }

    func testSethStopsMatchPointWidthsAndStrokeWidthMultipliers() {
        let stops = ThicknessProfile.stops(sethStops)
        for (index, t) in samplePositions.enumerated() {
            let width = stops.width(at: t, strokeWidth: 8)
            XCTAssertEqual(width, sethWidths[index], accuracy: 0.0001, "width at \(t)")
            XCTAssertEqual(
                stops.multiplier(at: t, strokeWidth: 8),
                sethMultipliers[index],
                accuracy: 0.0001,
                "multiplier at \(t)"
            )
            XCTAssertEqual(stops.width(at: t, strokeWidth: 2), sethWidths[index], accuracy: 0.0001)
            XCTAssertEqual(stops.width(at: t, strokeWidth: 20), sethWidths[index], accuracy: 0.0001)
        }
        XCTAssertEqual(stops.multiplier(at: 0), 1)
        XCTAssertEqual(stops.multiplier(at: 0.5, strokeWidth: 0), 0)
    }

    func testCustomElevenSampleIsUnchanged() {
        for (index, t) in samplePositions.enumerated() {
            XCTAssertEqual(
                sethCustom.multiplier(at: t),
                sethMultipliers[index],
                accuracy: 0.0001,
                "custom multiplier at \(t)"
            )
            XCTAssertEqual(
                sethCustom.width(at: t, strokeWidth: 8),
                sethWidths[index],
                accuracy: 0.0001,
                "custom width at \(t)"
            )
            XCTAssertEqual(
                sethCustom.multiplier(at: t, strokeWidth: 8),
                sethCustom.multiplier(at: t),
                accuracy: 0.0001
            )
        }
    }

    func testUnsortedStopsMatchTheSortedProfile() {
        let unsorted = ThicknessProfile.stops([
            WidthStop(position: 1, width: 4),
            WidthStop(position: 0.1, width: 8),
            WidthStop(position: 0, width: 4),
            WidthStop(position: 0.9, width: 8)
        ])
        let sorted = ThicknessProfile.stops(sethStops)
        for t in samplePositions {
            XCTAssertEqual(
                unsorted.width(at: t, strokeWidth: 3),
                sorted.width(at: t, strokeWidth: 3),
                accuracy: 0.0001,
                "unsorted width at \(t)"
            )
        }
    }

    func testSingleStopHoldsItsWidth() {
        let profile = ThicknessProfile.stops([WidthStop(position: 0.4, width: 5.5)])
        for t in [CGFloat]([-0.2, 0, 0.05, 0.4, 0.95, 1, 1.4]) {
            XCTAssertEqual(profile.width(at: t, strokeWidth: 12), 5.5, accuracy: 0.0001, "single stop at \(t)")
        }
    }

    func testEmptyStopsAreUniform() {
        let profile = ThicknessProfile.stops([])
        XCTAssertFalse(profile.variesAlongStroke)
        let strokeWidths: [CGFloat] = [1, 2.5, 8]
        for strokeWidth in strokeWidths {
            for t in samplePositions {
                XCTAssertEqual(profile.width(at: t, strokeWidth: strokeWidth), strokeWidth, accuracy: 0.0001)
                XCTAssertEqual(profile.multiplier(at: t, strokeWidth: strokeWidth), 1, accuracy: 0.0001)
            }
        }
        XCTAssertFalse(BrushProfile(thicknessProfile: profile).requiresCustomRendering)
    }

    func testStopsClampPositionAndWidthAndLaterDuplicateWins() {
        let low = WidthStop(position: -0.4, width: -2)
        let high = WidthStop(position: 1.8, width: 9)
        XCTAssertEqual(low.position, 0)
        XCTAssertEqual(low.width, 0)
        XCTAssertEqual(high.position, 1)
        XCTAssertEqual(high.width, 9)

        let profile = ThicknessProfile.stops([
            WidthStop(position: 0, width: 4),
            WidthStop(position: 0.5, width: 1),
            WidthStop(position: 0.5, width: 8),
            WidthStop(position: 1, width: 4)
        ])
        XCTAssertEqual(profile.width(at: 0, strokeWidth: 1), 4, accuracy: 0.0001)
        XCTAssertEqual(profile.width(at: 0.5, strokeWidth: 1), 8, accuracy: 0.0001)
        XCTAssertEqual(profile.width(at: 1, strokeWidth: 1), 4, accuracy: 0.0001)

        let held = ThicknessProfile.stops([
            WidthStop(position: 0.2, width: 3),
            WidthStop(position: 0.8, width: 9)
        ])
        XCTAssertEqual(held.width(at: 0, strokeWidth: 1), 3, accuracy: 0.0001)
        XCTAssertEqual(held.width(at: 0.5, strokeWidth: 1), 6, accuracy: 0.0001)
        XCTAssertEqual(held.width(at: 1, strokeWidth: 1), 9, accuracy: 0.0001)
    }

    func testOutlineUsesStopPointsAndIgnoresStrokeWidth() {
        let operations = horizontalLine()
        let stops = BrushProfile(thicknessProfile: .stops(sethStops), cap: .butt)
        let custom = BrushProfile(thicknessProfile: sethCustom, cap: .butt)
        let thinStops = points(in: outline(operations, profile: stops, strokeWidth: 2))
        let thickStops = points(in: outline(operations, profile: stops, strokeWidth: 21))
        let customAtEight = points(in: outline(operations, profile: custom, strokeWidth: 8))
        let customAtTwo = points(in: outline(operations, profile: custom, strokeWidth: 2))

        XCTAssertEqual(thinStops, thickStops)
        XCTAssertEqual(thinStops, customAtEight)
        XCTAssertNotEqual(thinStops, customAtTwo)
        assertRibbon(thinStops, centerY: 40, length: 200)
    }

    func testClosedContourKeepsEvenStrokeWidth() {
        let operations = rectangle()
        let stops = BrushProfile(thicknessProfile: .stops([
            WidthStop(position: 0, width: 2),
            WidthStop(position: 1, width: 30)
        ]))
        let even = BrushProfile()
        let stopped = points(in: outline(operations, profile: stops, strokeWidth: 7))
        let uniform = points(in: outline(operations, profile: even, strokeWidth: 7))
        let otherWidth = points(in: outline(operations, profile: even, strokeWidth: 4))

        XCTAssertEqual(stopped, uniform)
        XCTAssertNotEqual(stopped, otherWidth)
    }

    func testMarkerTipScalesStopsAndDropsVariableNoise() {
        let stops = sethStops
        let fromVariable = BrushProfile.marker(variation: 0.8, seed: 4)
        var replaced = fromVariable
        replaced.thicknessProfile = .stops(stops)
        let direct = BrushProfile(
            tip: .flat,
            thicknessProfile: .stops(stops),
            cap: .butt,
            join: .bevel
        )

        let operations = horizontalLine()
        XCTAssertEqual(
            points(in: outline(operations, profile: replaced, strokeWidth: 3)),
            points(in: outline(operations, profile: direct, strokeWidth: 11))
        )

        let vertical: [Sketchy.Operation] = [
            Move(data: [80, 0]),
            LineTo(data: [80, 160])
        ]
        let marker = BrushProfile(
            tip: .flat,
            thicknessProfile: .stops([WidthStop(position: 0.2, width: 10)]),
            cap: .butt,
            join: .bevel
        )
        let verticalWidth = outline(vertical, profile: marker, strokeWidth: 3).boundingRect.width
        let horizontalWidth = outline(operations, profile: marker, strokeWidth: 3).boundingRect.height
        XCTAssertEqual(
            verticalWidth,
            BrushTip.flat.effectiveWidth(baseWidth: 10, strokeAngle: .pi / 2),
            accuracy: 0.05
        )
        XCTAssertEqual(
            horizontalWidth,
            BrushTip.flat.effectiveWidth(baseWidth: 10, strokeAngle: 0),
            accuracy: 0.05
        )
        XCTAssertGreaterThan(abs(horizontalWidth - verticalWidth), 1)
    }

    func testOpenStopsFillWithWindingSoTheRoughPassesUnion() {
        let stopped = BrushProfile(thicknessProfile: .stops(sethStops))
        let commands = brushCommands(profile: stopped, strokeWidth: 2, closed: false)
        let closed = brushCommands(profile: stopped, strokeWidth: 2, closed: true)
        XCTAssertEqual(commands.first?.fillRule, .winding)
        XCTAssertEqual(closed.first?.fillRule, .evenOdd)

        let variable = brushCommands(
            profile: .marker(variation: 0.4, seed: 3),
            strokeWidth: 12,
            closed: false
        )
        XCTAssertEqual(variable.first?.fillRule, .winding)
    }

    func testCrayonIgnoresWidthStops() {
        var plain = BrushProfile.crayon
        plain.crayon = CrayonStyle(seed: 4)
        var stopped = plain
        stopped.thicknessProfile = .stops(sethStops)
        let operations = horizontalLine()
        let without = crayonPaths(profile: plain, operations: operations, strokeWidth: 5)
        let withStops = crayonPaths(profile: stopped, operations: operations, strokeWidth: 5)
        XCTAssertEqual(without.count, withStops.count)
        XCTAssertFalse(without.isEmpty)
        for (plainPath, stoppedPath) in zip(without, withStops) {
            XCTAssertEqual(points(in: plainPath), points(in: stoppedPath))
        }
    }

    func testWidthStopsModifierReplacesVariableAndKeepsTheMarkerTip() {
        let view = RoughView()
            .brushProfile(.marker(variation: 0.55, seed: 9))
            .widthStops([(0, 4), (0.1, 8), (0.9, 8), (1, 4)])
        XCTAssertEqual(view.options.brushProfile.tip, .flat)
        XCTAssertEqual(view.options.brushProfile.cap, .butt)
        XCTAssertEqual(view.options.brushProfile.join, .bevel)
        guard case .stops(let stops) = view.options.thicknessProfile else {
            return XCTFail("width stops should replace the variable profile")
        }
        XCTAssertEqual(stops.map(\.width), [4, 8, 8, 4])

        let reversed = RoughView()
            .widthStops([WidthStop(position: 0, width: 4), WidthStop(position: 1, width: 8)])
            .brushProfile(.marker(variation: 0.55, seed: 9))
        guard case .variable = reversed.options.thicknessProfile else {
            return XCTFail("a later brush profile replaces width stops")
        }
    }

    func testRoughTextWidthStopsStoreTheSameProfile() {
        let text = RoughText("Hi", font: UIFont.systemFont(ofSize: 18))
            .widthStops([(0, 4), (1, 8)])
        guard case .stops(let stops) = text.options.thicknessProfile else {
            return XCTFail("RoughText should store width stops")
        }
        XCTAssertEqual(stops.map(\.position), [0, 1])
        XCTAssertEqual(stops.map(\.width), [4, 8])
    }

    func testOptionsCacheHashIncludesStops() {
        var uniform = Options()
        uniform.brushProfile = .marker
        var stopped = uniform
        stopped.thicknessProfile = .stops(sethStops)
        var moved = stopped
        moved.thicknessProfile = .stops([WidthStop(position: 0, width: 5), WidthStop(position: 1, width: 5)])
        XCTAssertNotEqual(uniform.cacheHash, stopped.cacheHash)
        XCTAssertNotEqual(stopped.cacheHash, moved.cacheHash)
    }

    /// The round cap's nose is the sample furthest along `direction`. It should
    /// sit about `radius` ahead of `origin` and on the centerline. A cap that
    /// folds back leaves the two corners as the foremost points, off to the sides.
    private func assertCapNose(
        of path: SwiftUI.Path,
        at origin: CGPoint,
        direction: CGFloat,
        radius: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let forward = CGVector(dx: cos(direction), dy: sin(direction))
        let side = CGVector(dx: -forward.dy, dy: forward.dx)
        let scored = flattened(path).map { point -> (forward: CGFloat, side: CGFloat) in
            let dx = point.x - origin.x
            let dy = point.y - origin.y
            return (
                dx * forward.dx + dy * forward.dy,
                dx * side.dx + dy * side.dy
            )
        }
        guard let nose = scored.max(by: { $0.forward < $1.forward }) else {
            return XCTFail("outline has no points", file: file, line: line)
        }
        XCTAssertGreaterThan(nose.forward, radius * 0.65, "cap does not bulge outward", file: file, line: line)
        XCTAssertLessThan(abs(nose.side), radius * 0.5, "foremost point is a side prong, not the nose", file: file, line: line)
    }

    private func subpaths(of operations: [Sketchy.Operation]) -> [[Sketchy.Operation]] {
        var paths: [[Sketchy.Operation]] = []
        var current: [Sketchy.Operation] = []
        for operation in operations {
            if operation is Move, !current.isEmpty {
                paths.append(current)
                current = [operation]
            } else {
                current.append(operation)
            }
        }
        if !current.isEmpty {
            paths.append(current)
        }
        return paths
    }

    private func flattened(_ path: SwiftUI.Path) -> [CGPoint] {
        var samples: [CGPoint] = []
        var current = CGPoint.zero
        path.forEach { element in
            current = appendFlattened(element, from: current, into: &samples)
        }
        return samples
    }

    private func appendFlattened(
        _ element: SwiftUI.Path.Element,
        from current: CGPoint,
        into samples: inout [CGPoint]
    ) -> CGPoint {
        switch element {
        case .move(let point):
            samples.append(point)
            return point
        case .line(let point):
            samples.append(point)
            return point
        case .quadCurve(let point, let control):
            samples.append(contentsOf: quadSamples(from: current, control: control, to: point))
            return point
        case .curve(let point, let control1, let control2):
            samples.append(contentsOf: cubicSamples(from: current, control1: control1, control2: control2, to: point))
            return point
        case .closeSubpath:
            return current
        }
    }

    private func quadSamples(from: CGPoint, control: CGPoint, to: CGPoint) -> [CGPoint] {
        (1...4).map { step in
            let t = CGFloat(step) / 4
            let one = 1 - t
            let x = one * one * from.x + 2 * one * t * control.x + t * t * to.x
            let y = one * one * from.y + 2 * one * t * control.y + t * t * to.y
            return CGPoint(x: x, y: y)
        }
    }

    private func cubicSamples(
        from: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        to: CGPoint
    ) -> [CGPoint] {
        (1...4).map { step in
            cubicPoint(from: from, control1: control1, control2: control2, to: to, t: CGFloat(step) / 4)
        }
    }

    private func cubicPoint(
        from: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        to: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let one = 1 - t
        let one2 = one * one
        let one3 = one2 * one
        let t2 = t * t
        let t3 = t2 * t
        return CGPoint(
            x: one3 * from.x + 3 * one2 * t * control1.x + 3 * one * t2 * control2.x + t3 * to.x,
            y: one3 * from.y + 3 * one2 * t * control1.y + 3 * one * t2 * control2.y + t3 * to.y
        )
    }

    /// The ribbon is 4pt at the ends and 8pt through the middle.
    private func assertRibbon(
        _ samples: [CGPoint],
        centerY: CGFloat,
        length: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(span(samples, x: 0, centerY: centerY), 4, accuracy: 0.05, file: file, line: line)
        XCTAssertEqual(span(samples, x: length * 0.5, centerY: centerY), 8, accuracy: 0.05, file: file, line: line)
        XCTAssertEqual(span(samples, x: length, centerY: centerY), 4, accuracy: 0.05, file: file, line: line)
    }

    /// Vertical distance between the outline sides nearest `x`.
    private func span(_ samples: [CGPoint], x: CGFloat, centerY: CGFloat) -> CGFloat {
        let nearest = samples.min { lhs, rhs in
            abs(lhs.x - x) < abs(rhs.x - x)
        }
        guard let nearest else { return -1 }
        let band = samples.filter { abs($0.x - nearest.x) < 0.01 }
        let above = band.map(\.y).filter { $0 >= centerY }.min() ?? centerY
        let below = band.map(\.y).filter { $0 <= centerY }.max() ?? centerY
        return above - below
    }

    private func horizontalLine() -> [Sketchy.Operation] {
        [Move(data: [0, 40]), LineTo(data: [200, 40])]
    }

    private func rectangle() -> [Sketchy.Operation] {
        [
            Move(data: [10, 10]),
            LineTo(data: [90, 10]),
            LineTo(data: [90, 60]),
            LineTo(data: [10, 60]),
            Close()
        ]
    }

    private func outline(
        _ operations: [Sketchy.Operation],
        profile: BrushProfile,
        strokeWidth: CGFloat
    ) -> SwiftUI.Path {
        StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: strokeWidth,
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

    private func brushCommands(
        profile: BrushProfile,
        strokeWidth: Float,
        closed: Bool
    ) -> [RoughRenderCommand] {
        var operations = horizontalLine()
        if closed {
            operations.append(LineTo(data: [200, 80]))
            operations.append(LineTo(data: [0, 80]))
            operations.append(Close())
        }
        var options = Options()
        options.brushProfile = profile
        options.strokeWidth = strokeWidth
        let pathSet = OperationSet(type: .path, operations: operations, path: nil, size: nil)
        let drawing = Drawing(shape: "line", sets: [pathSet], options: options)
        return SwiftUIRenderer().commands(for: drawing, options: options, in: CGSize(width: 240, height: 120))
    }

    private func crayonPaths(
        profile: BrushProfile,
        operations: [Sketchy.Operation],
        strokeWidth: Float
    ) -> [SwiftUI.Path] {
        brushCommands(profile: profile, strokeWidth: strokeWidth, closed: false).map(\.path)
    }
}
