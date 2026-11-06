import XCTest

/// Renders the documentation gallery only when `TEST_RUNNER_RENDER_DOCS=1`.
///
/// xcodebuild forwards that argument to the test process. Some Xcode versions
/// strip the `TEST_RUNNER_` prefix, so `RENDER_DOCS=1` is accepted as well.
/// A normal suite leaves both unset and this test is skipped.
@MainActor
final class DocsGalleryTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(Self.isEnabled, Self.skipMessage)
    }

    func testRenderGallery() throws {
        let directory = try DocsGalleryRenderer.resolveOutputDirectory()
        try DocsGalleryRenderer.renderCatalog(to: directory)
        let manifest = directory.appending(path: "manifest.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.path))
    }

    private static var isEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["TEST_RUNNER_RENDER_DOCS"] == "1"
            || environment["RENDER_DOCS"] == "1"
    }

    private static var skipMessage: String {
        let environment = ProcessInfo.processInfo.environment
        let relevant = environment.keys
            .filter { $0.contains("RENDER_DOCS") || $0.contains("DOCS_OUTPUT") }
            .sorted()
            .map { "\($0)=\(environment[$0] ?? "")" }
            .joined(separator: ", ")
        let seen = relevant.isEmpty ? "none" : relevant
        return "Docs gallery rendering is opt-in. Set TEST_RUNNER_RENDER_DOCS=1. Seen: \(seen)"
    }
}
