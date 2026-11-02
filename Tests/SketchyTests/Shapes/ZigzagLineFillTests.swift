import XCTest
@testable import Sketchy

/// Zigzag-line teeth must stay inside the outline.
///
/// Roughness, bowing, and randomness are zero so `doubleLineOps` does not
/// jitter the vertices. The assertions are about the sawtooth itself.
@MainActor
final class ZigzagLineFillTests: XCTestCase {
    private let angles: [Float] = [0, 30, 45, 90, -41]
    private let zigOffset: Float = 14

    func testCircleZigzagVerticesStayInside() {
        let cx: Float = 92
        let cy: Float = 92
        let radius: Float = 88
        for angle in angles {
            let options = fillOptions(angle: angle, offset: zigOffset)
            let set = ZigzagLineFiller().fillEllipse(
                cx: cx, cy: cy, rx: radius, ry: radius, options: options
            )
            assertZigzagStaysInside(
                shape: "circle",
                angle: angle,
                operations: set?.operations ?? [],
                lines: baseLines(ellipse: (cx, cy, radius, radius), options: options),
                half: zigOffset / 2,
                maxOutside: 0.004,
                maxPerpendicular: zigOffset / 2 + 0.2,
                minimumExcursion: zigOffset / 2 * 0.8,
                outside: { x, y in
                    self.ellipseOutside(x, y, cx: cx, cy: cy, rx: radius, ry: radius)
                }
            )
        }
    }

    func testWideEllipseZigzagVerticesStayInside() {
        let cx: Float = 160
        let cy: Float = 90
        let rx: Float = 150
        let ry: Float = 48
        for angle in angles {
            let options = fillOptions(angle: angle, offset: zigOffset)
            let set = ZigzagLineFiller().fillEllipse(
                cx: cx, cy: cy, rx: rx, ry: ry, options: options
            )
            assertZigzagStaysInside(
                shape: "wide ellipse",
                angle: angle,
                operations: set?.operations ?? [],
                lines: baseLines(ellipse: (cx, cy, rx, ry), options: options),
                half: zigOffset / 2,
                maxOutside: 0.004,
                maxPerpendicular: zigOffset / 2 + 0.2,
                minimumExcursion: zigOffset / 2 * 0.8,
                outside: { x, y in
                    self.ellipseOutside(x, y, cx: cx, cy: cy, rx: rx, ry: ry)
                }
            )
        }
    }

    func testPolygonZigzagVerticesStayInside() {
        let rectangle: [[Float]] = [[10, 20], [230, 20], [230, 160], [10, 160]]
        let triangle: [[Float]] = [[30, 200], [320, 180], [140, 20]]
        let shapes: [(String, [[Float]])] = [
            ("rectangle", rectangle),
            ("triangle", triangle)
        ]
        for (name, polygon) in shapes {
            for angle in angles {
                let options = fillOptions(angle: angle, offset: zigOffset)
                let set = ZigzagLineFiller().fillPolygon(points: polygon, options: options)
                assertZigzagStaysInside(
                    shape: name,
                    angle: angle,
                    operations: set?.operations ?? [],
                    lines: baseLines(polygon: polygon, options: options),
                    half: zigOffset / 2,
                    maxOutside: 0.35,
                    maxPerpendicular: zigOffset / 2 + 0.2,
                    minimumExcursion: zigOffset / 2 * 0.8,
                    outside: { x, y in
                        self.polygonOutside(x, y, polygon)
                    }
                )
            }
        }
    }

    func testShortChordDrawsPlainLineInside() {
        // Pitch is 80. The square's chords are shorter than that, so the fill
        // has to fall back to the hachure chord instead of forcing one tooth.
        let square: [[Float]] = [[0, 0], [36, 0], [36, 70], [0, 70]]
        let offset: Float = 20
        let options = fillOptions(angle: 0, offset: offset)
        let set = ZigzagLineFiller().fillPolygon(points: square, options: options)
        assertZigzagStaysInside(
            shape: "short square",
            angle: 0,
            operations: set?.operations ?? [],
            lines: baseLines(polygon: square, options: options),
            half: offset / 2,
            maxOutside: 0.35,
            maxPerpendicular: 1.5,
            minimumExcursion: nil,
            outside: { x, y in
                self.polygonOutside(x, y, square)
            }
        )
    }

    // MARK: - Assertions

    /// `outside` returns how far the point sits past the boundary, or 0 when
    /// it is inside. Perpendicular distance is measured from the hachure chord.
    private func assertZigzagStaysInside(
        shape: String,
        angle: Float,
        operations: [Sketchy.Operation],
        lines: [FillLine],
        half: Float,
        maxOutside: Float,
        maxPerpendicular: Float,
        minimumExcursion: Float?,
        outside: (Float, Float) -> Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let points = pathPoints(operations)
        let whereText = "\(shape) at \(angle)°"
        XCTAssertFalse(points.isEmpty, "\(whereText) should draw a fill", file: file, line: line)
        XCTAssertFalse(lines.isEmpty, "\(whereText) should have hachure chords", file: file, line: line)

        let chords = lines.compactMap { Chord($0) }
        XCTAssertFalse(chords.isEmpty, "\(whereText) chords should be usable", file: file, line: line)

        var worstOutside: Float = 0
        var worstOutsidePoint = (x: Float(0), y: Float(0))
        var worstPastEnd: Float = 0
        var worstPerpendicular: Float = 0
        var lowestSigned = Float.greatestFiniteMagnitude
        var highestSigned = -Float.greatestFiniteMagnitude

        for point in points {
            let overrun = outside(point.x, point.y)
            if overrun > worstOutside {
                worstOutside = overrun
                worstOutsidePoint = point
            }

            var nearest = Float.greatestFiniteMagnitude
            var signed: Float = 0
            var parameter: Float = 0
            var chordLength: Float = 0
            for chord in chords {
                let vx = point.x - chord.startX
                let vy = point.y - chord.startY
                let distance = abs(vx * chord.normalX + vy * chord.normalY)
                if distance < nearest {
                    nearest = distance
                    signed = vx * chord.normalX + vy * chord.normalY
                    parameter = vx * chord.dirX + vy * chord.dirY
                    chordLength = chord.length
                }
            }
            worstPerpendicular = max(worstPerpendicular, nearest)
            lowestSigned = min(lowestSigned, signed)
            highestSigned = max(highestSigned, signed)
            if parameter < 0 {
                worstPastEnd = max(worstPastEnd, -parameter)
            } else if parameter > chordLength {
                worstPastEnd = max(worstPastEnd, parameter - chordLength)
            }
        }

        XCTAssertLessThanOrEqual(
            worstOutside,
            maxOutside,
            "\(whereText) vertex \(worstOutsidePoint) is \(worstOutside) outside (limit \(maxOutside))",
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            worstPastEnd,
            0.15,
            "\(whereText) tooth extends \(worstPastEnd) past its chord",
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            worstPerpendicular,
            maxPerpendicular,
            "\(whereText) peak is \(worstPerpendicular) off the chord; half offset is \(half)",
            file: file,
            line: line
        )
        if let minimumExcursion {
            XCTAssertLessThanOrEqual(
                lowestSigned,
                -minimumExcursion,
                "\(whereText) sawtooth should cross to the negative side of the chord",
                file: file,
                line: line
            )
            XCTAssertGreaterThanOrEqual(
                highestSigned,
                minimumExcursion,
                "\(whereText) sawtooth should cross to the positive side of the chord",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Geometry

    private func fillOptions(angle: Float, offset: Float) -> Options {
        var options = Options()
        options.fillStyle = .zigzagLine
        options.fillAngle = angle
        options.fillSpacing = 4
        options.zigzagOffset = offset
        options.strokeWidth = 2
        options.fillWeight = -1
        options.roughness = 0
        options.bowing = 0
        options.maxRandomnessOffset = 0
        options.seed = 52
        return options
    }

    /// Matches the spacing `ZigzagLineFiller` passes to the hachure generator.
    private func hachureOptions(from options: Options) -> Options {
        let gap = max(options.computedHachureGap, options.strokeWidth * 4)
        let offset: Float
        if options.zigzagOffset < 0 {
            offset = options.computedHachureGap < 0 ? options.strokeWidth * 4 : options.computedHachureGap
        } else {
            offset = options.zigzagOffset
        }
        var copy = options
        copy.fillSpacing = (gap + offset) / options.effectiveFillWeight
        return copy
    }

    private func baseLines(polygon: [[Float]], options: Options) -> [FillLine] {
        HachureFiller().hachureLines(points: polygon, options: hachureOptions(from: options))
    }

    private func baseLines(
        ellipse: (cx: Float, cy: Float, rx: Float, ry: Float),
        options: Options
    ) -> [FillLine] {
        HachureFiller().hachureEllipse(
            cx: ellipse.cx,
            cy: ellipse.cy,
            rx: ellipse.rx,
            ry: ellipse.ry,
            options: hachureOptions(from: options)
        )
    }

    /// How far the ellipse equation sits above 1. Zero when the point is inside.
    private func ellipseOutside(
        _ x: Float,
        _ y: Float,
        cx: Float,
        cy: Float,
        rx: Float,
        ry: Float
    ) -> Float {
        let nx = (x - cx) / rx
        let ny = (y - cy) / ry
        return max(0, nx * nx + ny * ny - 1)
    }

    private func polygonOutside(_ x: Float, _ y: Float, _ polygon: [[Float]]) -> Float {
        let distance = distanceToEdges(x, y, polygon)
        if distance <= 0.05 || pointInPolygon(x, y, polygon) { return 0 }
        return distance
    }

    private func pointInPolygon(_ x: Float, _ y: Float, _ polygon: [[Float]]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var previous = polygon.count - 1
        for index in polygon.indices {
            let currentX = polygon[index][0]
            let currentY = polygon[index][1]
            let previousX = polygon[previous][0]
            let previousY = polygon[previous][1]
            let crosses = (currentY > y) != (previousY > y)
            if crosses {
                let xCross = (previousX - currentX) * (y - currentY) / (previousY - currentY) + currentX
                if x < xCross {
                    inside.toggle()
                }
            }
            previous = index
        }
        return inside
    }

    private func distanceToEdges(_ x: Float, _ y: Float, _ polygon: [[Float]]) -> Float {
        guard polygon.count >= 2 else { return .greatestFiniteMagnitude }
        var best = Float.greatestFiniteMagnitude
        for index in polygon.indices {
            let next = polygon[(index + 1) % polygon.count]
            let ax = polygon[index][0]
            let ay = polygon[index][1]
            let bx = next[0]
            let by = next[1]
            let vx = bx - ax
            let vy = by - ay
            let lengthSquared = vx * vx + vy * vy
            let t: Float
            if lengthSquared < 1e-12 {
                t = 0
            } else {
                let raw = ((x - ax) * vx + (y - ay) * vy) / lengthSquared
                t = min(1, max(0, raw))
            }
            let dx = x - (ax + t * vx)
            let dy = y - (ay + t * vy)
            best = min(best, sqrt(dx * dx + dy * dy))
        }
        return best
    }

    private func pathPoints(_ operations: [Sketchy.Operation]) -> [(x: Float, y: Float)] {
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

    /// Hachure chord oriented the same way as the filler (left to right).
    private struct Chord {
        var startX: Float
        var startY: Float
        var dirX: Float
        var dirY: Float
        var normalX: Float
        var normalY: Float
        var length: Float

        init?(_ line: FillLine) {
            var start = line.start
            var end = line.end
            if start.x > end.x {
                swap(&start, &end)
            }
            let dx = end.x - start.x
            let dy = end.y - start.y
            let chord = sqrt(dx * dx + dy * dy)
            guard chord > 1e-3 else { return nil }
            startX = start.x
            startY = start.y
            dirX = dx / chord
            dirY = dy / chord
            normalX = -dirY
            normalY = dirX
            length = chord
        }
    }
}
