//
//  FillStyle.swift
//  RoughSwift
//
//  Created by khoa on 20/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//

import Foundation

public enum FillStyle: String {
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
}
