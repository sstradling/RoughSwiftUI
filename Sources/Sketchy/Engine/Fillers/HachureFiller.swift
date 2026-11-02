//
//  HachureFiller.swift
//  RoughSwift
//
//  Hachure fill pattern generator - diagonal line fill.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Generates hachure (diagonal line) fill patterns.
/// This is the default and most common fill style in rough.js.
public struct HachureFiller: FillGenerator {
    
    public init() {}
    
    public func fillPolygon(points: [[Float]], options: Options) -> OperationSet? {
        if options.seed != nil && !RoughRandom.isActive {
            return RoughRandom.with(seed: options.seed) {
                fillPolygon(points: points, options: options)
            }
        }
        let lines = hachureLines(points: points, options: options)
        let ops = renderLines(lines: lines, options: options, connect: false)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    public func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        if options.seed != nil && !RoughRandom.isActive {
            return RoughRandom.with(seed: options.seed) {
                fillEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: options)
            }
        }
        let lines = hachureEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: options)
        let ops = renderLines(lines: lines, options: options, connect: false)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    // MARK: - Hachure Line Generation
    
    /// Generates hachure lines for a polygon.
    public func hachureLines(points: [[Float]], options: Options) -> [FillLine] {
        guard points.count >= 3 else { return [] }
        
        var lines: [FillLine] = []
        
        // Get polygon bounds
        let bounds = RoughMath.polygonBounds(points)
        let minX = bounds.minX
        let maxX = bounds.maxX
        let minY = bounds.minY
        let maxY = bounds.maxY
        
        // The scanner's slope is cot(angle). Passing the complement makes
        // `fillAngle` the line direction: 0° horizontal, 90° vertical,
        // clockwise on screen because y points down. `hachureEllipse` draws
        // chords in that same direction.
        let angle = (90 - options.fillAngle) * Float.pi / 180
        var gap = options.computedHachureGap
        if gap < 0 {
            gap = options.strokeWidth * 4
        }
        gap = max(gap, 0.1)
        
        let sinAngle = sin(angle)
        let cosAngle = cos(angle)
        let tanAngle = tan(angle)
        
        // Create scan line iterator
        var scanner = HachureScanner(
            top: minY - 1,
            bottom: maxY + 1,
            left: minX - 1,
            right: maxX + 1,
            gap: gap,
            sinAngle: sinAngle,
            cosAngle: cosAngle,
            tanAngle: tanAngle
        )
        
        // Generate lines by scanning
        while let scanLine = scanner.nextLine() {
            let intersections = LineHelper.linePolygonIntersections(
                line: (start: scanLine.start, end: scanLine.end),
                polygon: points
            )
            
            // Sort intersections by position along the scan line
            let sorted = intersections.sorted { a, b in
                if abs(sinAngle) < 1e-4 {
                    return a.x < b.x
                } else {
                    return a.y < b.y
                }
            }
            
            // Pair intersections into line segments
            for i in stride(from: 0, to: sorted.count - 1, by: 2) {
                if i + 1 < sorted.count {
                    lines.append(FillLine(
                        start: (sorted[i].x, sorted[i].y),
                        end: (sorted[i + 1].x, sorted[i + 1].y)
                    ))
                }
            }
        }
        
        return lines
    }
    
    /// Generates hachure lines for an ellipse.
    ///
    /// Each line is a chord of the jittered ellipse at `options.fillAngle`.
    /// `0` is horizontal and `90` is vertical, clockwise on screen because y
    /// points down. Consecutive lines are one hachure gap apart, measured
    /// perpendicular to that direction.
    ///
    /// The ellipse is scaled to a circle, vertical chords are laid on that
    /// circle, and an affine map rotates them and scales y back. Rotating
    /// horizontal chords of the ellipse itself would spin the filled region
    /// whenever the radii differ.
    public func hachureEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> [FillLine] {
        var rx = abs(rx)
        var ry = abs(ry)
        guard rx > 0, ry > 0 else { return [] }

        // Same ±5% radius jitter rough.js applies before measuring chords.
        // Roughness scales it, so zero roughness leaves the radii unchanged.
        rx += RoughMath.randOffset(rx * 0.05, options: options)
        ry += RoughMath.randOffset(ry * 0.05, options: options)
        guard rx > 0, ry > 0 else { return [] }

        var gap = options.computedHachureGap
        if gap <= 0 {
            gap = options.strokeWidth * 4
        }
        guard gap > 0 else { return [] }
        guard let frame = ellipseHachureFrame(rx: rx, ry: ry, fillAngle: options.fillAngle, gap: gap) else {
            return []
        }

        var lines: [FillLine] = []
        var xPos = cx - rx + frame.gapPrime
        let limit = cx + rx
        while xPos < limit {
            let delta = cx - xPos
            let radicand = rx * rx - delta * delta
            if radicand > 0 {
                let halfLength = sqrt(radicand)
                let start = mapCirclePoint(
                    xPos, cy - halfLength,
                    cx: cx, cy: cy,
                    sinAlpha: frame.sinAlpha,
                    cosAlpha: frame.cosAlpha,
                    aspectRatio: frame.aspectRatio
                )
                let end = mapCirclePoint(
                    xPos, cy + halfLength,
                    cx: cx, cy: cy,
                    sinAlpha: frame.sinAlpha,
                    cosAlpha: frame.cosAlpha,
                    aspectRatio: frame.aspectRatio
                )
                lines.append(FillLine(start: start, end: end))
            }
            let next = xPos + frame.gapPrime
            if next <= xPos {
                break
            }
            xPos = next
        }

        return lines
    }
    
    // MARK: - Line Rendering
    
    /// Renders hachure lines as rough operations.
    /// - Parameters:
    ///   - lines: Array of fill lines
    ///   - options: Rendering options
    ///   - connect: Whether to connect consecutive lines (for zigzag effect)
    /// - Returns: Array of operations
    public func renderLines(lines: [FillLine], options: Options, connect: Bool) -> [Operation] {
        var ops: [Operation] = []
        var lastEnd: (x: Float, y: Float)?
        
        for line in lines {
            ops.append(contentsOf: RoughMath.doubleLineOps(
                x1: line.start.x, y1: line.start.y,
                x2: line.end.x, y2: line.end.y,
                options: options
            ))
            
            if connect, let last = lastEnd {
                ops.append(contentsOf: RoughMath.doubleLineOps(
                    x1: last.x, y1: last.y,
                    x2: line.start.x, y2: line.start.y,
                    options: options
                ))
            }
            
            lastEnd = line.end
        }
        
        return ops
    }
    
    // MARK: - Helpers
    
    /// Circle-space rotation and chord step for one ellipse hachure.
    ///
    /// `sinAlpha` and `cosAlpha` rotate vertical chords of the circle of
    /// radius `rx` so that, after y is scaled by `ry / rx`, the chords sit at
    /// `fillAngle`. `gapPrime` is the circle-space step whose image is `gap`
    /// points apart, measured perpendicular to those lines. Sine and cosine
    /// are used instead of tangent so 0° and 90° stay finite.
    private func ellipseHachureFrame(
        rx: Float,
        ry: Float,
        fillAngle: Float,
        gap: Float
    ) -> (sinAlpha: Float, cosAlpha: Float, gapPrime: Float, aspectRatio: Float)? {
        let aspectRatio = ry / rx
        let phi = fillAngle * Float.pi / 180
        let sinPhi = sin(phi)
        let cosPhi = cos(phi)
        let hypot = sqrt(aspectRatio * cosPhi * aspectRatio * cosPhi + sinPhi * sinPhi)
        guard hypot > 0, hypot.isFinite else { return nil }

        let sinAlpha = aspectRatio * cosPhi / hypot
        let cosAlpha = sinPhi / hypot
        let scale = sqrt(
            (ry * cosAlpha) * (ry * cosAlpha) + (rx * sinAlpha) * (rx * sinAlpha)
        )
        guard scale.isFinite, scale > 0 else { return nil }

        let gapPrime = gap * scale / ry
        guard gapPrime.isFinite, gapPrime > 0 else { return nil }
        return (sinAlpha, cosAlpha, gapPrime, aspectRatio)
    }

    /// Maps a point on the circle of radius `rx` onto the ellipse.
    ///
    /// This is the rough.js affine step: rotate about the center, then scale
    /// y by the aspect ratio so the circle becomes the ellipse.
    private func mapCirclePoint(
        _ x: Float,
        _ y: Float,
        cx: Float,
        cy: Float,
        sinAlpha: Float,
        cosAlpha: Float,
        aspectRatio: Float
    ) -> (Float, Float) {
        let dx = x - cx
        let dy = y - cy
        return (
            cx + dx * cosAlpha + dy * sinAlpha,
            cy + aspectRatio * (-dx * sinAlpha + dy * cosAlpha)
        )
    }
}

// MARK: - Hachure Scanner

/// Scans across a bounding box generating hachure lines.
struct HachureScanner {
    let top: Float
    let bottom: Float
    let left: Float
    let right: Float
    let gap: Float
    let sinAngle: Float
    let cosAngle: Float
    let tanAngle: Float
    
    private var pos: Float
    private let deltaX: Float
    private let hGap: Float
    private let sLeft: LineHelper.Line?
    private let sRight: LineHelper.Line?
    
    init(top: Float, bottom: Float, left: Float, right: Float,
         gap: Float, sinAngle: Float, cosAngle: Float, tanAngle: Float) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.gap = gap
        self.sinAngle = sinAngle
        self.cosAngle = cosAngle
        self.tanAngle = tanAngle
        
        if abs(sinAngle) < 1e-4 {
            // Near horizontal
            self.pos = left + gap
            self.deltaX = 0
            self.hGap = 0
            self.sLeft = nil
            self.sRight = nil
        } else if abs(sinAngle) > 0.9999 {
            // Near vertical
            self.pos = top + gap
            self.deltaX = 0
            self.hGap = 0
            self.sLeft = nil
            self.sRight = nil
        } else {
            self.deltaX = (bottom - top) * abs(tanAngle)
            self.pos = left - abs(deltaX)
            self.hGap = abs(gap / cosAngle)
            self.sLeft = LineHelper.Line(p1: (left, bottom), p2: (left, top))
            self.sRight = LineHelper.Line(p1: (right, bottom), p2: (right, top))
        }
    }
    
    mutating func nextLine() -> FillLine? {
        if abs(sinAngle) < 1e-4 {
            // Near horizontal - vertical scan lines
            if pos < right {
                let line = FillLine(start: (pos, top), end: (pos, bottom))
                pos += gap
                return line
            }
        } else if abs(sinAngle) > 0.9999 {
            // Near vertical - horizontal scan lines
            if pos < bottom {
                let line = FillLine(start: (left, pos), end: (right, pos))
                pos += gap
                return line
            }
        } else {
            // Angled lines
            if pos < right + deltaX {
                var x1 = pos - deltaX / 2
                var x2 = pos + deltaX / 2
                var y1 = bottom
                var y2 = top
                
                // Skip if completely outside
                while (x1 < left && x2 < left) || (x1 > right && x2 > right) {
                    pos += hGap
                    x1 = pos - deltaX / 2
                    x2 = pos + deltaX / 2
                    if pos > right + deltaX {
                        return nil
                    }
                }
                
                // Clip to bounds
                let scanLine = LineHelper.Line(p1: (x1, y1), p2: (x2, y2))
                
                if let sLeft = sLeft, let intersection = LineHelper.intersection(scanLine, sLeft) {
                    x1 = intersection.x
                    y1 = intersection.y
                }
                
                if let sRight = sRight, let intersection = LineHelper.intersection(scanLine, sRight) {
                    x2 = intersection.x
                    y2 = intersection.y
                }
                
                // Flip for negative angle
                if tanAngle > 0 {
                    x1 = right - (x1 - left)
                    x2 = right - (x2 - left)
                }
                
                let line = FillLine(start: (x1, y1), end: (x2, y2))
                pos += hGap
                return line
            }
        }
        
        return nil
    }
}

