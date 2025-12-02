//
//  Path+Operation.swift
//  RoughSwift
//
//  Created by Seth Stradling on 30/11/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
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
}


