import CoreGraphics
import SwiftUI
import UIKit
@testable import RoughSwiftUI

/// Failure while rasterizing the documentation gallery.
enum DocsGalleryError: Error, CustomStringConvertible {
    case outputNotWritable
    case imageRenderFailed(String)
    case blankImage(String)
    case unexpectedPixelSize(String, Int, Int)
    case pngEncodingFailed(String)
    case missingSeed(String)
    case missingAnimation(String)
    case identicalGIFFrames(String)

    var description: String {
        switch self {
        case .outputNotWritable:
            return "Could not write the docs render directory."
        case let .imageRenderFailed(id):
            return "ImageRenderer returned no image for \(id)."
        case let .blankImage(id):
            return "Rendered tile for \(id) is a flat color. The shape did not draw."
        case let .unexpectedPixelSize(id, width, height):
            let expected = Int(DocExampleCatalog.tileSide * DocExampleCatalog.renderScale)
            return "\(id) is \(width)x\(height), expected \(expected)x\(expected) at scale \(DocExampleCatalog.renderScale)."
        case let .pngEncodingFailed(name):
            return "Could not encode PNG data for \(name)."
        case let .missingSeed(id):
            return "\(id) must set Options.seed so the gallery is deterministic."
        case let .missingAnimation(id):
            return "\(id) is a GIF and needs AnimationConfig, including seed."
        case let .identicalGIFFrames(id):
            return "\(id) pinned frames are identical, so the animation hook did not advance."
        }
    }
}

/// Manifest consumed by `scripts/render-docs.sh` to compress images and write Examples.md.
struct DocsManifest: Encodable {
    struct Example: Encodable {
        var id: String
        var section: String
        var sectionSlug: String
        var title: String
        var description: String
        var snippet: String
        var kind: String
        var fps: Int?
        var frameCount: Int?
        var framesDirectory: String?
        var output: String
    }

    var examples: [Example]
}

/// Rasterizes catalog tiles to PNGs. The shell script compresses stills and builds GIFs.
@MainActor
enum DocsGalleryRenderer {
    /// Picks a writable directory. xcodebuild strips the `TEST_RUNNER_` prefix,
    /// so both the prefixed and stripped names are accepted.
    static func resolveOutputDirectory() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        var candidates: [URL] = []
        for key in ["TEST_RUNNER_DOCS_OUTPUT", "DOCS_OUTPUT"] {
            if let path = environment[key], !path.isEmpty {
                candidates.append(URL(fileURLWithPath: path, isDirectory: true))
            }
        }
        if let root = repositoryRoot() {
            candidates.append(root.appending(path: "build/docs-render", directoryHint: .isDirectory))
        }
        candidates.append(
            FileManager.default.temporaryDirectory
                .appending(path: "roughswiftui-docs-gallery", directoryHint: .isDirectory)
        )

        for candidate in candidates {
            if probe(candidate) {
                return candidate
            }
        }
        throw DocsGalleryError.outputNotWritable
    }

    /// Renders every catalog entry and writes `manifest.json` in `directory`.
    static func renderCatalog(to directory: URL) throws {
        var entries: [DocsManifest.Example] = []
        for example in DocExampleCatalog.examples {
            entries.append(try render(example, to: directory))
        }
        let manifest = DocsManifest(examples: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        let url = directory.appending(path: "manifest.json")
        try data.write(to: url, options: .atomic)
        let note = "DOC_RENDER_OUTPUT=\(directory.path)"
        NSLog("%@", note)
        if let bytes = "\(note)\n".data(using: .utf8) {
            FileHandle.standardError.write(bytes)
        }
    }

    private static func render(_ example: DocExample, to directory: URL) throws -> DocsManifest.Example {
        guard example.view().options.seed != nil else {
            throw DocsGalleryError.missingSeed(example.id)
        }

        switch example.kind {
        case .still:
            let image = try renderImage(example.view(), id: example.id)
            try writePNG(image, to: directory.appending(path: example.outputRelativePath))
            return entry(for: example, kind: "still", framesDirectory: nil)
        case let .gif(frameCount, fps):
            guard let animation = example.animation, animation.seed != nil else {
                throw DocsGalleryError.missingAnimation(example.id)
            }
            var encodedFrames: [Data] = []
            for index in 0..<frameCount {
                let frame = AnimatedRoughView(config: animation, roughView: example.view())
                    .pinnedFrame(index)
                let image = try renderImage(frame, id: "\(example.id) frame \(index)")
                let name = frameFileName(index: index)
                let relative = "\(example.framesDirectoryRelativePath)/\(name)"
                let url = directory.appending(path: relative)
                try writePNG(image, to: url)
                if let data = try? Data(contentsOf: url) {
                    encodedFrames.append(data)
                }
            }
            if encodedFrames.count >= 2, encodedFrames[0] == encodedFrames[1] {
                throw DocsGalleryError.identicalGIFFrames(example.id)
            }
            return entry(
                for: example,
                kind: "gif",
                framesDirectory: example.framesDirectoryRelativePath,
                fps: fps,
                frameCount: frameCount
            )
        }
    }

    private static func entry(
        for example: DocExample,
        kind: String,
        framesDirectory: String?,
        fps: Int? = nil,
        frameCount: Int? = nil
    ) -> DocsManifest.Example {
        DocsManifest.Example(
            id: example.id,
            section: example.section,
            sectionSlug: example.sectionSlug,
            title: example.title,
            description: example.description,
            snippet: example.snippet,
            kind: kind,
            fps: fps,
            frameCount: frameCount,
            framesDirectory: framesDirectory,
            output: example.outputRelativePath
        )
    }

    private static func renderImage<Content: View>(_ content: Content, id: String) throws -> UIImage {
        let tile = DocExampleTile(content: content)
        let renderer = ImageRenderer(content: tile)
        renderer.scale = DocExampleCatalog.renderScale
        renderer.proposedSize = ProposedViewSize(
            width: DocExampleCatalog.tileSide,
            height: DocExampleCatalog.tileSide
        )
        renderer.isOpaque = true
        guard let image = renderer.uiImage, let cgImage = image.cgImage else {
            throw DocsGalleryError.imageRenderFailed(id)
        }
        let expected = Int(DocExampleCatalog.tileSide * DocExampleCatalog.renderScale)
        guard cgImage.width == expected, cgImage.height == expected else {
            throw DocsGalleryError.unexpectedPixelSize(id, cgImage.width, cgImage.height)
        }
        guard distinctSampleCount(in: cgImage) >= 8 else {
            throw DocsGalleryError.blankImage(id)
        }
        return image
    }

    /// Counts distinct colors on a coarse grid. A paper-only tile stays at 1.
    private static func distinctSampleCount(in image: CGImage) -> Int {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let drew = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return 0 }

        var colors = Set<UInt32>()
        let step = 8
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let offset = y * bytesPerRow + x * 4
                let pixel = UInt32(pixels[offset]) << 24
                    | UInt32(pixels[offset + 1]) << 16
                    | UInt32(pixels[offset + 2]) << 8
                    | UInt32(pixels[offset + 3])
                colors.insert(pixel)
                x += step
            }
            y += step
        }
        return colors.count
    }

    private static func writePNG(_ image: UIImage, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = image.pngData() else {
            throw DocsGalleryError.pngEncodingFailed(url.lastPathComponent)
        }
        try data.write(to: url, options: .atomic)
    }

    private static func frameFileName(index: Int) -> String {
        let digits = String(index)
        let padding = String(repeating: "0", count: max(0, 2 - digits.count))
        return "frame-\(padding)\(digits).png"
    }

    private static func probe(_ url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let marker = url.appending(path: ".write-probe")
            try Data("ok".utf8).write(to: marker, options: .atomic)
            try FileManager.default.removeItem(at: marker)
            return true
        } catch {
            return false
        }
    }

    /// Walks up from this source file to the package root when the simulator can see it.
    private static func repositoryRoot() -> URL? {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let manifest = url.appending(path: "Package.swift")
            if FileManager.default.fileExists(atPath: manifest.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return nil
    }
}

/// Opaque light paper card. No dark-mode variant.
private struct DocExampleTile<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .padding(DocExampleCatalog.tileInset)
            .frame(width: DocExampleCatalog.tileSide, height: DocExampleCatalog.tileSide)
            .background(DocExampleCatalog.paper)
            .environment(\.colorScheme, .light)
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
    }
}
