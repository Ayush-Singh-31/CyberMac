import Foundation
import XCTest
import ImageIO
@testable import CyberMacCore

final class CyberpunkXBMPNGWriterTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CyberMacCyberpunkXBMPNGWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testWritesReadablePNGFromTinyRGBABuffer() throws {
        let width = 4
        let height = 4
        var pixels = Data(count: width * height * 4)
        for i in 0..<(width * height) {
            pixels[i * 4]     = 255 // R
            pixels[i * 4 + 1] = 0   // G
            pixels[i * 4 + 2] = 0   // B
            pixels[i * 4 + 3] = 255 // A
        }

        let output = tempDir.appendingPathComponent("solid_red.png")
        try CyberpunkXBMPNGWriter.writePNG(rgba: pixels, width: width, height: height, to: output)

        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(source), 1)
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, width)
        XCTAssertEqual(image.height, height)
    }

    func testRejectsMismatchedBufferSize() {
        XCTAssertThrowsError(try CyberpunkXBMPNGWriter.writePNG(
            rgba: Data([0, 0, 0]),
            width: 4,
            height: 4,
            to: tempDir.appendingPathComponent("bad.png")
        ))
    }

    func testCreatesParentDirectory() throws {
        let nested = tempDir
            .appendingPathComponent("a", isDirectory: true)
            .appendingPathComponent("b", isDirectory: true)
            .appendingPathComponent("c.png")
        let pixels = Data(repeating: 128, count: 2 * 2 * 4)
        try CyberpunkXBMPNGWriter.writePNG(rgba: pixels, width: 2, height: 2, to: nested)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }
}
