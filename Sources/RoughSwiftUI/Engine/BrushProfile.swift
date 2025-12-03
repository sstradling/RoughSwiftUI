//
//  BrushProfile.swift
//  RoughSwift
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  Custom brush profile types for variable-width strokes.
//

import Foundation
import CoreGraphics

// MARK: - Brush Tip

/// Configuration for an ellipse-based brush tip.
///
/// The brush tip determines how stroke width varies based on stroke direction.
/// A circular tip (roundness = 1.0) produces uniform width regardless of direction,
/// while a flat ellipse creates calligraphic-style strokes.
public struct BrushTip: Equatable, Hashable, Sendable {
    /// Aspect ratio of the ellipse (1.0 = circle, approaching 0 = flat ellipse).
    /// Valid range: 0.01 to 1.0. Default is 1.0 (circular).
    public var roundness: CGFloat
    
    /// Rotation angle of the ellipse in radians.
    /// 0 = horizontal ellipse, π/2 = vertical ellipse.
    public var angle: CGFloat
    
    /// Whether the stroke width varies with stroke direction.
    /// When false, the brush tip acts as a circle regardless of roundness.
    public var directionSensitive: Bool
    
    /// Creates a brush tip with the specified parameters.
    /// - Parameters:
    ///   - roundness: Aspect ratio (0.01-1.0). Default: 1.0 (circle).
    ///   - angle: Rotation angle in radians. Default: 0.
    ///   - directionSensitive: Whether width varies with direction. Default: true.
    public init(
        roundness: CGFloat = 1.0,
        angle: CGFloat = 0,
        directionSensitive: Bool = true
    ) {
        self.roundness = max(0.01, min(1.0, roundness))
        self.angle = angle
        self.directionSensitive = directionSensitive
    }
    
    /// A circular brush tip that produces uniform stroke width.
    public static let circular = BrushTip(roundness: 1.0, angle: 0, directionSensitive: false)
    
    /// A calligraphic brush tip angled at 45 degrees.
    public static let calligraphic = BrushTip(roundness: 0.3, angle: .pi / 4, directionSensitive: true)
    
    /// A flat horizontal brush tip for ribbon-like strokes.
    public static let flat = BrushTip(roundness: 0.2, angle: 0, directionSensitive: true)
    
    /// Computes the effective stroke width for a given stroke direction.
    ///
    /// For an ellipse with semi-axes a (along brush angle) and b (perpendicular),
    /// the width when cutting at strokeAngle is derived from the ellipse equation.
    ///
    /// - Parameters:
    ///   - baseWidth: The base stroke width.
    ///   - strokeAngle: The direction of the stroke at the current point (in radians).
    /// - Returns: The effective width at this point.
    public func effectiveWidth(baseWidth: CGFloat, strokeAngle: CGFloat) -> CGFloat {
        guard directionSensitive && roundness < 1.0 else {
            return baseWidth
        }
        
        // Semi-axes: a is along the brush angle, b is perpendicular
        // For a brush, we want the width perpendicular to stroke direction
        let a = baseWidth / 2  // Semi-axis along brush angle
        let b = a * roundness  // Semi-axis perpendicular (scaled by roundness)
        
        // Relative angle between stroke direction and brush orientation
        let relativeAngle = strokeAngle - angle
        
        // Width of ellipse perpendicular to stroke direction
        // Using the formula for ellipse radius at angle theta
        let cosTheta = cos(relativeAngle)
        let sinTheta = sin(relativeAngle)
        
        let denominator = sqrt(pow(b * cosTheta, 2) + pow(a * sinTheta, 2))
        guard denominator > 0.001 else {
            return baseWidth
        }
        
        let width = (2 * a * b) / denominator
        return width
    }
}

// MARK: - Thickness Profile

/// Defines how stroke thickness varies along the length of a stroke.
///
/// Thickness profiles allow for effects like tapered ends, pressure simulation,
/// or custom artistic variations.
public enum ThicknessProfile: Equatable, Hashable, Sendable {
    /// Uniform thickness along the entire stroke.
    case uniform
    
    /// Taper at the start of the stroke.
    /// - Parameter start: How far along the stroke (0-1) the taper extends.
    case taperIn(start: CGFloat)
    
    /// Taper at the end of the stroke.
    /// - Parameter end: How far from the end (0-1) the taper begins.
    case taperOut(end: CGFloat)
    
    /// Taper at both ends of the stroke.
    /// - Parameters:
    ///   - start: How far along (0-1) the start taper extends.
    ///   - end: How far from the end (0-1) the end taper begins.
    case taperBoth(start: CGFloat, end: CGFloat)
    
    /// Simulated pressure curve - starts light, peaks in middle, ends light.
    /// - Parameter values: Array of pressure values (0-1) to interpolate.
    case pressure([CGFloat])
    
    /// Custom thickness values to interpolate along the stroke.
    /// - Parameter values: Array of thickness multipliers (typically 0-1).
    case custom([CGFloat])
    
    // MARK: - Preset Profiles
    
    /// Natural pen stroke - tapers at both ends.
    public static let naturalPen = ThicknessProfile.taperBoth(start: 0.15, end: 0.15)
    
    /// Brush stroke starting from a point.
    public static let brushStart = ThicknessProfile.taperIn(start: 0.25)
    
    /// Brush stroke ending in a point.
    public static let brushEnd = ThicknessProfile.taperOut(end: 0.25)
    
    /// Simulated pen pressure curve.
    public static let penPressure = ThicknessProfile.pressure([0.2, 0.6, 0.9, 1.0, 0.95, 0.8, 0.5, 0.2])
    
    /// Computes the thickness multiplier at a given position along the stroke.
    ///
    /// - Parameter t: Position along the stroke, from 0 (start) to 1 (end).
    /// - Returns: Thickness multiplier (typically 0-1, but can exceed 1 for emphasis).
    public func multiplier(at t: CGFloat) -> CGFloat {
        let clampedT = max(0, min(1, t))
        
        switch self {
        case .uniform:
            return 1.0
            
        case .taperIn(let start):
            guard start > 0 else { return 1.0 }
            if clampedT < start {
                return clampedT / start
            }
            return 1.0
            
        case .taperOut(let end):
            guard end > 0 else { return 1.0 }
            let endStart = 1.0 - end
            if clampedT > endStart {
                return (1.0 - clampedT) / end
            }
            return 1.0
            
        case .taperBoth(let start, let end):
            let startMultiplier = ThicknessProfile.taperIn(start: start).multiplier(at: clampedT)
            let endMultiplier = ThicknessProfile.taperOut(end: end).multiplier(at: clampedT)
            return min(startMultiplier, endMultiplier)
            
        case .pressure(let values), .custom(let values):
            return interpolate(values: values, at: clampedT)
        }
    }
    
    /// Linear interpolation through an array of values.
    private func interpolate(values: [CGFloat], at t: CGFloat) -> CGFloat {
        guard !values.isEmpty else { return 1.0 }
        guard values.count > 1 else { return values[0] }
        
        let scaledT = t * CGFloat(values.count - 1)
        let lowerIndex = Int(scaledT)
        let upperIndex = min(lowerIndex + 1, values.count - 1)
        let fraction = scaledT - CGFloat(lowerIndex)
        
        let lowerValue = values[lowerIndex]
        let upperValue = values[upperIndex]
        
        return lowerValue + (upperValue - lowerValue) * fraction
    }
}

// MARK: - Stroke Cap

/// Style for the ends of strokes.
public enum BrushCap: Equatable, Hashable, Sendable {
    /// Square end exactly at the endpoint.
    case butt
    /// Rounded end extending past the endpoint by half the stroke width.
    case round
    /// Square end extending past the endpoint by half the stroke width.
    case square
    
    /// Converts to SwiftUI's CGLineCap for standard stroke rendering.
    public var cgLineCap: CGLineCap {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
}

// MARK: - Stroke Join

/// Style for corners/vertices in strokes.
public enum BrushJoin: Equatable, Hashable, Sendable {
    /// Sharp corner with miter limit.
    case miter
    /// Rounded corner.
    case round
    /// Beveled (flat) corner.
    case bevel
    
    /// Converts to SwiftUI's CGLineJoin for standard stroke rendering.
    public var cgLineJoin: CGLineJoin {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }
}

// MARK: - Brush Profile

/// Complete brush profile combining tip, thickness, and stroke style.
///
/// Use this to configure the full appearance of strokes in RoughSwiftUI.
public struct BrushProfile: Equatable, Hashable, Sendable {
    /// The brush tip configuration.
    public var tip: BrushTip
    
    /// The thickness profile along the stroke.
    public var thicknessProfile: ThicknessProfile
    
    /// Style for stroke endpoints.
    public var cap: BrushCap
    
    /// Style for stroke corners/vertices.
    public var join: BrushJoin
    
    /// Creates a brush profile with the specified components.
    public init(
        tip: BrushTip = .circular,
        thicknessProfile: ThicknessProfile = .uniform,
        cap: BrushCap = .round,
        join: BrushJoin = .round
    ) {
        self.tip = tip
        self.thicknessProfile = thicknessProfile
        self.cap = cap
        self.join = join
    }
    
    /// Default brush profile - circular tip with uniform thickness.
    public static let `default` = BrushProfile()
    
    /// Calligraphic brush with tapered ends.
    public static let calligraphic = BrushProfile(
        tip: .calligraphic,
        thicknessProfile: .naturalPen,
        cap: .round,
        join: .round
    )
    
    /// Marker-style brush with flat tip.
    public static let marker = BrushProfile(
        tip: .flat,
        thicknessProfile: .uniform,
        cap: .butt,
        join: .bevel
    )
    
    /// Pen-style brush with pressure simulation.
    public static let pen = BrushProfile(
        tip: .circular,
        thicknessProfile: .penPressure,
        cap: .round,
        join: .round
    )
    
    /// Whether this profile requires custom stroke-to-fill conversion.
    /// Returns false for simple profiles that can use standard stroke rendering.
    public var requiresCustomRendering: Bool {
        // Need custom rendering if:
        // 1. Brush tip is not circular and direction-sensitive
        // 2. Thickness profile is not uniform
        let hasNonCircularTip = tip.directionSensitive && tip.roundness < 0.99
        let hasVariableThickness = thicknessProfile != .uniform
        
        return hasNonCircularTip || hasVariableThickness
    }
}

