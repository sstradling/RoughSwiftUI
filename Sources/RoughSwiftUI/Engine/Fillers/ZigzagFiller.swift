//
//  ZigzagFiller.swift
//  RoughSwift
//
//  Zigzag fill pattern generator - hachure with connected endpoints.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Generates zigzag fill patterns (hachure lines connected at endpoints).
public struct ZigzagFiller: FillGenerator {
    
    private let hachureFiller = HachureFiller()
    
    public init() {}
    
    public func fillPolygon(points: [[Float]], options: Options) -> OperationSet? {
        let lines = hachureFiller.hachureLines(points: points, options: options)
        let ops = hachureFiller.renderLines(lines: lines, options: options, connect: true)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    public func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        let lines = hachureFiller.hachureEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: options)
        let ops = hachureFiller.renderLines(lines: lines, options: options, connect: true)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
}

