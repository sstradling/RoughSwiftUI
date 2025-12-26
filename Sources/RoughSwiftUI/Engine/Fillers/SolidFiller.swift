//
//  SolidFiller.swift
//  RoughSwift
//
//  Solid fill pattern generator.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Generates solid fill patterns (simple polygon fill without hachure lines).
public struct SolidFiller: FillGenerator {
    
    public init() {}
    
    public func fillPolygon(points: [[Float]], options: Options) -> OperationSet? {
        let ops = RoughMath.solidFillPathOps(points: points, options: options)
        return OperationSet(type: .fillPath, operations: ops, path: nil, size: nil)
    }
    
    public func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        // Generate a single closed ellipse for solid fill
        // Use solidEllipseOps instead of ellipseOps to get one fillable path
        let ellipseOps = RoughMath.solidEllipseOps(cx: cx, cy: cy, rx: rx, ry: ry, options: options)
        
        // Convert the ellipse to a fillPath type
        return OperationSet(type: .fillPath, operations: ellipseOps, path: nil, size: nil)
    }
    
    public func fillArc(cx: Float, cy: Float, rx: Float, ry: Float, start: Float, stop: Float, options: Options) -> OperationSet? {
        // Generate arc as polygon points
        var points: [[Float]] = [[cx, cy]]
        let increment = (stop - start) / options.curveStepCount
        
        var angle = start
        while angle <= stop {
            points.append([cx + rx * cos(angle), cy + ry * sin(angle)])
            angle += increment
        }
        points.append([cx + rx * cos(stop), cy + ry * sin(stop)])
        
        let ops = RoughMath.solidFillPathOps(points: points, options: options)
        return OperationSet(type: .fillPath, operations: ops, path: nil, size: nil)
    }
}

