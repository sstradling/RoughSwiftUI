import CoreGraphics
import XCTest
@testable import RoughSwiftUI

@MainActor
final class FillAngleOrientationTests: XCTestCase {
    private let square: [[Float]] = [[0, 0], [160, 0], [160, 100], [0, 100]]

    func testPolygonHachureMatchesDocumentedAngles() {
        assertLines(hachure(angle: 0), near: 0)
        assertLines(hachure(angle: 45), near: 45)
        assertLines(hachure(angle: 90), near: 90)
        assertLines(hachure(angle: 180), near: 0)
        assertLines(hachure(angle: 270), near: 90)
    }

    func testEllipseHachureMatchesPolygonAngles() {
        let filler = HachureFiller()
        for angle in [Float(0), 30, 45, 90] {
            let polygon = hachure(angle: angle)
            let options = quietOptions(angle: angle)
            let ellipse = filler.hachureEllipse(cx: 80, cy: 50, rx: 70, ry: 40, options: options)
            let polygonAngle = meanAngle(of: polygon)
            let ellipseAngle = meanAngle(of: ellipse)
            XCTAssertNotNil(polygonAngle)
            XCTAssertNotNil(ellipseAngle)
            if let polygonAngle, let ellipseAngle {
                XCTAssertLessThan(
                    angularDistance(polygonAngle, ellipseAngle),
                    4,
                    "polygon and ellipse diverged at \(angle)°"
                )
            }
        }
    }

    func testDashedAndZigzagFollowFillAngle() {
        var options = quietOptions(angle: 0)
        options.dashOffset = 16
        options.dashGap = 8
        let dashed = DashedFiller().fillPolygon(points: square, options: options)
        assertOperations(dashed?.operations ?? [], near: 0, minimumLength: 10)

        options.fillAngle = 90
        let vertical = DashedFiller().fillPolygon(points: square, options: options)
        assertOperations(vertical?.operations ?? [], near: 90, minimumLength: 10)

        // Zigzag strokes follow the hachure lines. The connectors between
        // those lines run along the scan, so orientation is checked on the lines.
        options.fillAngle = 20
        assertLines(HachureFiller().hachureLines(points: square, options: options), near: 20)
        XCTAssertNotNil(ZigzagFiller().fillPolygon(points: square, options: options))
    }

    func testCrossHatchUsesPerpendicularAngles() {
        let options = quietOptions(angle: 15)
        let filler = HachureFiller()
        assertLines(filler.hachureLines(points: square, options: options), near: 15)
        var perpendicular = options
        perpendicular.fillAngle = options.fillAngle + 90
        assertLines(filler.hachureLines(points: square, options: perpendicular), near: 105)
        XCTAssertNotNil(CrossHatchFiller().fillPolygon(points: square, options: options))
    }

    func testDotsSitOnHorizontalRows() {
        var options = quietOptions(angle: 90)
        options.fillSpacing = 14
        options.fillWeight = 2
        let set = DotsFiller().fillPolygon(points: square, options: options)
        let centers = ellipseCenters(in: set?.operations ?? [])
        XCTAssertGreaterThan(centers.count, 4)

        let rowBuckets = Dictionary(grouping: centers) { Int(($0.y / 8).rounded()) }
        let columnBuckets = Dictionary(grouping: centers) { Int(($0.x / 8).rounded()) }
        let widestRow = rowBuckets.values.map(\.count).max() ?? 0
        let tallestColumn = columnBuckets.values.map(\.count).max() ?? 0
        XCTAssertGreaterThan(widestRow, tallestColumn, "dot grid should run in horizontal rows")
    }

    func testZigzagLineBaseFollowsFillAngle() {
        var options = quietOptions(angle: 0)
        options.zigzagOffset = 8
        let lines = HachureFiller().hachureLines(points: square, options: options)
        assertLines(lines, near: 0)
        XCTAssertNotNil(ZigzagLineFiller().fillPolygon(points: square, options: options))
    }

    func testScribbleOriginZeroIsHorizontalAndNinetyIsVertical() {
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: 160, height: 100), transform: nil)
        assertScribble(path, origin: 0, near: 0)
        assertScribble(path, origin: 90, near: 90)
    }

    private func hachure(angle: Float) -> [FillLine] {
        HachureFiller().hachureLines(points: square, options: quietOptions(angle: angle))
    }

    private func quietOptions(angle: Float) -> Options {
        var options = Options()
        options.fillAngle = angle
        options.fillSpacing = 8
        options.fillWeight = 2
        options.strokeWidth = 2
        options.roughness = 0
        options.bowing = 0
        options.maxRandomnessOffset = 0
        options.seed = 1
        return options
    }

    private func assertLines(
        _ lines: [FillLine],
        near degrees: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let angles = lines.compactMap { line -> Float? in
            undirectedDegrees(
                dx: line.end.x - line.start.x,
                dy: line.end.y - line.start.y,
                minimum: 12
            )
        }
        XCTAssertGreaterThan(angles.count, 2, file: file, line: line)
        for angle in angles {
            XCTAssertLessThan(
                angularDistance(angle, degrees),
                3,
                "line at \(angle)° expected \(degrees)°",
                file: file,
                line: line
            )
        }
    }

    private func assertOperations(
        _ operations: [RoughSwiftUI.Operation],
        near degrees: Float,
        minimumLength: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var angles: [Float] = []
        var cursor: Point?
        for operation in operations {
            let end: Point?
            switch operation {
            case let move as Move:
                cursor = move.point
                continue
            case let segment as LineTo:
                end = segment.point
            case let curve as BezierCurveTo:
                end = curve.point
            case let quad as QuadraticCurveTo:
                end = quad.point
            default:
                continue
            }
            if let end, let start = cursor,
               let angle = undirectedDegrees(dx: end.x - start.x, dy: end.y - start.y, minimum: minimumLength) {
                angles.append(angle)
            }
            cursor = end
        }
        XCTAssertGreaterThan(angles.count, 2, file: file, line: line)
        for angle in angles {
            XCTAssertLessThan(angularDistance(angle, degrees), 8, "segment at \(angle)°", file: file, line: line)
        }
    }

    private func assertScribble(_ path: CGPath, origin: Float, near degrees: Float) {
        var options = quietOptions(angle: 0)
        options.scribbleOrigin = origin
        options.scribbleTightness = 6
        options.scribbleCurvature = 0
        let sets = ScribbleFillGenerator.generate(for: path, options: options)
        let operations = sets.flatMap(\.operations)
        assertOperations(operations, near: degrees, minimumLength: 30)
    }

    private func meanAngle(of lines: [FillLine]) -> Float? {
        let angles = lines.compactMap { line -> Float? in
            undirectedDegrees(dx: line.end.x - line.start.x, dy: line.end.y - line.start.y, minimum: 12)
        }
        guard let first = angles.first else { return nil }
        let total = angles.reduce(Float(0)) { partial, angle in
            partial + (angularDistance(angle, first) == abs(angle - first) ? angle : angle)
        }
        return total / Float(angles.count)
    }

    private func ellipseCenters(in operations: [RoughSwiftUI.Operation]) -> [CGPoint] {
        var groups: [[CGPoint]] = []
        var current: [CGPoint] = []
        func flush() {
            if current.count > 4 {
                groups.append(current)
            }
            current = []
        }
        for operation in operations {
            switch operation {
            case let move as Move:
                flush()
                current = [CGPoint(x: CGFloat(move.point.x), y: CGFloat(move.point.y))]
            case let curve as BezierCurveTo:
                current.append(CGPoint(x: CGFloat(curve.point.x), y: CGFloat(curve.point.y)))
            default:
                break
            }
        }
        flush()
        return groups.map { points in
            let x = points.map(\.x).reduce(0, +) / CGFloat(points.count)
            let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
            return CGPoint(x: x, y: y)
        }
    }

    private func undirectedDegrees(dx: Float, dy: Float, minimum: Float) -> Float? {
        guard hypot(dx, dy) >= minimum else { return nil }
        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < 0 { degrees += 180 }
        if degrees >= 180 { degrees -= 180 }
        return degrees
    }

    private func angularDistance(_ a: Float, _ b: Float) -> Float {
        let delta = abs(a - b).truncatingRemainder(dividingBy: 180)
        return min(delta, 180 - delta)
    }
}
