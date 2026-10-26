import Foundation
import Darwin
import ImageIO

public struct ClothingPreviewProgress: Codable, Sendable {
    public struct Result: Codable, Sendable {
        public let archivePath: String
        public let status: String
        public let sourceSHA256: String?
        public let preview: String?
        public let previewSHA256: String?
        public let error: String?
    }
    public var state: String
    public var total: Int
    public var completed: Int
    public var failed: Int
    public var current: String
    public var results: [Result]
    public var isActive: Bool { state == "loading" || state == "rendering" }
    public var readyCount: Int { results.filter { $0.status == "ready" }.count }
    public init(state: String = "loading", total: Int = 0, completed: Int = 0, failed: Int = 0, current: String = "Loading clothing…") {
        self.state = state; self.total = total; self.completed = completed; self.failed = failed; self.current = current; self.results = []
    }
}

public struct ClothingPreviewSnapshot: Sendable {
    public let progress: ClothingPreviewProgress
    public let images: [String: URL]
    public let errors: [String: String]
    public init(progress: ClothingPreviewProgress, images: [String: URL], errors: [String: String] = [:]) {
        self.progress = progress; self.images = images; self.errors = errors
    }
}

public protocol ClothingPreviewSessionProviding: Sendable {
    func run() throws
    func cancel()
    func snapshot() throws -> ClothingPreviewSnapshot?
}

public struct ClothingPreviewTools: Codable, Sendable {
    public let python: String
    public let dotnet: String
    public let blender: String
    public let wolvenkit: String
    public let kraken: String
    public let addonSource: String
}

public struct ClothingPreviewRenderer: Sendable {
    public let home: CyberMacHomeManager
    public init(home: CyberMacHomeManager = CyberMacHomeManager()) { self.home = home }

    public func session(package: URL, toolsFile: URL, scripts: URL, archivePaths: [String], force: Bool = false) throws -> any ClothingPreviewSessionProviding {
        let tools = try JSONDecoder().decode(ClothingPreviewTools.self, from: Data(contentsOf: toolsFile))
        for path in [tools.python, tools.dotnet, tools.blender] {
            guard FileManager.default.isExecutableFile(atPath: path) else { throw CyberMacError.notFound("The clothing preview tool is missing: \(URL(fileURLWithPath: path).lastPathComponent)") }
        }
        for path in [tools.wolvenkit, tools.kraken, scripts.appendingPathComponent("render_clothing_package.py").path] {
            guard FileManager.default.fileExists(atPath: path) else { throw CyberMacError.notFound("A clothing preview dependency is missing: \(URL(fileURLWithPath: path).lastPathComponent)") }
        }
        let game = try GameInstallDetector().detect()
        let packageHash = try PathSafety.sha256(url: package)
        let seal = game.appURL.appendingPathComponent("Contents/_CodeSignature/CodeResources")
        let gameHash = try PathSafety.sha256(url: seal)
        let key = PathSafety.sha256(string: "clothing-preview-fast-v2|\(packageHash)|\(gameHash)")
        let output = home.generatedURL.appendingPathComponent("clothing-previews/\(key)", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        struct Request: Encodable { let package: String; let packageSHA256: String; let gameApp: String; let output: String; let tools: ClothingPreviewTools; let mode: String; let archivePaths: [String] }
        let request = output.appendingPathComponent("request-\(UUID().uuidString).json")
        try JSONEncoder().encode(Request(package: package.path, packageSHA256: packageHash, gameApp: game.appURL.path, output: output.path, tools: tools, mode: "fast", archivePaths: archivePaths)).write(to: request, options: .atomic)
        return ClothingPreviewProcess(output: output, python: URL(fileURLWithPath: tools.python), script: scripts.appendingPathComponent("render_clothing_package.py"), request: request, force: force)
    }
}

/// An ordinary child process, with bounded file-based progress; no privilege
/// escalation or game writes. Separate process groups let cancellation stop
/// the exporter and Blender as well as the Python coordinator.
final class ClothingPreviewProcess: ClothingPreviewSessionProviding, @unchecked Sendable {
    private let output: URL
    private let python: URL
    private let script: URL
    private let request: URL
    private let force: Bool
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var hasStarted = false
    private var verified: [String: URL] = [:]

    init(output: URL, python: URL, script: URL, request: URL, force: Bool) {
        self.output = output; self.python = python; self.script = script; self.request = request; self.force = force
    }

    func run() throws {
        defer { try? FileManager.default.removeItem(at: request) }
        let descriptor = open(output.deletingLastPathComponent().appendingPathComponent("clothing-renderer.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw CyberMacError.fileSystem("Could not lock the clothing preview cache.") }
        defer { flock(descriptor, LOCK_UN); close(descriptor) }
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            if lock.withLock({ cancelled }) { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        if lock.withLock({ cancelled }) { return }
        if !force, try snapshot()?.progress.state == "finished" { return }
        let progressURL = output.appendingPathComponent("progress.json")
        if let previous = try? Data(contentsOf: progressURL) { try previous.write(to: output.appendingPathComponent("resume.json"), options: .atomic) }
        try JSONEncoder().encode(ClothingPreviewProgress()).write(to: progressURL, options: .atomic)
        lock.withLock { hasStarted = true }
        let logURL = output.appendingPathComponent("process.log")
        _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }
        let child = Process()
        child.qualityOfService = .background
        child.environment = ProcessInfo.processInfo.environment.merging(["OMP_NUM_THREADS": "2", "OPENBLAS_NUM_THREADS": "1", "DOTNET_PROCESSOR_COUNT": "2"]) { _, new in new }
        child.executableURL = python
        child.arguments = [script.path, "--request", request.path]
        child.standardOutput = log; child.standardError = log
        let started = try lock.withLock {
            if cancelled { return false }
            try child.run()
            process = child
            return true
        }
        guard started else { return }
        child.waitUntilExit()
        lock.withLock { process = nil }
        if child.terminationStatus != 0 && !lock.withLock({ cancelled }) {
            let detail = (try snapshot()?.progress.current) ?? "See the preview rendering log."
            throw CyberMacError.fileSystem("Clothing preview rendering stopped: \(detail)")
        }
    }

    func cancel() {
        lock.withLock {
            cancelled = true
            if let process, process.isRunning {
                if kill(-process.processIdentifier, SIGTERM) != 0 { process.terminate() }
            }
        }
    }

    func snapshot() throws -> ClothingPreviewSnapshot? {
        if force && !lock.withLock({ hasStarted }) { return nil }
        let file = output.appendingPathComponent("progress.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        guard try PathSafety.fileSize(url: file) <= 8 * 1024 * 1024 else { throw CyberMacError.invalidInput("Preview progress is too large.") }
        let progress = try JSONDecoder().decode(ClothingPreviewProgress.self, from: Data(contentsOf: file))
        guard progress.total >= 0, progress.total <= PathSafety.maxArchiveEntries,
              progress.completed >= 0, progress.completed <= progress.total,
              progress.results.count <= progress.total else { throw CyberMacError.invalidInput("Invalid clothing preview progress.") }
        var images: [String: URL] = [:], errors: [String: String] = [:]
        for result in progress.results {
            if let error = result.error { errors[result.archivePath] = error }
            guard result.status == "ready", let name = result.preview, let hash = result.previewSHA256,
                  let sourceHash = result.sourceSHA256, name == "images/\(sourceHash).png",
                  sourceHash.count == 64, sourceHash.allSatisfy(\.isHexDigit), hash.count == 64 else { continue }
            let identity = name + "|" + hash
            if let cached = lock.withLock({ verified[identity] }) { images[result.archivePath] = cached; continue }
            let url = output.appendingPathComponent(name)
            try PathSafety.validateContainedPath(url.resolvingSymlinksInPath(), in: output.resolvingSymlinksInPath())
            guard try PathSafety.fileSize(url: url) <= 2 * 1024 * 1024,
                  try PathSafety.sha256(url: url) == hash,
                  let image = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let info = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
                  let width = info[kCGImagePropertyPixelWidth] as? Int,
                  [160, 256].contains(width), info[kCGImagePropertyPixelHeight] as? Int == width else {
                throw CyberMacError.invalidInput("A rendered garment preview failed verification.")
            }
            lock.withLock { verified[identity] = url }
            images[result.archivePath] = url
        }
        return ClothingPreviewSnapshot(progress: progress, images: images, errors: errors)
    }
}
