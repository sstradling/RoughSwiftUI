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

// MARK: - Width Stop

/// An absolute stroke width at one position along a stroke.
///
/// `position` is the fraction of the stroke length, 0 at the start and 1 at
/// the end. `width` is points, not a multiple of `strokeWidth`.
/// `ThicknessProfile.stops` sorts stops and interpolates between them.
public struct WidthStop: Equatable, Hashable, Sendable {
    /// Fraction of the stroke length. Clamped to 0...1.
    public var position: CGFloat

    /// Width in points at `position`. Clamped to at least 0.
    public var width: CGFloat

    /// Creates a stop.
    ///
    /// - Parameters:
    ///   - position: Fraction of the stroke length. Values outside 0...1 are clamped.
    ///   - width: Width in points. Negative values are clamped to 0.
    public init(position: CGFloat, width: CGFloat) {
        self.position = min(1, max(0, position))
        self.width = max(0, width)
    }

    /// Linear width at `t` through `stops`, or `nil` when `stops` is empty.
    ///
    /// Stops are sorted by position. A later stop wins when two share a
    /// position. Before the first stop and after the last, the end widths hold.
    /// `t` is clamped to 0...1.
    static func width(of stops: [WidthStop], at t: CGFloat) -> CGFloat? {
        guard !stops.isEmpty else { return nil }
        let t = min(1, max(0, t))
        let sorted = stops.sorted { $0.position < $1.position }
        var collapsed: [WidthStop] = []
        collapsed.reserveCapacity(sorted.count)
        for stop in sorted {
            if let last = collapsed.last, last.position == stop.position {
                collapsed[collapsed.count - 1] = stop
            } else {
                collapsed.append(stop)
            }
        }

        guard let first = collapsed.first else { return nil }
        if t <= first.position {
            return first.width
        }
        guard let last = collapsed.last else { return nil }
        if t >= last.position {
            return last.width
        }
        for index in 1..<collapsed.count {
            let right = collapsed[index]
            if t <= right.position {
                let left = collapsed[index - 1]
                let span = right.position - left.position
                if span <= 0 {
                    return right.width
                }
                let fraction = (t - left.position) / span
                return left.width + (right.width - left.width) * fraction
            }
        }
        return last.width
    }
}

// MARK: - Thickness Profile

/// Defines how stroke thickness varies along the length of a stroke.
///
/// Thickness profiles allow for effects like tapered ends, pressure simulation,
/// or custom artistic variations. A brush stores one profile. `.stops` and
/// `.variable` do not multiply; setting one replaces the other.
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
    
    /// Evenly spaced multipliers of `strokeWidth`.
    ///
    /// The first value is the start of the stroke and the last value is the
    /// end. Values are spaced by `1 / (count - 1)`. With `strokeWidth` 8,
    /// `.custom([0.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.5])` is 4pt at the start,
    /// 8pt at 10% of the length, 8pt through 90%, and 4pt at the end.
    ///
    /// For point widths at chosen positions, use `.stops`.
    /// - Parameter values: Thickness multipliers. An empty list is a multiplier of 1.
    case custom([CGFloat])

    /// Absolute widths in points at positions along the stroke.
    ///
    /// Each `WidthStop` is a position from 0 to 1 and a width in points.
    /// Stops are sorted by position. Linear interpolation connects them.
    /// Before the first stop and after the last, the end widths hold.
    /// Positions are clamped to 0...1. An empty list is an even `strokeWidth`.
    ///
    /// A non-empty list ignores `strokeWidth` (and `fillWeight`, when a
    /// scribble stroke uses this profile). The brush tip still scales the
    /// result by stroke direction, so a flat marker is thinner when the stroke
    /// runs along the tip. `.variable` noise is not applied on top: this case
    /// replaces that profile. Closed contours ignore the stops and draw an
    /// even `strokeWidth` so the join does not seam.
    ///
    /// `.custom([0.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.5])` at `strokeWidth` 8
    /// matches `.stops` of 4pt, 8pt at 10%, 8pt at 90%, and 4pt at the end.
    case stops([WidthStop])

    /// Seeded width along the stroke. See `VariableStrokeWidth`.
    ///
    /// The marker factory builds this. Other brushes can use it through
    /// `thicknessProfile(_:)`. Closed contours still render at an even width.
    case variable(VariableStrokeWidth)
    
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
    /// This is a fraction of `strokeWidth` for every case except `.stops`.
    /// `.stops` stores point widths, so this returns `1` and the renderer uses
    /// `width(at:strokeWidth:)` instead. That includes a non-empty stop list:
    /// the point width is not a multiplier.
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

        case .variable(let width):
            return width.multiplier(at: clampedT)

        case .stops:
            return 1
        }
    }

    /// Stroke width in points at `t`.
    ///
    /// Multiplier profiles, including `.custom` and `.variable`, scale
    /// `strokeWidth`. Non-empty `.stops` return the interpolated point width
    /// and ignore `strokeWidth`. Empty `.stops` return `strokeWidth`.
    ///
    /// The brush tip may still scale this width by stroke direction. Closed
    /// contours do not call this with the stop list; they use an even
    /// `strokeWidth`.
    ///
    /// - Parameters:
    ///   - t: Position along the stroke, from 0 (start) to 1 (end). Clamped.
    ///   - strokeWidth: Base width in points for multiplier profiles.
    /// - Returns: Width in points.
    public func width(at t: CGFloat, strokeWidth: CGFloat) -> CGFloat {
        switch self {
        case .stops(let stops):
            return WidthStop.width(of: stops, at: t) ?? strokeWidth
        default:
            return multiplier(at: t) * strokeWidth
        }
    }

    /// Multiplier of `strokeWidth` that produces `width(at:strokeWidth:)`.
    ///
    /// For `.stops`, this is the interpolated point width divided by
    /// `strokeWidth`. Empty stops return `1`. A non-empty list and a
    /// `strokeWidth` of `0` return `0` because the ratio is undefined; the
    /// rendered width is still the point width from `width(at:strokeWidth:)`.
    /// Every other profile returns `multiplier(at:)`.
    public func multiplier(at t: CGFloat, strokeWidth: CGFloat) -> CGFloat {
        switch self {
        case .stops(let stops):
            guard !stops.isEmpty else { return 1 }
            guard strokeWidth != 0 else { return 0 }
            return width(at: t, strokeWidth: strokeWidth) / strokeWidth
        default:
            return multiplier(at: t)
        }
    }

    /// True when an open stroke should vary its width along the path.
    ///
    /// Empty `.stops` are uniform. An empty `.custom` or `.pressure` list is
    /// still a distinct profile and stays on the variable-width path.
    var variesAlongStroke: Bool {
        switch self {
        case .uniform:
            return false
        case .stops(let stops):
            return !stops.isEmpty
        default:
            return true
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
/// Use this to configure the full appearance of strokes in Sketchy.
public struct BrushProfile: Equatable, Hashable, Sendable {
    /// The brush tip configuration.
    public var tip: BrushTip
    
    /// The thickness profile along the stroke.
    public var thicknessProfile: ThicknessProfile
    
    /// Style for stroke endpoints.
    public var cap: BrushCap
    
    /// Style for stroke corners/vertices.
    public var join: BrushJoin

    /// Wax-crayon texture. When set, strokes are a continuous greasy base with
    /// grit on top, instead of a solid stroke or a variable-width outline.
    ///
    /// `nil` keeps the existing stroke behavior. Default profiles leave this `nil`.
    public var crayon: CrayonStyle?

    /// Opacity along the stroke. `.uniform` leaves existing strokes unchanged.
    ///
    /// The value multiplies `Options.strokeOpacity`. A profile that changes
    /// along the stroke is painted into one mask so segment overlaps do not darken.
    public var opacityProfile: OpacityProfile

    /// Wet-wash settings. `nil` keeps the existing stroke. See `watercolor(...)`.
    public var watercolor: WatercolorStyle?
    
    /// Creates a brush profile with the specified components.
    public init(
        tip: BrushTip = .circular,
        thicknessProfile: ThicknessProfile = .uniform,
        cap: BrushCap = .round,
        join: BrushJoin = .round,
        crayon: CrayonStyle? = nil,
        opacityProfile: OpacityProfile = .uniform,
        watercolor: WatercolorStyle? = nil
    ) {
        self.tip = tip
        self.thicknessProfile = thicknessProfile
        self.cap = cap
        self.join = join
        self.crayon = crayon
        self.opacityProfile = opacityProfile
        self.watercolor = watercolor
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
    
    /// Marker-style brush with a flat tip, butt caps, and an even width.
    ///
    /// `marker(variation:minimum:maximum:taperStart:taperEnd:pressure:seed:)`
    /// is the same tip with width that changes along an open stroke.
    public static let marker = BrushProfile(
        tip: .flat,
        thicknessProfile: .uniform,
        cap: .butt,
        join: .bevel
    )

    /// Marker with width that changes along an open stroke.
    ///
    /// Defaults match `BrushProfile.marker`: flat tip, butt caps, bevel joins,
    /// and a multiplier of 1. `variation` sizes the wobble when the bounds are
    /// omitted. `minimum` and `maximum` are multipliers of `strokeWidth`.
    /// Taper uses the same ramps as `ThicknessProfile.taperIn` and `taperOut`
    /// and may reach 0. `pressure` is interpolated like `ThicknessProfile.pressure`
    /// and then multiplied by the noisy body. `seed` repeats the wobble.
    ///
    /// Closed contours ignore this profile and keep an even width.
    /// `.widthStops` replaces this profile, including the noise. The flat tip
    /// stays, and it scales the stop width by stroke direction.
    ///
    /// - Parameters:
    ///   - variation: Fraction of `strokeWidth` the width may wander, 0...1. Default 0.
    ///   - minimum: Lower body multiplier. Default derived from `variation`, or the whole span when bounds are set and `variation` is 0.
    ///   - maximum: Upper multiplier. Default derived from `variation`.
    ///   - taperStart: Fraction of the stroke that thins at the start. Default 0.
    ///   - taperEnd: Fraction of the stroke that thins at the end. Default 0.
    ///   - pressure: Pressure multipliers along the stroke. Default empty.
    ///   - seed: Stable noise seed. Default 1.
    ///   - frequency: Noise cycles along the stroke. Default 3.
    public static func marker(
        variation: CGFloat = 0,
        minimum: CGFloat? = nil,
        maximum: CGFloat? = nil,
        taperStart: CGFloat = 0,
        taperEnd: CGFloat = 0,
        pressure: [CGFloat] = [],
        seed: UInt64 = 1,
        frequency: CGFloat = 3
    ) -> BrushProfile {
        let width = VariableStrokeWidth(
            variation: variation,
            minimum: minimum,
            maximum: maximum,
            taperStart: taperStart,
            taperEnd: taperEnd,
            pressure: pressure,
            seed: seed,
            frequency: frequency
        )
        guard width.changesWidth else { return .marker }
        return BrushProfile(
            tip: .flat,
            thicknessProfile: .variable(width),
            cap: .butt,
            join: .bevel
        )
    }
    
    /// Pen-style brush with pressure simulation.
    public static let pen = BrushProfile(
        tip: .circular,
        thicknessProfile: .penPressure,
        cap: .round,
        join: .round
    )

    /// Wax-crayon stroke: a continuous greasy base with dense grit on top.
    ///
    /// The preset uses a circular tip. Texture comes from `crayon`, not from
    /// the calligraphic outline converter. `strokeWidth` is the wax width in points.
    public static let crayon = BrushProfile(crayon: CrayonStyle())

    /// Crayon preset with explicit texture settings.
    ///
    /// - Parameters:
    ///   - grain: How much the grit thins into speckle, 0...1. Does not break the base. Default 0.28.
    ///   - edgeRoughness: Raggedness of the grit edge, 0...1. Default 0.75.
    ///   - widthVariation: Along-stroke width wander, 0...1. Default 0.18.
    ///   - opacityVariation: How much later grit passes fade, 0...1. Default 0.35.
    ///   - passes: Grit layers on top of the base, 1...3. Default 2.
    ///   - baseOpacity: Opacity of the greasy base, 0.2...1. Default 0.8.
    ///   - baseSoftness: Width of the soft halo, 0...1. Default 0.5.
    ///   - grit: Flake density, 0...1. Default 0.92.
    ///   - flakeSize: Flake size relative to the preset, 0.35...3. Default 1.45.
    ///   - seed: Stable grain seed. The same seed and path repeat the same texture.
    public static func crayon(
        grain: Float = 0.28,
        edgeRoughness: Float = 0.75,
        widthVariation: Float = 0.18,
        opacityVariation: Float = 0.35,
        passes: Int = 2,
        baseOpacity: Float = 0.8,
        baseSoftness: Float = 0.5,
        grit: Float = 0.92,
        flakeSize: Float = 1.45,
        seed: UInt64 = 1
    ) -> BrushProfile {
        BrushProfile(
            crayon: CrayonStyle(
                grain: grain,
                edgeRoughness: edgeRoughness,
                widthVariation: widthVariation,
                opacityVariation: opacityVariation,
                passes: passes,
                baseOpacity: baseOpacity,
                baseSoftness: baseSoftness,
                grit: grit,
                flakeSize: flakeSize,
                seed: seed
            )
        )
    }

    /// Watercolor wash along the outline. Several translucent passes and a broken darker rim.
    ///
    /// `watercolor()` with the defaults equals `.watercolor`. `variation` feeds
    /// `ThicknessProfile.variable` and an `OpacityProfile.noise` curve. `seed`
    /// repeats the wash. `WatercolorStyle.defaultSeed` (`1`) yields to `Options.seed`.
    ///
    /// The outline is the wash. `.fillStyle(.watercolor)` uses this style for a
    /// clipped interior when the brush carries one, and `WatercolorStyle()` when
    /// it does not. Hachure and the other sketch fills are unchanged.
    ///
    /// - Parameters:
    ///   - pigment: Wash strength, 0...1. Default 0.72.
    ///   - wetness: How far passes drift, 0...1. Default 0.6.
    ///   - edgeDarkening: Rim versus centre, 0...1. Default 0.75.
    ///   - layers: Body passes, 1...5. Default 3. Crossings stack.
    ///   - variation: Width, opacity, and grain, 0...1. Default 0.45.
    ///   - bleed: Uneven edge and backruns, 0...1. Default 0.5. Not a blur.
    ///   - seed: Stable wash seed. Default 1.
    public static func watercolor(
        pigment: Float = 0.72,
        wetness: Float = 0.6,
        edgeDarkening: Float = 0.75,
        layers: Int = 3,
        variation: Float = 0.45,
        bleed: Float = 0.5,
        seed: UInt64 = WatercolorStyle.defaultSeed
    ) -> BrushProfile {
        let style = WatercolorStyle(
            pigment: pigment,
            wetness: wetness,
            edgeDarkening: edgeDarkening,
            layers: layers,
            variation: variation,
            bleed: bleed,
            seed: seed
        )
        let wander = CGFloat(style.variation)
        let thickness: ThicknessProfile
        let opacity: OpacityProfile
        if wander > 0.001 {
            thickness = .variable(VariableStrokeWidth(
                variation: min(1, wander * 1.15),
                minimum: 0.4,
                maximum: 1.65,
                seed: seed,
                frequency: 1.5
            ))
            opacity = .noise(
                minimum: 0.42,
                maximum: 1,
                variation: min(1, wander * 1.25),
                seed: seed &+ 17,
                frequency: 1.5
            )
        } else {
            thickness = .uniform
            opacity = .uniform
        }
        return BrushProfile(
            tip: .circular,
            thicknessProfile: thickness,
            cap: .round,
            join: .round,
            opacityProfile: opacity,
            watercolor: style
        )
    }

    /// Watercolor preset. Same settings as `watercolor()` with default arguments.
    public static let watercolor = BrushProfile.watercolor(
        pigment: 0.72,
        wetness: 0.6,
        edgeDarkening: 0.75,
        layers: 3,
        variation: 0.45,
        bleed: 0.5,
        seed: WatercolorStyle.defaultSeed
    )
    
    /// Whether this profile requires custom stroke-to-fill conversion.
    /// Returns false for simple profiles that can use standard stroke rendering.
    public var requiresCustomRendering: Bool {
        if crayon != nil || watercolor != nil || opacityProfile.variesAlongStroke {
            return true
        }
        // Need custom rendering if:
        // 1. Brush tip is not circular and direction-sensitive
        // 2. Thickness profile changes width along an open stroke
        let hasNonCircularTip = tip.directionSensitive && tip.roundness < 0.99
        let hasVariableThickness = thicknessProfile.variesAlongStroke
        
        return hasNonCircularTip || hasVariableThickness
    }
    
    /// Returns a copy of this profile with uniform thickness.
    /// Used for closed paths where a taper, width stops, or a width wobble would seam at the join.
    /// The even width is `strokeWidth`.
    func withUniformThickness() -> BrushProfile {
        BrushProfile(
            tip: tip,
            thicknessProfile: .uniform,
            cap: cap,
            join: join,
            crayon: crayon,
            opacityProfile: opacityProfile,
            watercolor: watercolor
        )
    }
}

