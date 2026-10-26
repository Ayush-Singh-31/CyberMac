import Foundation
import XCTest
@testable import CyberMacCore

final class ClothingPreviewRendererTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("images"), withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testVerifiedPreviewIsMappedToItsSourceVariantWithoutEnablingInstallation() throws {
        let source = String(repeating: "a", count: 64), path = "Jinguji/Skirt/red.archive"
        let png = root.appendingPathComponent("images/\(source).png")
        try CyberpunkXBMPNGWriter.writePNG(rgba: Data(repeating: 180, count: 160*160*4), width: 160, height: 160, to: png)
        var progress = ClothingPreviewProgress(state: "finished", total: 1, completed: 1)
        progress.results = [.init(archivePath: path, status: "ready", sourceSHA256: source, preview: "images/\(source).png", previewSHA256: try PathSafety.sha256(url: png), error: nil)]
        try JSONEncoder().encode(progress).write(to: root.appendingPathComponent("progress.json"))
        let snapshot = try XCTUnwrap(session().snapshot())
        XCTAssertEqual(snapshot.images[path], png)
        XCTAssertEqual(snapshot.progress.readyCount, 1)
        let catalog = ClothingImportCatalog(contents: .init(archives: [.init(path: path, preparedPieces: [])]), wardrobe: nil).applying(snapshot)
        XCTAssertEqual(catalog.items.first?.previewURL, png)
        XCTAssertFalse(try XCTUnwrap(catalog.items.first).canSelect)
        XCTAssertTrue(catalog.availableItems.isEmpty)
    }

    func testCorruptPreviewCannotBeDisplayedAsACompletedImage() throws {
        let source = String(repeating: "a", count: 64), png = root.appendingPathComponent("images/\(source).png")
        try Data("not an image".utf8).write(to: png)
        var progress = ClothingPreviewProgress(state: "finished", total: 1, completed: 1)
        progress.results = [.init(archivePath: "garment.archive", status: "ready", sourceSHA256: source, preview: "images/\(source).png", previewSHA256: try PathSafety.sha256(url: png), error: nil)]
        try JSONEncoder().encode(progress).write(to: root.appendingPathComponent("progress.json"))
        XCTAssertThrowsError(try session().snapshot())
    }

    func testProgressCannotPointOutsideItsPreviewCache() throws {
        var progress = ClothingPreviewProgress(state: "finished", total: 1, completed: 1)
        progress.results = [.init(archivePath: "garment.archive", status: "ready", sourceSHA256: String(repeating:"a",count:64), preview: "../../outside.png", previewSHA256: String(repeating:"b",count:64), error: nil)]
        try JSONEncoder().encode(progress).write(to: root.appendingPathComponent("progress.json"))
        XCTAssertTrue(try XCTUnwrap(session().snapshot()).images.isEmpty)
    }

    func testCompletedCacheDoesNotLaunchAnExporterAgain() throws {
        let progress = ClothingPreviewProgress(state: "finished", total: 0)
        try JSONEncoder().encode(progress).write(to: root.appendingPathComponent("progress.json"))
        XCTAssertNoThrow(try session().run()) // The fixture's executable does not exist.
    }

    func testCancellationBeforeStartDoesNotLaunchTools() throws {
        let value = session(); value.cancel()
        XCTAssertNoThrow(try value.run())
    }

    private func session() -> ClothingPreviewProcess {
        ClothingPreviewProcess(output: root, python: root.appendingPathComponent("missing-python"), script: root.appendingPathComponent("missing-script"), request: root.appendingPathComponent("request.json"), force: false)
    }
}
