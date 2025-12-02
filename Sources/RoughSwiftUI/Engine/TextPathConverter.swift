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
        
        var currentPosition = CGPoint.zero
        
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
                
                // Transform: translate to the glyph position
                // CoreText gives positions relative to the line origin
                var transform = CGAffineTransform(translationX: currentPosition.x + position.x,
                                                   y: currentPosition.y + position.y)
                
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
    
    /// Get the bounding box of the text path.
    ///
    /// - Parameter attributedString: The attributed string to measure.
    /// - Returns: The bounding rectangle of the text.
    public static func boundingBox(for attributedString: NSAttributedString) -> CGRect {
        let path = self.path(from: attributedString)
        return path.boundingBox
    }
    
    /// Get the bounding box of a plain string with a font.
    ///
    /// - Parameters:
    ///   - string: The text string to measure.
    ///   - font: The font to use.
    /// - Returns: The bounding rectangle of the text.
    public static func boundingBox(for string: String, font: UIFont) -> CGRect {
        let path = self.path(from: string, font: font)
        return path.boundingBox
    }
}

