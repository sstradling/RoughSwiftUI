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
    
    /// The angle of fill lines in degrees. Default is 45°.
    ///
    /// Core Graphics y points down, so positive angles rotate clockwise from
    /// the +x axis. The same bearing is used by hachure, zigzag, cross-hatch,
    /// dashed, and zigzag-line fills, and by the horizontal dot grid at 0°:
    /// - 0° = horizontal lines
    /// - 45° = diagonal lines (default)
    /// - 90° = vertical lines
    ///
    /// Dots always place marks on the 0° grid. Scribble strokes use
    /// `scribbleOrigin` instead, with the same clockwise bearing. Starburst
    /// fills are radial and ignore this angle.
    public var fillAngle: Float = 45

    /// How far the fill sits inside the outline, in points.
    ///
    /// `0` puts the fill edge on the same shape the outline draws. A positive
    /// value insets every fill style: ellipse and circle radii shrink, and
    /// polygon edges move inward. A negative value grows the fill past the
    /// outline. When the inset collapses the shape, the fill is omitted.
    public var fillPadding: CGFloat = 0

    /// Shifts the fill relative to the outline. `.zero` leaves it centered.
    public var fillOffset: CGSize = .zero

    /// Seed for roughness, bowing, and fill wobble.
    ///
    /// `nil` (the default) keeps the system random generator, so an uncached
    /// drawing is different each time it is built. A value restarts a
    /// `SplitMix64` sequence at each `NativeGenerator.generate`, direct filler
    /// call, and scribble generation. Nested stroke and fill work keeps
    /// consuming that sequence instead of starting over.
    ///
    /// Crayon grain still uses `CrayonStyle.seed`. When this property is set
    /// and the crayon seed is still `CrayonStyle.defaultSeed` (1), grain is
    /// taken from this seed. Any other crayon seed wins. `nil` leaves the
    /// crayon seed unchanged.
    public var seed: UInt64? = nil
    
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

    /// Selects between sampled-point (legacy) and continuous-Bezier stroke
    /// generation for native curved shapes (circle, ellipse, arc, egg,
    /// rounded-rectangle corners, polygons, lines).
    ///
    /// Default is `.legacy` so existing visual snapshots and downstream
    /// tests are unaffected. Opt in per-view with
    /// `RoughView.strokeContinuity(.continuous)` to render true cubic
    /// Bezier curves instead of point-sampled approximations.
    ///
    /// See `StrokeContinuity` for a full discussion of the tradeoffs.
    public var strokeContinuity: StrokeContinuity = .legacy
    
    // MARK: - Scribble Fill Options
    
    /// Direction of each scribble stroke, in degrees.
    ///
    /// Core Graphics y points down: 0 runs to the right, 90 runs straight down,
    /// and positive angles rotate clockwise. The return stroke comes back along
    /// the same bearing. Range is any angle; values wrap at 360.
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

    /// Opacity multiplier along the outline. `.uniform` is 1.
    public var opacityProfile: OpacityProfile {
        get { brushProfile.opacityProfile }
        set { brushProfile.opacityProfile = newValue }
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
    ///
    /// The hash covers geometry, colour, opacity, brush, and seed. `Hasher`
    /// is salted per process, so compare hashes inside one run only.
    /// The drawing cache stores geometry and applies colour at render time;
    /// it includes `seed` because the seed changes the paths, and it leaves
    /// colour, opacity, and brush out of that geometry key.
    public var cacheHash: Int {
        var hasher = Hasher()
        hasher.combine(maxRandomnessOffset)
        hasher.combine(roughness)
        hasher.combine(bowing)
        hasher.combine(strokeColor)
        hasher.combine(fillColor)
        hasher.combine(strokeOpacity)
        hasher.combine(fillOpacity)
        hasher.combine(strokeWidth)
        hasher.combine(curveTightness)
        hasher.combine(curveStepCount)
        hasher.combine(fillStyle)
        hasher.combine(fillWeight)
        hasher.combine(fillAngle)
        hasher.combine(fillPadding)
        hasher.combine(fillOffset.width)
        hasher.combine(fillOffset.height)
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
        hasher.combine(strokeContinuity)
        hasher.combine(svgStrokeWidth)
        hasher.combine(svgFillWeight)
        hasher.combine(svgFillStrokeAlignment)
        hasher.combine(brushProfile)
        hasher.combine(seed)
        return hasher.finalize()
    }

    /// Crayon texture after resolving `seed`.
    ///
    /// An explicit `CrayonStyle.seed` other than `CrayonStyle.defaultSeed`
    /// is kept. When `seed` is set and the crayon style is still on that
    /// default, the grain seed becomes `seed`.
    public var resolvedCrayonStyle: CrayonStyle? {
        guard var crayon = brushProfile.crayon else { return nil }
        if let seed, crayon.seed == CrayonStyle.defaultSeed {
            crayon.seed = seed
        }
        return crayon
    }

    /// Opacity profile after `Options.seed` replaces `OpacityNoise.defaultSeed`.
    ///
    /// A noise seed other than `1` is kept.
    func resolvedOpacityProfile() -> OpacityProfile {
        guard case .noise(var noise) = brushProfile.opacityProfile else {
            return brushProfile.opacityProfile
        }
        if let seed, noise.seed == OpacityNoise.defaultSeed {
            noise = noise.with(seed: seed)
            return .noise(noise)
        }
        return .noise(noise)
    }

    /// Watercolor brush after `Options.seed` replaces a default style seed.
    ///
    /// Width and opacity that were baked from `WatercolorStyle.defaultSeed`
    /// follow the same seed. An explicit watercolor seed, or a profile whose
    /// seed is not that default, is left alone.
    func resolvedWatercolorBrush() -> (profile: BrushProfile, style: WatercolorStyle)? {
        guard var style = brushProfile.watercolor else { return nil }
        var profile = brushProfile
        if let seed, style.seed == WatercolorStyle.defaultSeed {
            if case .variable(var width) = profile.thicknessProfile, width.seed == WatercolorStyle.defaultSeed {
                profile.thicknessProfile = .variable(width.with(seed: seed))
            }
            if case .noise(var noise) = profile.opacityProfile, noise.seed == WatercolorStyle.defaultSeed &+ 17 {
                profile.opacityProfile = .noise(noise.with(seed: seed &+ 17))
            }
            style.seed = seed
            profile.watercolor = style
        }
        return (profile, style)
    }

    /// Style for `.fillStyle(.watercolor)`.
    ///
    /// A watercolor brush shares its resolved style. Otherwise the fill uses
    /// `WatercolorStyle()`, and `Options.seed` replaces the default seed.
    func resolvedWatercolorFillStyle() -> WatercolorStyle {
        if let (_, style) = resolvedWatercolorBrush() {
            return style
        }
        var style = WatercolorStyle()
        if let seed {
            style.seed = seed
        }
        return style
    }
    
    func toRoughDictionary() -> JSONDictionary {
        var dictionary: JSONDictionary = [
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
            "fillPadding": Double(fillPadding),
            "fillOffsetX": Double(fillOffset.width),
            "fillOffsetY": Double(fillOffset.height),
            "dashOffset": dashOffset,
            "dashGap": dashGap,
            "zigzagOffset": zigzagOffset
        ]
        if let seed {
            dictionary["seed"] = NSNumber(value: seed)
        }
        return dictionary
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
        if let padding = (dictionary["fillPadding"] as? NSNumber)?.doubleValue {
            fillPadding = CGFloat(padding)
        }
        let offsetX = (dictionary["fillOffsetX"] as? NSNumber)?.doubleValue ?? 0
        let offsetY = (dictionary["fillOffsetY"] as? NSNumber)?.doubleValue ?? 0
        if offsetX != 0 || offsetY != 0 {
            fillOffset = CGSize(width: offsetX, height: offsetY)
        }
        dashOffset <-? (dictionary["dashOffset"] as? NSNumber)?.floatValue
        dashGap <-? (dictionary["dashGap"] as? NSNumber)?.floatValue
        zigzagOffset <-? (dictionary["zigzagOffset"] as? NSNumber)?.floatValue
        if let seedNumber = dictionary["seed"] as? NSNumber {
            seed = seedNumber.uint64Value
        }
        
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
