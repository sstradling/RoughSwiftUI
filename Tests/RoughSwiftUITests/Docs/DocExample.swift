import SwiftUI
@testable import RoughSwiftUI

/// One documentation tile in the examples gallery.
///
/// The snippet is the Swift shown beside the picture. `view` builds the same
/// drawing. Every example sets `Options.seed`, and GIFs also set
/// `AnimationConfig.seed`, so two renders of the catalog match.
struct DocExample {
    /// Still PNG, or a GIF assembled from pinned animation frames.
    enum Kind: Equatable {
        case still
        case gif(frameCount: Int, fps: Int)
    }

    /// File name, without an extension. Unique across the catalog.
    let id: String

    /// Heading used to group the gallery. Also the image folder name.
    let section: String

    /// Short title shown above the picture.
    let title: String

    /// One or two sentences shown under the title.
    let description: String

    /// SwiftUI source shown in the gallery. Keep it aligned with `view`.
    let snippet: String

    let kind: Kind

    /// Drawing rendered into the tile. GIFs animate this view.
    let view: () -> RoughView

    /// Required for `.gif` examples. `seed` must be set.
    let animation: AnimationConfig?

    /// Folder under `docs/images`.
    var sectionSlug: String {
        section.lowercased().replacing(" ", with: "-")
    }

    /// Relative path of the published image, from `docs/images`.
    var outputRelativePath: String {
        switch kind {
        case .still:
            return "\(sectionSlug)/\(id).png"
        case .gif:
            return "\(sectionSlug)/\(id).gif"
        }
    }

    /// Relative directory of raw GIF frames, from the render scratch folder.
    var framesDirectoryRelativePath: String {
        "\(sectionSlug)/\(id)-frames"
    }
}
