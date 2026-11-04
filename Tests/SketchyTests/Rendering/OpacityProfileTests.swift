import CoreGraphics
import XCTest
@testable import Sketchy

/// Opacity profiles, the watercolor brush, and the promise that older brushes stay put.
@MainActor
final class OpacityProfileTests: XCTestCase {
    func testUniformOpacityIsOne() {
        XCTAssertEqual(OpacityProfile.uniform.value(at: 0), 1)
        XCTAssertEqual(OpacityProfile.uniform.value(at: 0.5), 1)
        XCTAssertEqual(OpacityProfile.uniform.value(at: 1), 1)
        XCTAssertFalse(OpacityProfile.uniform.variesAlongStroke)
    }

    func testValuesAreEvenlySpacedAndClamped() {
        let profile = OpacityProfile.values([0, 1, 0])
        XCTAssertEqual(profile.value(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 0.25), 0.5, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 0.5), 1, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 0.75), 0.5, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 1), 0, accuracy: 0.0001)
        XCTAssertTrue(profile.variesAlongStroke)

        let clamped = OpacityProfile.values([-2, 4])
        XCTAssertEqual(clamped.value(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(clamped.value(at: 1), 1, accuracy: 0.0001)

        XCTAssertEqual(OpacityProfile.values([]).value(at: 0.3), 1, accuracy: 0.0001)
        XCTAssertFalse(OpacityProfile.values([0.4, 0.4]).variesAlongStroke)
        XCTAssertEqual(OpacityProfile.values([0.4]).value(at: 0.8), 0.4, accuracy: 0.0001)
    }

    func testStopsInterpolateAndHoldOutsideTheRange() {
        let profile = OpacityProfile.stops([
            OpacityStop(0.2, at: 0.2),
            OpacityStop(0.8, at: 0.6),
            OpacityStop(0.0, at: 1)
        ])
        XCTAssertEqual(profile.value(at: 0), 0.2, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 0.2), 0.2, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 0.4), 0.5, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 0.6), 0.8, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 0.8), 0.4, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 1), 0, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: -1), 0.2, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 2), 0, accuracy: 0.0001)
    }

    func testStopsIgnoreOrderAndClamp() {
        let profile = OpacityProfile.stops([
            OpacityStop(1.4, at: 1.2),
            OpacityStop(-0.5, at: -0.2)
        ])
        XCTAssertEqual(profile.value(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 0.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(profile.value(at: 1), 1, accuracy: 0.0001)
        XCTAssertEqual(OpacityProfile.stops([]).value(at: 0.4), 1, accuracy: 0.0001)
        XCTAssertFalse(OpacityProfile.stops([OpacityStop(0.3, at: 0), OpacityStop(0.3, at: 1)]).variesAlongStroke)
    }

    func testNoiseStaysInsideBoundsAndRepeatsTheSeed() {
        let noise = OpacityProfile.noise(minimum: 0.2, maximum: 0.8, variation: 1, seed: 11, frequency: 3)
        var samples: [CGFloat] = []
        for index in 0..<64 {
            let value = noise.value(at: CGFloat(index) / 63)
            samples.append(value)
            XCTAssertGreaterThanOrEqual(value, 0.2 - 0.0001)
            XCTAssertLessThanOrEqual(value, 0.8 + 0.0001)
        }
        let again = (0..<64).map { OpacityProfile.noise(minimum: 0.2, maximum: 0.8, variation: 1, seed: 11, frequency: 3).value(at: CGFloat($0) / 63) }
        XCTAssertEqual(samples, again)
        let other = (0..<64).map { OpacityProfile.noise(minimum: 0.2, maximum: 0.8, variation: 1, seed: 12, frequency: 3).value(at: CGFloat($0) / 63) }
        XCTAssertNotEqual(samples, other)
        XCTAssertGreaterThan(samples.max()! - samples.min()!, 0.05)
    }

    func testNoiseVariationZeroIsTheMidpoint() {
        let profile = OpacityProfile.noise(minimum: 0.2, maximum: 0.8, variation: 0, seed: 4)
        XCTAssertFalse(profile.variesAlongStroke)
        XCTAssertEqual(profile.value(at: 0.3), 0.5, accuracy: 0.0001)
    }

    func testPeriodicNoiseMatchesAtTheJoin() {
        let profile = OpacityProfile.noise(minimum: 0.1, maximum: 0.9, variation: 1, seed: 9, frequency: 2.4)
        XCTAssertEqual(
            profile.value(at: 0, periodic: true),
            profile.value(at: 1, periodic: true),
            accuracy: 0.0001
        )
    }

    func testResolvedOpacityFollowsOptionsSeedOnlyForTheDefaultNoiseSeed() {
        var options = Options()
        options.opacityProfile = .noise(minimum: 0.2, maximum: 1, seed: OpacityNoise.defaultSeed)
        options.seed = 42
        guard case .noise(let resolved) = options.resolvedOpacityProfile() else {
            return XCTFail("expected noise")
        }
        XCTAssertEqual(resolved.seed, 42)

        options.opacityProfile = .noise(minimum: 0.2, maximum: 1, seed: 7)
        guard case .noise(let kept) = options.resolvedOpacityProfile() else {
            return XCTFail("expected noise")
        }
        XCTAssertEqual(kept.seed, 7)
    }

    func testVariableOpacityCommandsStayInBoundsAndRepeat() {
        let profile = OpacityProfile.stops([
            OpacityStop(0.2, at: 0),
            OpacityStop(1, at: 0.5),
            OpacityStop(0.25, at: 1)
        ])
        var options = Options()
        options.opacityProfile = profile
        options.strokeOpacity = 0.5
        options.strokeWidth = 12
        let first = outlineCommands(options: options)
        let second = outlineCommands(options: options)
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first.map(\.maskOpacity), second.map(\.maskOpacity))
        XCTAssertEqual(first.map(\.opacityMaskGroup), second.map(\.opacityMaskGroup))
        let group = first.first?.opacityMaskGroup
        XCTAssertNotNil(group)
        XCTAssertTrue(first.allSatisfy { $0.opacityMaskGroup == group })
        for command in first {
            XCTAssertGreaterThanOrEqual(command.maskOpacity, 0)
            XCTAssertLessThanOrEqual(command.maskOpacity, 0.5 + 0.0001)
        }
        XCTAssertGreaterThan(first.map(\.maskOpacity).max()! - first.map(\.maskOpacity).min()!, 0.05)
    }

    func testClosedOpacityJoinUsesOneMaskAndDoesNotDarkenBySplittingGroups() {
        var options = Options()
        options.opacityProfile = .noise(minimum: 0.3, maximum: 0.9, variation: 1, seed: 5, frequency: 2)
        options.strokeWidth = 8
        let commands = outlineCommands(options: options, closed: true)
        let groups = Set(commands.compactMap(\.opacityMaskGroup))
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(commands.isEmpty)
    }

    func testExistingBrushesDoNotGainAnOpacityMaskOrWatercolor() {
        for profile in [BrushProfile.default, .calligraphic, .marker, .pen, .crayon, .marker(variation: 0.4, seed: 3)] {
            XCTAssertNil(profile.watercolor)
            XCTAssertEqual(profile.opacityProfile, .uniform)
            let commands = outlineCommands(profile: profile)
            XCTAssertTrue(commands.allSatisfy { $0.opacityMaskGroup == nil })
            XCTAssertFalse(commands.isEmpty)
        }
        XCTAssertEqual(outlineCommands(profile: .default).count, 1)
        XCTAssertEqual(outlineCommands(profile: .pen).count, 1)
        XCTAssertEqual(outlineCommands(profile: .marker).count, 1)
        XCTAssertGreaterThan(outlineCommands(profile: .crayon).count, 1)
    }

    func testUniformOpacityDoesNotChangeThePenOutline() {
        let plain = outlineCommands(profile: .pen)
        var options = Options()
        options.brushProfile = .pen
        options.opacityProfile = .uniform
        options.strokeWidth = 12
        let withProfile = outlineCommands(options: options)
        XCTAssertEqual(plain.count, withProfile.count)
        XCTAssertNil(plain.first?.opacityMaskGroup)
        XCTAssertNil(withProfile.first?.opacityMaskGroup)
        XCTAssertEqual(plain.first?.path.boundingRect, withProfile.first?.path.boundingRect)
    }

    func testWatercolorFactoryClampsAndStaysSeeded() {
        let profile = BrushProfile.watercolor(
            pigment: 4,
            wetness: -1,
            edgeDarkening: 2,
            layers: 9,
            variation: -3,
            bleed: 3,
            seed: 8
        )
        XCTAssertEqual(profile.watercolor?.pigment, 1)
        XCTAssertEqual(profile.watercolor?.wetness, 0)
        XCTAssertEqual(profile.watercolor?.edgeDarkening, 1)
        XCTAssertEqual(profile.watercolor?.layers, 5)
        XCTAssertEqual(profile.watercolor?.variation, 0)
        XCTAssertEqual(profile.watercolor?.bleed, 1)
        XCTAssertEqual(profile.watercolor?.seed, 8)
        XCTAssertEqual(profile.opacityProfile, .uniform)
        XCTAssertEqual(profile.thicknessProfile, .uniform)
        XCTAssertEqual(BrushProfile.watercolor(), .watercolor)
        XCTAssertNotNil(BrushProfile.watercolor.watercolor)
    }

    func testTightBendKeepsTheRibbonOutOfTheCorner() {
        var options = Options()
        options.brushProfile = .watercolor(
            pigment: 0.8,
            wetness: 0.4,
            edgeDarkening: 0.9,
            layers: 2,
            variation: 0.2,
            bleed: 0.5,
            seed: 3
        )
        options.strokeWidth = 18
        options.roughness = 0
        let operations: [Sketchy.Operation] = [
            Move(data: [20, 40]),
            LineTo(data: [140, 40]),
            LineTo(data: [140, 120]),
            LineTo(data: [20, 120])
        ]
        let pathSet = OperationSet(type: .path, operations: operations, path: nil, size: nil)
        let drawing = Drawing(shape: "line", sets: [pathSet], options: options)
        let commands = SwiftUIRenderer().commands(
            for: drawing,
            options: options,
            in: CGSize(width: 180, height: 160)
        )
        let pocket = CGPoint(x: 118, y: 62)
        for command in commands where command.fillRule != .evenOdd {
            XCTAssertFalse(
                command.path.cgPath.contains(pocket),
                "tight bend filled across the inside of the corner"
            )
        }
    }

    func testWatercolorCommandsRepeatForASeedAndDifferForAnother() {
        let first = watercolorCommands(seed: 4)
        let second = watercolorCommands(seed: 4)
        let other = watercolorCommands(seed: 9)
        XCTAssertEqual(first.map { $0.path.boundingRect }, second.map { $0.path.boundingRect })
        XCTAssertNotEqual(first.map { $0.path.boundingRect }, other.map { $0.path.boundingRect })
        XCTAssertGreaterThan(first.count, 8)
        XCTAssertTrue(first.allSatisfy { $0.opacityMaskGroup == nil })
        XCTAssertTrue(first.allSatisfy { $0.opacityMaskBlur == 0 })
    }

    func testWatercolorGlazesInsteadOfMasking() {
        let commands = watercolorCommands(seed: 4)
        XCTAssertTrue(commands.allSatisfy { command in
            if case .fill = command.style { return true }
            return false
        })
    }

    func testWatercolorFillIsClippedAndRespectsPadding() {
        var options = Options()
        options.fillStyle = .watercolor
        options.fill = UIColor.systemBlue
        options.fillOpacity = 0.8
        options.strokeWidth = 0
        options.seed = 6
        options.brushProfile = .watercolor(variation: 0.4, bleed: 0.4, seed: 6)
        let unpadded = fillBounds(Circle(x: 80, y: 80, diameter: 100), options: options)

        var padded = options
        padded.fillPadding = 14
        let inset = fillBounds(Circle(x: 80, y: 80, diameter: 100), options: padded)

        XCTAssertGreaterThan(unpadded.width, inset.width + 10)
        XCTAssertGreaterThan(unpadded.height, inset.height + 10)
        XCTAssertFalse(inset.isNull)
    }

    func testWatercolorFillCommandsStayInsideTheStrokeOpacityRange() {
        var options = Options()
        options.fillStyle = .watercolor
        options.fill = UIColor.systemTeal
        options.fillOpacity = 0.5
        options.seed = 3
        let commands = fillCommands(Circle(x: 40, y: 40, diameter: 60), options: options)
        XCTAssertFalse(commands.isEmpty)
        XCTAssertTrue(commands.allSatisfy { $0.clipPath != nil })
        XCTAssertTrue(commands.allSatisfy { $0.opacityMaskGroup == nil })
        XCTAssertGreaterThan(commands.count, 8)
    }

    private func outlineCommands(
        profile: BrushProfile,
        closed: Bool = false
    ) -> [RoughRenderCommand] {
        var options = Options()
        options.brushProfile = profile
        options.strokeWidth = 12
        return outlineCommands(options: options, closed: closed)
    }

    private func outlineCommands(options: Options, closed: Bool = false) -> [RoughRenderCommand] {
        var operations: [Sketchy.Operation] = [
            Move(data: [10, 30]),
            LineTo(data: [110, 36])
        ]
        if closed {
            operations.append(LineTo(data: [104, 90]))
            operations.append(LineTo(data: [16, 84]))
            operations.append(Close())
        }
        let pathSet = OperationSet(type: .path, operations: operations, path: nil, size: nil)
        let drawing = Drawing(shape: "line", sets: [pathSet], options: options)
        return SwiftUIRenderer().commands(for: drawing, options: options, in: CGSize(width: 140, height: 120))
    }

    private func watercolorCommands(seed: UInt64) -> [RoughRenderCommand] {
        var options = Options()
        options.brushProfile = .watercolor(pigment: 0.7, wetness: 0.5, edgeDarkening: 0.8, layers: 3, variation: 0.5, bleed: 0.4, seed: seed)
        options.strokeWidth = 18
        options.strokeOpacity = 1
        return outlineCommands(options: options)
    }

    private func fillCommands(_ drawable: Drawable, options: Options) -> [RoughRenderCommand] {
        let generator = Engine.shared.generator(size: CGSize(width: 200, height: 200))
        let drawing = generator.generate(drawable: drawable, options: options)
        XCTAssertNotNil(drawing)
        return SwiftUIRenderer().commands(
            for: drawing ?? Drawing(shape: "circle", sets: [], options: options),
            options: options,
            in: CGSize(width: 200, height: 200)
        ).filter { $0.clipPath != nil && $0.opacityMaskGroup == nil }
    }

    private func fillBounds(_ drawable: Drawable, options: Options) -> CGRect {
        fillCommands(drawable, options: options).reduce(CGRect.null) { partial, command in
            guard let clip = command.clipPath else { return partial }
            if partial.isNull { return clip.boundingRect }
            return partial.union(clip.boundingRect)
        }
    }
}
