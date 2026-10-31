import CoreGraphics
import Foundation

/// Reads the named path groups out of the Affinity duck SVG and drops the bitmap uses.
final class CrayonDuckSVG: NSObject, XMLParserDelegate {
    struct Shape {
        var name: String
        var d: String
        var ctm: CGAffineTransform
    }

    private struct Frame {
        var ctm: CGAffineTransform
        var pushedName: Bool
    }

    private(set) var shapes: [Shape] = []
    private(set) var droppedImages: [String] = []
    private(set) var droppedUses: [String] = []
    private var frames: [Frame] = [Frame(ctm: .identity, pushedName: false)]
    private var names: [String] = []

    /// Parses `svg`, stripping a DOCTYPE so the parser does not fetch the DTD.
    static func parse(_ svg: String) throws -> CrayonDuckSVG {
        var source = svg
        if let doctype = source.range(of: "<!DOCTYPE"),
           let end = source.range(of: ">", range: doctype.lowerBound..<source.endIndex) {
            source.removeSubrange(doctype.lowerBound..<end.upperBound)
        }
        let collector = CrayonDuckSVG()
        let parser = XMLParser(data: Data(source.utf8))
        parser.shouldResolveExternalEntities = false
        parser.delegate = collector
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return collector
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String] = [:]
    ) {
        let parent = frames.last?.ctm ?? .identity
        let local = Self.matrix(attributes["transform"]) ?? .identity
        let ctm = local.concatenating(parent)
        let name = attributes["id"]
        frames.append(Frame(ctm: ctm, pushedName: name != nil))
        if let name {
            names.append(name)
        }

        switch elementName {
        case "path":
            shapes.append(Shape(
                name: name ?? names.last ?? "path-\(shapes.count + 1)",
                d: attributes["d"] ?? "",
                ctm: ctm
            ))
        case "image":
            droppedImages.append(name ?? "image")
        case "use":
            let href = attributes["xlink:href"] ?? attributes["href"] ?? "?"
            droppedUses.append(href)
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let frame = frames.removeLast()
        if frame.pushedName {
            names.removeLast()
        }
    }

    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
        Data()
    }

    /// SVG `matrix(a b c d e f)` matches `CGAffineTransform` component order.
    private static func matrix(_ value: String?) -> CGAffineTransform? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("matrix("), trimmed.hasSuffix(")") else { return nil }
        let inner = trimmed.dropFirst("matrix(".count).dropLast()
        let parts = inner.split { $0 == "," || $0.isWhitespace }.compactMap { Double($0) }
        guard parts.count == 6 else { return nil }
        return CGAffineTransform(
            a: parts[0],
            b: parts[1],
            c: parts[2],
            d: parts[3],
            tx: parts[4],
            ty: parts[5]
        )
    }
}
