//
//  Path+Operation.swift
//  RoughSwift
//
//  Created by Cursor on 30/11/2025.
//
//  Helpers for converting RoughSwift operations into SwiftUI paths.
//

import SwiftUI

/// Convenience conversions from engine primitives to SwiftUI types.
extension Point {
    /// Convert a `Point` from the engine into a `CGPoint` for drawing.
    var cgPoint: CGPoint {
        CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

extension SwiftUI.Path {
    /// Append a single drawing `Operation` to this SwiftUI `Path`.
    ///
    /// - Parameter operation: The engine operation to map into path commands.
    mutating func add(operation: Operation) {
        switch operation {
        case let moveOp as Move:
            self.move(to: moveOp.point.cgPoint)
        case let line as LineTo:
            self.addLine(to: line.point.cgPoint)
        case let curve as BezierCurveTo:
            self.addCurve(
                to: curve.point.cgPoint,
                control1: curve.controlPoint1.cgPoint,
                control2: curve.controlPoint2.cgPoint
            )
        case let quad as QuadraticCurveTo:
            self.addQuadCurve(
                to: quad.point.cgPoint,
                control: quad.controlPoint.cgPoint
            )
        default:
            // Unsupported or unknown operation types are ignored.
            break
        }
    }

    /// Build a `Path` from an entire `OperationSet`.
    ///
    /// - Parameter operationSet: Collection of low‑level operations to replay.
    /// - Returns: A SwiftUI `Path` representing the same geometry.
    static func from(operationSet: OperationSet) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        operationSet.operations.forEach { op in
            path.add(operation: op)
        }
        return path
    }
    
    /// Build a `Path` from an `OperationSet` with optional smoothing applied.
    ///
    /// Smoothing reduces jitter in rough.js strokes by averaging control points
    /// across neighboring curve segments, creating smoother transitions.
    ///
    /// - Parameters:
    ///   - operationSet: Collection of low‑level operations to replay.
    ///   - smoothing: Smoothing factor from 0.0 (none) to 1.0 (maximum).
    /// - Returns: A SwiftUI `Path` with smoothing applied.
    static func from(operationSet: OperationSet, smoothing: Float) -> SwiftUI.Path {
        guard smoothing > 0 else {
            return from(operationSet: operationSet)
        }
        
        let operations = operationSet.operations
        let s = CGFloat(min(1.0, max(0.0, smoothing)))
        
        // First pass: collect all curve data for smoothing
        var curveData: [CurveSegment] = []
        var currentPoint: CGPoint = .zero
        
        for op in operations {
            switch op {
            case let moveOp as Move:
                currentPoint = moveOp.point.cgPoint
                curveData.append(.move(to: currentPoint))
                
            case let line as LineTo:
                let endPoint = line.point.cgPoint
                curveData.append(.line(from: currentPoint, to: endPoint))
                currentPoint = endPoint
                
            case let curve as BezierCurveTo:
                let endPoint = curve.point.cgPoint
                curveData.append(.bezier(
                    from: currentPoint,
                    to: endPoint,
                    cp1: curve.controlPoint1.cgPoint,
                    cp2: curve.controlPoint2.cgPoint
                ))
                currentPoint = endPoint
                
            case let quad as QuadraticCurveTo:
                let endPoint = quad.point.cgPoint
                curveData.append(.quad(
                    from: currentPoint,
                    to: endPoint,
                    cp: quad.controlPoint.cgPoint
                ))
                currentPoint = endPoint
                
            default:
                break
            }
        }
        
        // Second pass: apply smoothing by averaging with neighbors
        var path = SwiftUI.Path()
        
        for (index, segment) in curveData.enumerated() {
            switch segment {
            case .move(let to):
                path.move(to: to)
                
            case .line(_, let to):
                path.addLine(to: to)
                
            case .bezier(let from, let to, let cp1, let cp2):
                // Get neighboring control points for averaging
                let prevCp2 = getPreviousOutgoingControlPoint(curveData, at: index)
                let nextCp1 = getNextIncomingControlPoint(curveData, at: index)
                
                // Smooth cp1 by averaging with previous segment's outgoing direction
                var smoothedCp1 = cp1
                if let prev = prevCp2 {
                    // Calculate ideal cp1 for smooth transition (reflection of prev cp2 across 'from')
                    let idealCp1 = CGPoint(
                        x: from.x + (from.x - prev.x),
                        y: from.y + (from.y - prev.y)
                    )
                    smoothedCp1 = CGPoint(
                        x: cp1.x + (idealCp1.x - cp1.x) * s * 0.5,
                        y: cp1.y + (idealCp1.y - cp1.y) * s * 0.5
                    )
                }
                
                // Smooth cp2 by averaging with next segment's incoming direction
                var smoothedCp2 = cp2
                if let next = nextCp1 {
                    // Calculate ideal cp2 for smooth transition (reflection of next cp1 across 'to')
                    let idealCp2 = CGPoint(
                        x: to.x + (to.x - next.x),
                        y: to.y + (to.y - next.y)
                    )
                    smoothedCp2 = CGPoint(
                        x: cp2.x + (idealCp2.x - cp2.x) * s * 0.5,
                        y: cp2.y + (idealCp2.y - cp2.y) * s * 0.5
                    )
                }
                
                path.addCurve(to: to, control1: smoothedCp1, control2: smoothedCp2)
                
            case .quad(_, let to, let cp):
                // Get neighboring control points for averaging
                let prevCp = getPreviousOutgoingControlPoint(curveData, at: index)
                let nextCp = getNextIncomingControlPoint(curveData, at: index)
                
                var smoothedCp = cp
                if prevCp != nil || nextCp != nil {
                    var targetX = cp.x
                    var targetY = cp.y
                    var count: CGFloat = 1
                    
                    if let prev = prevCp {
                        targetX += prev.x
                        targetY += prev.y
                        count += 1
                    }
                    if let next = nextCp {
                        targetX += next.x
                        targetY += next.y
                        count += 1
                    }
                    
                    let avgCp = CGPoint(x: targetX / count, y: targetY / count)
                    smoothedCp = CGPoint(
                        x: cp.x + (avgCp.x - cp.x) * s * 0.3,
                        y: cp.y + (avgCp.y - cp.y) * s * 0.3
                    )
                }
                
                path.addQuadCurve(to: to, control: smoothedCp)
            }
        }
        
        return path
    }
}

// MARK: - Curve Segment Types for Smoothing

/// Represents a segment of a path for smoothing calculations.
private enum CurveSegment {
    case move(to: CGPoint)
    case line(from: CGPoint, to: CGPoint)
    case bezier(from: CGPoint, to: CGPoint, cp1: CGPoint, cp2: CGPoint)
    case quad(from: CGPoint, to: CGPoint, cp: CGPoint)
}

/// Gets the outgoing control point from the previous curve segment.
private func getPreviousOutgoingControlPoint(_ segments: [CurveSegment], at index: Int) -> CGPoint? {
    guard index > 0 else { return nil }
    
    switch segments[index - 1] {
    case .bezier(_, _, _, let cp2):
        return cp2
    case .quad(_, _, let cp):
        return cp
    default:
        return nil
    }
}

/// Gets the incoming control point from the next curve segment.
private func getNextIncomingControlPoint(_ segments: [CurveSegment], at index: Int) -> CGPoint? {
    guard index < segments.count - 1 else { return nil }
    
    switch segments[index + 1] {
    case .bezier(_, _, let cp1, _):
        return cp1
    case .quad(_, _, let cp):
        return cp
    default:
        return nil
    }
}


