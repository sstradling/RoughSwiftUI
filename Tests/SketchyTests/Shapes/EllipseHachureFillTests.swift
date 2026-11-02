import XCTest
@testable import Sketchy

/// Ellipse hachure must be chords of the ellipse at `fillAngle`.
///
/// Rotating horizontal chords spins the filled region when `rx != ry`, so a
/// wide ellipse spills past the top and bottom and leaves the side ends empty.
/// These tests keep every endpoint on the ellipse and require the lines to
/// reach both axes. The scan starts one gap in from the tangent, so the
/// extent check allows that inset.
@MainActor
final class EllipseHachureFillTests: XCTestCase {
    private let wideCenter = (x: Float(200), y: Float(150))
    private let wideRadii = (x: Float(120), y: Float(60))
    private let angles: [Float] = [0, 30, 45, 90, -41]

    func testWideEllipseHachureEndpointsLieInsideAndCoverExtent() {
        let gap = quietGap
        for angle in angles {
            let lines = HachureFiller().hachureEllipse(
                cx: wideCenter.x,
                cy: wideCenter.y,
                rx: wideRadii.x,
                ry: wideRadii.y,
                options: quietOptions(angle: angle)
            )
            assertChords(
                lines,
                center: wideCenter,
                radii: wideRadii,
                angle: angle,
                gap: gap,
                insideLimit: 1.01,
                shortfallAllowance: gap + 1
            )
        }
    }

    func testWideEllipseHachureJitterStaysNearTheOutline() {
        // Roughness 1 jitters each radius by about 5% before the chords are cut.
        // Endpoints stay near the requested ellipse, and the lines still span it.
        var options = quietOptions(angle: 0)
        options.roughness = 1
        options.seed = 11
        let gap = options.computedHachureGap
        let allowance = gap + 0.05 * max(wideRadii.x, wideRadii.y) + 1
        for angle in angles {
            options.fillAngle = angle
            let lines = HachureFiller().hachureEllipse(
                cx: wideCenter.x,
                cy: wideCenter.y,
                rx: wideRadii.x,
                ry: wideRadii.y,
                options: options
            )
            assertChords(
                lines,
                center: wideCenter,
                radii: wideRadii,
                angle: angle,
                gap: gap,
                insideLimit: 1.12,
                shortfallAllowance: allowance
            )
        }
    }

    func testCircleHachureChordsStayInsideAndCoverExtent() {
        let center = (x: Float(100), y: Float(100))
        let radii = (x: Float(80), y: Float(80))
        let gap = quietGap
        for angle in angles {
            let lines = HachureFiller().hachureEllipse(
                cx: center.x,
                cy: center.y,
                rx: radii.x,
                ry: radii.y,
                options: quietOptions(angle: angle)
            )
            assertChords(
                lines,
                center: center,
                radii: radii,
                angle: angle,
                gap: gap,
                insideLimit: 1.01,
                shortfallAllowance: gap + 1
            )
        }
    }

    func testDelegatedEllipseFillsStayInsideTheOutline() {
        // Cross-hatch, zigzag, and dashed stroke the hachure chords (cross-hatch
        // adds the perpendicular angle). Dots and zigzag-line call the same
        // ellipse chords; their marks extend past the chord, so this checks
        // that they still produce a fill.
        for angle in angles {
            let options = quietOptions(angle: angle)
            for filler in delegatedFillers() {
                let set = filler.fillEllipse(
                    cx: wideCenter.x,
                    cy: wideCenter.y,
                    rx: wideRadii.x,
                    ry: wideRadii.y,
                    options: options
                )
                let points = operationPoints(set?.operations ?? [])
                XCTAssertGreaterThan(points.count, 8, "\(type(of: filler)) at \(angle)°")
                for point in points {
                    let value = ellipseValue(point, center: wideCenter, radii: wideRadii)
                    XCTAssertLessThanOrEqual(
                        value,
                        1.01,
                        "\(type(of: filler)) point outside the ellipse at \(angle)°"
                    )
                }
            }
        }

        let options = quietOptions(angle: 45)
        let dots = DotsFiller().fillEllipse(
            cx: wideCenter.x, cy: wideCenter.y,
            rx: wideRadii.x, ry: wideRadii.y,
            options: options
        )
        XCTAssertGreaterThan(dots?.operations.count ?? 0, 0)
        let zigzagLine = ZigzagLineFiller().fillEllipse(
            cx: wideCenter.x, cy: wideCenter.y,
            rx: wideRadii.x, ry: wideRadii.y,
            options: options
        )
        XCTAssertGreaterThan(zigzagLine?.operations.count ?? 0, 0)
    }

    // MARK: - Helpers

    private var quietGap: Float {
        quietOptions(angle: 0).computedHachureGap
    }

    private func quietOptions(angle: Float) -> Options {
        var options = Options()
        options.fillAngle = angle
        options.fillSpacing = 4
        options.fillWeight = 2
        options.strokeWidth = 2
        options.roughness = 0
        options.bowing = 0
        options.maxRandomnessOffset = 0
        options.seed = 1
        return options
    }

    private func delegatedFillers() -> [FillGenerator] {
        [HachureFiller(), CrossHatchFiller(), ZigzagFiller(), DashedFiller()]
    }

    private func assertChords(
        _ lines: [FillLine],
        center: (x: Float, y: Float),
        radii: (x: Float, y: Float),
        angle: Float,
        gap: Float,
        insideLimit: Float,
        shortfallAllowance: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThan(lines.count, 4, "expected several chords at \(angle)°", file: file, line: line)

        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var longLineCount = 0

        for chord in lines {
            for point in [chord.start, chord.end] {
                let value = ellipseValue(point, center: center, radii: radii)
                XCTAssertLessThanOrEqual(
                    value,
                    insideLimit,
                    "endpoint outside the ellipse at \(angle)° (value \(value))",
                    file: file,
                    line: line
                )
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
            let dx = chord.end.x - chord.start.x
            let dy = chord.end.y - chord.start.y
            if sqrt(dx * dx + dy * dy) >= 12 {
                longLineCount += 1
                let degrees = undirectedDegrees(dx: dx, dy: dy)
                XCTAssertLessThan(
                    angularDistance(degrees, angle),
                    1,
                    "chord at \(degrees)° expected \(angle)°",
                    file: file,
                    line: line
                )
            }
        }
        XCTAssertGreaterThan(longLineCount, 2, "expected long chords at \(angle)°", file: file, line: line)

        let shortfallX = max(minX - (center.x - radii.x), (center.x + radii.x) - maxX)
        let shortfallY = max(minY - (center.y - radii.y), (center.y + radii.y) - maxY)
        XCTAssertLessThanOrEqual(
            shortfallX,
            shortfallAllowance,
            "horizontal extent short by \(shortfallX) at \(angle)°",
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            shortfallY,
            shortfallAllowance,
            "vertical extent short by \(shortfallY) at \(angle)°",
            file: file,
            line: line
        )

        let radians = angle * .pi / 180
        let normalX = -sin(radians)
        let normalY = cos(radians)
        for index in 1..<lines.count {
            let dx = lines[index].start.x - lines[index - 1].start.x
            let dy = lines[index].start.y - lines[index - 1].start.y
            let spacing = abs(normalX * dx + normalY * dy)
            XCTAssertEqual(
                spacing,
                gap,
                accuracy: 0.05,
                "perpendicular gap \(spacing) at \(angle)°",
                file: file,
                line: line
            )
        }
    }

    private func ellipseValue(
        _ point: (x: Float, y: Float),
        center: (x: Float, y: Float),
        radii: (x: Float, y: Float)
    ) -> Float {
        let nx = (point.x - center.x) / radii.x
        let ny = (point.y - center.y) / radii.y
        return nx * nx + ny * ny
    }

    private func operationPoints(_ operations: [Sketchy.Operation]) -> [(x: Float, y: Float)] {
        var points: [(x: Float, y: Float)] = []
        for operation in operations {
            switch operation {
            case let move as Move:
                points.append((move.point.x, move.point.y))
            case let segment as LineTo:
                points.append((segment.point.x, segment.point.y))
            case let curve as BezierCurveTo:
                points.append((curve.controlPoint1.x, curve.controlPoint1.y))
                points.append((curve.controlPoint2.x, curve.controlPoint2.y))
                points.append((curve.point.x, curve.point.y))
            case let quad as QuadraticCurveTo:
                points.append((quad.controlPoint.x, quad.controlPoint.y))
                points.append((quad.point.x, quad.point.y))
            default:
                break
            }
        }
        return points
    }

    private func undirectedDegrees(dx: Float, dy: Float) -> Float {
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
