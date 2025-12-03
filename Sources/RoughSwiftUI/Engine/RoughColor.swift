//
//  RoughColor.swift
//  RoughSwiftUI
//
//  Internal color abstraction used by RoughSwiftUI.
//
//  Copyright © 2025 Seth Stradling. All rights reserved.
//

import UIKit
import SwiftUI

/// Internal representation of a color used by the RoughSwiftUI engine.
///
/// This type centralizes conversions between `UIColor`, `SwiftUI.Color`,
/// and the hex strings expected by `rough.js`.
struct RoughColor: Equatable, Hashable {
    /// Backing UIKit color. UIKit is the canonical representation since the
    /// JavaScript bridge already works in terms of `UIColor` + hex.
    private let uiColor: UIColor

    /// Initialize from a UIKit color.
    init(uiColor: UIColor) {
        self.uiColor = uiColor
    }

    /// Initialize from a SwiftUI color.
    /// On iOS 17 / SwiftUI this bridges through `UIColor`.
    init(_ color: Color) {
        self.uiColor = UIColor(color)
    }

    /// Access the color as UIKit.
    var asUIColor: UIColor {
        uiColor
    }

    /// Access the color as SwiftUI `Color`.
    var asSwiftUIColor: Color {
        Color(uiColor)
    }

    /// Hex string representation understood by `rough.js`.
    func toHex() -> String {
        uiColor.toHex()
    }
}


