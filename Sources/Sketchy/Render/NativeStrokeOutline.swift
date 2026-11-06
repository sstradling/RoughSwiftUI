//
//  NativeStrokeOutline.swift
//  Sketchy
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
/// `.miter`, `.round`, and `.bevel` come from CoreGraphics. `.curvedBevel`
/// is constructed, because CoreGraphics has no such join. Variable-width
/// effects (taper, calligraphic tips, width jitter) still go through
/// `StrokeToFillConverter`, which uses the same corner joins where the
/// tangent breaks. Use this helper for a uniform-width filled outline when
/// clipping, compositing, or masking.
public enum NativeStrokeOutline: Sendable {
    /// Converts `path` into the filled outline of its native stroke.
    ///
    /// - Parameters:
    ///   - path: The centerline path to stroke.
    ///   - width: Stroke width in points. Values `<= 0` return an empty path.
    ///   - cap: Endpoint cap style.
    ///   - join: Corner join style.
    ///   - miterLimit: Maximum miter length divided by stroke width before
    ///     CoreGraphics falls back to a bevel join. Values below `1` are
    ///     clamped to `1`.
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

        if join.requiresCustomOutline {
            let profile = BrushProfile(
                tip: .circular,
                thicknessProfile: .uniform,
                cap: cap,
                join: join
            )
            return StrokeToFillConverter.convert(
                path: path,
                baseWidth: width,
                profile: profile,
                miterLimit: miterLimit
            )
        }

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
