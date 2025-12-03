//
//  CrossHatchFiller.swift
//  RoughSwift
//
//  Cross-hatch fill pattern generator - two perpendicular hachure layers.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Generates cross-hatch fill patterns (hachure at two perpendicular angles).
public struct CrossHatchFiller: FillGenerator {
    
    private let hachureFiller = HachureFiller()
    
    public init() {}
    
    public func fillPolygon(points: [[Float]], options: Options) -> OperationSet? {
        // First pass at original angle
        let lines1 = hachureFiller.hachureLines(points: points, options: options)
        var ops = hachureFiller.renderLines(lines: lines1, options: options, connect: false)
        
        // Second pass at perpendicular angle
        var options2 = options
        options2.fillAngle = options.fillAngle + 90
        let lines2 = hachureFiller.hachureLines(points: points, options: options2)
        ops.append(contentsOf: hachureFiller.renderLines(lines: lines2, options: options2, connect: false))
        
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    public func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        // First pass at original angle
        let lines1 = hachureFiller.hachureEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: options)
        var ops = hachureFiller.renderLines(lines: lines1, options: options, connect: false)
        
        // Second pass at perpendicular angle
        var options2 = options
        options2.fillAngle = options.fillAngle + 90
        let lines2 = hachureFiller.hachureEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: options2)
        ops.append(contentsOf: hachureFiller.renderLines(lines: lines2, options: options2, connect: false))
        
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
}

