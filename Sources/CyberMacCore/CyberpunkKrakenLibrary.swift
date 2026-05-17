import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Thin wrapper around the libkraken / libooz dynamic library shipped with WolvenKit.
///
/// The library exports two C symbols:
///   int Kraken_Decompress(const uint8_t *src, size_t src_len, uint8_t *dst, size_t dst_len);
///   int Kraken_Compress  (...)
///
/// We dlopen the dylib lazily and dlsym `Kraken_Decompress`. Only decompression
/// is wired up — that's all CyberMac needs for .xbm payloads wrapped in KARK.
public final class CyberpunkKrakenLibrary: @unchecked Sendable {
    public typealias KrakenDecompressFn = @convention(c) (
        UnsafePointer<UInt8>?,           // src
        Int,                              // src_len (size_t)
        UnsafeMutablePointer<UInt8>?,    // dst
        Int                               // dst_len (size_t)
    ) -> Int32

    public static let decompressSymbolName = "Kraken_Decompress"

    public let libraryPath: String
    public let decompressFunction: KrakenDecompressFn

    private let handle: UnsafeMutableRawPointer

    public init(libraryPath: String) throws {
        let resolved = (libraryPath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: resolved) else {
            throw CyberMacError.notFound("Kraken library not found at \(resolved).")
        }

        dlerror() // clear any previous error
        guard let opened = dlopen(resolved, RTLD_LAZY | RTLD_LOCAL) else {
            let message = CyberpunkKrakenLibrary.lastDLError() ?? "<unknown>"
            throw CyberMacError.fileSystem("Failed to dlopen Kraken library at \(resolved): \(message)")
        }

        dlerror()
        guard let symbol = dlsym(opened, CyberpunkKrakenLibrary.decompressSymbolName) else {
            let message = CyberpunkKrakenLibrary.lastDLError() ?? "<unknown>"
            dlclose(opened)
            throw CyberMacError.fileSystem(
                "Kraken library at \(resolved) does not export \(CyberpunkKrakenLibrary.decompressSymbolName): \(message)"
            )
        }

        self.libraryPath = resolved
        self.handle = opened
        self.decompressFunction = unsafeBitCast(symbol, to: KrakenDecompressFn.self)
    }

    deinit {
        dlclose(handle)
    }

    /// Calls `Kraken_Decompress(src, src_len, dst, dst_len)`.
    ///
    /// Returns the decompressor's reported number of bytes written.
    /// Negative or zero return values indicate failure.
    public func decompress(source: Data, destinationCapacity: Int) throws -> Data {
        guard destinationCapacity > 0 else {
            throw CyberMacError.invalidInput("Kraken_Decompress destination capacity must be > 0.")
        }
        guard !source.isEmpty else {
            throw CyberMacError.invalidInput("Kraken_Decompress source buffer is empty.")
        }

        var destination = [UInt8](repeating: 0, count: destinationCapacity)
        let written: Int32 = source.withUnsafeBytes { srcRaw -> Int32 in
            let srcPtr = srcRaw.bindMemory(to: UInt8.self).baseAddress
            return destination.withUnsafeMutableBufferPointer { dstBuf -> Int32 in
                return decompressFunction(srcPtr, source.count, dstBuf.baseAddress, destinationCapacity)
            }
        }

        guard written > 0 else {
            throw CyberMacError.fileSystem(
                "Kraken_Decompress failed (returned \(written)) for src=\(source.count) dst-capacity=\(destinationCapacity)."
            )
        }
        let count = Int(written)
        guard count <= destinationCapacity else {
            throw CyberMacError.fileSystem(
                "Kraken_Decompress reported \(count) bytes written but only \(destinationCapacity) were allocated."
            )
        }
        return Data(destination.prefix(count))
    }

    private static func lastDLError() -> String? {
        guard let raw = dlerror() else { return nil }
        return String(cString: raw)
    }
}
