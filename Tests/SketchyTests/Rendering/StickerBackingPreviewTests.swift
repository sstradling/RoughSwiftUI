import SwiftUI
import XCTest
@testable import Sketchy

/// Writes paper-card PNGs of the real sticker backing. Skipped unless
/// `STICKER_PREVIEW=1`. xcodebuild delivers that as `TEST_RUNNER_STICKER_PREVIEW`.
@MainActor
final class StickerBackingPreviewTests: XCTestCase {

    private let cardWidth: CGFloat = 980
    private let cardHeight: CGFloat = 480
    private let slate = Color(red: 0.22, green: 0.31, blue: 0.39)
    private let ink = Color(red: 0.12, green: 0.14, blue: 0.18)
    private let blue = Color(red: 0.20, green: 0.48, blue: 0.78)
    private let coral = Color(red: 0.86, green: 0.36, blue: 0.28)
    private let leaf = Color(red: 0.24, green: 0.58, blue: 0.40)
    private let plum = Color(red: 0.50, green: 0.32, blue: 0.62)

    func testRenderStickerPreviewCards() throws {
        guard previewsEnabled() else {
            throw XCTSkip("Set STICKER_PREVIEW=1 to write sticker preview cards.")
        }
        let directory = try outputDirectory()
        try write(starCard, name: "sticker-star-compare.png", to: directory)
        try write(organicCard, name: "sticker-organic-widths.png", to: directory)
        try write(compoundCard, name: "sticker-compound-crayon.png", to: directory)
        let curvedEdge = eggOutline(curved: true)
        let facetedEdge = eggOutline(curved: false)
        XCTAssertGreaterThan(curvedEdge.boundingRect.width, 40)
        XCTAssertGreaterThan(facetedEdge.boundingRect.width, 40)
        try write(edgeCloseup, name: "sticker-egg-edge-closeup.png", to: directory)
        try write(surfaceCard, name: "sticker-color-texture.png", to: directory)
        try write(edgeModes, name: "sticker-egg-fully-smooth.png", width: 1040, height: 520, to: directory)
        try write(fullEgg, name: "sticker-fully-smooth-egg-closeup.png", width: 760, height: 900, to: directory)
        try write(starModes, name: "sticker-fully-smooth-star.png", width: 860, height: 520, to: directory)
        try write(smoothCompound, name: "sticker-fully-smooth-compound.png", width: 860, height: 520, to: directory)
    }

    private var starCard: some View {
        card("Star: none, close, smoothed silhouette, torn") {
            HStack(alignment: .top, spacing: 18) {
                sample("No backing", star(backing: nil))
                sample("Close, 14pt", star(backing: StickerBacking(width: 14, smoothness: 0)))
                sample("Smoothed, 14pt", star(backing: StickerBacking(width: 14, smoothness: 1)))
                sample("Torn, 14pt", star(backing: StickerBacking(
                    width: 14,
                    smoothness: 0.45,
                    edge: .torn(StickerTear(depth: 8, length: 16, jaggedness: 0.45))
                )))
            }
        }
    }

    private var organicCard: some View {
        card("Egg: narrow close cut, wide smooth cut, wide torn cut") {
            HStack(alignment: .top, spacing: 28) {
                sample("Close, width 8", egg(backing: StickerBacking(width: 8, smoothness: 0.08)))
                sample("Smoothed, width 22", egg(backing: StickerBacking(width: 22, smoothness: 1)))
                sample("Torn, width 22", egg(backing: StickerBacking(
                    width: 22,
                    smoothness: 0.55,
                    edge: .torn(StickerTear(depth: 9, length: 18, jaggedness: 0.35))
                )))
            }
        }
    }

    private var compoundCard: some View {
        card("Hole, crayon, and watercolor on the same sheet") {
            HStack(alignment: .top, spacing: 18) {
                sample("Hole, smoothed", donut(backing: StickerBacking(width: 12, smoothness: 0.9)), fillsView: true)
                sample("Hole, torn", donut(backing: StickerBacking(
                    width: 14,
                    smoothness: 0.4,
                    edge: .torn(StickerTear(depth: 9, length: 20, jaggedness: 0.55))
                )), fillsView: true)
                sample("Crayon", crayon, fillsView: true)
                sample("Watercolor", watercolor, fillsView: true)
            }
        }
    }

    private var edgeCloseup: some View {
        let faceted = eggOutline(curved: false)
        let curved = eggOutline(curved: true)
        return card("Egg edge, close-up: offset polygon and smooth curve") {
            HStack(alignment: .top, spacing: 24) {
                zoomedOutline("Offset polygon", faceted)
                zoomedOutline("Smooth curve", curved)
            }
        }
    }

    private var surfaceCard: some View {
        card("Sheet color, grain, and both. Torn grain stays chopped.") {
            HStack(alignment: .top, spacing: 16) {
                sample("Tinted", egg(backing: StickerBacking(
                    width: 18,
                    smoothness: 1,
                    color: UIColor(red: 0.96, green: 0.91, blue: 0.78, alpha: 1)
                )))
                sample("White grain", egg(backing: StickerBacking(
                    width: 18,
                    smoothness: 1,
                    texture: .paper(amount: 0.62, scale: 9, seed: 6)
                )))
                sample("Tint + grain", egg(backing: StickerBacking(
                    width: 18,
                    smoothness: 1,
                    color: UIColor(red: 0.73, green: 0.84, blue: 0.78, alpha: 1),
                    texture: .paper(amount: 0.62, scale: 9, seed: 6)
                )))
                sample("Torn + grain", egg(backing: StickerBacking(
                    width: 16,
                    smoothness: 0.7,
                    edge: .torn(StickerTear(depth: 8, length: 16, jaggedness: 0.4)),
                    texture: .paper(amount: 0.5, scale: 10, seed: 6)
                )))
            }
        }
    }

    private func eggOutline(curved: Bool) -> SwiftUI.Path {
        var options = Options()
        options.roughness = 0
        options.bowing = 0
        options.maxRandomnessOffset = 0
        options.strokeWidth = 2
        options.seed = 17
        options.stickerBacking = StickerBacking(width: 22, smoothness: 1)
        let size = CGSize(width: 240, height: 280)
        let generator = Engine().generator(size: size)
        guard let drawing = generator.generate(
            drawable: EggShape(x: 120, y: 145, width: 100, height: 160, tilt: 0.42),
            options: options
        ) else {
            return SwiftUI.Path()
        }
        let lines = StickerBackingBuilder.centerlines(
            for: drawing,
            options: options,
            backing: options.stickerBacking!,
            transform: nil
        )
        guard let line = lines.first(where: \.closed) ?? lines.first else {
            return SwiftUI.Path()
        }
        let ring = StickerBackingBuilder.offsetClosed(line.points, by: 23) ?? line.points
        return StickerBackingBuilder.contourPath(ring, closed: true, curved: curved)
    }

    private func zoomedOutline(_ label: String, _ path: SwiftUI.Path) -> some View {
        let bounds = path.boundingRect
        let focus = CGRect(
            x: bounds.midX - bounds.width * 0.02,
            y: bounds.midY - bounds.height * 0.34,
            width: bounds.width * 0.62,
            height: bounds.height * 0.58
        )
        return VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(white: 0.93))
            Canvas { context, size in
                let scale = min(size.width / max(focus.width, 1), size.height / max(focus.height, 1))
                let transform = CGAffineTransform(
                    a: scale,
                    b: 0,
                    c: 0,
                    d: scale,
                    tx: -focus.minX * scale,
                    ty: -focus.minY * scale
                )
                let drawn = path.applying(transform)
                context.fill(drawn, with: .color(.white))
                context.stroke(drawn, with: .color(Color(white: 0.12)), lineWidth: 2)
            }
            .frame(width: 360, height: 240)
            .background(slate)
        }
    }

    private func star(backing: StickerBacking?) -> RoughView {
        RoughView()
            .fill(blue)
            .fillStyle(.hachure)
            .fillAngle(0)
            .fillSpacing(2.8)
            .stroke(ink)
            .strokeWidth(2)
            .roughness(2.1)
            .maxRandomnessOffset(3.2)
            .bowing(1)
            .seed(42)
            .stickerBacking(backing)
            .draw(Polygon(points: starPoints(cx: 100, cy: 108, outer: 64, inner: 26)))
    }

    private func egg(backing: StickerBacking?) -> RoughView {
        RoughView()
            .fill(leaf)
            .fillStyle(.hachure)
            .fillAngle(0)
            .fillSpacing(3)
            .stroke(ink)
            .strokeWidth(2)
            .roughness(1.45)
            .maxRandomnessOffset(2.4)
            .seed(17)
            .stickerBacking(backing)
            .draw(EggShape(x: 100, y: 112, width: 86, height: 124, tilt: 0.42))
    }

    private func donut(backing: StickerBacking?) -> RoughView {
        RoughView()
            .fill(coral)
            .fillStyle(.hachure)
            .fillAngle(0)
            .fillSpacing(3)
            .stroke(ink)
            .strokeWidth(2)
            .roughness(1.2)
            .seed(9)
            .stickerBacking(backing)
            .draw(Sketchy.Path(d: "M16 16 H144 V144 H16 Z M50 50 H110 V110 H50 Z"))
    }

    private var crayon: RoughView {
        RoughView()
            .fill(plum)
            .fillStyle(.hachure)
            .fillAngle(0)
            .fillSpacing(3.4)
            .stroke(plum)
            .strokeWidth(13)
            .brushProfile(.crayon(seed: 4))
            .seed(4)
            .stickerBacking(width: 20, smoothness: 0.75)
            .circle()
    }

    private var watercolor: RoughView {
        RoughView()
            .fill(Color(red: 0.20, green: 0.48, blue: 0.66))
            .fillStyle(.watercolor)
            .stroke(ink)
            .strokeWidth(2)
            .seed(11)
            .stickerBacking(width: 16, smoothness: 0.8)
            .circle()
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(white: 0.96))
            content()
        }
        .padding(24)
        .frame(width: cardWidth, height: cardHeight, alignment: .top)
        .background(slate)
    }

    private func sample(_ label: String, _ view: RoughView, fillsView: Bool = false) -> some View {
        let canvas = fillsView
            ? AnyView(view.frame(width: 168, height: 196).frame(width: 214, height: 242))
            : AnyView(view.frame(width: 214, height: 242))
        return VStack(spacing: 6) {
            canvas
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(white: 0.93))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 214)
        }
    }

    private func starPoints(cx: Float, cy: Float, outer: Float, inner: Float) -> [Point] {
        (0..<10).map { index in
            let angle = -Float.pi / 2 + Float(index) * .pi / 5
            let radius: Float = index.isMultiple(of: 2) ? outer : inner
            return Point(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
        }
    }

    private var edgeModes: some View {
        sizedCard("Same egg, tilt 0.42, width 22. Corner-preserving, fully smooth, torn.", width: 1040, height: 520) {
            HStack(alignment: .top, spacing: 18) {
                labeledEgg("Corner-preserving", edge: .smooth)
                labeledEgg("Fully smooth", edge: .fullySmooth())
                labeledEgg("Torn", edge: .torn(StickerTear(depth: 8, length: 16, jaggedness: 0.4)))
            }
        }
    }

    private var fullEgg: some View {
        sizedCard("Fully smooth egg. Entire cutout, tilt 0.42, width 22.", width: 760, height: 900) {
            VStack(spacing: 16) {
                Text("Continuous edge, no cropped shape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(white: 0.93))
                previewEgg(edge: .fullySmooth())
                    .frame(width: 240, height: 300)
                    .scaleEffect(2.15)
                    .frame(width: 640, height: 700)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var smoothCompound: some View {
        sizedCard("Fully smooth compound. Hole stays open. Corner-preserving shown beside it.", width: 860, height: 520) {
            HStack(alignment: .top, spacing: 36) {
                VStack(spacing: 8) {
                    donut(backing: StickerBacking(width: 14, smoothness: 0.9, edge: .smooth))
                        .frame(width: 220, height: 220)
                        .frame(width: 300, height: 320)
                    Text("Corner-preserving")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.93))
                }
                VStack(spacing: 8) {
                    donut(backing: StickerBacking(width: 14, smoothness: 0.9, edge: .fullySmooth()))
                        .frame(width: 220, height: 220)
                        .frame(width: 300, height: 320)
                    Text("Fully smooth")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.93))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var starModes: some View {
        sizedCard("Fully smooth rounds star corners. Corner-preserving keeps them.", width: 860, height: 520) {
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 8) {
                    star(backing: StickerBacking(width: 14, smoothness: 1, edge: .smooth))
                        .frame(width: 280, height: 300)
                    Text("Corner-preserving")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.93))
                }
                VStack(spacing: 8) {
                    star(backing: StickerBacking(width: 14, smoothness: 1, edge: .fullySmooth()))
                        .frame(width: 280, height: 300)
                    Text("Fully smooth")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.93))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func labeledEgg(_ label: String, edge: StickerEdge) -> some View {
        VStack(spacing: 8) {
            previewEgg(edge: edge)
                .frame(width: 280, height: 340)
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(white: 0.93))
        }
    }

    /// The egg from the wide-margin preview: tilt 0.42, backing width 22.
    private func previewEgg(edge: StickerEdge) -> RoughView {
        egg(backing: StickerBacking(width: 22, smoothness: 1, edge: edge))
    }

    private func sizedCard<Content: View>(
        _ title: String,
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(white: 0.96))
            content()
        }
        .padding(28)
        .frame(width: width, height: height, alignment: .top)
        .background(slate)
    }

    private func write<Content: View>(
        _ content: Content,
        name: String,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        to directory: URL
    ) throws {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(
            width: width ?? cardWidth,
            height: height ?? cardHeight
        )
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage, "No image for \(name)")
        let data = try XCTUnwrap(image.pngData(), "No PNG for \(name)")
        XCTAssertLessThan(data.count, 10 * 1024 * 1024, "\(name) exceeds 10 MB")
        XCTAssertGreaterThan(data.count, 8 * 1024, "\(name) looks empty")
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        NSLog("STICKER_PREVIEW %@", directory.appendingPathComponent(name).path)
    }

    private func previewsEnabled() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["STICKER_PREVIEW"] == "1" || environment["TEST_RUNNER_STICKER_PREVIEW"] == "1"
    }

    private func outputDirectory() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let path = environment["STICKER_PREVIEW_OUTPUT"]
            ?? environment["TEST_RUNNER_STICKER_PREVIEW_OUTPUT"]
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("sticker-previews").path
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
