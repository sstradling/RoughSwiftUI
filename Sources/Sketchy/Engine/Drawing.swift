//
//  Drawing.swift
//  RoughSwift
//
//  Created by khoa on 19/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//

import CoreGraphics
import Foundation

/// Information from Generator about the drawable to render
public struct Drawing {
    public let shape: String
    public let sets: [OperationSet]
    public let options: Options

    /// Input silhouette in outline coordinates, before roughness.
    ///
    /// Sticker backing blends toward these rings as `smoothness` rises.
    /// `nil` when the shape has no separate silhouette. Sketch strokes do
    /// not read this.
    let stickerGuide: [StickerGuideRing]?

    public init(shape: String, sets: [OperationSet], options: Options) {
        self.init(shape: shape, sets: sets, options: options, stickerGuide: nil)
    }

    init(
        shape: String,
        sets: [OperationSet],
        options: Options,
        stickerGuide: [StickerGuideRing]?
    ) {
        self.shape = shape
        self.sets = sets
        self.options = options
        self.stickerGuide = stickerGuide
    }
}

/// One input contour a sticker can follow. Internal to the engine.
struct StickerGuideRing {
    var points: [CGPoint]
    var closed: Bool
}

public extension Drawing {
    init?(dictionary: JSONDictionary) {
        guard
            let shape = dictionary["shape"] as? String,
            let sets = dictionary["sets"] as? JSONArray,
            let options = dictionary["options"] as? JSONDictionary
        else {
            return nil
        }

        self.init(
            shape: shape,
            sets: sets.compactMap({ OperationSet.from(dictionary: $0) }),
            options: Options(dictionary: options)
        )
    }
}
