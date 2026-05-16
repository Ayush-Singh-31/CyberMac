import Foundation

public enum CyberpunkXBMBlockDecoderError: Error, CustomStringConvertible {
    case payloadTooSmall(expected: Int, actual: Int, format: String)
    case invalidDimensions(width: Int, height: Int)

    public var description: String {
        switch self {
        case .payloadTooSmall(let expected, let actual, let format):
            return "Payload too small for \(format): expected at least \(expected) bytes, got \(actual)."
        case .invalidDimensions(let width, let height):
            return "Invalid texture dimensions: \(width)x\(height)."
        }
    }
}

/// Shared 5/6-bit RGB565 expansion used by BC1/BC2/BC3 colour blocks.
enum CyberpunkXBMRGB565 {
    @inline(__always)
    static func decode(_ value: UInt16) -> (r: UInt8, g: UInt8, b: UInt8) {
        let r5 = UInt32((value >> 11) & 0x1F)
        let g6 = UInt32((value >> 5) & 0x3F)
        let b5 = UInt32(value & 0x1F)
        let r = (r5 << 3) | (r5 >> 2)
        let g = (g6 << 2) | (g6 >> 4)
        let b = (b5 << 3) | (b5 >> 2)
        return (UInt8(r), UInt8(g), UInt8(b))
    }
}

public enum CyberpunkXBMBC1Decoder {
    public static let blockByteSize = 8

    public static func decode(blockData: Data, width: Int, height: Int) throws -> Data {
        guard width > 0, height > 0 else { throw CyberpunkXBMBlockDecoderError.invalidDimensions(width: width, height: height) }
        let blocksWide = (width + 3) / 4
        let blocksHigh = (height + 3) / 4
        let expected = blocksWide * blocksHigh * blockByteSize
        guard blockData.count >= expected else {
            throw CyberpunkXBMBlockDecoderError.payloadTooSmall(expected: expected, actual: blockData.count, format: "BC1")
        }

        var rgba = Data(count: width * height * 4)
        rgba.withUnsafeMutableBytes { rgbaPointer in
            let rgbaBuffer = rgbaPointer.bindMemory(to: UInt8.self)
            blockData.withUnsafeBytes { dataPointer in
                let bytes = dataPointer.bindMemory(to: UInt8.self)
                for by in 0..<blocksHigh {
                    for bx in 0..<blocksWide {
                        let blockOffset = (by * blocksWide + bx) * blockByteSize
                        decodeBlock(
                            bytes: bytes,
                            blockOffset: blockOffset,
                            blockX: bx * 4,
                            blockY: by * 4,
                            width: width,
                            height: height,
                            rgba: rgbaBuffer
                        )
                    }
                }
            }
        }
        return rgba
    }

    private static func decodeBlock(
        bytes: UnsafeBufferPointer<UInt8>,
        blockOffset: Int,
        blockX: Int,
        blockY: Int,
        width: Int,
        height: Int,
        rgba: UnsafeMutableBufferPointer<UInt8>
    ) {
        let c0 = UInt16(bytes[blockOffset]) | (UInt16(bytes[blockOffset + 1]) << 8)
        let c1 = UInt16(bytes[blockOffset + 2]) | (UInt16(bytes[blockOffset + 3]) << 8)
        let p0 = CyberpunkXBMRGB565.decode(c0)
        let p1 = CyberpunkXBMRGB565.decode(c1)
        var palette: [(UInt8, UInt8, UInt8, UInt8)] = [
            (p0.r, p0.g, p0.b, 255),
            (p1.r, p1.g, p1.b, 255),
            (0, 0, 0, 255),
            (0, 0, 0, 255)
        ]
        if c0 > c1 {
            palette[2] = (
                UInt8((UInt32(p0.r) * 2 + UInt32(p1.r)) / 3),
                UInt8((UInt32(p0.g) * 2 + UInt32(p1.g)) / 3),
                UInt8((UInt32(p0.b) * 2 + UInt32(p1.b)) / 3),
                255
            )
            palette[3] = (
                UInt8((UInt32(p0.r) + UInt32(p1.r) * 2) / 3),
                UInt8((UInt32(p0.g) + UInt32(p1.g) * 2) / 3),
                UInt8((UInt32(p0.b) + UInt32(p1.b) * 2) / 3),
                255
            )
        } else {
            palette[2] = (
                UInt8((UInt32(p0.r) + UInt32(p1.r)) / 2),
                UInt8((UInt32(p0.g) + UInt32(p1.g)) / 2),
                UInt8((UInt32(p0.b) + UInt32(p1.b)) / 2),
                255
            )
            palette[3] = (0, 0, 0, 0)
        }
        let indexBits = UInt32(bytes[blockOffset + 4])
            | (UInt32(bytes[blockOffset + 5]) << 8)
            | (UInt32(bytes[blockOffset + 6]) << 16)
            | (UInt32(bytes[blockOffset + 7]) << 24)

        for py in 0..<4 {
            for px in 0..<4 {
                let x = blockX + px
                let y = blockY + py
                if x >= width || y >= height { continue }
                let shift = UInt32((py * 4 + px) * 2)
                let idx = Int((indexBits >> shift) & 0x3)
                let pixel = palette[idx]
                let dst = (y * width + x) * 4
                rgba[dst] = pixel.0
                rgba[dst + 1] = pixel.1
                rgba[dst + 2] = pixel.2
                rgba[dst + 3] = pixel.3
            }
        }
    }
}

public enum CyberpunkXBMBC3Decoder {
    public static let blockByteSize = 16

    public static func decode(blockData: Data, width: Int, height: Int) throws -> Data {
        guard width > 0, height > 0 else { throw CyberpunkXBMBlockDecoderError.invalidDimensions(width: width, height: height) }
        let blocksWide = (width + 3) / 4
        let blocksHigh = (height + 3) / 4
        let expected = blocksWide * blocksHigh * blockByteSize
        guard blockData.count >= expected else {
            throw CyberpunkXBMBlockDecoderError.payloadTooSmall(expected: expected, actual: blockData.count, format: "BC3")
        }

        var rgba = Data(count: width * height * 4)
        rgba.withUnsafeMutableBytes { rgbaPointer in
            let rgbaBuffer = rgbaPointer.bindMemory(to: UInt8.self)
            blockData.withUnsafeBytes { dataPointer in
                let bytes = dataPointer.bindMemory(to: UInt8.self)
                for by in 0..<blocksHigh {
                    for bx in 0..<blocksWide {
                        let blockOffset = (by * blocksWide + bx) * blockByteSize
                        decodeBlock(
                            bytes: bytes,
                            blockOffset: blockOffset,
                            blockX: bx * 4,
                            blockY: by * 4,
                            width: width,
                            height: height,
                            rgba: rgbaBuffer
                        )
                    }
                }
            }
        }
        return rgba
    }

    private static func decodeBlock(
        bytes: UnsafeBufferPointer<UInt8>,
        blockOffset: Int,
        blockX: Int,
        blockY: Int,
        width: Int,
        height: Int,
        rgba: UnsafeMutableBufferPointer<UInt8>
    ) {
        // Alpha block: bytes 0..7
        let a0 = bytes[blockOffset]
        let a1 = bytes[blockOffset + 1]
        var alphas: [UInt8] = [a0, a1, 0, 0, 0, 0, 0, 0]
        if a0 > a1 {
            alphas[2] = UInt8((UInt32(a0) * 6 + UInt32(a1) * 1) / 7)
            alphas[3] = UInt8((UInt32(a0) * 5 + UInt32(a1) * 2) / 7)
            alphas[4] = UInt8((UInt32(a0) * 4 + UInt32(a1) * 3) / 7)
            alphas[5] = UInt8((UInt32(a0) * 3 + UInt32(a1) * 4) / 7)
            alphas[6] = UInt8((UInt32(a0) * 2 + UInt32(a1) * 5) / 7)
            alphas[7] = UInt8((UInt32(a0) * 1 + UInt32(a1) * 6) / 7)
        } else {
            alphas[2] = UInt8((UInt32(a0) * 4 + UInt32(a1) * 1) / 5)
            alphas[3] = UInt8((UInt32(a0) * 3 + UInt32(a1) * 2) / 5)
            alphas[4] = UInt8((UInt32(a0) * 2 + UInt32(a1) * 3) / 5)
            alphas[5] = UInt8((UInt32(a0) * 1 + UInt32(a1) * 4) / 5)
            alphas[6] = 0
            alphas[7] = 255
        }
        // 48 bits of 3-bit indices packed across bytes 2..7 (LE).
        let alphaIndexBits: UInt64 =
            UInt64(bytes[blockOffset + 2])
            | (UInt64(bytes[blockOffset + 3]) << 8)
            | (UInt64(bytes[blockOffset + 4]) << 16)
            | (UInt64(bytes[blockOffset + 5]) << 24)
            | (UInt64(bytes[blockOffset + 6]) << 32)
            | (UInt64(bytes[blockOffset + 7]) << 40)

        // Colour block: bytes 8..15 (BC3 always uses 4-colour interpolation).
        let c0 = UInt16(bytes[blockOffset + 8]) | (UInt16(bytes[blockOffset + 9]) << 8)
        let c1 = UInt16(bytes[blockOffset + 10]) | (UInt16(bytes[blockOffset + 11]) << 8)
        let p0 = CyberpunkXBMRGB565.decode(c0)
        let p1 = CyberpunkXBMRGB565.decode(c1)
        let c2: (UInt8, UInt8, UInt8) = (
            UInt8((UInt32(p0.r) * 2 + UInt32(p1.r)) / 3),
            UInt8((UInt32(p0.g) * 2 + UInt32(p1.g)) / 3),
            UInt8((UInt32(p0.b) * 2 + UInt32(p1.b)) / 3)
        )
        let c3: (UInt8, UInt8, UInt8) = (
            UInt8((UInt32(p0.r) + UInt32(p1.r) * 2) / 3),
            UInt8((UInt32(p0.g) + UInt32(p1.g) * 2) / 3),
            UInt8((UInt32(p0.b) + UInt32(p1.b) * 2) / 3)
        )
        let palette: [(UInt8, UInt8, UInt8)] = [
            (p0.r, p0.g, p0.b),
            (p1.r, p1.g, p1.b),
            c2,
            c3
        ]
        let colorIndexBits = UInt32(bytes[blockOffset + 12])
            | (UInt32(bytes[blockOffset + 13]) << 8)
            | (UInt32(bytes[blockOffset + 14]) << 16)
            | (UInt32(bytes[blockOffset + 15]) << 24)

        for py in 0..<4 {
            for px in 0..<4 {
                let x = blockX + px
                let y = blockY + py
                if x >= width || y >= height { continue }
                let alphaShift = UInt64((py * 4 + px) * 3)
                let alphaIdx = Int((alphaIndexBits >> alphaShift) & 0x7)
                let colorShift = UInt32((py * 4 + px) * 2)
                let colorIdx = Int((colorIndexBits >> colorShift) & 0x3)
                let colour = palette[colorIdx]
                let dst = (y * width + x) * 4
                rgba[dst] = colour.0
                rgba[dst + 1] = colour.1
                rgba[dst + 2] = colour.2
                rgba[dst + 3] = alphas[alphaIdx]
            }
        }
    }
}
