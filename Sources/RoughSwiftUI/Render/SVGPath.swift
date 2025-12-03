//
//  SVGPath.swift
//  SVGPath
//
//  Created by Tim Wood on 1/21/15.
//  Copyright (c) 2015 Tim Wood. All rights reserved.
//
//  Modifications Copyright © 2025 Seth Stradling. All rights reserved.
//

import UIKit
import CoreGraphics
import os.signpost

// MARK: UIBezierPath

public extension UIBezierPath {
    convenience init (svgPath: String) {
        self.init()
        measurePerformance(ParsingSignpost.svgParse, log: RoughPerformanceLog.parsing, metadata: "len=\(svgPath.count)") {
            applyCommands(from: SVGPath(svgPath))
        }
    }
}

private extension UIBezierPath {
    func applyCommands(from svgPath: SVGPath) {
        for command in svgPath.commands {
            switch command.type {
            case .move: move(to: command.point)
            case .line: addLine(to: command.point)
            case .quadCurve: addQuadCurve(to: command.point, controlPoint: command.control1)
            case .cubeCurve: addCurve(to: command.point, controlPoint1: command.control1, controlPoint2: command.control2)
            case .close: close()
            }
        }
    }
}

// MARK: Enums

fileprivate enum Coordinates {
    case absolute
    case relative
}

// MARK: Class

public class SVGPath {
    public var commands: [SVGCommand] = []
    private var builder: SVGCommandBuilder = move
    private var coords: Coordinates = .absolute
    private var increment: Int = 2
    private var numbers = ""
    
    public init (_ string: String) {
        for char in string {
            switch char {
            case "M": use(.absolute, 2, move)
            case "m": use(.relative, 2, move)
            case "L": use(.absolute, 2, line)
            case "l": use(.relative, 2, line)
            case "V": use(.absolute, 1, lineVertical)
            case "v": use(.relative, 1, lineVertical)
            case "H": use(.absolute, 1, lineHorizontal)
            case "h": use(.relative, 1, lineHorizontal)
            case "Q": use(.absolute, 4, quadBroken)
            case "q": use(.relative, 4, quadBroken)
            case "T": use(.absolute, 2, quadSmooth)
            case "t": use(.relative, 2, quadSmooth)
            case "C": use(.absolute, 6, cubeBroken)
            case "c": use(.relative, 6, cubeBroken)
            case "S": use(.absolute, 4, cubeSmooth)
            case "s": use(.relative, 4, cubeSmooth)
            case "Z": use(.absolute, 0, close)
            case "z": use(.absolute, 0, close)
            default: numbers.append(char)
            }
        }
        finishLastCommand()
    }
    
    private func use (_ coords: Coordinates, _ increment: Int, _ builder: @escaping SVGCommandBuilder) {
        finishLastCommand()
        self.builder = builder
        self.coords = coords
        self.increment = increment
    }
    
    private func finishLastCommand () {
        for command in take(SVGPath.parseNumbers(numbers), increment: increment, coords: coords, last: commands.last, callback: builder) {
            commands.append(coords == .relative ? command.relative(to: commands.last) : command)
        }
        numbers = ""
    }
}

// MARK: Numbers - Fast Native Parsing

public extension SVGPath {
    /// Parses SVG path number sequences into CGFloat values.
    ///
    /// This implementation uses native Swift `Double` parsing instead of
    /// `NSDecimalNumber` for significantly better performance (~10x faster).
    /// Handles SVG number format including:
    /// - Negative numbers (e.g., "-5.2")
    /// - Scientific notation (e.g., "1e-5", "2.5E+3")
    /// - Implicit separators (e.g., "1-2" parses as [1, -2])
    /// - Decimal points without leading zero (e.g., ".5")
    class func parseNumbers(_ numbers: String) -> [CGFloat] {
        guard !numbers.isEmpty else { return [] }
        
        // Pre-allocate with estimated capacity (avg 6 chars per number)
        var result: [CGFloat] = []
        result.reserveCapacity(max(1, numbers.count / 6))
        
        // Track current number being built
        var startIndex: String.Index? = nil
        var lastChar: Character = " "
        var hasDecimal = false
        var inExponent = false
        
        let chars = numbers
        var index = chars.startIndex
        
        @inline(__always)
        func flushNumber(endIndex: String.Index) {
            guard let start = startIndex else { return }
            let substring = chars[start..<endIndex]
            if !substring.isEmpty, let value = Double(substring) {
                result.append(CGFloat(value))
            }
            startIndex = nil
            hasDecimal = false
            inExponent = false
        }
        
        while index < chars.endIndex {
            let char = chars[index]
            
            switch char {
            case "0"..."9":
                if startIndex == nil {
                    startIndex = index
                }
                
            case ".":
                if startIndex == nil {
                    // Decimal without leading digit (e.g., ".5")
                    startIndex = index
                    hasDecimal = true
                } else if hasDecimal && !inExponent {
                    // Second decimal point starts a new number (e.g., "1.2.3" -> [1.2, 0.3])
                    flushNumber(endIndex: index)
                    startIndex = index
                    hasDecimal = true
                } else {
                    hasDecimal = true
                }
                
            case "-", "+":
                if startIndex != nil {
                    // Check if this is part of exponent (e.g., "1e-5")
                    if inExponent && (lastChar == "e" || lastChar == "E") {
                        // This sign is part of the exponent, continue
                    } else {
                        // This starts a new number
                        flushNumber(endIndex: index)
                        if char == "-" {
                            startIndex = index
                        }
                    }
                } else if char == "-" {
                    startIndex = index
                }
                
            case "e", "E":
                if startIndex != nil {
                    inExponent = true
                }
                
            default:
                // Separator character (space, comma, etc.)
                if startIndex != nil {
                    flushNumber(endIndex: index)
                }
            }
            
            lastChar = char
            index = chars.index(after: index)
        }
        
        // Flush any remaining number
        if startIndex != nil {
            flushNumber(endIndex: chars.endIndex)
        }
        
        return result
    }
}

// MARK: Commands

public struct SVGCommand {
    public var point:CGPoint
    public var control1:CGPoint
    public var control2:CGPoint
    public var type:Kind
    
    public enum Kind {
        case move
        case line
        case cubeCurve
        case quadCurve
        case close
    }
    
    public init () {
        let point = CGPoint()
        self.init(point, point, point, type: .close)
    }
    
    public init (_ x: CGFloat, _ y: CGFloat, type: Kind) {
        let point = CGPoint(x: x, y: y)
        self.init(point, point, point, type: type)
    }
    
    public init (_ cx: CGFloat, _ cy: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        let control = CGPoint(x: cx, y: cy)
        self.init(control, control, CGPoint(x: x, y: y), type: .quadCurve)
    }
    
    public init (_ cx1: CGFloat, _ cy1: CGFloat, _ cx2: CGFloat, _ cy2: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        self.init(CGPoint(x: cx1, y: cy1), CGPoint(x: cx2, y: cy2), CGPoint(x: x, y: y), type: .cubeCurve)
    }
    
    public init (_ control1: CGPoint, _ control2: CGPoint, _ point: CGPoint, type: Kind) {
        self.point = point
        self.control1 = control1
        self.control2 = control2
        self.type = type
    }
    
    fileprivate func relative (to other:SVGCommand?) -> SVGCommand {
        if let otherPoint = other?.point {
            return SVGCommand(control1 + otherPoint, control2 + otherPoint, point + otherPoint, type: type)
        }
        return self
    }
}

// MARK: CGPoint helpers

private func +(a:CGPoint, b:CGPoint) -> CGPoint {
    return CGPoint(x: a.x + b.x, y: a.y + b.y)
}

private func -(a:CGPoint, b:CGPoint) -> CGPoint {
    return CGPoint(x: a.x - b.x, y: a.y - b.y)
}

// MARK: Command Builders

private typealias SVGCommandBuilder = ([CGFloat], SVGCommand?, Coordinates) -> SVGCommand

private func take (_ numbers: [CGFloat], increment: Int, coords: Coordinates, last: SVGCommand?, callback: SVGCommandBuilder) -> [SVGCommand] {
    var out: [SVGCommand] = []
    var lastCommand:SVGCommand? = last
    
    // Handle commands that don't need numbers (like close)
    if increment == 0 {
        lastCommand = callback([], lastCommand, coords)
        out.append(lastCommand!)
        return out
    }
    
    let count = (numbers.count / increment) * increment
    var nums:[CGFloat] = [0, 0, 0, 0, 0, 0];
    
    for i in stride(from: 0, to: count, by: increment) {
        for j in 0 ..< increment {
            nums[j] = numbers[i + j]
        }
        lastCommand = callback(nums, lastCommand, coords)
        out.append(lastCommand!)
    }
    
    return out
}

// MARK: Mm - Move

private func move (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    return SVGCommand(numbers[0], numbers[1], type: .move)
}

// MARK: Ll - Line

private func line (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    return SVGCommand(numbers[0], numbers[1], type: .line)
}

// MARK: Vv - Vertical Line

private func lineVertical (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    return SVGCommand(coords == .absolute ? last?.point.x ?? 0 : 0, numbers[0], type: .line)
}

// MARK: Hh - Horizontal Line

private func lineHorizontal (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    return SVGCommand(numbers[0], coords == .absolute ? last?.point.y ?? 0 : 0, type: .line)
}

// MARK: Qq - Quadratic Curve To

private func quadBroken (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    return SVGCommand(numbers[0], numbers[1], numbers[2], numbers[3])
}

// MARK: Tt - Smooth Quadratic Curve To

private func quadSmooth (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    var lastControl = last?.control1 ?? CGPoint()
    let lastPoint = last?.point ?? CGPoint()
    if (last?.type ?? .line) != .quadCurve {
        lastControl = lastPoint
    }
    var control = lastPoint - lastControl
    if coords == .absolute {
        control = control + lastPoint
    }
    return SVGCommand(control.x, control.y, numbers[0], numbers[1])
}

// MARK: Cc - Cubic Curve To

private func cubeBroken (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    return SVGCommand(numbers[0], numbers[1], numbers[2], numbers[3], numbers[4], numbers[5])
}

// MARK: Ss - Smooth Cubic Curve To

private func cubeSmooth (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    var lastControl = last?.control2 ?? CGPoint()
    let lastPoint = last?.point ?? CGPoint()
    if (last?.type ?? .line) != .cubeCurve {
        lastControl = lastPoint
    }
    var control = lastPoint - lastControl
    if coords == .absolute {
        control = control + lastPoint
    }
    return SVGCommand(control.x, control.y, numbers[0], numbers[1], numbers[2], numbers[3])
}

// MARK: Zz - Close Path

private func close (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    return SVGCommand()
}
