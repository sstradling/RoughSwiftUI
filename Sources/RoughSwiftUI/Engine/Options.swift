//
//  Option.swift
//  RoughSwift
//
//  Created by khoa on 19/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//

import UIKit

/// Controls how the SVG fill stroke is aligned relative to the path.
public enum SVGFillStrokeAlignment {
    /// Stroke is centered on the path (default behavior).
    case center
    /// Stroke is applied to the inside/inner edge of the path.
    case inside
    /// Stroke is applied to the outside/outer edge of the path.
    case outside
}

public struct Options {
    public var maxRandomnessOffset: Float = 2
    public var roughness: Float = 1
    public var bowing: Float = 1

    // Internal color storage goes through `RoughColor` so we can
    // easily bridge to hex / SwiftUI while keeping the public API
    // in terms of `UIColor` for now.
    private var strokeColor: RoughColor = RoughColor(uiColor: .black)
    private var fillColor: RoughColor = RoughColor(uiColor: .clear)

    public var strokeWidth: Float = 1
    public var curveTightness: Float = 0
    public var curveStepCount: Float = 9
    public var fillStyle: FillStyle = .hachure
    public var fillWeight: Float = -1
    public var hachureAngle: Float = -41
    public var hachureGap: Float = -1
    public var dashOffset: Float = -1
    public var dashGap: Float = -1
    public var zigzagOffset: Float = -1
    
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
            "hachureAngle": hachureAngle,
            "hachureGap": hachureGap,
            "dashOffset": dashOffset,
            "dashGap": dashGap,
            "zigzagOffset": zigzagOffset
        ]
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
        hachureAngle <-? (dictionary["hachureAngle"] as? NSNumber)?.floatValue
        hachureGap <-? (dictionary["hachureGap"] as? NSNumber)?.floatValue
        dashOffset <-? (dictionary["dashOffset"] as? NSNumber)?.floatValue
        dashGap <-? (dictionary["dashGap"] as? NSNumber)?.floatValue
        zigzagOffset <-? (dictionary["zigzagOffset"] as? NSNumber)?.floatValue

        if let fillStyleRawValue = dictionary["fillStyle"] as? String,
           let fillStyle = FillStyle(rawValue: fillStyleRawValue) {
            self.fillStyle = fillStyle
        }

        stroke <-? (dictionary["stroke"] as? String).map(UIColor.init(hex:))
        fill <-? (dictionary["fill"] as? String).map(UIColor.init(hex:))
    }
}
