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

    // MARK: - BC7

    func testBC7DecodesSingleBlockToCorrectByteCount() throws {
        // 16-byte input is one BC7 block. We don't assert pixel values here
        // (the bcdec implementation is exercised by integration tests against
        // real .xbm fixtures); we just verify the wrapper produces a full
        // 4×4 RGBA8 buffer and the call doesn't fail.
        let block = Data(repeating: 0x40, count: CyberpunkXBMBC7Decoder.blockByteSize)
        let rgba = try CyberpunkXBMBC7Decoder.decode(blockData: block, width: 4, height: 4)
        XCTAssertEqual(rgba.count, 4 * 4 * 4)
    }

    func testBC7ProducesDifferentOutputsForDifferentInputs() throws {
        // Sanity check: two distinct compressed blocks should not decode to
        // the same RGBA buffer. Catches the "function silently writes zeros"
        // regression where the wrapper might not be invoking the decoder.
        let a = Data(repeating: 0x40, count: CyberpunkXBMBC7Decoder.blockByteSize)
        var bBytes = [UInt8](repeating: 0x40, count: CyberpunkXBMBC7Decoder.blockByteSize)
        bBytes[1] = 0xA5
        bBytes[2] = 0x5A
        let b = Data(bBytes)
        let rgbaA = try CyberpunkXBMBC7Decoder.decode(blockData: a, width: 4, height: 4)
        let rgbaB = try CyberpunkXBMBC7Decoder.decode(blockData: b, width: 4, height: 4)
        XCTAssertNotEqual(rgbaA, rgbaB)
    }

    func testBC7HandlesEdgeBlockSmallerThan4x4() throws {
        // 3×2 destination should still call into bcdec but only copy the
        // in-bounds region from the 4×4 scratch buffer.
        let block = Data(repeating: 0x40, count: CyberpunkXBMBC7Decoder.blockByteSize)
        let rgba = try CyberpunkXBMBC7Decoder.decode(blockData: block, width: 3, height: 2)
        XCTAssertEqual(rgba.count, 3 * 2 * 4)
    }

    func testBC7RejectsTruncatedPayload() {
        XCTAssertThrowsError(try CyberpunkXBMBC7Decoder.decode(blockData: Data([0x00, 0x00]), width: 4, height: 4)) { error in
            guard case CyberpunkXBMBlockDecoderError.payloadTooSmall(_, _, let format) = error else {
                XCTFail("Expected payloadTooSmall, got \(error)")
                return
            }
            XCTAssertEqual(format, "BC7")
        }
    }

    func testBC7RejectsZeroDimensions() {
        let block = Data(repeating: 0x00, count: CyberpunkXBMBC7Decoder.blockByteSize)
        XCTAssertThrowsError(try CyberpunkXBMBC7Decoder.decode(blockData: block, width: 0, height: 4))
        XCTAssertThrowsError(try CyberpunkXBMBC7Decoder.decode(blockData: block, width: 4, height: 0))
    }
}
