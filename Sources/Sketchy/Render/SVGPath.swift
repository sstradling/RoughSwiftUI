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
        var currentPoint = CGPoint.zero
        var subpathStartPoint: CGPoint?

        for command in svgPath.commands {
            switch command.type {
            case .move:
                move(to: command.point)
                currentPoint = command.point
                subpathStartPoint = command.point
            case .line:
                addLine(to: command.point)
                currentPoint = command.point
            case .quadCurve:
                addQuadCurve(to: command.point, controlPoint: command.control1)
                currentPoint = command.point
            case .cubeCurve:
                addCurve(to: command.point, controlPoint1: command.control1, controlPoint2: command.control2)
                currentPoint = command.point
            case .arc:
                let curves = SVGArcConverter.cubicCurves(
                    from: currentPoint,
                    to: command.point,
                    rx: command.rx,
                    ry: command.ry,
                    xAxisRotation: command.xAxisRotation,
                    largeArc: command.largeArc,
                    sweep: command.sweep
                )
                if curves.isEmpty {
                    addLine(to: command.point)
                } else {
                    for curve in curves {
                        addCurve(
                            to: curve.point,
                            controlPoint1: curve.control1,
                            controlPoint2: curve.control2
                        )
                    }
                }
                currentPoint = command.point
            case .close:
                close()
                if let subpathStartPoint {
                    currentPoint = subpathStartPoint
                }
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
            case "A": use(.absolute, 7, arc)
            case "a": use(.relative, 7, arc)
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
        case arc
        case close
    }

    /// Horizontal radius for elliptical arc commands.
    public var rx: CGFloat

    /// Vertical radius for elliptical arc commands.
    public var ry: CGFloat

    /// Arc x-axis rotation in degrees.
    public var xAxisRotation: CGFloat

    /// SVG large-arc flag.
    public var largeArc: Bool

    /// SVG sweep flag.
    public var sweep: Bool
    
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
        self.rx = 0
        self.ry = 0
        self.xAxisRotation = 0
        self.largeArc = false
        self.sweep = false
    }

    public init(
        rx: CGFloat,
        ry: CGFloat,
        xAxisRotation: CGFloat,
        largeArc: Bool,
        sweep: Bool,
        point: CGPoint
    ) {
        self.point = point
        self.control1 = .zero
        self.control2 = .zero
        self.type = .arc
        self.rx = rx
        self.ry = ry
        self.xAxisRotation = xAxisRotation
        self.largeArc = largeArc
        self.sweep = sweep
    }
    
    fileprivate func relative (to other:SVGCommand?) -> SVGCommand {
        if let otherPoint = other?.point {
            if type == .arc {
                return SVGCommand(
                    rx: rx,
                    ry: ry,
                    xAxisRotation: xAxisRotation,
                    largeArc: largeArc,
                    sweep: sweep,
                    point: point + otherPoint
                )
            }
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
    var nums = [CGFloat](repeating: 0, count: max(increment, 1))
    
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

// MARK: Aa - Elliptical Arc To

private func arc (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    SVGCommand(
        rx: numbers[0],
        ry: numbers[1],
        xAxisRotation: numbers[2],
        largeArc: numbers[3] != 0,
        sweep: numbers[4] != 0,
        point: CGPoint(x: numbers[5], y: numbers[6])
    )
}

// MARK: Zz - Close Path

private func close (_ numbers: [CGFloat], last: SVGCommand?, coords: Coordinates) -> SVGCommand {
    return SVGCommand()
}

// MARK: - SVG Elliptical Arc Conversion

/// Converts SVG endpoint-parameterized elliptical arcs into cubic Bezier
/// segments, following the SVG 1.1 implementation notes.
///
/// SVG stores arcs as: current point, `(rx, ry)`, x-axis rotation, large-arc
/// flag, sweep flag, and endpoint. CoreGraphics and SwiftUI have no equivalent
/// endpoint-arc path primitive, so we decompose each arc into one to four cubic
/// Beziers (splitting at <=90° spans). This preserves curved geometry instead
/// of approximating arcs with straight line segments.
public enum SVGArcConverter {
    public struct CubicCurve: Equatable {
        public let control1: CGPoint
        public let control2: CGPoint
        public let point: CGPoint
    }

    public static func cubicCurves(
        from start: CGPoint,
        to end: CGPoint,
        rx inputRx: CGFloat,
        ry inputRy: CGFloat,
        xAxisRotation: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) -> [CubicCurve] {
        guard start != end else { return [] }

        var rx = abs(inputRx)
        var ry = abs(inputRy)

        guard rx > 0, ry > 0 else { return [] }

        let phi = xAxisRotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2

        let x1Prime = cosPhi * dx + sinPhi * dy
        let y1Prime = -sinPhi * dx + cosPhi * dy

        // Radii correction: if the requested radii are too small to connect
        // the endpoints, scale them up uniformly (SVG 1.1 F.6.6.2).
        let radiiScale = (x1Prime * x1Prime) / (rx * rx)
            + (y1Prime * y1Prime) / (ry * ry)
        if radiiScale > 1 {
            let factor = sqrt(radiiScale)
            rx *= factor
            ry *= factor
        }

        let rx2 = rx * rx
        let ry2 = ry * ry
        let x1p2 = x1Prime * x1Prime
        let y1p2 = y1Prime * y1Prime

        let numerator = max(0, rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2)
        let denominator = rx2 * y1p2 + ry2 * x1p2
        let sign: CGFloat = largeArc == sweep ? -1 : 1
        let coefficient = denominator == 0 ? 0 : sign * sqrt(numerator / denominator)

        let cxPrime = coefficient * (rx * y1Prime / ry)
        let cyPrime = coefficient * (-ry * x1Prime / rx)

        let center = CGPoint(
            x: cosPhi * cxPrime - sinPhi * cyPrime + (start.x + end.x) / 2,
            y: sinPhi * cxPrime + cosPhi * cyPrime + (start.y + end.y) / 2
        )

        let ux = (x1Prime - cxPrime) / rx
        let uy = (y1Prime - cyPrime) / ry
        let vx = (-x1Prime - cxPrime) / rx
        let vy = (-y1Prime - cyPrime) / ry

        let startAngle = vectorAngle(ux: 1, uy: 0, vx: ux, vy: uy)
        var deltaAngle = vectorAngle(ux: ux, uy: uy, vx: vx, vy: vy)

        if !sweep && deltaAngle > 0 {
            deltaAngle -= 2 * .pi
        } else if sweep && deltaAngle < 0 {
            deltaAngle += 2 * .pi
        }

        let segmentCount = max(1, Int(ceil(abs(deltaAngle) / (.pi / 2))))
        let segmentDelta = deltaAngle / CGFloat(segmentCount)

        return (0..<segmentCount).map { segmentIndex in
            let theta1 = startAngle + CGFloat(segmentIndex) * segmentDelta
            let theta2 = theta1 + segmentDelta
            return cubicCurve(
                center: center,
                rx: rx,
                ry: ry,
                phi: phi,
                theta1: theta1,
                theta2: theta2
            )
        }
    }

    private static func vectorAngle(ux: CGFloat, uy: CGFloat, vx: CGFloat, vy: CGFloat) -> CGFloat {
        let dot = ux * vx + uy * vy
        let length = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
        guard length > 0 else { return 0 }

        let clamped = max(-1, min(1, dot / length))
        let sign: CGFloat = (ux * vy - uy * vx) < 0 ? -1 : 1
        return sign * acos(clamped)
    }

    private static func cubicCurve(
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        phi: CGFloat,
        theta1: CGFloat,
        theta2: CGFloat
    ) -> CubicCurve {
        let delta = theta2 - theta1
        let alpha = (4 / 3) * tan(delta / 4)

        let p1 = point(center: center, rx: rx, ry: ry, phi: phi, theta: theta1)
        let p2 = point(center: center, rx: rx, ry: ry, phi: phi, theta: theta2)
        let d1 = derivative(rx: rx, ry: ry, phi: phi, theta: theta1)
        let d2 = derivative(rx: rx, ry: ry, phi: phi, theta: theta2)

        return CubicCurve(
            control1: CGPoint(x: p1.x + alpha * d1.x, y: p1.y + alpha * d1.y),
            control2: CGPoint(x: p2.x - alpha * d2.x, y: p2.y - alpha * d2.y),
            point: p2
        )
    }

    private static func point(
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        phi: CGFloat,
        theta: CGFloat
    ) -> CGPoint {
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)

        return CGPoint(
            x: center.x + rx * cosTheta * cosPhi - ry * sinTheta * sinPhi,
            y: center.y + rx * cosTheta * sinPhi + ry * sinTheta * cosPhi
        )
    }

    private static func derivative(
        rx: CGFloat,
        ry: CGFloat,
        phi: CGFloat,
        theta: CGFloat
    ) -> CGVector {
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)

        return CGVector(
            dx: -rx * sinTheta * cosPhi - ry * cosTheta * sinPhi,
            dy: -rx * sinTheta * sinPhi + ry * cosTheta * cosPhi
        )
    }
}
