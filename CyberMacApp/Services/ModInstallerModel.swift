import CyberMacCore
import Foundation
import Observation

enum ModImportPhase: String, Codable, Sendable {
    case queued, working, choosing, choosingClothes, waiting, ready, installed, blocked, failed, restored
}

struct ModImportJob: Identifiable, Codable, Sendable {
    let id: UUID
    var url: URL
    var phase: ModImportPhase = .queued
    var message = "Waiting to inspect…"
    var lastFailure: String?
    var variants: [String] = []
    var variant: String?
    var transaction: ModInstallTransaction?
    var appearanceID: String?
    var contents: ModPackageContents?
    var contentsError: String?
    var clothingCatalog: ClothingImportCatalog?
    var clothingRecords: [String]?
    var removedAt: Date?
    var previewProgress: ClothingPreviewProgress?

    var installedMessage: String {
        if appearanceID?.hasPrefix(ClothingAdditionInstaller.verificationPrefix) == true {
            return "Selected clothes added as separate inventory items. Load a save to receive them, then equip the pieces you want."
        }
        if appearanceID?.hasPrefix(BodyModInstaller.verificationPrefix) == true {
            if variant?.hasPrefix("Lethal Curves") == true {
                return variant?.hasSuffix("(V + NPCs test)") == true
                    ? "Lethal Curves maximum installed for V and feminine NPCs. This diagnostic changes the shared rig. Load a save and compare the body; restore this entry to remove it."
                    : "Lethal Curves maximum installed for feminine V. Load a save and compare the body in inventory or Photo Mode."
            }
            return variant == BodyModInstaller.variants[1]
                ? "Feminine V shoulder test installed. Load a save and check V in inventory and Photo Mode. Clothing items are preserved; the visible result still needs checking."
                : "Unique V framework installed for feminine V. Original body shape retained. Clothing items are preserved."
        }
        return appearanceID == nil
            ? "Installed and verified. Your enabled script mods and input patches are active."
            : "Installed and verified. Check the replacement in game; visual compatibility is unverified. This does not grant new clothing items."
    }
}

struct ClothingImportPresentation: Identifiable {
    let id: UUID
    let packageName: String
    let catalog: ClothingImportCatalog
    let selectedRecords: Set<String>
}

protocol ModInstallerProviding: Sendable {
    var liveClothingPreviewsEnabled: Bool { get }
    func retain(_ url: URL) throws -> URL
    func prepare(_ url: URL, variant: String?, clothingRecords: [String]?) throws -> ModInstallPreparation
    func contents(_ url: URL) throws -> ModPackageContents?
    func clothingCatalog(_ contents: ModPackageContents) throws -> ClothingImportCatalog
    func apply(_ transaction: ModInstallTransaction) async throws
    func verify(_ transaction: ModInstallTransaction, appearanceID: String?) throws
    func load() throws -> [ModImportJob]
    func save(_ jobs: [ModImportJob]) throws
    func previewSession(_ url: URL, archivePaths: [String], force: Bool) throws -> (any ClothingPreviewSessionProviding)?
}

extension ModInstallerProviding {
    var liveClothingPreviewsEnabled: Bool { false }
    func previewSession(_ url: URL, archivePaths: [String], force: Bool) throws -> (any ClothingPreviewSessionProviding)? { nil }
}

struct ModInstallerService: ModInstallerProviding {
    let home: CyberMacHomeManager
    init(home: CyberMacHomeManager = CyberMacHomeManager()) { self.home = home }
    private var historyURL: URL { home.configURL.appendingPathComponent("installer-history.json") }
    func retain(_ url: URL) throws -> URL {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        _ = try ModPackageRouter(home: home).route(url)
        return try ModPackageRouter(home: home).retain(url)
    }
    func prepare(_ url: URL, variant: String?, clothingRecords: [String]?) throws -> ModInstallPreparation {
        try AutomaticModInstaller(home: home).prepare(url, variant: variant, clothingRecords: clothingRecords)
    }
    func contents(_ url: URL) throws -> ModPackageContents? {
        guard url.pathExtension.lowercased() == "zip" else { return nil }
        let contents = try ClothingWardrobeManager(home: home).packageContents(in: url)
        guard !contents.archives.isEmpty else { return nil }
        if try BodyModInstaller.recognizes(url) { return contents }
        guard try ModArchiveScanner().scan(zipURL: url).dependencyMarkers.frameworkMarkerLabels.isEmpty else { return nil }
        return try ClothingAdditionInstaller(home: home).contents(url)
    }
    func clothingCatalog(_ contents: ModPackageContents) throws -> ClothingImportCatalog {
        do {
            let wardrobe = try ClothingWardrobeManager(home: home).current()
            return ClothingImportCatalog(contents: contents, wardrobe: wardrobe,
                notice: wardrobe == nil && contents.clothingDiscoveryVersion == nil ? "Open your prepared wardrobe in Clothing to enable the available garments." : nil)
        } catch {
            return ClothingImportCatalog(contents: contents, wardrobe: nil, notice: "Could not open the wardrobe: \(error)")
        }
    }
    func apply(_ transaction: ModInstallTransaction) async throws { try await SystemModInstaller(home: home).apply(transaction) }
    func verify(_ transaction: ModInstallTransaction, appearanceID: String?) throws {
        try AutomaticModInstaller(home: home).verify(transaction, appearanceID: appearanceID)
    }
    func load() throws -> [ModImportJob] {
        guard FileManager.default.fileExists(atPath: historyURL.path) else { return [] }
        return try JSONDecoder().decode([ModImportJob].self, from: Data(contentsOf: historyURL))
    }
    func save(_ jobs: [ModImportJob]) throws {
        try FileManager.default.createDirectory(at: home.configURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(jobs).write(to: historyURL, options: .atomic)
    }
    func previewSession(_ url: URL, archivePaths: [String], force: Bool) throws -> (any ClothingPreviewSessionProviding)? {
        guard liveClothingPreviewsEnabled else { return nil }
        let resources = Bundle.main.resourceURL?.appendingPathComponent("ClothingPreviewRenderer", isDirectory: true)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let tools = resources?.appendingPathComponent("renderer-tools.json")
        let config = tools.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            ?? repo.appendingPathComponent(".research/renderer-tools.json")
        guard FileManager.default.fileExists(atPath: config.path) else {
            throw CyberMacError.notFound("The clothing preview renderer is not configured. Rebuild CyberMac with its local preview tools available.")
        }
        let scripts = resources.flatMap { FileManager.default.fileExists(atPath: $0.appendingPathComponent("render_clothing_package.py").path) ? $0 : nil }
            ?? repo.appendingPathComponent("tools")
        return try ClothingPreviewRenderer(home: home).session(package: url, toolsFile: config, scripts: scripts, archivePaths: archivePaths, force: force)
    }
}

@MainActor @Observable
final class ModInstallerModel {
    var jobs: [ModImportJob] = []
    var busy = false
    var historyError: String?
    var clothingPresentation: ClothingImportPresentation?
    var visibleJobs: [ModImportJob] { jobs.filter { $0.removedAt == nil } }
    var removedJobs: [ModImportJob] { jobs.filter { $0.removedAt != nil }.sorted { ($0.removedAt ?? .distantPast) > ($1.removedAt ?? .distantPast) } }
    var liveClothingPreviewsEnabled: Bool { service.liveClothingPreviewsEnabled }
    var isLoadingHistory: Bool { loading != nil && !loaded }
    private var pendingClothingPanes: [UUID] = []
    private var waitingForPickerDismissal = false
    private let service: any ModInstallerProviding
    private var loaded = false
    private var loading: Task<[ModImportJob], Error>?
    @ObservationIgnored private var previewTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var previewSessions: [UUID: any ClothingPreviewSessionProviding] = [:]
    @ObservationIgnored private var previewTokens: [UUID: UUID] = [:]
    @ObservationIgnored private var previewRequestedPaths: [UUID: Set<String>] = [:]
    @ObservationIgnored private var previewDebounce: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var previewPaused: Set<UUID> = []
    init(service: any ModInstallerProviding = ModInstallerService()) { self.service = service }

    func load() async {
        guard !loaded else { return }
        let task = loading ?? Task.detached { [service] in
            var history = try service.load()
            var reconciled = false
            // Repair the former no-payload receipt false negative. Verification
            // checks every game file and commits the pending mod state;
            // it never authorizes another install or writes game files.
            for index in history.indices where history[index].phase == .failed &&
                history[index].message.contains("macOS Installer closed without completing this package") {
                guard let transaction = history[index].transaction else { continue }
                do {
                    try service.verify(transaction, appearanceID: history[index].appearanceID)
                    history[index].phase = .installed
                    history[index].message = history[index].installedMessage
                    reconciled = true
                } catch { /* Keep the original failure and recovery plan. */ }
            }
            if reconciled { try service.save(history) }
            // Upgrade existing imports too; the user should not have to drop
            // Jinguji again just to see what was hidden in its package row.
            for index in history.indices where history[index].removedAt == nil &&
                (history[index].contents == nil || (history[index].contents?.isClothingCollection == true && history[index].contents?.clothingDiscoveryVersion != 1)) {
                do { history[index].contents = try service.contents(history[index].url) }
                catch { history[index].contentsError = "Could not list package contents: \(error)" }
            }
            for index in history.indices {
                if history[index].removedAt == nil, let contents = history[index].contents, contents.isClothingCollection {
                    do { history[index].clothingCatalog = try service.clothingCatalog(contents) }
                    catch { history[index].contentsError = "Could not load clothing previews: \(error)" }
                    history[index].previewProgress = nil // Reattach verified disk cache on reopen.
                }
            }
            return history
        }
        loading = task
        do {
            let history = try await task.value
            guard !loaded else { return }
            loaded = true
            jobs = history
            for index in jobs.indices where jobs[index].phase == .working || jobs[index].phase == .queued {
                jobs[index].phase = .failed
                jobs[index].message = "CyberMac closed before this job finished. Retry to check and continue."
            }
        } catch { loaded = true; historyError = "Could not load installer history: \(error)" }
    }

    func enqueue(_ urls: [URL]) async {
        await load()
        // Accept a whole drop in order, including while another job is running.
        for url in urls where !jobs.contains(where: { $0.removedAt == nil && $0.url == url && [.queued, .working, .choosing, .choosingClothes, .waiting].contains($0.phase) }) {
            jobs.append(ModImportJob(id: UUID(), url: url))
        }
        await drain()
    }

    /// Removing a list entry is reversible. Keep its downloads and recovery
    /// information; never mistake dismissing a card for uninstalling game files.
    func removeFromList(_ id: UUID) async { await setRemoved(id, date: Date()) }
    func putBackInList(_ id: UUID) async { await setRemoved(id, date: nil) }

    private func setRemoved(_ id: UUID, date: Date?) async {
        guard !busy, let index = jobs.firstIndex(where: { $0.id == id }), jobs[index].phase != .working else { return }
        busy = true
        let previous = jobs[index].removedAt
        jobs[index].removedAt = date
        do {
            try await persist()
            historyError = nil
            if date != nil {
                cancelPreviewRendering(id)
                pendingClothingPanes.removeAll { $0 == id }
                if clothingPresentation?.id == id { dismissClothingPicker() }
            }
            if date == nil { startPreviewRendering(id) }
        } catch {
            jobs[index].removedAt = previous
            historyError = "Could not update the list: \(error)"
        }
        busy = false
        await drain()
    }

    func showClothingPicker(_ id: UUID) {
        guard !busy, !waitingForPickerDismissal, let job = jobs.first(where: { $0.id == id && $0.removedAt == nil }), let catalog = job.clothingCatalog else { return }
        pendingClothingPanes.removeAll { $0 == id }
        clothingPresentation = ClothingImportPresentation(id: id, packageName: job.url.lastPathComponent,
            catalog: catalog, selectedRecords: Set(job.clothingRecords ?? []))
        startPreviewRendering(id)
    }

    func presentNextClothingPicker() {
        guard !busy, !waitingForPickerDismissal, clothingPresentation == nil else { return }
        while !pendingClothingPanes.isEmpty {
            let id = pendingClothingPanes.removeFirst()
            guard jobs.contains(where: { $0.id == id && $0.removedAt == nil && $0.phase == .choosingClothes }) else { continue }
            showClothingPicker(id)
            break
        }
    }

    func dismissClothingPicker() {
        waitingForPickerDismissal = clothingPresentation != nil
        clothingPresentation = nil
    }

    func clothingPickerDidDismiss() {
        waitingForPickerDismissal = false
        presentNextClothingPicker()
    }

    func startPreviewRendering(_ id: UUID, force: Bool = false) {
        guard liveClothingPreviewsEnabled else { cancelPreviewRendering(id); return }
        guard !previewPaused.contains(id), previewTasks[id] == nil, let index = jobs.firstIndex(where: { $0.id == id && $0.removedAt == nil }), jobs[index].clothingCatalog != nil else { return }
        if !force && jobs[index].previewProgress?.state == "finished" { return }
        if previewRequestedPaths[id]?.isEmpty != false {
            previewRequestedPaths[id] = Set(jobs[index].clothingCatalog?.items.filter { $0.previewURL == nil }.prefix(4).map(\.archivePath) ?? [])
        }
        let paths = Array((previewRequestedPaths[id] ?? []).sorted().prefix(6))
        guard !paths.isEmpty else { return }
        let token = UUID(), url = jobs[index].url
        previewTokens[id] = token
        jobs[index].previewProgress = ClothingPreviewProgress(total: jobs[index].contents?.archives.count ?? 0)
        previewTasks[id] = Task { [weak self, service] in
            guard let self else { return }
            defer {
                if self.previewTokens[id] == token {
                    self.previewTasks[id] = nil; self.previewSessions[id] = nil; self.previewTokens[id] = nil
                    if self.jobs.first(where: { $0.id == id })?.previewProgress?.state == "finished", self.previewRequestedPaths[id]?.isEmpty == false {
                        self.startPreviewRendering(id, force: true)
                    }
                }
            }
            do {
                guard let session = try await BackgroundTaskRunner.run({ try service.previewSession(url, archivePaths: paths, force: force) }) else {
                    self.previewFailed(id, token: token, message: "Preview rendering is unavailable in this session.")
                    return
                }
                guard self.previewTokens[id] == token, !Task.isCancelled else { session.cancel(); return }
                self.previewSessions[id] = session
                let polling = Task { [weak self] in
                    while !Task.isCancelled {
                        do {
                            if let snapshot = try await BackgroundTaskRunner.run({ try session.snapshot() }) {
                                self?.applyPreviews(snapshot, id: id, token: token)
                            }
                            try await Task.sleep(for: .milliseconds(350))
                        } catch is CancellationError { break }
                        catch { self?.previewFailed(id, token: token, message: String(describing: error)); session.cancel(); break }
                    }
                }
                defer { polling.cancel() }
                let render = Task.detached(priority: .utility) { try session.run() }
                try await withTaskCancellationHandler {
                    try await render.value
                } onCancel: { session.cancel(); render.cancel() }
                if let snapshot = try await BackgroundTaskRunner.run({ try session.snapshot() }) {
                    self.applyPreviews(snapshot, id: id, token: token)
                }
            } catch {
                if !Task.isCancelled { self.previewFailed(id, token: token, message: String(describing: error)) }
            }
        }
    }

    private func applyPreviews(_ snapshot: ClothingPreviewSnapshot, id: UUID, token: UUID) {
        guard previewTokens[id] == token, let index = jobs.firstIndex(where: { $0.id == id && $0.removedAt == nil }) else { return }
        jobs[index].previewProgress = snapshot.progress
        jobs[index].clothingCatalog = jobs[index].clothingCatalog?.applying(snapshot)
        previewRequestedPaths[id]?.subtract(snapshot.images.keys)
        previewRequestedPaths[id]?.subtract(snapshot.errors.keys)
    }

    func requestPreview(_ id: UUID, archivePath: String) {
        guard liveClothingPreviewsEnabled else { return }
        guard let job = jobs.first(where: { $0.id == id && $0.removedAt == nil }),
              job.clothingCatalog?.items.contains(where: { $0.archivePath == archivePath && $0.previewURL == nil && $0.previewError == nil }) == true else { return }
        previewRequestedPaths[id, default: []].insert(archivePath)
        guard !previewPaused.contains(id) else { return }
        previewDebounce[id]?.cancel()
        previewDebounce[id] = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            self?.startPreviewRendering(id, force: true)
        }
    }

    func releasePreview(_ id: UUID, archivePath: String) { previewRequestedPaths[id]?.remove(archivePath) }

    private func previewFailed(_ id: UUID, token: UUID, message: String) {
        guard previewTokens[id] == token, let index = jobs.firstIndex(where: { $0.id == id && $0.removedAt == nil }) else { return }
        var progress = jobs[index].previewProgress ?? ClothingPreviewProgress()
        progress.state = "failed"; progress.current = message
        jobs[index].previewProgress = progress
    }

    func cancelPreviewRendering(_ id: UUID) {
        previewPaused.insert(id)
        previewDebounce.removeValue(forKey: id)?.cancel()
        previewTokens[id] = nil
        previewTasks.removeValue(forKey: id)?.cancel()
        previewSessions.removeValue(forKey: id)?.cancel()
        if let index = jobs.firstIndex(where: { $0.id == id }), jobs[index].previewProgress?.isActive == true {
            jobs[index].previewProgress?.state = "cancelled"
        }
    }

    func resumePreviewRendering(_ id: UUID) {
        guard liveClothingPreviewsEnabled else { return }
        previewPaused.remove(id)
        startPreviewRendering(id, force: true)
    }

    func stopPreviewRendering() {
        for id in Array(previewTokens.keys) { cancelPreviewRendering(id) }
    }

    func installClothingSelection(_ id: UUID, records: [String]) async {
        guard !busy, let index = jobs.firstIndex(where: { $0.id == id && $0.removedAt == nil }), let catalog = jobs[index].clothingCatalog else { return }
        do { try catalog.validateSelection(records) }
        catch { historyError = String(describing: error); return }
        jobs[index].clothingRecords = records.sorted()
        jobs[index].transaction = nil; jobs[index].appearanceID = nil
        jobs[index].phase = .queued
        dismissClothingPicker()
        pendingClothingPanes.removeAll { $0 == id }
        await drain()
    }

    func retry(_ id: UUID, variant: String? = nil, startOver: Bool = false) async {
        guard let index = jobs.firstIndex(where: { $0.id == id && $0.removedAt == nil }), jobs[index].phase != .working else { return }
        jobs[index].variant = variant ?? jobs[index].variant
        if startOver { jobs[index].transaction = nil; jobs[index].appearanceID = nil; jobs[index].clothingRecords = nil; jobs[index].clothingCatalog = nil }
        jobs[index].phase = .queued
        await drain()
    }

    func restore(_ id: UUID) async {
        guard !busy, let index = jobs.firstIndex(where: { $0.id == id }), let transaction = jobs[index].transaction else { return }
        busy = true
        jobs[index].phase = .working; jobs[index].message = "Restoring the files from before this install…"
        do {
            try await persist()
            try await service.apply(transaction.reversed())
            jobs[index].phase = .restored; jobs[index].message = "Previous files restored and verified."
        } catch {
            jobs[index].phase = .failed; jobs[index].message = String(describing: error)
            jobs[index].lastFailure = jobs[index].message
        }
        do { try await persist() } catch { historyError = String(describing: error) }
        busy = false
        await drain()
    }

    private func drain() async {
        guard !busy else { return }
        busy = true
        defer { busy = false; presentNextClothingPicker() }
        while let index = jobs.firstIndex(where: { $0.phase == .queued && $0.removedAt == nil }) {
            jobs[index].phase = .working; jobs[index].message = "Identifying package and preparing files…"
            do {
                let original = jobs[index].url
                let retained = try await BackgroundTaskRunner.run { [service] in try service.retain(original) }
                jobs[index].url = retained
                if jobs[index].contents == nil {
                    jobs[index].contents = try await BackgroundTaskRunner.run { [service] in try service.contents(retained) }
                    jobs[index].contentsError = nil
                }
                if let contents = jobs[index].contents, contents.isClothingCollection, jobs[index].transaction == nil {
                    if jobs[index].clothingCatalog == nil {
                        jobs[index].clothingCatalog = try await BackgroundTaskRunner.run { [service] in try service.clothingCatalog(contents) }
                    }
                    if jobs[index].clothingRecords == nil {
                        startPreviewRendering(jobs[index].id)
                        jobs[index].phase = .choosingClothes
                        jobs[index].message = "Choose your garments. No clothing selection has been applied from this import."
                        if !pendingClothingPanes.contains(jobs[index].id) { pendingClothingPanes.append(jobs[index].id) }
                        try await persist()
                        continue
                    }
                }
                if let previous = jobs.first(where: { $0.id != jobs[index].id && $0.url == retained && $0.variant == jobs[index].variant && $0.clothingRecords == jobs[index].clothingRecords && $0.phase == .installed }),
                   let transaction = previous.transaction {
                    let stillInstalled = await Task.detached { (try? transaction.verify()) != nil }.value
                    if stillInstalled {
                        jobs[index].phase = .ready; jobs[index].message = "This download is already installed and verified."
                        try await persist(); continue
                    }
                }
                if jobs[index].transaction == nil {
                    let variant = jobs[index].variant
                    let records = jobs[index].clothingRecords
                    if records != nil { jobs[index].message = "Preparing your selected clothes as separate inventory items…" }
                    let preparation = try await BackgroundTaskRunner.run { [service] in try service.prepare(retained, variant: variant, clothingRecords: records) }
                    switch preparation {
                    case .ready(let message): jobs[index].phase = .ready; jobs[index].message = message
                    case .runtimeReady(let message):
                        jobs[index].phase = .ready; jobs[index].message = message
                        for pending in jobs.indices where jobs[pending].phase == .waiting && jobs[pending].removedAt == nil { jobs[pending].phase = .queued }
                    case .needsSetup(let message): jobs[index].phase = .waiting; jobs[index].message = message
                    case .blocked(let message): jobs[index].phase = .blocked; jobs[index].message = message
                    case .choices(let variants):
                        jobs[index].phase = .choosing; jobs[index].variants = variants
                        jobs[index].message = "Choose one variant to install. Collections can contain conflicting alternatives."
                    case .clothingSelectionRequired:
                        jobs[index].phase = .choosingClothes
                        jobs[index].message = "Choose your garments before installing."
                        if !pendingClothingPanes.contains(jobs[index].id) { pendingClothingPanes.append(jobs[index].id) }
                    case .prepared(let transaction, let appearanceID):
                        jobs[index].transaction = transaction; jobs[index].appearanceID = appearanceID
                    }
                }
                if jobs[index].phase == .working, let transaction = jobs[index].transaction {
                    jobs[index].message = "Complete the macOS Installer window to continue. CyberMac will verify the game files when it finishes."
                    // Persist recovery information BEFORE asking macOS to write.
                    try await persist()
                    let appearanceID = jobs[index].appearanceID
                    // Finish an interrupted verification without asking for
                    // authorization or writing the same files again.
                    let alreadyApplied = await Task.detached { (try? transaction.verify()) != nil }.value
                    if !alreadyApplied { try await service.apply(transaction) }
                    try await BackgroundTaskRunner.run { [service] in try service.verify(transaction, appearanceID: appearanceID) }
                    jobs[index].phase = .installed
                    jobs[index].message = jobs[index].installedMessage
                }
                try await persist()
            } catch {
                jobs[index].phase = .failed; jobs[index].message = String(describing: error)
                jobs[index].lastFailure = jobs[index].message
                do { try await persist() } catch { historyError = "Could not save recovery history: \(error)" }
            }
        }
    }

    private func persist() async throws {
        let snapshot = jobs
        try await BackgroundTaskRunner.run { [service] in try service.save(snapshot) }
    }
}
