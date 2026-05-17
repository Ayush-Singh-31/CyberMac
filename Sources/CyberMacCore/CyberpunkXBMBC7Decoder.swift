import Foundation
import CyberMacBC7Decoder

/// Decodes a BC7 (BPTC) compressed mip into an RGBA8 buffer by calling the
/// vendored `bcdec.h` C decoder one 4x4 block at a time. Edge blocks for
/// non-multiple-of-4 dimensions decode into a scratch 4x4 buffer first and
/// only the in-bounds rows/columns are copied into the destination, mirroring
/// the behavior of `CyberpunkXBMBC1Decoder` / `CyberpunkXBMBC3Decoder`.
public enum CyberpunkXBMBC7Decoder {
    public static let blockByteSize = Int(CYBERMAC_BC7_BLOCK_BYTE_SIZE)
    private static let blockPixelDimension = 4
    private static let bytesPerPixel = 4

    public static func decode(blockData: Data, width: Int, height: Int) throws -> Data {
        guard width > 0, height > 0 else {
            throw CyberpunkXBMBlockDecoderError.invalidDimensions(width: width, height: height)
        }
        let blocksWide = (width + blockPixelDimension - 1) / blockPixelDimension
        let blocksHigh = (height + blockPixelDimension - 1) / blockPixelDimension
        let expected = blocksWide * blocksHigh * blockByteSize
        guard blockData.count >= expected else {
            throw CyberpunkXBMBlockDecoderError.payloadTooSmall(
                expected: expected,
                actual: blockData.count,
                format: "BC7"
            )
        }

        let outputCount = width * height * bytesPerPixel
        var rgba = Data(count: outputCount)
        let blockRowStride = blockPixelDimension * bytesPerPixel // 16 bytes per scratch row
        let destinationPitch = Int32(width * bytesPerPixel)
        let edgeColumns = width % blockPixelDimension == 0 ? blockPixelDimension : width % blockPixelDimension
        let edgeRows = height % blockPixelDimension == 0 ? blockPixelDimension : height % blockPixelDimension

        rgba.withUnsafeMutableBytes { rgbaRaw in
            guard let dstBase = rgbaRaw.baseAddress else { return }
            blockData.withUnsafeBytes { srcRaw in
                guard let srcBase = srcRaw.baseAddress else { return }
                var scratch = [UInt8](repeating: 0, count: blockRowStride * blockPixelDimension)
                scratch.withUnsafeMutableBufferPointer { scratchBuffer in
                    guard let scratchBase = scratchBuffer.baseAddress else { return }
                    for by in 0..<blocksHigh {
                        let blockY = by * blockPixelDimension
                        let pixelsInBlockY = (by == blocksHigh - 1) ? edgeRows : blockPixelDimension
                        for bx in 0..<blocksWide {
                            let blockX = bx * blockPixelDimension
                            let pixelsInBlockX = (bx == blocksWide - 1) ? edgeColumns : blockPixelDimension
                            let blockOffset = (by * blocksWide + bx) * blockByteSize
                            let srcBlock = srcBase.advanced(by: blockOffset)

                            if pixelsInBlockX == blockPixelDimension && pixelsInBlockY == blockPixelDimension {
                                // Full 4x4 block: write straight into the destination at the correct pitch.
                                let dstPixelOffset = (blockY * width + blockX) * bytesPerPixel
                                let dstPtr = dstBase.advanced(by: dstPixelOffset)
                                cybermac_bc7_decode_block(srcBlock, dstPtr, destinationPitch)
                            } else {
                                // Edge block: decode into 4x4 scratch then copy the in-bounds region only.
                                cybermac_bc7_decode_block(srcBlock, UnsafeMutableRawPointer(scratchBase), Int32(blockRowStride))
                                for row in 0..<pixelsInBlockY {
                                    let dstPixelOffset = ((blockY + row) * width + blockX) * bytesPerPixel
                                    let dstPtr = dstBase.advanced(by: dstPixelOffset)
                                    let srcPtr = UnsafeRawPointer(scratchBase.advanced(by: row * blockRowStride))
                                    memcpy(dstPtr, srcPtr, pixelsInBlockX * bytesPerPixel)
                                }
                            }
                        }
                    }
                }
            }
        }

        return rgba
    }
}
