//
//  CGPathToSVG.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  Converts CGPath to SVG path string for use with rough.js.
//

import CoreGraphics

/// Extension to convert `CGPath` to SVG path string format.
public extension CGPath {
    
    /// Convert this `CGPath` to an SVG path string (d attribute format).
    ///
    /// The SVG path string can be used with rough.js via the `Path(d:)` drawable
    /// to render the path with hand-drawn styling.
    ///
    /// Supported path elements:
    /// - Move to (M)
    /// - Line to (L)
    /// - Quadratic curve (Q)
    /// - Cubic curve (C)
    /// - Close path (Z)
    ///
    /// - Parameter precision: Number of decimal places for coordinates. Default is 2.
    /// - Returns: An SVG path string suitable for the `d` attribute.
    func toSVGPathString(precision: Int = 2) -> String {
        var svg = ""
        
        self.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            let points = element.points
            
            switch element.type {
            case .moveToPoint:
                let p = points[0]
                svg += "M\(format(p.x, precision)) \(format(p.y, precision))"
                
            case .addLineToPoint:
                let p = points[0]
                svg += "L\(format(p.x, precision)) \(format(p.y, precision))"
                
            case .addQuadCurveToPoint:
                // Quad curve: control point is points[0], end point is points[1]
                let cp = points[0]
                let p = points[1]
                svg += "Q\(format(cp.x, precision)) \(format(cp.y, precision)) \(format(p.x, precision)) \(format(p.y, precision))"
                
            case .addCurveToPoint:
                // Cubic curve: control1 is points[0], control2 is points[1], end is points[2]
                let cp1 = points[0]
                let cp2 = points[1]
                let p = points[2]
                svg += "C\(format(cp1.x, precision)) \(format(cp1.y, precision)) \(format(cp2.x, precision)) \(format(cp2.y, precision)) \(format(p.x, precision)) \(format(p.y, precision))"
                
            case .closeSubpath:
                svg += "Z"
                
            @unknown default:
                break
            }
        }
        
        return svg
    }
    
    /// Convert this `CGPath` to an SVG path string, applying a transform first.
    ///
    /// This is useful for flipping coordinates (e.g., to convert from CoreGraphics
    /// coordinate system to SVG coordinate system) or scaling.
    ///
    /// - Parameters:
    ///   - transform: The transform to apply before conversion.
    ///   - precision: Number of decimal places for coordinates. Default is 2.
    /// - Returns: An SVG path string suitable for the `d` attribute.
    func toSVGPathString(applying transform: CGAffineTransform, precision: Int = 2) -> String {
        guard let transformedPath = self.copy(using: [transform]) else {
            return toSVGPathString(precision: precision)
        }
        return transformedPath.toSVGPathString(precision: precision)
    }
    
    /// Convert this `CGPath` to an SVG path string, flipping Y coordinates.
    ///
    /// CoreGraphics uses a coordinate system where Y increases upward, but SVG
    /// uses a coordinate system where Y increases downward. This method flips
    /// the Y axis around the path's vertical center.
    ///
    /// - Parameter precision: Number of decimal places for coordinates. Default is 2.
    /// - Returns: An SVG path string with Y coordinates flipped.
    func toSVGPathStringFlippingY(precision: Int = 2) -> String {
        let bounds = self.boundingBox
        guard !bounds.isNull && !bounds.isInfinite else {
            return toSVGPathString(precision: precision)
        }
        
        // Flip around the vertical center of the bounding box
        // This transforms y' = bounds.maxY + bounds.minY - y
        // Which is equivalent to: translate, scale -1, translate back
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: 0, y: bounds.maxY + bounds.minY)
        transform = transform.scaledBy(x: 1, y: -1)
        
        return toSVGPathString(applying: transform, precision: precision)
    }
}

// MARK: - Private Helpers

private func format(_ value: CGFloat, _ precision: Int) -> String {
    let formatted = String(format: "%.\(precision)f", value)
    // Remove trailing zeros and unnecessary decimal point
    var result = formatted
    if result.contains(".") {
        while result.hasSuffix("0") {
            result.removeLast()
        }
        if result.hasSuffix(".") {
            result.removeLast()
        }
    }
    return result
}

