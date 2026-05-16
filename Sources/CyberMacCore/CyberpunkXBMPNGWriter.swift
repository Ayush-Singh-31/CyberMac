import Foundation
import CoreGraphics
import ImageIO

public enum CyberpunkXBMPNGWriterError: Error, CustomStringConvertible {
    case bufferSizeMismatch(expected: Int, actual: Int)
    case cgImageCreationFailed
    case cgDestinationCreationFailed(url: URL)
    case cgDestinationFinaliseFailed(url: URL)

    public var description: String {
        switch self {
        case .bufferSizeMismatch(let expected, let actual):
            return "RGBA buffer size mismatch: expected \(expected) bytes, got \(actual)."
        case .cgImageCreationFailed:
            return "Failed to create CGImage from RGBA buffer."
        case .cgDestinationCreationFailed(let url):
            return "Failed to create PNG destination at \(url.path)."
        case .cgDestinationFinaliseFailed(let url):
            return "Failed to finalise PNG destination at \(url.path)."
        }
    }
}

public enum CyberpunkXBMPNGWriter {
    /// Writes an RGBA8 buffer (row-major, no row padding) as a PNG file.
    public static func writePNG(rgba: Data, width: Int, height: Int, to url: URL) throws {
        let expected = width * height * 4
        guard rgba.count == expected else {
            throw CyberpunkXBMPNGWriterError.bufferSizeMismatch(expected: expected, actual: rgba.count)
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let colourSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
        guard let provider = CGDataProvider(data: rgba as CFData) else {
            throw CyberpunkXBMPNGWriterError.cgImageCreationFailed
        }
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colourSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw CyberpunkXBMPNGWriterError.cgImageCreationFailed
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw CyberpunkXBMPNGWriterError.cgDestinationCreationFailed(url: url)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CyberpunkXBMPNGWriterError.cgDestinationFinaliseFailed(url: url)
        }
    }
}
