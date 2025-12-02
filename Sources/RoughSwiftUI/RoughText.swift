//
//  RoughText.swift
//  RoughSwiftUI
//
//  Created by Cursor on 02/12/2025.
//
//  A SwiftUI view for rendering text with hand-drawn rough.js styling.
//

import SwiftUI
import UIKit

/// A SwiftUI view that renders text with hand-drawn, sketchy styling.
///
/// `RoughText` converts text into vector paths and renders them using the rough.js
/// engine, creating a hand-drawn appearance. The text can be styled with various
/// fill patterns like hachure, crosshatch, dots, and more.
///
/// ## Basic Usage
///
/// ```swift
/// RoughText("Hello", font: .systemFont(ofSize: 48, weight: .bold))
///     .fill(.red)
///     .fillStyle(.hachure)
///     .frame(width: 200, height: 80)
/// ```
///
/// ## With Attributed String
///
/// ```swift
/// let attributed = NSAttributedString(
///     string: "Styled",
///     attributes: [.font: UIFont.boldSystemFont(ofSize: 36)]
/// )
/// RoughText(attributedString: attributed)
///     .fill(.blue)
///     .stroke(.black)
/// ```
public struct RoughText: View {
    
    /// The underlying RoughView used for rendering.
    private var roughView: RoughView
    
    /// Create a rough text view from a plain string and font.
    ///
    /// - Parameters:
    ///   - string: The text to render.
    ///   - font: The font to use for rendering.
    public init(_ string: String, font: UIFont) {
        var view = RoughView()
        view.drawables.append(Text(string, font: font))
        self.roughView = view
    }
    
    /// Create a rough text view from an `NSAttributedString`.
    ///
    /// The attributed string can contain multiple fonts, sizes, and other text attributes.
    ///
    /// - Parameter attributedString: The attributed string to render.
    public init(attributedString: NSAttributedString) {
        var view = RoughView()
        view.drawables.append(Text(attributedString: attributedString))
        self.roughView = view
    }
    
    /// Create a rough text view from a string with font name and size.
    ///
    /// - Parameters:
    ///   - string: The text to render.
    ///   - fontName: The PostScript name of the font (e.g., "Helvetica-Bold").
    ///   - fontSize: The font size in points.
    public init(_ string: String, fontName: String, fontSize: CGFloat) {
        let font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        self.init(string, font: font)
    }
    
    public var body: some View {
        roughView
    }
}

// MARK: - Style Modifiers

public extension RoughText {
    
    /// Set the maximum randomness offset for the hand-drawn effect.
    func maxRandomnessOffset(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.maxRandomnessOffset(value)
        return copy
    }
    
    /// Set the roughness level of the hand-drawn strokes.
    func roughness(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.roughness(value)
        return copy
    }
    
    /// Set the bowing factor for curved strokes.
    func bowing(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.bowing(value)
        return copy
    }
    
    /// Set the stroke width.
    func strokeWidth(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.strokeWidth(value)
        return copy
    }
    
    /// Set the fill pattern line weight.
    func fillWeight(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.fillWeight(value)
        return copy
    }
    
    /// Set the dash offset for dashed fill styles.
    func dashOffset(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.dashOffset(value)
        return copy
    }
    
    /// Set the zigzag offset for zigzag fill styles.
    func zigzagOffset(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.zigzagOffset(value)
        return copy
    }
    
    /// Set the dash gap for dashed fill styles.
    func dashGap(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.dashGap(value)
        return copy
    }
    
    /// Set the spacing between fill lines.
    func fillSpacing(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.fillSpacing(value)
        return copy
    }
    
    /// Set a pattern of spacing factors for gradient effects.
    func fillSpacingPattern(_ pattern: [Float]) -> Self {
        var copy = self
        copy.roughView = copy.roughView.fillSpacingPattern(pattern)
        return copy
    }
    
    /// Set the angle of fill lines in degrees.
    func fillAngle(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.fillAngle(value)
        return copy
    }
    
    /// Set the curve tightness.
    func curveTightness(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.curveTightness(value)
        return copy
    }
    
    /// Set the curve step count.
    func curveStepCount(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.curveStepCount(value)
        return copy
    }
    
    /// Set the stroke color using `UIColor`.
    func stroke(_ value: UIColor) -> Self {
        var copy = self
        copy.roughView = copy.roughView.stroke(value)
        return copy
    }
    
    /// Set the stroke color using SwiftUI `Color`.
    func stroke(_ value: Color) -> Self {
        var copy = self
        copy.roughView = copy.roughView.stroke(value)
        return copy
    }
    
    /// Set the fill color using `UIColor`.
    func fill(_ value: UIColor) -> Self {
        var copy = self
        copy.roughView = copy.roughView.fill(value)
        return copy
    }
    
    /// Set the fill color using SwiftUI `Color`.
    func fill(_ value: Color) -> Self {
        var copy = self
        copy.roughView = copy.roughView.fill(value)
        return copy
    }
    
    /// Set the fill style (hachure, crossHatch, dots, etc.).
    func fillStyle(_ value: FillStyle) -> Self {
        var copy = self
        copy.roughView = copy.roughView.fillStyle(value)
        return copy
    }
    
    // MARK: - SVG-specific modifiers
    
    /// Set the stroke width specifically for SVG path rendering.
    func svgStrokeWidth(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.svgStrokeWidth(value)
        return copy
    }
    
    /// Set the fill weight specifically for SVG path rendering.
    func svgFillWeight(_ value: Float) -> Self {
        var copy = self
        copy.roughView = copy.roughView.svgFillWeight(value)
        return copy
    }
    
    /// Set the alignment of the fill stroke relative to the text path.
    func svgFillStrokeAlignment(_ value: SVGFillStrokeAlignment) -> Self {
        var copy = self
        copy.roughView = copy.roughView.svgFillStrokeAlignment(value)
        return copy
    }
    
    // MARK: - Animation
    
    /// Add animation to the rough text with the given configuration.
    func animated(config: AnimationConfig = .default) -> AnimatedRoughView {
        roughView.animated(config: config)
    }
    
    /// Add animation to the rough text with custom parameters.
    func animated(
        steps: Int = 4,
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium
    ) -> AnimatedRoughView {
        roughView.animated(steps: steps, speed: speed, variance: variance)
    }
}

