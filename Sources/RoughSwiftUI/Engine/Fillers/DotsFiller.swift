//
//  DotsFiller.swift
//  RoughSwift
//
//  Dots fill pattern generator - small ellipses along hachure lines.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Generates dots fill patterns (small ellipses distributed along scan lines).
public struct DotsFiller: FillGenerator {
    
    private let hachureFiller = HachureFiller()
    
    public init() {}
    
    public func fillPolygon(points: [[Float]], options: Options) -> OperationSet? {
        // Use horizontal hachure for dot placement
        var dotOptions = options
        dotOptions.fillAngle = 0
        dotOptions.curveStepCount = 4
        
        let lines = hachureFiller.hachureLines(points: points, options: dotOptions)
        let ops = dotsOnLines(lines: lines, options: options)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    public func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        var dotOptions = options
        dotOptions.fillAngle = 0
        dotOptions.curveStepCount = 4
        
        let lines = hachureFiller.hachureEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: dotOptions)
        let ops = dotsOnLines(lines: lines, options: options)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    // MARK: - Dot Generation
    
    /// Places dots along the given lines.
    private func dotsOnLines(lines: [FillLine], options: Options) -> [Operation] {
        var ops: [Operation] = []
        
        var gap = options.computedHachureGap
        if gap < 0 {
            gap = options.strokeWidth * 4
        }
        gap = max(gap, 0.1)
        
        var fillWeight = options.effectiveFillWeight
        if fillWeight < 0 {
            fillWeight = options.strokeWidth / 2
        }
        
        for line in lines {
            let length = line.length
            let dotCount = Int(ceil(length / gap)) - 1
            
            if dotCount < 1 { continue }
            
            let angle = atan2(line.end.y - line.start.y, line.end.x - line.start.x)
            
            for i in 0..<dotCount {
                let distance = gap * Float(i + 1)
                let dx = distance * cos(angle)
                let dy = distance * sin(angle)
                
                // Offset the dot slightly from the exact line position
                let cx = line.start.x + dx + RoughMath.randOffsetWithRange(
                    -gap / 4, gap / 4, options: options
                )
                let cy = line.start.y + dy + RoughMath.randOffsetWithRange(
                    -gap / 4, gap / 4, options: options
                )
                
                // Draw small ellipse
                let ellipseOps = RoughMath.ellipseOps(
                    cx: cx, cy: cy,
                    rx: fillWeight, ry: fillWeight,
                    options: options
                )
                ops.append(contentsOf: ellipseOps)
            }
        }
        
        return ops
    }
}

