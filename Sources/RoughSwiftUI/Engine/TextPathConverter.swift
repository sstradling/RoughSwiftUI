//
//  TextPathConverter.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
// 
//  Converts text (String or NSAttributedString) to CGPath using CoreText.
//

import UIKit
import CoreText

/// Utility for converting text strings into `CGPath` glyph outlines.
///
/// This uses CoreText to extract the vector paths of each glyph in the text,
/// which can then be converted to SVG and rendered with rough.js styling.
public struct TextPathConverter {
    
    /// Convert an `NSAttributedString` to a `CGPath` containing all glyph outlines.
    ///
    /// The resulting path is positioned with the text baseline at y=0, with glyphs
    /// extending upward (negative y values for ascenders). The path uses standard
    /// CoreGraphics coordinates (y increases upward).
    ///
    /// - Parameter attributedString: The attributed string to convert.
    /// - Returns: A `CGPath` containing the outlines of all glyphs, or an empty path if conversion fails.
    public static func path(from attributedString: NSAttributedString) -> CGPath {
        let mutablePath = CGMutablePath()
        
        // Create a CTLine from the attributed string
        let line = CTLineCreateWithAttributedString(attributedString)
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        
        // Start at origin (baseline at y=0)
        let baselineOrigin = CGPoint.zero
        
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            guard glyphCount > 0 else { continue }
            
            // Get the font for this run
            let attributesRef = CTRunGetAttributes(run)
            guard let fontRef = CFDictionaryGetValue(attributesRef, Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()) else { continue }
            let runFont = unsafeBitCast(fontRef, to: CTFont.self)
            
            // Get glyphs and positions
            var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
            var positions = [CGPoint](repeating: .zero, count: glyphCount)
            
            CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
            
            // Convert each glyph to a path
            for i in 0..<glyphCount {
                let glyph = glyphs[i]
                let position = positions[i]
                
                // Get the path for this glyph
                guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyph, nil) else { continue }
                
                // Transform: translate to the glyph position relative to baseline origin
                // CoreText gives positions relative to the line origin (baseline)
                var transform = CGAffineTransform(translationX: baselineOrigin.x + position.x,
                                                   y: baselineOrigin.y + position.y)
                
                mutablePath.addPath(glyphPath, transform: transform)
            }
        }
        
        return mutablePath
    }
    
    /// Convert a plain `String` with a `UIFont` to a `CGPath` containing all glyph outlines.
    ///
    /// This is a convenience method that creates an attributed string internally.
    ///
    /// - Parameters:
    ///   - string: The text string to convert.
    ///   - font: The font to use for rendering.
    /// - Returns: A `CGPath` containing the outlines of all glyphs.
    public static func path(from string: String, font: UIFont) -> CGPath {
        let attributedString = NSAttributedString(
            string: string,
            attributes: [.font: font]
        )
        return path(from: attributedString)
    }
    
    /// Convert a plain `String` with font name and size to a `CGPath`.
    ///
    /// - Parameters:
    ///   - string: The text string to convert.
    ///   - fontName: The PostScript name of the font (e.g., "Helvetica-Bold").
    ///   - fontSize: The font size in points.
    /// - Returns: A `CGPath` containing the outlines of all glyphs.
    public static func path(from string: String, fontName: String, fontSize: CGFloat) -> CGPath {
        let font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        return path(from: string, font: font)
    }
    
    /// Get the bounding box of the text path (ink bounds, not typographic).
    ///
    /// - Parameter attributedString: The attributed string to measure.
    /// - Returns: The bounding rectangle of the text.
    public static func boundingBox(for attributedString: NSAttributedString) -> CGRect {
        let path = self.path(from: attributedString)
        return path.boundingBox
    }
    
    /// Get the bounding box of a plain string with a font (ink bounds, not typographic).
    ///
    /// - Parameters:
    ///   - string: The text string to measure.
    ///   - font: The font to use.
    /// - Returns: The bounding rectangle of the text.
    public static func boundingBox(for string: String, font: UIFont) -> CGRect {
        let path = self.path(from: string, font: font)
        return path.boundingBox
    }
    
    // MARK: - Typographic Size Calculation
    
    /// Calculate the typographic size of text, matching SwiftUI.Text dimensions.
    ///
    /// Uses path ink bounds for width and font metrics for height.
    ///
    /// - Parameter attributedString: The attributed string to measure.
    /// - Returns: The typographic size as CGSize.
    public static func typographicSize(for attributedString: NSAttributedString) -> CGSize {
        // Use the actual glyph ink bounds for width (tighter than advance width)
        let path = self.path(from: attributedString)
        let inkBounds = path.boundingBox
        
        // Use font metrics for height (matches SwiftUI.Text intrinsic height)
        let font = attributedString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            ?? UIFont.systemFont(ofSize: 12)
        let height = font.ascender + abs(font.descender)
        
        return CGSize(width: inkBounds.width, height: height)
    }
    
    /// Calculate the typographic size of a plain string with a font.
    ///
    /// Uses path ink bounds for width and font metrics for height.
    ///
    /// - Parameters:
    ///   - string: The text string to measure.
    ///   - font: The font to use.
    /// - Returns: The typographic size as CGSize.
    public static func typographicSize(for string: String, font: UIFont) -> CGSize {
        let attributedString = NSAttributedString(string: string, attributes: [.font: font])
        return typographicSize(for: attributedString)
    }
    
    /// Calculate the typographic size plus additional data needed for positioning.
    ///
    /// Returns the typographic size along with the ascent value, which is needed
    /// to properly position text after Y-axis flipping.
    ///
    /// - Parameter attributedString: The attributed string to measure.
    /// - Returns: A tuple with size and ascent.
    public static func typographicMetrics(for attributedString: NSAttributedString) -> (size: CGSize, ascent: CGFloat) {
        // Get ink bounds for width (tighter than advance width)
        let path = self.path(from: attributedString)
        let inkBounds = path.boundingBox
        
        // Get ascent from CTLine for positioning calculations
        let line = CTLineCreateWithAttributedString(attributedString)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        
        // Use font metrics for height (matches SwiftUI.Text intrinsic height)
        let font = attributedString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            ?? UIFont.systemFont(ofSize: 12)
        let height = font.ascender + abs(font.descender)
        
        return (CGSize(width: inkBounds.width, height: height), ascent)
    }
    
    /// Calculate the typographic metrics for a plain string with a font.
    ///
    /// Uses ink bounds for width and font metrics for height.
    ///
    /// - Parameters:
    ///   - string: The text string to measure.
    ///   - font: The font to use.
    /// - Returns: A tuple with size and ascent.
    public static func typographicMetrics(for string: String, font: UIFont) -> (size: CGSize, ascent: CGFloat) {
        let attributedString = NSAttributedString(string: string, attributes: [.font: font])
        return typographicMetrics(for: attributedString)
    }
    
    /// Get both the CGPath and typographic size for text.
    ///
    /// This is an efficient method that computes both in a single pass.
    ///
    /// - Parameter attributedString: The attributed string to process.
    /// - Returns: A tuple containing the CGPath and typographic size.
    public static func pathAndSize(for attributedString: NSAttributedString) -> (path: CGPath, size: CGSize) {
        let path = self.path(from: attributedString)
        let size = typographicSize(for: attributedString)
        return (path, size)
    }
    
    /// Get both the CGPath and typographic size for a plain string.
    ///
    /// - Parameters:
    ///   - string: The text string to process.
    ///   - font: The font to use.
    /// - Returns: A tuple containing the CGPath and typographic size.
    public static func pathAndSize(for string: String, font: UIFont) -> (path: CGPath, size: CGSize) {
        let attributedString = NSAttributedString(
            string: string,
            attributes: [.font: font]
        )
        return pathAndSize(for: attributedString)
    }
    
    /// Get the CGPath, typographic size, ascent, and ink bounds origin for text.
    ///
    /// This method computes the path and all metrics needed for proper positioning.
    /// The ascent is needed for Y-axis positioning, and the ink origin is needed
    /// to normalize the path to start at (0, baseline).
    ///
    /// - Parameter attributedString: The attributed string to process.
    /// - Returns: A tuple containing the CGPath, typographic size, ascent, and ink origin.
    public static func pathSizeAndAscent(for attributedString: NSAttributedString) -> (path: CGPath, size: CGSize, ascent: CGFloat, inkOrigin: CGPoint) {
        let path = self.path(from: attributedString)
        let inkBounds = path.boundingBox
        
        // Get ascent from CTLine for positioning calculations
        let line = CTLineCreateWithAttributedString(attributedString)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        
        // Use font metrics for height (matches SwiftUI.Text intrinsic height)
        let font = attributedString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            ?? UIFont.systemFont(ofSize: 12)
        let height = font.ascender + abs(font.descender)
        
        let size = CGSize(width: inkBounds.width, height: height)
        let inkOrigin = CGPoint(x: inkBounds.minX, y: inkBounds.minY)
        
        return (path, size, ascent, inkOrigin)
    }
    
    /// Get the CGPath, typographic size, ascent, and ink origin for a plain string.
    ///
    /// - Parameters:
    ///   - string: The text string to process.
    ///   - font: The font to use.
    /// - Returns: A tuple containing the CGPath, typographic size, ascent, and ink origin.
    public static func pathSizeAndAscent(for string: String, font: UIFont) -> (path: CGPath, size: CGSize, ascent: CGFloat, inkOrigin: CGPoint) {
        let attributedString = NSAttributedString(
            string: string,
            attributes: [.font: font]
        )
        return pathSizeAndAscent(for: attributedString)
    }
}

