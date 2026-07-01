//
//  StrokeContinuity.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Selects between the original sampled-point stroke generation and the
//  continuous-Bezier replacement.
//

import Foundation

/// Controls how stroke borders are constructed for native shapes (circle,
/// ellipse, arc, egg, rounded-rectangle corners, polygons, lines).
///
/// ## Background
///
/// The original `RoughMath` algorithms (ported from rough.js) sample the
/// outline at `Options.curveStepCount` points around the perimeter and then
/// stitch those samples together with Catmull-Rom→Bezier conversion. Each
/// step becomes its own short cubic, so a circle at default settings is ~9
/// independent short cubics per pass. Increasing `curveStepCount` for
/// smoothness produces *more* visible polygon facets, not fewer, because
/// each tiny segment can wobble independently of its neighbors.
///
/// `.continuous` replaces these with a small fixed number of Bezier
/// curves that match the *actual* parametric shape, with jitter applied to
/// shared endpoints and handles. A circle becomes 4 cubic Beziers per pass
/// (the standard `c = 0.5522847498` construction); polygon edges share
/// endpoints with their neighbors so a closed shape is one continuous
/// subpath instead of N independent passes.
///
/// ## Defaults and migration
///
/// Default is `.continuous`, because RoughSwiftUI is expected to favor
/// continuous hand-drawn borders over sampled-point curve approximations.
/// Use `.legacy` only when you specifically need the original rough.js-style
/// sampled outlines.
public enum StrokeContinuity: Equatable, Hashable, Sendable {
    /// Original behavior: sample `curveStepCount` points around curved
    /// outlines and Catmull-Rom-stitch them with per-sample jitter.
    case legacy

    /// Emit a small fixed number of true cubic Beziers per shape with
    /// shared, jittered endpoints between neighbors. Matches the underlying
    /// parametric geometry instead of approximating it with sampled points.
    case continuous
}
