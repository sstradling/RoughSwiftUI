//
//  RoughText.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
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
/// The view automatically sizes itself to match the dimensions of equivalent
/// SwiftUI `Text` with the same font, ensuring proper layout integration.
///
/// ## Basic Usage
///
/// ```swift
/// RoughText("Hello", font: .systemFont(ofSize: 48, weight: .bold))
///     .fill(.red)
///     .fillStyle(.hachure)
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
    
    /// The typographic size of the text (matching SwiftUI.Text dimensions).
    private let textSize: CGSize
    
    /// Create a rough text view from a plain string and font.
    ///
    /// - Parameters:
    ///   - string: The text to render.
    ///   - font: The font to use for rendering.
    public init(_ string: String, font: UIFont) {
        // Calculate typographic size that matches SwiftUI.Text
        let size = TextPathConverter.typographicSize(for: string, font: font)
        self.textSize = size
        
        // Use FullText for proper positioning within the calculated bounds
        var view = RoughView()
        view.drawables.append(FullText(string, font: font))
        self.roughView = view
    }
    
    /// Create a rough text view from an `NSAttributedString`.
    ///
    /// The attributed string can contain multiple fonts, sizes, and other text attributes.
    ///
    /// - Parameter attributedString: The attributed string to render.
    public init(attributedString: NSAttributedString) {
        // Calculate typographic size that matches SwiftUI.Text
        let size = TextPathConverter.typographicSize(for: attributedString)
        self.textSize = size
        
        // Use FullText for proper positioning within the calculated bounds
        var view = RoughView()
        view.drawables.append(FullText(attributedString: attributedString))
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
    
    /// Internal initializer for modifier chaining.
    private init(roughView: RoughView, textSize: CGSize) {
        self.roughView = roughView
        self.textSize = textSize
    }
    
    public var body: some View {
        roughView
            .frame(width: textSize.width, height: textSize.height)
    }
}

// MARK: - Style Modifiers

public extension RoughText {
    
    /// Set the maximum randomness offset for the hand-drawn effect.
    func maxRandomnessOffset(_ value: Float) -> Self {
        RoughText(roughView: roughView.maxRandomnessOffset(value), textSize: textSize)
    }
    
    /// Set the roughness level of the hand-drawn strokes.
    func roughness(_ value: Float) -> Self {
        RoughText(roughView: roughView.roughness(value), textSize: textSize)
    }
    
    /// Set the bowing factor for curved strokes.
    func bowing(_ value: Float) -> Self {
        RoughText(roughView: roughView.bowing(value), textSize: textSize)
    }
    
    /// Set the stroke width.
    func strokeWidth(_ value: Float) -> Self {
        RoughText(roughView: roughView.strokeWidth(value), textSize: textSize)
    }
    
    /// Set the fill pattern line weight.
    func fillWeight(_ value: Float) -> Self {
        RoughText(roughView: roughView.fillWeight(value), textSize: textSize)
    }
    
    /// Set the dash offset for dashed fill styles.
    func dashOffset(_ value: Float) -> Self {
        RoughText(roughView: roughView.dashOffset(value), textSize: textSize)
    }
    
    /// Set the zigzag offset for zigzag fill styles.
    func zigzagOffset(_ value: Float) -> Self {
        RoughText(roughView: roughView.zigzagOffset(value), textSize: textSize)
    }
    
    /// Set the dash gap for dashed fill styles.
    func dashGap(_ value: Float) -> Self {
        RoughText(roughView: roughView.dashGap(value), textSize: textSize)
    }
    
    /// Set the spacing between fill lines.
    func fillSpacing(_ value: Float) -> Self {
        RoughText(roughView: roughView.fillSpacing(value), textSize: textSize)
    }
    
    /// Set a pattern of spacing factors for gradient effects.
    func fillSpacingPattern(_ pattern: [Float]) -> Self {
        RoughText(roughView: roughView.fillSpacingPattern(pattern), textSize: textSize)
    }
    
    /// Set the angle of fill lines in degrees.
    func fillAngle(_ value: Float) -> Self {
        RoughText(roughView: roughView.fillAngle(value), textSize: textSize)
    }
    
    /// Set the curve tightness.
    func curveTightness(_ value: Float) -> Self {
        RoughText(roughView: roughView.curveTightness(value), textSize: textSize)
    }
    
    /// Set the curve step count.
    func curveStepCount(_ value: Float) -> Self {
        RoughText(roughView: roughView.curveStepCount(value), textSize: textSize)
    }
    
    /// Set the stroke color using `UIColor`.
    func stroke(_ value: UIColor) -> Self {
        RoughText(roughView: roughView.stroke(value), textSize: textSize)
    }
    
    /// Set the stroke color using SwiftUI `Color`.
    func stroke(_ value: Color) -> Self {
        RoughText(roughView: roughView.stroke(value), textSize: textSize)
    }
    
    /// Set the fill color using `UIColor`.
    func fill(_ value: UIColor) -> Self {
        RoughText(roughView: roughView.fill(value), textSize: textSize)
    }
    
    /// Set the fill color using SwiftUI `Color`.
    func fill(_ value: Color) -> Self {
        RoughText(roughView: roughView.fill(value), textSize: textSize)
    }
    
    /// Set the fill style (hachure, crossHatch, dots, etc.).
    func fillStyle(_ value: FillStyle) -> Self {
        RoughText(roughView: roughView.fillStyle(value), textSize: textSize)
    }
    
    // MARK: - Brush Tip Modifiers
    
    /// Set custom brush tip parameters for stroke rendering.
    ///
    /// - Parameters:
    ///   - roundness: How round the brush tip is (0 = flat, 1 = round). Default is `1.0`.
    ///   - angle: The angle of the brush tip in radians. Default is `0`.
    ///   - directionSensitive: Whether the brush tip rotates with stroke direction. Default is `true`.
    /// - Returns: A view with the custom brush tip applied.
    func brushTip(
        roundness: CGFloat = 1.0,
        angle: CGFloat = 0,
        directionSensitive: Bool = true
    ) -> Self {
        RoughText(
            roughView: roughView.brushTip(
                roundness: roundness,
                angle: angle,
                directionSensitive: directionSensitive
            ),
            textSize: textSize
        )
    }
    
    /// Set the brush tip using a preset.
    ///
    /// Available presets:
    /// - `.circular`: Circular brush tip (default, uniform stroke width)
    /// - `.flat`: Flat horizontal brush tip for ribbon-like strokes
    /// - `.calligraphic`: Angled calligraphic brush tip (45 degrees)
    ///
    /// - Parameter tip: The brush tip preset to use.
    /// - Returns: A view with the brush tip applied.
    func brushTip(_ tip: BrushTip) -> Self {
        RoughText(roughView: roughView.brushTip(tip), textSize: textSize)
    }
    
    // MARK: - SVG-specific modifiers
    
    /// Set the stroke width specifically for SVG path rendering.
    func svgStrokeWidth(_ value: Float) -> Self {
        RoughText(roughView: roughView.svgStrokeWidth(value), textSize: textSize)
    }
    
    /// Set the fill weight specifically for SVG path rendering.
    func svgFillWeight(_ value: Float) -> Self {
        RoughText(roughView: roughView.svgFillWeight(value), textSize: textSize)
    }
    
    /// Set the alignment of the fill stroke relative to the text path.
    func svgFillStrokeAlignment(_ value: SVGFillStrokeAlignment) -> Self {
        RoughText(roughView: roughView.svgFillStrokeAlignment(value), textSize: textSize)
    }
    
    // MARK: - Animation
    
    /// Add animation to the rough text with the given configuration.
    ///
    /// - Returns: An animated view with the text size preserved.
    func animated(config: AnimationConfig = .default) -> some View {
        roughView.animated(config: config)
            .frame(width: textSize.width, height: textSize.height)
    }
    
    /// Add animation to the rough text with custom parameters.
    ///
    /// - Returns: An animated view with the text size preserved.
    func animated(
        steps: Int = 4,
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium
    ) -> some View {
        roughView.animated(steps: steps, speed: speed, variance: variance)
            .frame(width: textSize.width, height: textSize.height)
    }
}

