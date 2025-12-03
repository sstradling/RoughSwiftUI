//
//  PerformanceInstrumentation.swift
//  RoughSwift
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  Performance instrumentation using os_signpost for profiling.
//
//  ## Usage
//
//  Use Instruments.app with the "os_signpost" instrument to visualize
//  performance data from this package. Look for the "RoughSwiftUI" subsystem.
//
//  ### Viewing Performance Data
//
//  1. Open Instruments.app
//  2. Choose "Blank" template
//  3. Add "os_signpost" instrument
//  4. Filter by subsystem: "com.roughswiftui"
//  5. Run your app and observe the timeline
//
//  ### Categories
//
//  - `rendering`: Canvas rendering operations
//  - `generation`: Drawing generation (JS bridge)
//  - `pathOps`: Path operations (scribble fill, stroke-to-fill)
//  - `animation`: Animation frame computation
//  - `parsing`: SVG and path parsing
//

import os.signpost
import Foundation

// MARK: - Performance Logging Infrastructure

/// The unified signpost log for all RoughSwiftUI performance events.
///
/// Use this log with Instruments.app to profile rendering performance.
/// Filter by subsystem "com.roughswiftui" to see all events.
@usableFromInline
let roughPerformanceLog = OSLog(
    subsystem: "com.roughswiftui",
    category: .pointsOfInterest
)

/// Specialized logs for different subsystems.
/// These allow filtering by category in Instruments.
public enum RoughPerformanceLog {
    /// Log for rendering operations (Canvas drawing, command execution).
    public static let rendering = OSLog(
        subsystem: "com.roughswiftui",
        category: "rendering"
    )
    
    /// Log for drawing generation (JavaScript bridge, rough.js calls).
    public static let generation = OSLog(
        subsystem: "com.roughswiftui",
        category: "generation"
    )
    
    /// Log for path operations (scribble fill, stroke-to-fill conversion).
    public static let pathOps = OSLog(
        subsystem: "com.roughswiftui",
        category: "pathOps"
    )
    
    /// Log for animation operations (variance computation, frame caching).
    public static let animation = OSLog(
        subsystem: "com.roughswiftui",
        category: "animation"
    )
    
    /// Log for parsing operations (SVG path parsing, number parsing).
    public static let parsing = OSLog(
        subsystem: "com.roughswiftui",
        category: "parsing"
    )
}

// MARK: - Signpost IDs

/// Manages signpost IDs for correlating begin/end events.
///
/// Each operation type has a unique signpost ID to help Instruments
/// correctly pair begin and end markers, even when nested.
@usableFromInline
struct SignpostID {
    @usableFromInline let rawValue: OSSignpostID
    
    @usableFromInline
    init(_ log: OSLog) {
        self.rawValue = OSSignpostID(log: log)
    }
    
    @usableFromInline
    static func makeUnique(_ log: OSLog) -> OSSignpostID {
        OSSignpostID(log: log)
    }
}

// MARK: - Signpost Names (StaticString)

/// Signpost names for rendering operations.
@usableFromInline
enum RenderingSignpost {
    @usableFromInline static let canvasRender: StaticString = "Canvas Render"
    @usableFromInline static let commandExecution: StaticString = "Command Execution"
    @usableFromInline static let buildCommands: StaticString = "Build Commands"
    @usableFromInline static let svgTransform: StaticString = "SVG Transform"
}

/// Signpost names for generation operations.
@usableFromInline
enum GenerationSignpost {
    @usableFromInline static let createGenerator: StaticString = "Create Generator"
    @usableFromInline static let generateDrawing: StaticString = "Generate Drawing"
    @usableFromInline static let jsInvoke: StaticString = "JS Invoke"
}

/// Signpost names for path operations.
@usableFromInline
enum PathOpsSignpost {
    @usableFromInline static let scribbleFill: StaticString = "Scribble Fill"
    @usableFromInline static let rayIntersection: StaticString = "Ray Intersection"
    @usableFromInline static let strokeToFill: StaticString = "Stroke to Fill"
    @usableFromInline static let pathSampling: StaticString = "Path Sampling"
    @usableFromInline static let outlineGeneration: StaticString = "Outline Generation"
    @usableFromInline static let duplicateRemoval: StaticString = "Duplicate Removal"
}

/// Signpost names for animation operations.
@usableFromInline
enum AnimationSignpost {
    @usableFromInline static let frameRender: StaticString = "Frame Render"
    @usableFromInline static let varianceCompute: StaticString = "Variance Compute"
    @usableFromInline static let precompute: StaticString = "Precompute Variance"
    @usableFromInline static let applyVariance: StaticString = "Apply Variance"
}

/// Signpost names for parsing operations.
@usableFromInline
enum ParsingSignpost {
    @usableFromInline static let svgParse: StaticString = "SVG Parse"
    @usableFromInline static let numberParse: StaticString = "Number Parse"
    @usableFromInline static let pathExtract: StaticString = "Path Extract"
}

// MARK: - Conditional Compilation

/// Controls whether performance instrumentation is active.
///
/// Set `ROUGH_PERFORMANCE_INSTRUMENTATION` in your build settings
/// to enable instrumentation. By default, instrumentation is disabled
/// in release builds for zero overhead.
///
/// To enable in Xcode:
/// 1. Select your target
/// 2. Build Settings → Swift Compiler - Custom Flags
/// 3. Add `-DROUGH_PERFORMANCE_INSTRUMENTATION` to "Other Swift Flags"
@usableFromInline
var isInstrumentationEnabled: Bool {
    #if ROUGH_PERFORMANCE_INSTRUMENTATION || DEBUG
    return true
    #else
    return false
    #endif
}

// MARK: - Performance Measurement API

/// Measures the execution time of a synchronous closure with signpost markers.
///
/// This function emits os_signpost begin/end markers that can be visualized
/// in Instruments.app. Use the "os_signpost" instrument and filter by
/// subsystem "com.roughswiftui".
///
/// - Parameters:
///   - name: The signpost name (must be StaticString for performance).
///   - log: The OSLog to use for the signpost.
///   - metadata: Optional metadata string to include in the signpost.
///   - operation: The closure to measure.
/// - Returns: The result of the operation.
@inlinable
public func measurePerformance<T>(
    _ name: StaticString,
    log: OSLog = roughPerformanceLog,
    metadata: String? = nil,
    _ operation: () throws -> T
) rethrows -> T {
    #if ROUGH_PERFORMANCE_INSTRUMENTATION || DEBUG
    let signpostID = OSSignpostID(log: log)
    
    if let metadata = metadata {
        os_signpost(.begin, log: log, name: name, signpostID: signpostID, "%{public}s", metadata)
    } else {
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
    }
    
    defer {
        os_signpost(.end, log: log, name: name, signpostID: signpostID)
    }
    
    return try operation()
    #else
    return try operation()
    #endif
}

/// Measures the execution time of an async closure with signpost markers.
///
/// - Parameters:
///   - name: The signpost name (must be StaticString for performance).
///   - log: The OSLog to use for the signpost.
///   - metadata: Optional metadata string to include in the signpost.
///   - operation: The async closure to measure.
/// - Returns: The result of the operation.
@inlinable
public func measurePerformanceAsync<T>(
    _ name: StaticString,
    log: OSLog = roughPerformanceLog,
    metadata: String? = nil,
    _ operation: () async throws -> T
) async rethrows -> T {
    #if ROUGH_PERFORMANCE_INSTRUMENTATION || DEBUG
    let signpostID = OSSignpostID(log: log)
    
    if let metadata = metadata {
        os_signpost(.begin, log: log, name: name, signpostID: signpostID, "%{public}s", metadata)
    } else {
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
    }
    
    defer {
        os_signpost(.end, log: log, name: name, signpostID: signpostID)
    }
    
    return try await operation()
    #else
    return try await operation()
    #endif
}

// MARK: - Event Markers

/// Emits a single point-in-time event marker.
///
/// Use this for instantaneous events that don't have duration,
/// such as cache hits/misses or state changes.
///
/// - Parameters:
///   - name: The event name.
///   - log: The OSLog to use.
///   - message: Optional message to include.
@inlinable
public func emitPerformanceEvent(
    _ name: StaticString,
    log: OSLog = roughPerformanceLog,
    message: String? = nil
) {
    #if ROUGH_PERFORMANCE_INSTRUMENTATION || DEBUG
    if let message = message {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    } else {
        os_signpost(.event, log: log, name: name)
    }
    #endif
}

// MARK: - Interval Tracking

/// A performance interval that can be manually started and ended.
///
/// Use this when the begin and end points are in different scopes,
/// or when you need to conditionally end the interval.
///
/// Example:
/// ```swift
/// let interval = PerformanceInterval.begin("My Operation", log: .rendering)
/// // ... do work ...
/// interval.end()
/// ```
public struct PerformanceInterval {
    private let name: StaticString
    private let log: OSLog
    private let signpostID: OSSignpostID
    private var hasEnded = false
    
    private init(name: StaticString, log: OSLog, signpostID: OSSignpostID) {
        self.name = name
        self.log = log
        self.signpostID = signpostID
    }
    
    /// Begins a new performance interval.
    ///
    /// - Parameters:
    ///   - name: The interval name.
    ///   - log: The OSLog to use.
    ///   - metadata: Optional metadata to include.
    /// - Returns: A PerformanceInterval that must be ended.
    public static func begin(
        _ name: StaticString,
        log: OSLog = roughPerformanceLog,
        metadata: String? = nil
    ) -> PerformanceInterval {
        let signpostID = OSSignpostID(log: log)
        
        #if ROUGH_PERFORMANCE_INSTRUMENTATION || DEBUG
        if let metadata = metadata {
            os_signpost(.begin, log: log, name: name, signpostID: signpostID, "%{public}s", metadata)
        } else {
            os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        }
        #endif
        
        return PerformanceInterval(name: name, log: log, signpostID: signpostID)
    }
    
    /// Ends this performance interval.
    ///
    /// - Parameter metadata: Optional metadata to include in the end marker.
    public mutating func end(metadata: String? = nil) {
        guard !hasEnded else { return }
        hasEnded = true
        
        #if ROUGH_PERFORMANCE_INSTRUMENTATION || DEBUG
        if let metadata = metadata {
            os_signpost(.end, log: log, name: name, signpostID: signpostID, "%{public}s", metadata)
        } else {
            os_signpost(.end, log: log, name: name, signpostID: signpostID)
        }
        #endif
    }
}

// MARK: - Statistics Collection

/// Collects and reports aggregate performance statistics.
///
/// Use this to track cumulative metrics across multiple operations,
/// such as total time spent in JavaScript calls or average frame render time.
///
/// Note: Statistics collection has some overhead and should only be
/// enabled when actively profiling.
public final class PerformanceStatistics: @unchecked Sendable {
    
    /// Singleton instance for global statistics.
    public static let shared = PerformanceStatistics()
    
    private let lock = NSLock()
    private var measurements: [String: [TimeInterval]] = [:]
    private var counters: [String: Int] = [:]
    
    private init() {}
    
    /// Records a duration measurement for a named operation.
    public func record(_ name: String, duration: TimeInterval) {
        #if ROUGH_PERFORMANCE_INSTRUMENTATION || DEBUG
        lock.lock()
        defer { lock.unlock() }
        measurements[name, default: []].append(duration)
        #endif
    }
    
    /// Increments a counter for a named event.
    public func increment(_ name: String, by value: Int = 1) {
        #if ROUGH_PERFORMANCE_INSTRUMENTATION || DEBUG
        lock.lock()
        defer { lock.unlock() }
        counters[name, default: 0] += value
        #endif
    }
    
    /// Gets statistics for a named operation.
    public func statistics(for name: String) -> (count: Int, total: TimeInterval, average: TimeInterval, max: TimeInterval)? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let durations = measurements[name], !durations.isEmpty else {
            return nil
        }
        
        let total = durations.reduce(0, +)
        let average = total / TimeInterval(durations.count)
        let max = durations.max() ?? 0
        
        return (durations.count, total, average, max)
    }
    
    /// Gets the current value of a counter.
    public func counter(for name: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counters[name] ?? 0
    }
    
    /// Resets all collected statistics.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        measurements.removeAll()
        counters.removeAll()
    }
    
    /// Generates a summary report of all collected statistics.
    public func generateReport() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        var report = "=== RoughSwiftUI Performance Report ===\n\n"
        
        // Duration measurements
        if !measurements.isEmpty {
            report += "Duration Measurements:\n"
            for (name, durations) in measurements.sorted(by: { $0.key < $1.key }) {
                let total = durations.reduce(0, +)
                let avg = total / TimeInterval(durations.count)
                let max = durations.max() ?? 0
                report += "  \(name):\n"
                report += "    Count: \(durations.count)\n"
                report += "    Total: \(String(format: "%.3f", total * 1000))ms\n"
                report += "    Average: \(String(format: "%.3f", avg * 1000))ms\n"
                report += "    Max: \(String(format: "%.3f", max * 1000))ms\n"
            }
            report += "\n"
        }
        
        // Counters
        if !counters.isEmpty {
            report += "Counters:\n"
            for (name, count) in counters.sorted(by: { $0.key < $1.key }) {
                report += "  \(name): \(count)\n"
            }
        }
        
        return report
    }
    
    /// Prints the performance report to the console.
    public func printReport() {
        print(generateReport())
    }
}

// MARK: - Convenience Extensions

extension PerformanceStatistics {
    /// Measures and records a named operation.
    @inlinable
    public func measure<T>(_ name: String, _ operation: () throws -> T) rethrows -> T {
        #if ROUGH_PERFORMANCE_INSTRUMENTATION || DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - start
            record(name, duration: duration)
        }
        return try operation()
        #else
        return try operation()
        #endif
    }
}

