//
//  Option.swift
//  RoughSwift
//
//  Created by khoa on 19/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//
//  Modifications Copyright © 2025 Seth Stradling. All rights reserved.
//

import UIKit

/// Controls how the SVG fill stroke is aligned relative to the path.
public enum SVGFillStrokeAlignment: Equatable, Hashable, Sendable {
    /// Stroke is centered on the path (default behavior).
    case center
    /// Stroke is applied to the inside/inner edge of the path.
    case inside
    /// Stroke is applied to the outside/outer edge of the path.
    case outside
}

public struct Options: Equatable, Hashable {
    public var maxRandomnessOffset: Float = 2
    public var roughness: Float = 1
    public var bowing: Float = 1

    // Internal color storage goes through `RoughColor` so we can
    // easily bridge to hex / SwiftUI while keeping the public API
    // in terms of `UIColor` for now.
    private var strokeColor: RoughColor = RoughColor(uiColor: .black)
    private var fillColor: RoughColor = RoughColor(uiColor: .clear)

    /// Opacity of stroke color (0.0 = fully transparent, 1.0 = fully opaque).
    /// Range: 0.0 to 1.0. Default is 1.0.
    public var strokeOpacity: Float = 1.0
    
    /// Opacity of fill color (0.0 = fully transparent, 1.0 = fully opaque).
    /// Range: 0.0 to 1.0. Default is 1.0.
    public var fillOpacity: Float = 1.0

    public var strokeWidth: Float = 1
    public var curveTightness: Float = 0
    public var curveStepCount: Float = 9
    public var fillStyle: FillStyle = .hachure
    public var fillWeight: Float = -1
    
    /// The angle of fill lines in degrees (0-360). Default is 45°.
    /// - 0° = horizontal lines
    /// - 45° = diagonal lines (default)
    /// - 90° = vertical lines
    public var fillAngle: Float = 45
    
    /// Spacing between fill lines as a factor of fill line weight.
    /// Range: 0.5 to 100. Default is 4.0 (4x the fill weight).
    /// Lower values = denser fill, higher values = sparser fill.
    public var fillSpacing: Float = 4.0
    
    /// Optional pattern of spacing factors for creating gradient effects.
    /// Each value is a multiplier applied to fillSpacing.
    /// Example: [1, 1, 2, 3, 5, 8] creates increasingly sparse lines.
    /// When nil, uniform spacing (fillSpacing) is used.
    public var fillSpacingPattern: [Float]? = nil
    public var dashOffset: Float = -1
    public var dashGap: Float = -1
    public var zigzagOffset: Float = -1
    
    // MARK: - Scribble Fill Options
    
    /// The starting angle for scribble fill (0-360 degrees).
    /// 0 = right-center edge, 90 = bottom-center, 180 = left-center, 270 = top-center.
    /// The scribble traverses from this point to the opposite point (origin + 180).
    public var scribbleOrigin: Float = 0
    
    /// Number of zig-zags in the scribble fill. Higher values = denser fill.
    /// Range: 1 to 100. Default is 10.
    public var scribbleTightness: Int = 10
    
    /// Curvature of vertices in the zig-zag pattern.
    /// 0 = sharp corners, 50 = maximum curve (50% of segment length).
    /// Range: 0 to 50. Default is 0.
    public var scribbleCurvature: Float = 0
    
    /// Whether to use brush strokes for scribble fill lines.
    /// When true, applies the current brush profile for variable-width strokes.
    /// When false, uses simple straight strokes.
    public var scribbleUseBrushStroke: Bool = false
    
    /// Optional array of tightness values for variable density scribble fill.
    /// The traversal axis is divided into sections corresponding to the array length.
    /// Each section uses its corresponding tightness value from the array.
    /// Example: [10, 30, 10] creates sparse-dense-sparse pattern.
    /// When nil, uses uniform tightness from `scribbleTightness`.
    public var scribbleTightnessPattern: [Int]? = nil
    
    // MARK: - SVG-specific options
    
    /// Override stroke width for SVG paths. If nil, uses `strokeWidth`.
    public var svgStrokeWidth: Float? = nil
    
    /// Override fill weight for SVG paths. If nil, uses `fillWeight`.
    public var svgFillWeight: Float? = nil
    
    /// Controls how the SVG fill stroke is aligned relative to the path.
    /// - `.center`: Stroke centered on path (default)
    /// - `.inside`: Stroke on inner edge of path
    /// - `.outside`: Stroke on outer edge of path
    public var svgFillStrokeAlignment: SVGFillStrokeAlignment = .center
    
    /// Computed property that returns the effective stroke width for SVG rendering.
    public var effectiveSVGStrokeWidth: Float {
        svgStrokeWidth ?? strokeWidth
    }
    
    /// Computed property that returns the effective fill weight for SVG rendering.
    public var effectiveSVGFillWeight: Float {
        svgFillWeight ?? fillWeight
    }
    
    // MARK: - Brush Profile Options
    
    /// The brush profile for stroke rendering.
    /// Controls brush tip shape, thickness variation, and stroke caps/joins.
    public var brushProfile: BrushProfile = .default
    
    /// Convenience accessor for the brush tip configuration.
    public var brushTip: BrushTip {
        get { brushProfile.tip }
        set { brushProfile.tip = newValue }
    }
    
    /// Convenience accessor for the thickness profile.
    public var thicknessProfile: ThicknessProfile {
        get { brushProfile.thicknessProfile }
        set { brushProfile.thicknessProfile = newValue }
    }
    
    /// Convenience accessor for the stroke cap style.
    public var strokeCap: BrushCap {
        get { brushProfile.cap }
        set { brushProfile.cap = newValue }
    }
    
    /// Convenience accessor for the stroke join style.
    public var strokeJoin: BrushJoin {
        get { brushProfile.join }
        set { brushProfile.join = newValue }
    }

    /// Public-facing stroke color as `UIColor` for backward compatibility.
    public var stroke: UIColor {
        get { strokeColor.asUIColor }
        set { strokeColor = RoughColor(uiColor: newValue) }
    }

    /// Public-facing fill color as `UIColor` for backward compatibility.
    public var fill: UIColor {
        get { fillColor.asUIColor }
        set { fillColor = RoughColor(uiColor: newValue) }
    }

    public init() {}

    /// Computes the effective fill weight, handling the -1 auto value.
    var effectiveFillWeight: Float {
        fillWeight < 0 ? max(strokeWidth / 2, 1) : fillWeight
    }
    
    /// Computes the hachure gap from fillSpacing and fillWeight.
    var computedHachureGap: Float {
        let weight = effectiveFillWeight
        let clampedSpacing = max(0.5, min(100, fillSpacing))
        return weight * clampedSpacing
    }
    
    /// Computes a hash value for caching purposes.
    /// This hash covers all rendering-affecting properties.
    public var cacheHash: Int {
        var hasher = Hasher()
        hasher.combine(maxRandomnessOffset)
        hasher.combine(roughness)
        hasher.combine(bowing)
        hasher.combine(strokeWidth)
        hasher.combine(curveTightness)
        hasher.combine(curveStepCount)
        hasher.combine(fillStyle)
        hasher.combine(fillWeight)
        hasher.combine(fillAngle)
        hasher.combine(fillSpacing)
        hasher.combine(fillSpacingPattern)
        hasher.combine(dashOffset)
        hasher.combine(dashGap)
        hasher.combine(zigzagOffset)
        hasher.combine(scribbleOrigin)
        hasher.combine(scribbleTightness)
        hasher.combine(scribbleCurvature)
        hasher.combine(scribbleUseBrushStroke)
        hasher.combine(scribbleTightnessPattern)
        return hasher.finalize()
    }
    
    func toRoughDictionary() -> JSONDictionary {
        return [
            "maxRandomnessOffset": maxRandomnessOffset,
            "roughness": roughness,
            "bowing": bowing,
            "stroke": strokeColor.toHex(),
            "fill": fillColor.toHex(),
            "strokeWidth": strokeWidth,
            "curveTightness": curveTightness,
            "curveStepCount": curveStepCount,
            "fillStyle": fillStyle.rawValue,
            "fillWeight": fillWeight,
            "hachureAngle": fillAngle,
            "hachureGap": computedHachureGap,
            "dashOffset": dashOffset,
            "dashGap": dashGap,
            "zigzagOffset": zigzagOffset
        ]
    }
    
    /// Creates a copy of options with a specific hachure gap override.
    /// Used internally for pattern-based spacing.
    func withHachureGap(_ gap: Float) -> Options {
        var copy = self
        copy.fillSpacing = gap / copy.effectiveFillWeight
        return copy
    }
}

public extension Options {
    init(dictionary: JSONDictionary) {
        maxRandomnessOffset <-? (dictionary["maxRandomnessOffset"] as? NSNumber)?.floatValue
        roughness <-? (dictionary["roughness"] as? NSNumber)?.floatValue
        bowing <-? (dictionary["bowing"] as? NSNumber)?.floatValue
        strokeWidth <-? (dictionary["strokeWidth"] as? NSNumber)?.floatValue
        curveTightness <-? (dictionary["curveTightness"] as? NSNumber)?.floatValue
        curveStepCount <-? (dictionary["curveStepCount"] as? NSNumber)?.floatValue
        fillWeight <-? (dictionary["fillWeight"] as? NSNumber)?.floatValue
        fillAngle <-? (dictionary["hachureAngle"] as? NSNumber)?.floatValue
        dashOffset <-? (dictionary["dashOffset"] as? NSNumber)?.floatValue
        dashGap <-? (dictionary["dashGap"] as? NSNumber)?.floatValue
        zigzagOffset <-? (dictionary["zigzagOffset"] as? NSNumber)?.floatValue
        
        // Convert hachureGap back to fillSpacing factor
        if let gap = (dictionary["hachureGap"] as? NSNumber)?.floatValue, gap > 0 {
            let weight = effectiveFillWeight
            fillSpacing = gap / weight
        }

        if let fillStyleRawValue = dictionary["fillStyle"] as? String,
           let fillStyle = FillStyle(rawValue: fillStyleRawValue) {
            self.fillStyle = fillStyle
        }

        stroke <-? (dictionary["stroke"] as? String).map(UIColor.init(hex:))
        fill <-? (dictionary["fill"] as? String).map(UIColor.init(hex:))
    }
}
