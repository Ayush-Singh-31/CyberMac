import AppKit
import CyberMacCore
import Foundation
import Observation

@MainActor @Observable
final class ClothingWardrobeModel {
    var wardrobe: ClothingWardrobe?
    var selected: Set<String> = []
    var search = ""
    var collection = "All"
    var busy: String?
    var error: String?
    var message: String?
    var session: ClothingSessionStatus?

    var visibleItems: [ClothingWardrobeItem] {
        (wardrobe?.items ?? []).filter {
            (collection == "All" || $0.collection == collection) &&
            (search.isEmpty || ($0.name + " " + $0.slot).localizedCaseInsensitiveContains(search))
        }
    }
    var canPlay: Bool { wardrobe != nil && busy == nil && session?.isActive != true }

    func load() async {
        await perform("Loading wardrobe…") {
            let value = try await BackgroundTaskRunner.run { try ClothingWardrobeManager().current() }
            wardrobe = value; selected = value?.selectedRecords ?? []
            await refreshStatus()
        }
    }
    func openWorkspace(_ url: URL) async {
        await perform("Opening wardrobe…") {
            let value = try await BackgroundTaskRunner.run { try ClothingWardrobeManager().register(workspace: url) }
            wardrobe = value; selected = value.selectedRecords; session = nil; message = "Wardrobe opened. Choose the pieces you want."
        }
    }
    func importZIP(_ url: URL) async {
        guard wardrobe != nil else { error = "Open your prepared wardrobe first."; return }
        await perform("Reading clothing package…") {
            let records = try await BackgroundTaskRunner.run { try ClothingWardrobeManager().pieces(in: url) }
            selected.formUnion(records)
            message = "Selected \(records.count) supported pieces from \(url.lastPathComponent)."
        }
    }
    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
    func selectVisible() { selected.formUnion(visibleItems.map(\.id)) }
    func play() async {
        guard let wardrobe, canPlay else { return }
        let records = Array(selected)
        await perform("Preparing selected clothes…") {
            let command = try await BackgroundTaskRunner.run {
                try ClothingWardrobeManager().prepareLaunch(workspace: wardrobe.workspace, records: records)
            }
            guard NSWorkspace.shared.open(command) else { throw CyberMacError.fileSystem("Terminal could not open the clothing launcher.") }
            message = "Launcher opened in Terminal. Enter your Mac password there if asked. The game opens after verification."
        }
    }
    func refreshStatus() async {
        guard let workspace = wardrobe?.workspace else { return }
        do {
            let value = try await BackgroundTaskRunner.run { try ClothingWardrobeManager().sessionStatus(workspace: workspace) }
            session = value
        } catch { self.error = "Could not read launch status: \(error)" }
    }
    func restore() {
        guard let wardrobe else { return }
        guard NSWorkspace.shared.open(wardrobe.workspace.appendingPathComponent("Restore New Clothing.command")) else {
            error = "Could not open the recovery command in Terminal."; return
        }
        message = "Recovery opened in Terminal. Fully close the game before restoring."
    }
    private func perform(_ title: String, action: () async throws -> Void) async {
        guard busy == nil else { return }
        busy = title; error = nil
        defer { busy = nil }
        do { try await action() } catch { self.error = String(describing: error) }
    }
}
