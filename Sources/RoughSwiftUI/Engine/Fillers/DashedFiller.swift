//
//  DashedFiller.swift
//  RoughSwift
//
//  Dashed fill pattern generator - hachure with gaps.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Generates dashed fill patterns (hachure lines with gaps).
public struct DashedFiller: FillGenerator {
    
    private let hachureFiller = HachureFiller()
    
    public init() {}
    
    public func fillPolygon(points: [[Float]], options: Options) -> OperationSet? {
        let lines = hachureFiller.hachureLines(points: points, options: options)
        let ops = dashedLines(lines: lines, options: options)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    public func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        let lines = hachureFiller.hachureEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: options)
        let ops = dashedLines(lines: lines, options: options)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    // MARK: - Dashed Line Generation
    
    /// Converts continuous lines to dashed segments.
    private func dashedLines(lines: [FillLine], options: Options) -> [Operation] {
        var ops: [Operation] = []
        
        // Dash parameters
        var dashOffset = options.dashOffset
        if dashOffset < 0 {
            dashOffset = options.computedHachureGap < 0 ? options.strokeWidth * 4 : options.computedHachureGap
        }
        
        var dashGap = options.dashGap
        if dashGap < 0 {
            dashGap = options.computedHachureGap < 0 ? options.strokeWidth * 4 : options.computedHachureGap
        }
        
        for line in lines {
            let length = line.length
            let dashCount = Int(floor(length / (dashOffset + dashGap)))
            
            if dashCount < 1 {
                // Line too short - draw entire line
                ops.append(contentsOf: RoughMath.doubleLineOps(
                    x1: line.start.x, y1: line.start.y,
                    x2: line.end.x, y2: line.end.y,
                    options: options
                ))
                continue
            }
            
            // Calculate angle of the line
            var start = line.start
            var end = line.end
            
            // Ensure consistent direction
            if start.x > end.x {
                swap(&start, &end)
            }
            
            let angle = atan2(end.y - start.y, end.x - start.x)
            let cos_a = cos(angle)
            let sin_a = sin(angle)
            
            // Center the dashes within the line
            let totalDashLength = Float(dashCount) * (dashOffset + dashGap)
            let offset = (length - totalDashLength + dashGap) / 2
            
            for i in 0..<dashCount {
                let segmentStart = Float(i) * (dashOffset + dashGap)
                let segmentEnd = segmentStart + dashOffset
                
                let x1 = start.x + (segmentStart + offset) * cos_a
                let y1 = start.y + (segmentStart + offset) * sin_a
                let x2 = start.x + (segmentEnd + offset) * cos_a
                let y2 = start.y + (segmentEnd + offset) * sin_a
                
                ops.append(contentsOf: RoughMath.doubleLineOps(
                    x1: x1, y1: y1,
                    x2: x2, y2: y2,
                    options: options
                ))
            }
        }
        
        return ops
    }
}

