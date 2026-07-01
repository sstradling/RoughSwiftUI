//
//  NativeStrokeOutline.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 07/01/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  CoreGraphics-backed conversion from a stroked path into a filled outline.
//

import SwiftUI
import CoreGraphics

/// Builds native CoreGraphics stroked outlines from SwiftUI paths.
///
/// This helper is useful when a renderer needs a *filled* representation of a
/// uniform-width stroke while preserving CoreGraphics' exact cap/join geometry
/// (`round`, `bevel`, `miter`) and miter-limit behavior.
///
/// It intentionally does not handle variable-width effects (taper,
/// calligraphic brush tips, or width jitter). Those still require
/// `StrokeToFillConverter`. Use this helper for the uniform-width case where
/// native-quality joins matter but a filled outline is desired for clipping,
/// compositing, masking, or future segmentation work.
public enum NativeStrokeOutline {
    /// Converts `path` into the filled outline of its native stroke.
    ///
    /// - Parameters:
    ///   - path: The centerline path to stroke.
    ///   - width: Stroke width in points. Values `<= 0` return an empty path.
    ///   - cap: Endpoint cap style.
    ///   - join: Corner join style.
    ///   - miterLimit: Maximum miter length divided by stroke width before
    ///     CoreGraphics falls back to a bevel join. Values `<= 0` are clamped
    ///     to `1`.
    /// - Returns: A fillable `SwiftUI.Path` representing the native stroked
    ///   outline.
    public static func path(
        from path: SwiftUI.Path,
        width: CGFloat,
        cap: BrushCap,
        join: BrushJoin,
        miterLimit: CGFloat = 10
    ) -> SwiftUI.Path {
        guard width > 0 else { return SwiftUI.Path() }

        let stroked = path.cgPath.copy(
            strokingWithWidth: width,
            lineCap: cap.cgLineCap,
            lineJoin: join.cgLineJoin,
            miterLimit: max(1, miterLimit),
            transform: .identity
        )

        return SwiftUI.Path(stroked)
    }

    /// Convenience overload for engine operations.
    ///
    /// - Parameters:
    ///   - operations: Engine operations describing the centerline path.
    ///   - width: Stroke width in points.
    ///   - cap: Endpoint cap style.
    ///   - join: Corner join style.
    ///   - miterLimit: Miter limit used by CoreGraphics.
    /// - Returns: A fillable path representing the native stroked outline.
    public static func path(
        operations: [Operation],
        width: CGFloat,
        cap: BrushCap,
        join: BrushJoin,
        miterLimit: CGFloat = 10
    ) -> SwiftUI.Path {
        let operationSet = OperationSet(
            type: .path,
            operations: operations,
            path: nil,
            size: nil
        )
        let centerline = SwiftUI.Path.from(operationSet: operationSet)
        return path(
            from: centerline,
            width: width,
            cap: cap,
            join: join,
            miterLimit: miterLimit
        )
    }
}
