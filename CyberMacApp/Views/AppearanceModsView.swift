import AppKit
import CyberMacCore
import SwiftUI
import UniformTypeIdentifiers

struct AppearanceModsView: View {
    @State private var selectedFile: URL?
    @State private var variants: [String] = []
    @State private var selectedVariant = ""
    @State private var plan: AppearancePatchPlan?
    @State private var staged: AppearancePatchStage?
    @State private var delivery: AppearanceItemDelivery?
    @State private var recent: [AppearancePatchPlan] = []
    @State private var busy: String?
    @State private var errorMessage: String?
    @State private var verificationMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Appearance Mods").font(.largeTitle.weight(.semibold))
                Text("Feminine V · Clothes first, then body shapes and matching refits")
                    .foregroundStyle(.secondary)
                CyberPanel(accent: .purple) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose one clothing mod").font(.title3.weight(.semibold))
                        Text("Start with the original feminine body. CyberMac checks the chosen mod against your installed game's archives.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Choose ZIP or archive…", systemImage: "folder") { chooseFile() }
                                .buttonStyle(CyberButtonStyle(.primary, accent: .purple))
                            if let selectedFile { Text(selectedFile.lastPathComponent).lineLimit(2).textSelection(.enabled) }
                        }
                        if variants.count > 1 {
                            Picker("Clothing variant", selection: $selectedVariant) {
                                Text("Choose one variant").tag("")
                                ForEach(variants, id: \.self) { Text($0).tag($0) }
                            }
                            Text("Choose one alternative; a collection can contain conflicting replacements.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button("Inspect compatibility", systemImage: "magnifyingglass") { Task { await inspect() } }
                            .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
                            .disabled(selectedFile == nil || (variants.count > 1 && selectedVariant.isEmpty))
                    }
                }
                if let plan { inspection(plan) }
                if let staged { installation(staged) }
                if let delivery { itemDelivery(delivery) }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).textSelection(.enabled)
                }
                if let verificationMessage {
                    Text(verificationMessage).textSelection(.enabled)
                }
                if !recent.isEmpty {
                    DisclosureGroup("Recent appearance experiments") {
                        ForEach(recent, id: \.id) { item in
                            Button {
                                plan = item
                                staged = try? AppearancePatchManager(home: CyberMacHomeManager()).loadStage(item.id)
                                delivery = try? AppearancePatchManager(home: CyberMacHomeManager()).loadItemDelivery(item.id)
                                verificationMessage = nil; errorMessage = nil
                            } label: {
                                HStack {
                                    Text(item.packageName).lineLimit(1)
                                    Spacer()
                                    Text(item.createdAt, style: .date).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain).padding(.vertical, 6)
                        }
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .disabled(busy != nil)
        }
        .overlay { if let busy { ProgressOverlay(title: busy) } }
        .task { await loadRecent() }
    }

    private func inspection(_ plan: AppearancePatchPlan) -> some View {
        CyberPanel(accent: plan.canStage ? .green : .amber) {
            VStack(alignment: .leading, spacing: 12) {
                Text(plan.canStage ? "Ready to prepare a clothing test" : "This mod needs another loading route")
                    .font(.title3.weight(.semibold))
                Text("Game \(plan.gameVersion) · \(plan.officialArchiveCount) official archives checked")
                    .foregroundStyle(.secondary)
                Text("\(plan.recordCount) mod resources · \(plan.unmatchedResources.count) new assets · \(plan.unresolvedDependencies.count) unresolved dependencies")
                ForEach(plan.targets, id: \.relativePath) { target in
                    Text("\(URL(fileURLWithPath: target.relativePath).lastPathComponent): \(target.resourceHashes.count) existing resources to replace")
                        .font(.callout).textSelection(.enabled)
                }
                if let target = plan.newResourceTarget {
                    Text("New assets will be added to \(URL(fileURLWithPath: target).lastPathComponent).")
                        .font(.callout).foregroundStyle(.secondary)
                } else if !plan.unmatchedResources.isEmpty {
                    Text("New assets have no single verified destination. This experiment is blocked.")
                        .foregroundStyle(.orange)
                }
                if !plan.itemIDs.isEmpty {
                    DisclosureGroup("Existing garment IDs from the package") {
                        Text(plan.itemIDs.joined(separator: "\n")).textSelection(.enabled)
                    }
                }
                Text("Appearance in-game is unverified. Preparing files creates backups and separate patched copies.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Prepare clothing test", systemImage: "archivebox") { Task { await stage(plan) } }
                    .buttonStyle(CyberButtonStyle(.primary, accent: .green))
                    .disabled(!plan.canStage || staged != nil)
                if !plan.itemIDs.isEmpty {
                    Divider()
                    Text("Get the clothes into your inventory").font(.headline)
                    Text("Prepare a temporary helper that adds this package's \(plan.itemIDs.count) garment(s) when you load V. Already-owned items are skipped. You can test from a separate save slot.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Prepare item delivery…", systemImage: "shippingbox") { chooseDeliveryRuntime(plan) }
                        .buttonStyle(CyberButtonStyle(.secondary, accent: .purple))
                        .disabled(!plan.canStage || delivery != nil)
                    Link("Download the official redscript Mac release (2.5 needs 0.5.32 or newer)",
                         destination: URL(string: "https://github.com/jac3km4/redscript/releases/latest")!)
                        .font(.caption)
                }
            }
        }
    }

    private func itemDelivery(_ delivery: AppearanceItemDelivery) -> some View {
        CyberPanel(accent: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Inventory helper prepared").font(.title3.weight(.semibold))
                Text("\(delivery.packageName) · \(delivery.itemIDs.count) garment(s) · compiler \(delivery.runtimeVersion)")
                    .foregroundStyle(.secondary)
                Text("After manually installing both prepared files, load V to receive the target garments. Open your clothing inventory and check the newest items. The archive patch changes their appearance; the helper supplies the items.")
                CommandBox(command: delivery.installCommand, title: "Install inventory helper", collapsedByDefault: true)
                CommandBox(command: delivery.restoreCommand, title: "Remove helper and restore original scripts", collapsedByDefault: true)
                HStack {
                    Button("Verify helper installed") { Task { await verifyDelivery(delivery, restore: false) } }
                    Button("Verify scripts restored") { Task { await verifyDelivery(delivery, restore: true) } }
                }
                .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
                Text("Compilation is verified; delivery and appearance still need an in-game test. Inventory additions can persist in manual or automatic saves. Use a separate test save and restore the original scripts afterward.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func installation(_ stage: AppearancePatchStage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prepared files and original backups").font(.title2.weight(.semibold))
            Text("Close the game, review the copy commands, and run them manually. Keep the originals until the clothing test and restore have both been checked.")
                .foregroundStyle(.secondary)
            ForEach(stage.files, id: \.relativePath) { file in
                CommandBox(command: file.installCommand, title: "Install \(URL(fileURLWithPath: file.relativePath).lastPathComponent)", collapsedByDefault: true)
                CommandBox(command: file.restoreCommand, title: "Restore original archive", collapsedByDefault: true)
            }
            HStack {
                Button("Verify installed files", systemImage: "checkmark.shield") { Task { await verify(stage, restore: false) } }
                Button("Verify restored originals", systemImage: "arrow.uturn.backward") { Task { await verify(stage, restore: true) } }
            }
            .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
            Text("File verification checks placement only. Equip the garment named by the mod and confirm its appearance in-game.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @MainActor private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip, UTType(filenameExtension: "archive") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectedFile = url; variants = []; selectedVariant = ""
        plan = nil; staged = nil; delivery = nil; verificationMessage = nil; errorMessage = nil
        Task {
            await perform("Reading clothing package…", operation: {
                url.pathExtension.lowercased() == "zip" ? try ModArchiveScanner().scan(zipURL: url).archiveEntries : []
            }) { entries in
                variants = entries
                if entries.count == 1 { selectedVariant = entries[0] }
            }
        }
    }
    @MainActor private func inspect() async {
        guard let file = selectedFile else { return }
        let selected = selectedVariant.isEmpty ? nil : selectedVariant
        let home = CyberMacHomeManager()
        plan = nil; staged = nil; delivery = nil; verificationMessage = nil
        await perform("Checking clothing resources…", operation: {
            let game = try GameInstallDetector().detect()
            return try AppearancePatchManager(home: home).inspect(packageURL: file, game: game, archiveEntry: selected)
        }) { plan = $0 }
        await loadRecent()
    }
    @MainActor private func stage(_ plan: AppearancePatchPlan) async {
        let home = CyberMacHomeManager()
        await perform("Backing up and preparing clothing files…", operation: {
            let game = try GameInstallDetector().detect(preferredAppPath: plan.gameAppPath)
            return try AppearancePatchManager(home: home).stage(id: plan.id, game: game)
        }) { staged = $0 }
    }
    @MainActor private func chooseDeliveryRuntime(_ plan: AppearancePatchPlan) {
        let panel = NSOpenPanel()
        panel.title = "Choose the official redscript Mac ZIP"
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let runtime = panel.url else { return }
        let home = CyberMacHomeManager()
        Task {
            await perform("Compiling clothing item delivery…", operation: {
                let game = try GameInstallDetector().detect(preferredAppPath: plan.gameAppPath)
                return try AppearancePatchManager(home: home).prepareItemDelivery(id: plan.id, game: game, runtimeZipURL: runtime)
            }) { delivery = $0 }
        }
    }
    @MainActor private func verifyDelivery(_ delivery: AppearanceItemDelivery, restore: Bool) async {
        let home = CyberMacHomeManager()
        await perform("Verifying inventory helper files…", operation: {
            let game = try GameInstallDetector().detect(preferredAppPath: delivery.gameAppPath)
            return try AppearancePatchManager(home: home).verifyItemDelivery(id: delivery.planID, game: game, restore: restore)
        }) { result in
            verificationMessage = result.matched
                ? (restore ? "Original scripts verified." : "Inventory helper installed. Delivery still needs an in-game test.")
                : "Game scripts do not match the expected \(restore ? "original" : "prepared") file."
        }
    }
    @MainActor private func verify(_ stage: AppearancePatchStage, restore: Bool) async {
        let home = CyberMacHomeManager()
        await perform("Verifying game files…", operation: {
            let game = try GameInstallDetector().detect(preferredAppPath: stage.gameAppPath)
            return try AppearancePatchManager(home: home).verify(id: stage.planID, game: game, restore: restore)
        }) { result in
            verificationMessage = result.matched
                ? (restore ? "Original archives verified." : "Prepared archives are installed. Check the garment in-game.")
                : "The game files do not match the expected \(restore ? "original" : "prepared") archives."
        }
    }
    @MainActor private func loadRecent() async {
        let home = CyberMacHomeManager()
        recent = (try? await BackgroundTaskRunner.run { try AppearancePatchManager(home: home).recentPlans() }) ?? []
    }
    @MainActor private func perform<Value: Sendable>(_ title: String,
        operation: @escaping @Sendable () throws -> Value, completion: (Value) -> Void) async {
        guard busy == nil else { return }
        busy = title; errorMessage = nil
        defer { busy = nil }
        do { completion(try await BackgroundTaskRunner.run(operation)) }
        catch { errorMessage = String(describing: error) }
    }
}
