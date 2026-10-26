@testable import CyberMacCore
import Foundation
import XCTest
@testable import CyberMacApp

@MainActor
final class ModInstallerModelTests: XCTestCase {
    func testInitialPreviewWorkIsBoundedInsteadOfRenderingWholeCollection() async throws {
        let service = InstallerFixtureService()
        service.catalog = ModPackageContents(archives: (0..<30).map { .init(path: "Clothes/Other/variant\($0).archive", preparedPieces: []) })
        let model = ModInstallerModel(service: service)
        await model.enqueue([url("large-clothing.zip")])
        for _ in 0..<100 {
            if !service.previewRequests.isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(service.previewRequests.count, 1)
        XCTAssertLessThanOrEqual(service.previewRequests[0].count, 6)
        XCTAssertLessThan(service.previewRequests[0].count, 30)
        model.stopPreviewRendering()
    }

    func testPausedPreviewDoesNotRestartWhenMoreRowsAppear() async throws {
        let service = clothingService(), session = PreviewFixtureSession(wait: true)
        service.preview = session
        let model = ModInstallerModel(service: service)
        await model.enqueue([url("clothing.zip")])
        for _ in 0..<100 {
            if session.started { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let id = model.jobs[0].id
        model.cancelPreviewRendering(id)
        model.requestPreview(id, archivePath: "Clothes/Other/unconverted.archive")
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(service.previewRequests.count, 1)
        XCTAssertEqual(model.jobs[0].previewProgress?.state, "cancelled")
        XCTAssertTrue(session.cancelled)
    }

    func testBackgroundPreviewsArriveWithoutPreparingOrInstallingUnconvertedClothes() async throws {
        let service = clothingService()
        let session = PreviewFixtureSession()
        service.preview = session
        let model = ModInstallerModel(service: service)
        await model.enqueue([url("clothing.zip")])
        for _ in 0..<100 {
            if model.jobs[0].previewProgress?.state == "finished" { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let item = try XCTUnwrap(model.jobs[0].clothingCatalog?.items.first { $0.record == nil })
        XCTAssertEqual(item.previewURL, URL(fileURLWithPath: "/private/tmp/rendered-variant.png"))
        XCTAssertFalse(item.canSelect)
        XCTAssertEqual(model.jobs[0].previewProgress?.state, "finished")
        XCTAssertTrue(service.prepared.isEmpty)
        XCTAssertEqual(service.applied, 0)
    }

    func testRemovingImportCancelsItsBackgroundRenderer() async throws {
        let service = clothingService(), session = PreviewFixtureSession(wait: true)
        service.preview = session
        let model = ModInstallerModel(service: service)
        await model.enqueue([url("clothing.zip")])
        for _ in 0..<100 {
            if session.started { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        await model.removeFromList(model.jobs[0].id)
        for _ in 0..<100 {
            if session.cancelled { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(session.cancelled)
        XCTAssertTrue(model.visibleJobs.isEmpty)
        XCTAssertEqual(service.applied, 0)
    }

    func testRemoveAndPutBackPersistWithoutChangingInstalledFiles() async {
        let service = InstallerFixtureService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("example.zip")])
        let id = model.jobs[0].id
        await model.removeFromList(id)
        XCTAssertTrue(model.visibleJobs.isEmpty)
        XCTAssertEqual(model.removedJobs.count, 1)
        XCTAssertEqual(service.applied, 0)
        XCTAssertEqual(service.prepared, ["example.zip"])

        let reopened = ModInstallerModel(service: service)
        await reopened.load()
        XCTAssertTrue(reopened.visibleJobs.isEmpty)
        XCTAssertEqual(reopened.removedJobs.first?.id, id)
        await reopened.putBackInList(id)
        XCTAssertEqual(reopened.visibleJobs.first?.id, id)
        XCTAssertTrue(reopened.removedJobs.isEmpty)
        XCTAssertNil(service.history.first?.removedAt)
        XCTAssertEqual(service.applied, 0)
    }

    func testRemovalKeepsTransactionAndRecoveryInformation() async throws {
        let service = InstallerFixtureService()
        let plan = try fixturePlan()
        service.history = [ModImportJob(id: UUID(), url: url("installed.zip"), phase: .installed, transaction: plan)]
        let model = ModInstallerModel(service: service)
        await model.load()
        await model.removeFromList(model.jobs[0].id)
        XCTAssertTrue(model.visibleJobs.isEmpty)
        XCTAssertEqual(model.removedJobs.first?.transaction?.files.first?.backup, plan.files[0].backup)
        XCTAssertEqual(service.history.first?.transaction?.files.count, plan.files.count)
        XCTAssertEqual(service.applied, 0)
    }

    func testRemovalSaveFailureLeavesEntryVisible() async {
        let service = InstallerFixtureService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("example.zip")])
        service.failSave = true
        await model.removeFromList(model.jobs[0].id)
        XCTAssertEqual(model.visibleJobs.count, 1)
        XCTAssertTrue(model.removedJobs.isEmpty)
        XCTAssertNotNil(model.historyError)
        XCTAssertFalse(model.busy)
    }

    func testRemovedClothingEntryCannotReopenItsPickerOrInstall() async {
        let service = clothingService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("clothing.zip")])
        let id = model.jobs[0].id
        await model.removeFromList(id)
        model.clothingPickerDidDismiss()
        model.showClothingPicker(id)
        await model.installClothingSelection(id, records: ["Items.Pants"])
        XCTAssertNil(model.clothingPresentation)
        XCTAssertTrue(service.prepared.isEmpty)
        XCTAssertTrue(model.visibleJobs.isEmpty)
    }

    func testRemovalIsDisabledWhileInstallationIsWorking() async throws {
        let service = InstallerFixtureService(), model = ModInstallerModel(service: service)
        let work = Task { await model.enqueue([url("slow.zip")]) }
        for _ in 0..<100 {
            if !model.jobs.isEmpty && service.prepared.contains("slow.zip") { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(model.busy)
        await model.removeFromList(model.jobs[0].id)
        XCTAssertEqual(model.visibleJobs.count, 1)
        XCTAssertTrue(model.removedJobs.isEmpty)
        service.release.signal()
        await work.value
    }

    func testClothingDropOpensVisualChoiceBeforeAnyInstall() async {
        let service = clothingService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("clothing.zip")])
        XCTAssertEqual(model.jobs.first?.phase, .choosingClothes)
        XCTAssertEqual(model.clothingPresentation?.catalog.availableItems.count, 2)
        XCTAssertTrue(model.clothingPresentation?.selectedRecords.isEmpty == true)
        XCTAssertTrue(service.prepared.isEmpty)
        XCTAssertEqual(service.applied, 0)
    }

    func testOnlyCheckedClothingRecordsArePassedToInstaller() async {
        let service = clothingService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("clothing.zip")])
        await model.installClothingSelection(model.jobs[0].id, records: ["Items.Pants"])
        XCTAssertEqual(service.clothingSelections, [["Items.Pants"]])
        XCTAssertEqual(model.jobs[0].clothingRecords, ["Items.Pants"])
        XCTAssertEqual(model.jobs[0].phase, .ready)
        XCTAssertNil(model.clothingPresentation)
    }

    func testCancellingClothingPaneDoesNotPrepareAnything() async {
        let service = clothingService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("clothing.zip")])
        model.dismissClothingPicker()
        model.clothingPickerDidDismiss()
        XCTAssertNil(model.clothingPresentation)
        XCTAssertEqual(model.jobs[0].phase, .choosingClothes)
        XCTAssertTrue(service.prepared.isEmpty)
    }

    func testUnavailableAndForeignSelectionsCannotReachInstaller() async {
        let service = clothingService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("clothing.zip")])
        for records in [[], ["archive:Clothes/other.archive"], ["Items.Foreign"], ["Items.Pants", "Items.Pants"]] {
            await model.installClothingSelection(model.jobs[0].id, records: records)
        }
        XCTAssertTrue(service.prepared.isEmpty)
        XCTAssertNotNil(model.clothingPresentation)
    }

    func testMultipleClothingZIPsWaitForTheirOwnSelections() async {
        let service = clothingService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("first.zip"), url("second.zip")])
        XCTAssertEqual(model.jobs.map(\.phase), [.choosingClothes, .choosingClothes])
        XCTAssertEqual(model.clothingPresentation?.id, model.jobs[0].id)
        await model.installClothingSelection(model.jobs[0].id, records: ["Items.Corset"])
        XCTAssertNil(model.clothingPresentation, "Wait for the first sheet to finish closing")
        model.clothingPickerDidDismiss()
        XCTAssertEqual(model.clothingPresentation?.id, model.jobs[1].id)
        XCTAssertEqual(service.clothingSelections, [["Items.Corset"]])
    }

    private func clothingService() -> InstallerFixtureService {
        let service = InstallerFixtureService()
        service.catalog = ModPackageContents(archives: [
            .init(path: "Clothes/Tops/corset.archive", preparedPieces: [.init(id: "Items.Corset", name: "Corset")]),
            .init(path: "Clothes/Legs/pants.archive", preparedPieces: [.init(id: "Items.Pants", name: "Pants")]),
            .init(path: "Clothes/Other/unconverted.archive", preparedPieces: [])
        ])
        return service
    }

    func testPackageContentsAreRetainedForEachImport() async {
        let service = InstallerFixtureService()
        service.catalog = ModPackageContents(archives: [.init(path: "Jinguji/Corset/red.archive", preparedPieces: [.init(id: "Items.Corset", name: "Red corset")])])
        let model = ModInstallerModel(service: service)
        await model.enqueue([url("collection.zip")])
        XCTAssertEqual(model.jobs.first?.contents?.archives.count, 1)
        XCTAssertEqual(model.jobs.first?.contents?.preparedPieces.first?.name, "Red corset")
        XCTAssertEqual(service.history.first?.contents?.preparedPieces.count, 1)
    }

    func testExistingPackageRowIsEnrichedWithoutReinstalling() async {
        let service = InstallerFixtureService()
        service.history = [ModImportJob(id: UUID(), url: url("old.zip"), phase: .ready)]
        service.catalog = ModPackageContents(archives: [.init(path: "Clothes/Tops/red.archive", preparedPieces: []), .init(path: "Clothes/Boots/black.archive", preparedPieces: [])])
        let model = ModInstallerModel(service: service)
        await model.load()
        XCTAssertEqual(model.jobs.first?.contents?.archives.count, 2)
        XCTAssertEqual(model.jobs.first?.phase, .ready)
        XCTAssertEqual(service.applied, 0)
        XCTAssertTrue(service.prepared.isEmpty)
    }

    func testWholeDropContinuesAfterBlockedAndFailedPackages() async {
        let service = InstallerFixtureService()
        let model = ModInstallerModel(service: service)
        await model.enqueue([url("good.zip"), url("blocked.zip"), url("broken.zip"), url("last.zip")])
        XCTAssertEqual(model.jobs.map(\.phase), [.ready, .blocked, .failed, .ready])
        XCTAssertFalse(model.busy)
        XCTAssertEqual(service.prepared, ["good.zip", "blocked.zip", "broken.zip", "last.zip"])
    }

    func testVariantChoiceResumesOnlySelectedPackage() async {
        let service = InstallerFixtureService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("choices.zip"), url("other.zip")])
        XCTAssertEqual(model.jobs.map(\.phase), [.choosing, .ready])
        await model.retry(model.jobs[0].id, variant: "blue.archive")
        XCTAssertEqual(model.jobs[0].phase, .ready)
        XCTAssertEqual(model.jobs[0].message, "Selected blue.archive")
        XCTAssertEqual(service.prepared.filter { $0 == "other.zip" }.count, 1)
    }

    func testRuntimeImportAutomaticallyResumesWaitingMods() async {
        let service = InstallerFixtureService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("needs-runtime.zip"), url("runtime.zip")])
        XCTAssertEqual(model.jobs.map(\.phase), [.ready, .ready])
        XCTAssertEqual(service.prepared, ["needs-runtime.zip", "runtime.zip", "needs-runtime.zip"])
    }

    func testMultipleDropsWhileWorkingAreNotLost() async throws {
        let service = InstallerFixtureService(), model = ModInstallerModel(service: service)
        let first = Task { await model.enqueue([url("slow.zip")]) }
        for _ in 0..<100 {
            if service.prepared.contains("slow.zip") { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(model.busy)
        await model.enqueue([url("second.zip"), url("third.zip")])
        service.release.signal()
        await first.value
        XCTAssertEqual(model.jobs.map(\.phase), [.ready, .ready, .ready])
        XCTAssertEqual(service.prepared, ["slow.zip", "second.zip", "third.zip"])
    }

    func testRepeatedFilesInOneDropAreDeduplicated() async {
        let service = InstallerFixtureService(), model = ModInstallerModel(service: service)
        await model.enqueue([url("same.zip"), url("same.zip")])
        XCTAssertEqual(model.jobs.count, 1)
        XCTAssertEqual(service.prepared.count, 1)
    }

    func testRecoveryHistoryMustBeSavedBeforeAuthorization() async throws {
        let service = InstallerFixtureService()
        service.failSave = true
        service.plan = try fixturePlan()
        let model = ModInstallerModel(service: service)
        await model.enqueue([url("install.zip")])
        XCTAssertEqual(model.jobs.first?.phase, .failed)
        XCTAssertEqual(service.applied, 0)
        XCTAssertNotNil(model.jobs.first?.transaction)
    }

    func testInterruptedJobIsRecoverableWithoutAutomaticGameWrites() async {
        let service = InstallerFixtureService()
        service.history = [ModImportJob(id: UUID(), url: url("old.zip"), phase: .working)]
        let model = ModInstallerModel(service: service)
        await model.load()
        XCTAssertEqual(model.jobs.first?.phase, .failed)
        XCTAssertEqual(service.applied, 0)
        await model.retry(model.jobs[0].id)
        XCTAssertEqual(model.jobs.first?.phase, .ready)
    }

    private func url(_ name: String) -> URL { URL(fileURLWithPath: "/private/tmp/\(name)") }
    private func fixturePlan() throws -> ModInstallTransaction {
        let app = url("CyberMacFixture.app"), data = app.appendingPathComponent("Contents/Data")
        let game = GameInstall(appURL: app, executableURL: app.appendingPathComponent("Contents/MacOS/FakeCP77"),
            dataURL: data, archiveMacURL: nil, r6URL: nil, storefront: .unknown, displayName: "Fixture")
        return try ModInstallTransaction(game: game, files: [.init(source: url("unwritten-source").path,
            target: data.appendingPathComponent("r6/cache/final.redscripts").path, backup: url("unwritten-backup").path,
            originalSHA256: String(repeating: "a", count: 64), installedSHA256: String(repeating: "b", count: 64))])
    }
}

private final class InstallerFixtureService: ModInstallerProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [String] = []
    private var runtime = false
    private var applyCount = 0
    private var selections: [[String]] = []
    private var previewCalls: [[String]] = []
    let release = DispatchSemaphore(value: 0)
    var failSave = false
    var plan: ModInstallTransaction?
    var history: [ModImportJob] = []
    var catalog: ModPackageContents?
    var preview: (any ClothingPreviewSessionProviding)?
    var prepared: [String] { lock.withLock { calls } }
    var applied: Int { lock.withLock { applyCount } }
    var clothingSelections: [[String]] { lock.withLock { selections } }
    var previewRequests: [[String]] { lock.withLock { previewCalls } }
    func retain(_ url: URL) throws -> URL { url }
    func contents(_ url: URL) throws -> ModPackageContents? { lock.withLock { catalog } }
    func previewSession(_ url: URL, archivePaths: [String], force: Bool) throws -> (any ClothingPreviewSessionProviding)? {
        lock.withLock { previewCalls.append(archivePaths); return preview }
    }
    func clothingCatalog(_ contents: ModPackageContents) throws -> ClothingImportCatalog {
        let items = contents.preparedPieces.map { ClothingWardrobeItem(id: $0.id, name: $0.name, collection: "Fixture", slot: "Torso", previewURL: URL(fileURLWithPath: "/private/tmp/fixture.png")) }
        let wardrobe = ClothingWardrobe(workspace: URL(fileURLWithPath: "/private/tmp/fixture"), gameApp: "Fixture.app", items: items, selectedRecords: [], previewStyle: "Fixture")
        return ClothingImportCatalog(contents: contents, wardrobe: wardrobe)
    }
    func prepare(_ url: URL, variant: String?, clothingRecords: [String]?) throws -> ModInstallPreparation {
        let name = url.lastPathComponent
        lock.withLock { calls.append(name); if let clothingRecords { selections.append(clothingRecords) } }
        switch name {
        case "blocked.zip": return .blocked("Framework unavailable")
        case "broken.zip": throw CyberMacError.invalidInput("Invalid ZIP")
        case "slow.zip": _ = release.wait(timeout: .now() + 5); return .ready("Finished")
        case "choices.zip": return variant.map { .ready("Selected \($0)") } ?? .choices(["red.archive", "blue.archive"])
        case "needs-runtime.zip": return lock.withLock { runtime ? .ready("Finished") : .needsSetup("Drop runtime") }
        case "runtime.zip": lock.withLock { runtime = true }; return .runtimeReady("Imported")
        case "install.zip": return .prepared(plan!, appearanceID: nil)
        default: return .ready("Finished")
        }
    }
    func apply(_ transaction: ModInstallTransaction) throws { lock.withLock { applyCount += 1 } }
    func verify(_ transaction: ModInstallTransaction, appearanceID: String?) throws { }
    func load() throws -> [ModImportJob] { lock.withLock { history } }
    func save(_ jobs: [ModImportJob]) throws {
        if failSave { throw CyberMacError.fileSystem("History is not writable") }
        lock.withLock { history = jobs }
    }
}

private final class PreviewFixtureSession: ClothingPreviewSessionProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let release = DispatchSemaphore(value: 0)
    private let wait: Bool
    private var didStart = false, didFinish = false, didCancel = false
    var started: Bool { lock.withLock { didStart } }
    var cancelled: Bool { lock.withLock { didCancel } }
    init(wait: Bool = false) { self.wait = wait }
    func run() throws {
        lock.withLock { didStart = true }
        if wait { _ = release.wait(timeout: .now()+5) }
        lock.withLock { didFinish = true }
    }
    func cancel() { lock.withLock { didCancel = true }; release.signal() }
    func snapshot() throws -> ClothingPreviewSnapshot? {
        let finished = lock.withLock { didFinish }
        return ClothingPreviewSnapshot(progress: .init(state: finished ? "finished" : "rendering", total: 1, completed: finished ? 1 : 0),
            images: finished ? ["Clothes/Other/unconverted.archive": URL(fileURLWithPath: "/private/tmp/rendered-variant.png")] : [:])
    }
}
