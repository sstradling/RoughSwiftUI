//
//  Canvas.swift
//  RoughSwift
//
//  Created by khoa on 19/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//

import UIKit
import JavaScriptCore

public typealias JSONDictionary = [String: Any]
public typealias JSONArray = [JSONDictionary]

/// Main entry point for interacting with the underlying `rough.js` engine.
///
/// This type is annotated with `@MainActor` to ensure all JavaScriptCore work
/// happens on the main thread, which matches SwiftUI's rendering model.
@MainActor
public final class Engine {
    private let context: JSContext
    private let rough: JSValue

    public static let shared = Engine()

    public init() {
        guard let context = JSContext() else {
            fatalError("RoughSwiftUI.Engine failed to create JSContext")
        }
        self.context = context

        // Capture JavaScript exceptions emitted by rough.js
        context.exceptionHandler = { _, exception in
            if let message = exception?.toString() {
                print("RoughSwiftUI.Engine JavaScript exception: \(message)")
            }
        }

        let bundle = Bundle.module
        guard let path = bundle.url(forResource: "rough", withExtension: "js") else {
            fatalError("RoughSwiftUI.Engine could not locate rough.js in the module bundle")
        }

        do {
            let content = try String(contentsOf: path)
            context.evaluateScript(content)
        } catch {
            fatalError("RoughSwiftUI.Engine failed to load rough.js: \(error)")
        }

        guard let rough = context.objectForKeyedSubscript("rough") else {
            fatalError("RoughSwiftUI.Engine could not find `rough` global after evaluating rough.js")
        }

        self.rough = rough
    }

    /// Create a new `Generator` bound to a specific drawing surface size.
    public func generator(size: CGSize) -> Generator {
        let drawingSurface: JSONDictionary = [
            "width": size.width,
            "height": size.height
        ]

        guard let value = rough.invokeMethod("generator", withArguments: [drawingSurface]) else {
            fatalError("RoughSwiftUI.Engine failed to create rough.js generator")
        }

        return Generator(size: size, jsValue: value)
    }
}
