//
//  ZigzagLineFiller.swift
//  RoughSwift
//
//  Zigzag line fill pattern generator - each hachure line is a zigzag.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Generates zigzag-line fill patterns (each hachure line is itself a zigzag).
public struct ZigzagLineFiller: FillGenerator {
    
    private let hachureFiller = HachureFiller()
    
    public init() {}
    
    public func fillPolygon(points: [[Float]], options: Options) -> OperationSet? {
        let gap = max(options.computedHachureGap, options.strokeWidth * 4)
        var zigOptions = options
        zigOptions.fillSpacing = (gap + zigzagOffset(options: options)) / options.effectiveFillWeight
        
        let lines = hachureFiller.hachureLines(points: points, options: zigOptions)
        let ops = zigzagLines(lines: lines, options: options)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    public func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        let gap = max(options.computedHachureGap, options.strokeWidth * 4)
        var zigOptions = options
        zigOptions.fillSpacing = (gap + zigzagOffset(options: options)) / options.effectiveFillWeight
        
        let lines = hachureFiller.hachureEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: zigOptions)
        let ops = zigzagLines(lines: lines, options: options)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    // MARK: - Zigzag Generation
    
    private func zigzagOffset(options: Options) -> Float {
        if options.zigzagOffset < 0 {
            return options.computedHachureGap < 0 ? options.strokeWidth * 4 : options.computedHachureGap
        }
        return options.zigzagOffset
    }
    
    /// Converts straight lines to zigzag patterns.
    private func zigzagLines(lines: [FillLine], options: Options) -> [Operation] {
        var ops: [Operation] = []
        
        let gap = max(options.computedHachureGap, options.strokeWidth * 4)
        let zigOffset = zigzagOffset(options: options)
        
        for line in lines {
            let length = line.length
            let zigCount = max(1, Int(round(length / (2 * zigOffset))))
            
            var start = line.start
            var end = line.end
            
            // Ensure consistent direction
            if start.x > end.x {
                swap(&start, &end)
            }
            
            let angle = atan2(end.y - start.y, end.x - start.x)
            let cos_a = cos(angle)
            let sin_a = sin(angle)
            
            // Zigzag amplitude (perpendicular to line)
            let amplitude = sqrt(2 * pow(zigOffset, 2))
            
            for i in 0..<zigCount {
                let t1 = Float(2 * i) * zigOffset
                let t2 = Float(2 * i + 2) * zigOffset
                
                // Start point
                let x1 = start.x + t1 * cos_a
                let y1 = start.y + t1 * sin_a
                
                // Peak point (offset perpendicular to line)
                let midT = t1 + zigOffset
                let peakX = start.x + midT * cos_a + amplitude * cos(angle + Float.pi / 4)
                let peakY = start.y + midT * sin_a + amplitude * sin(angle + Float.pi / 4)
                
                // End point
                let x2 = start.x + min(t2, length) * cos_a
                let y2 = start.y + min(t2, length) * sin_a
                
                // Draw two segments forming the zigzag
                ops.append(contentsOf: RoughMath.doubleLineOps(
                    x1: x1, y1: y1,
                    x2: peakX, y2: peakY,
                    options: options
                ))
                ops.append(contentsOf: RoughMath.doubleLineOps(
                    x1: peakX, y1: peakY,
                    x2: x2, y2: y2,
                    options: options
                ))
            }
        }
        
        return ops
    }
}

