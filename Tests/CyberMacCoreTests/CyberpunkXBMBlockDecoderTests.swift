import Foundation
import XCTest
@testable import CyberMacCore

final class CyberpunkXBMBlockDecoderTests: XCTestCase {
    // MARK: - BC1

    func testBC1SolidRedBlockDecodesToOpaqueRed() throws {
        // c0 = 0xF800 (pure red RGB565), c1 = 0x0000, indices all-zero → all pixels = c0.
        let block: [UInt8] = [
            0x00, 0xF8, // c0 little-endian
            0x00, 0x00, // c1
            0x00, 0x00, 0x00, 0x00 // 16 × 2-bit indices all 0
        ]
        let rgba = try CyberpunkXBMBC1Decoder.decode(blockData: Data(block), width: 4, height: 4)
        XCTAssertEqual(rgba.count, 4 * 4 * 4)
        for i in 0..<16 {
            XCTAssertEqual(rgba[i * 4], 255)
            XCTAssertEqual(rgba[i * 4 + 1], 0)
            XCTAssertEqual(rgba[i * 4 + 2], 0)
            XCTAssertEqual(rgba[i * 4 + 3], 255)
        }
    }

    func testBC1PunchThroughAlphaProducesTransparentPixel() throws {
        // c0 == c1 == 0 → 3-colour mode; index 3 → transparent black.
        // Bottom-right pixel index = 3, others = 0.
        let indices: UInt32 = UInt32(3) << ((15) * 2) // pixel (3,3) -> shift = 30
        var blockBytes: [UInt8] = [
            0x00, 0x00, // c0
            0x00, 0x00  // c1 (c0 <= c1 → punch-through alpha mode)
        ]
        blockBytes.append(UInt8(indices & 0xFF))
        blockBytes.append(UInt8((indices >> 8) & 0xFF))
        blockBytes.append(UInt8((indices >> 16) & 0xFF))
        blockBytes.append(UInt8((indices >> 24) & 0xFF))
        let rgba = try CyberpunkXBMBC1Decoder.decode(blockData: Data(blockBytes), width: 4, height: 4)
        // Pixel (3,3) → alpha 0
        let i = (3 * 4 + 3) * 4
        XCTAssertEqual(rgba[i + 3], 0)
        // Pixel (0,0) uses c0 → opaque
        XCTAssertEqual(rgba[3], 255)
    }

    func testBC1RejectsTruncatedPayload() {
        XCTAssertThrowsError(try CyberpunkXBMBC1Decoder.decode(blockData: Data([0x00, 0x00]), width: 4, height: 4))
    }

    // MARK: - BC3

    func testBC3SolidOpaqueRedBlockDecodesCorrectly() throws {
        // Alpha: a0=255, a1=255, all indices 0 → all alpha 255.
        // Colour: c0=0xF800 (red), c1=0x0000, all colour indices 0 → all pixels c0.
        let block: [UInt8] = [
            0xFF, 0xFF,                         // a0, a1
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 48 bits of alpha indices
            0x00, 0xF8, 0x00, 0x00,             // c0 LE = 0xF800, c1 LE = 0x0000
            0x00, 0x00, 0x00, 0x00              // 32 bits of colour indices all 0
        ]
        let rgba = try CyberpunkXBMBC3Decoder.decode(blockData: Data(block), width: 4, height: 4)
        XCTAssertEqual(rgba.count, 4 * 4 * 4)
        for i in 0..<16 {
            XCTAssertEqual(rgba[i * 4], 255, "Pixel \(i) R")
            XCTAssertEqual(rgba[i * 4 + 1], 0, "Pixel \(i) G")
            XCTAssertEqual(rgba[i * 4 + 2], 0, "Pixel \(i) B")
            XCTAssertEqual(rgba[i * 4 + 3], 255, "Pixel \(i) A")
        }
    }

    func testBC3AlphaGradientIs7StepWhenA0GreaterThanA1() throws {
        // a0=255, a1=0, palette interpolation 7-step.
        // Use 3-bit alpha indices in bytes 2..7. Set pixel 0 → index 1 (=a1=0), pixel 1 → index 2.
        // Pack: index[0]=1, others=0 → first 3 bits of byte 2 = 001 = 0x01.
        var block: [UInt8] = [0xFF, 0x00,
                              0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
                              0x00, 0xF8, 0x00, 0x00,
                              0x00, 0x00, 0x00, 0x00]
        _ = block // (silence warning if unused later)
        let rgba = try CyberpunkXBMBC3Decoder.decode(blockData: Data(block), width: 4, height: 4)
        // Pixel (0,0) alpha index = 1 → a1 = 0.
        XCTAssertEqual(rgba[3], 0)
        // Pixel (1,0) alpha index = 0 → a0 = 255.
        XCTAssertEqual(rgba[(0 * 4 + 1) * 4 + 3], 255)
    }

    func testBC3HandlesEdgeBlockSmallerThan4x4() throws {
        let block: [UInt8] = [
            0xFF, 0xFF,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0xF8, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00
        ]
        let rgba = try CyberpunkXBMBC3Decoder.decode(blockData: Data(block), width: 3, height: 2)
        XCTAssertEqual(rgba.count, 3 * 2 * 4)
        // Every emitted pixel should be opaque red.
        for i in 0..<6 {
            XCTAssertEqual(rgba[i * 4], 255)
            XCTAssertEqual(rgba[i * 4 + 1], 0)
            XCTAssertEqual(rgba[i * 4 + 2], 0)
            XCTAssertEqual(rgba[i * 4 + 3], 255)
        }
    }

    func testBC3RejectsTruncatedPayload() {
        XCTAssertThrowsError(try CyberpunkXBMBC3Decoder.decode(blockData: Data([0xFF, 0xFF]), width: 4, height: 4))
    }
}
