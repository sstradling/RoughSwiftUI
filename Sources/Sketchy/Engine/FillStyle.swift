//
//  FillStyle.swift
//  RoughSwift
//
//  Created by khoa on 20/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//
//  Modifications Copyright © 2025 Seth Stradling. All rights reserved.
//

import Foundation

public enum FillStyle: String, Equatable, Hashable, Sendable {
    case hachure
    case solid
    case zigzag
    case crossHatch = "cross-hatch"
    case dots
    case sunBurst = "sunburst"
    case starBurst = "starburst"
    case dashed
    case zigzagLine = "zigzag-line"
    /// A single continuous zig-zag scribble that traverses from one edge of the shape to the opposite edge.
    /// This fill style is rendered natively in Swift rather than through rough.js.
    case scribble
    /// A translucent wash clipped to the shape, with a darker rim and a lighter centre.
    ///
    /// The generator builds the same region as a solid fill, including `fillPadding`
    /// and `fillOffset`. The renderer paints layered glazes, an uneven edge, and a
    /// few blooms from `WatercolorStyle()`. `Options.seed` replaces the default seed.
    case watercolor
}
