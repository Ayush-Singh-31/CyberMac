// RDAR layout and record-transplant approach informed by:
// JoshuSnuff/cp2077-macos-archive-loader and brunoformagio/cp2077-mac-archive-patcher.
// Copyright (c) 2026 JoshuSnuff and Bruno Formagio. MIT; see THIRD_PARTY_NOTICES.md.
// CyberMac uses an independent bounded reader and writes only a disposable copy.
import Foundation
import CryptoKit

struct NativeArchive: Sendable {
    struct Record: Sendable {
        let hash: UInt64
        let bytes: Data
        let segments: Range<Int>
        let dependencies: Range<Int>
    }
    struct Segment: Sendable {
        let offset: UInt64
        let compressedSize: UInt32
        let size: UInt32
    }
    let url: URL
    let header: Data
    let index: Data
    let records: [Record]
    let segments: [Segment]
    let dependencies: [UInt64]
    let actualSize: UInt64
    var indexFingerprint: String { PathSafety.sha256(data: header + index) }

    static func read(_ url: URL) throws -> NativeArchive {
        let size = try PathSafety.fileSize(url: url)
        guard size >= 52 else { throw invalid("Truncated archive header") }
        let header = try readBytes(url, offset: 0, count: 52)
        guard header.prefix(4) == Data("RDAR".utf8), try u32(header, 4) == 12 else {
            throw invalid("Only RDAR version 12 archives are supported")
        }
        let position = try u64(header, 8)
        let indexSize = UInt64(try u32(header, 16))
        guard position >= 52, position <= size, indexSize >= 28,
              indexSize <= 128 * 1024 * 1024, indexSize <= size - position else {
            throw invalid("Archive index lies outside the file or exceeds the 128 MB limit")
        }
        let index = try readBytes(url, offset: position, count: Int(indexSize))
        let recordCount = Int(try u32(index, 16))
        let segmentCount = Int(try u32(index, 20))
        let dependencyCount = Int(try u32(index, 24))
        let segmentOffset = 28 + recordCount * 56
        let dependencyOffset = segmentOffset + segmentCount * 16
        guard dependencyOffset + dependencyCount * 8 == index.count else {
            throw invalid("Archive table counts do not match its index length")
        }
        guard try u64(index, 8) == crc64(Data(index.dropFirst(16))) else {
            throw invalid("Archive index checksum does not match")
        }
        var segments: [Segment] = []
        segments.reserveCapacity(segmentCount)
        for i in 0..<segmentCount {
            let at = segmentOffset + i * 16
            let offset = try u64(index, at)
            let compressed = try u32(index, at + 8)
            guard offset >= 52, offset <= size, UInt64(compressed) <= size - offset else {
                throw invalid("Archive payload segment lies outside the file")
            }
            segments.append(Segment(offset: offset, compressedSize: compressed, size: try u32(index, at + 12)))
        }
        var records: [Record] = []
        records.reserveCapacity(recordCount)
        for i in 0..<recordCount {
            let at = 28 + i * 56
            let start = Int(try u32(index, at + 20)), end = Int(try u32(index, at + 24))
            let depStart = Int(try u32(index, at + 28)), depEnd = Int(try u32(index, at + 32))
            guard start <= end, end <= segmentCount, depStart <= depEnd, depEnd <= dependencyCount else {
                throw invalid("Archive record has invalid segment or dependency ranges")
            }
            records.append(Record(hash: try u64(index, at), bytes: Data(index[at..<at+56]),
                                  segments: start..<end, dependencies: depStart..<depEnd))
        }
        let dependencies = try (0..<dependencyCount).map { try u64(index, dependencyOffset + $0 * 8) }
        return NativeArchive(url: url, header: header, index: index, records: records,
                             segments: segments, dependencies: dependencies, actualSize: size)
    }

    /// SHA-256 of stored segment bytes plus segment boundaries and uncompressed sizes.
    func payloadDigest(_ record: Record) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hash = SHA256()
        for i in record.segments {
            let segment = segments[i]
            var shape = Data(count: 8)
            Self.put32(segment.compressedSize, &shape, 0); Self.put32(segment.size, &shape, 4)
            hash.update(data: shape)
            try Self.stream(file, offset: segment.offset, count: UInt64(segment.compressedSize)) { hash.update(data: $0) }
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Append donor payloads and a new index to a COPY. Never changes either input.
    static func stageReplacing(source: NativeArchive, target: NativeArchive,
                               hashes: Set<UInt64>, insertionHashes: Set<UInt64> = [], output: URL) throws -> NativeArchive {
        let resolvedOutput = output.resolvingSymlinksInPath().standardizedFileURL
        guard resolvedOutput != source.url.resolvingSymlinksInPath().standardizedFileURL,
              resolvedOutput != target.url.resolvingSymlinksInPath().standardizedFileURL,
              !FileManager.default.fileExists(atPath: output.path) else {
            throw invalid("Staging destination must be a new file distinct from both input archives")
        }
        let groupedSource = Dictionary(grouping: source.records, by: \.hash)
        let groupedTarget = Dictionary(grouping: target.records, by: \.hash)
        var replacements: [UInt64: Record] = [:]
        guard hashes.isDisjoint(with: insertionHashes) else { throw invalid("Insertions overlap replacements") }
        for hash in hashes.union(insertionHashes) {
            let targets = groupedTarget[hash] ?? []
            guard let donors = groupedSource[hash], donors.count == 1,
                  insertionHashes.contains(hash) ? targets.isEmpty : !targets.isEmpty else {
                throw invalid("Replacement has a missing or ambiguous source/target record")
            }
            if targets.count > 1 {
                let digest = try target.payloadDigest(targets[0])
                for duplicate in targets.dropFirst() {
                    guard try target.payloadDigest(duplicate) == digest else {
                        throw invalid("Official archive has different payloads for a duplicated resource hash")
                    }
                }
            }
            replacements[hash] = donors[0]
        }
        guard !replacements.isEmpty else { throw invalid("No replacement records selected") }
        var segmentBytes = Data(target.index[(28 + target.records.count * 56)..<(28 + target.records.count * 56 + target.segments.count * 16)])
        var dependencyBytes = Data(target.index.suffix(target.dependencies.count * 8))
        var updated: [UInt64: Data] = [:]
        let extraSegments = replacements.values.reduce(0) { $0 + $1.segments.count }
        let extraDependencies = replacements.values.reduce(0) { $0 + $1.dependencies.count }
        guard target.segments.count + extraSegments <= Int(UInt32.max),
              target.dependencies.count + extraDependencies <= Int(UInt32.max),
              target.index.count + insertionHashes.count * 56 + extraSegments * 16 + extraDependencies * 8 <= 128 * 1024 * 1024 else {
            throw invalid("Staged archive would exceed format limits")
        }
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PathSafety.copySpaceEfficiently(from: target.url, to: output)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: output) } }
        // APFS clones can inherit a read-only game file's mode; only change our copy.
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
        let write = try FileHandle(forUpdating: output)
        let read = try FileHandle(forReadingFrom: source.url)
        defer { try? write.close(); try? read.close() }
        var cursor = target.actualSize
        for hash in replacements.keys.sorted() {
            guard let record = replacements[hash] else { continue }
            var bytes = record.bytes
            let segmentStart = segmentBytes.count / 16
            put32(UInt32(segmentStart), &bytes, 20)
            for i in record.segments {
                let segment = source.segments[i]
                try write.seek(toOffset: cursor)
                try stream(read, offset: segment.offset, count: UInt64(segment.compressedSize)) { try write.write(contentsOf: $0) }
                var entry = Data(count: 16)
                put64(cursor, &entry, 0); put32(segment.compressedSize, &entry, 8); put32(segment.size, &entry, 12)
                segmentBytes.append(entry); cursor += UInt64(segment.compressedSize)
            }
            put32(UInt32(segmentBytes.count / 16), &bytes, 24)
            put32(UInt32(dependencyBytes.count / 8), &bytes, 28)
            for i in record.dependencies {
                var entry = Data(count: 8); put64(source.dependencies[i], &entry, 0); dependencyBytes.append(entry)
            }
            put32(UInt32(dependencyBytes.count / 8), &bytes, 32)
            updated[hash] = bytes
        }
        var index = Data(target.index.prefix(28))
        let addedRecords = insertionHashes.sorted().compactMap { replacements[$0] }
        let ordered = (target.records + addedRecords).enumerated().sorted {
            $0.element.hash == $1.element.hash ? $0.offset < $1.offset : $0.element.hash < $1.element.hash
        }.map(\.element)
        for record in ordered { index.append(updated[record.hash] ?? record.bytes) }
        index.append(segmentBytes); index.append(dependencyBytes)
        put32(UInt32(index.count - 8), &index, 4)
        put32(UInt32(ordered.count), &index, 16)
        put32(UInt32(segmentBytes.count / 16), &index, 20)
        put32(UInt32(dependencyBytes.count / 8), &index, 24)
        put64(crc64(Data(index.dropFirst(16))), &index, 8)
        let indexPosition = (cursor + 4095) / 4096 * 4096
        try write.seek(toOffset: cursor)
        try write.write(contentsOf: Data(count: Int(indexPosition - cursor)))
        try write.write(contentsOf: index)
        let end = indexPosition + UInt64(index.count), length = (end + 4095) / 4096 * 4096
        try write.write(contentsOf: Data(count: Int(length - end)))
        var header = target.header
        put64(indexPosition, &header, 8); put32(UInt32(index.count), &header, 16); put64(length, &header, 32)
        try write.seek(toOffset: 0); try write.write(contentsOf: header)
        try write.synchronize(); try write.close()
        let result = try NativeArchive.read(output)
        guard result.records.count == target.records.count + insertionHashes.count else { throw invalid("Staged record count changed") }
        let resultRecords = Dictionary(grouping: result.records, by: \.hash)
        for (hash, record) in replacements {
            guard let copies = resultRecords[hash] else { throw invalid("Replacement vanished from staged archive") }
            let expected = try source.payloadDigest(record)
            for copy in copies {
                guard try result.payloadDigest(copy) == expected,
                      Array(result.dependencies[copy.dependencies]) == Array(source.dependencies[record.dependencies]),
                      copy.bytes.prefix(20) == record.bytes.prefix(20), copy.bytes.suffix(20) == record.bytes.suffix(20) else {
                    throw invalid("Staged payload, metadata or dependencies failed verification")
                }
            }
        }
        // Clone-based manual installation carries the source mode, so retain the game's readable mode.
        let attributes = try FileManager.default.attributesOfItem(atPath: target.url.path)
        if let permissions = attributes[.posixPermissions] {
            try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: output.path)
        }
        complete = true
        return result
    }

    static func hex(_ value: UInt64) -> String { String(format: "0x%016llx", value) }
    private static func invalid(_ message: String) -> CyberMacError { .invalidInput(message) }
    private static func readBytes(_ url: URL, offset: UInt64, count: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        let data = try handle.read(upToCount: count) ?? Data()
        guard data.count == count else { throw invalid("Short archive read") }; return data
    }
    private static func u32(_ data: Data, _ at: Int) throws -> UInt32 {
        guard at >= 0, at <= data.count - 4 else { throw invalid("Truncated archive integer") }
        return (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[at + $1]) << ($1 * 8) }
    }
    private static func u64(_ data: Data, _ at: Int) throws -> UInt64 {
        guard at >= 0, at <= data.count - 8 else { throw invalid("Truncated archive integer") }
        return (0..<8).reduce(UInt64(0)) { $0 | UInt64(data[at + $1]) << ($1 * 8) }
    }
    private static func put32(_ value: UInt32, _ data: inout Data, _ at: Int) {
        for i in 0..<4 { data[at + i] = UInt8(truncatingIfNeeded: value >> (i * 8)) }
    }
    private static func put64(_ value: UInt64, _ data: inout Data, _ at: Int) {
        for i in 0..<8 { data[at + i] = UInt8(truncatingIfNeeded: value >> (i * 8)) }
    }
    private static let crcTable: [UInt64] = (0..<256).map { n in
        var crc = UInt64(n)
        for _ in 0..<8 { crc = crc & 1 != 0 ? (crc >> 1) ^ 0xC96C5795D7870F42 : crc >> 1 }
        return crc
    }
    static func crc64(_ data: Data) -> UInt64 {
        var crc = UInt64.max
        for byte in data { crc = (crc >> 8) ^ crcTable[Int((crc ^ UInt64(byte)) & 255)] }
        return ~crc
    }
    private static func stream(_ handle: FileHandle, offset: UInt64, count: UInt64,
                               consume: (Data) throws -> Void) throws {
        try handle.seek(toOffset: offset)
        var remaining = count
        while remaining > 0 {
            try autoreleasepool {
                let amount = Int(min(remaining, 1024 * 1024))
                let data = try handle.read(upToCount: amount) ?? Data()
                guard data.count == amount else { throw invalid("Truncated archive payload") }
                try consume(data); remaining -= UInt64(amount)
            }
        }
    }
}
