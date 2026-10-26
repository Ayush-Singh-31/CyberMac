import CyberMacCore
import SwiftUI
import UniformTypeIdentifiers

struct InstallModsView: View {
    @Bindable var installer: ModInstallerModel
    let appState: CyberMacAppState
    let openClothing: () -> Void
    @State private var choosingFile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Install mods").font(.largeTitle.weight(.semibold))
                        Text("Drop your download. CyberMac identifies it and handles the setup.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clothing", systemImage: "tshirt", action: openClothing)
                        .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
                        .disabled(installer.busy)
                }
                InteractiveDropZone(title: "Drop ZIPs here", subtitle: "Scripts, clothing, appearance mods, or Mac runtime tools") { urls in
                    Task { await installer.enqueue(urls) }
                }
                .overlay(alignment: .bottom) {
                    Button("Or choose files…") { choosingFile = true }
                        .buttonStyle(.link).padding(.bottom, 12)
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield").foregroundStyle(.secondary)
                    Text("Backups and verification are automatic. macOS may ask for your password to update game files.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                HStack {
                    Label(appState.doctor?.game.found == true ? "Cyberpunk 2077 detected" : "Game not detected yet", systemImage: "gamecontroller")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button("Launch game", systemImage: "play.fill") { Task { await appState.launchGame() } }
                        .buttonStyle(CyberButtonStyle(.primary, accent: .cyan))
                        .disabled(installer.busy || appState.currentTask != nil || appState.doctor?.game.found != true)
                }
                if let error = installer.historyError {
                    Text(error).foregroundStyle(.orange).textSelection(.enabled)
                }
                if installer.visibleJobs.contains(where: { $0.phase == .waiting }) {
                    Link("Get the official macOS redscript release", destination: URL(string: "https://github.com/jac3km4/redscript/releases/latest")!)
                }
                if !installer.visibleJobs.isEmpty {
                    Text("Your imports").font(.title2.weight(.semibold))
                    Text("× removes an entry from this list. To undo an installation in the game, use Restore previous files first.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(installer.visibleJobs.reversed()) { job in
                        ImportJobCard(job: job, installer: installer, openClothing: openClothing)
                    }
                } else {
                    Text("If a download contains alternatives, you’ll choose a variant. Mods that need unavailable frameworks will show an explanation here.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if !installer.removedJobs.isEmpty {
                    DisclosureGroup("Recently removed (\(installer.removedJobs.count))") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Removed entries keep their recovery files. Put an entry back to view its details or change its clothing selection.")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(installer.removedJobs) { job in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(job.url.lastPathComponent).lineLimit(2)
                                        if job.phase == .restored || job.phase == .failed || job.phase == .working {
                                            Text(job.message).font(.caption).foregroundStyle(.secondary).lineLimit(3).textSelection(.enabled)
                                        }
                                    }
                                    Spacer()
                                    if job.transaction != nil && job.phase != .restored {
                                        Button("Restore previous files") { Task { await installer.restore(job.id) } }
                                    }
                                    Button("Put back") { Task { await installer.putBackInList(job.id) } }
                                }
                                .disabled(installer.busy)
                            }
                        }.padding(.top, 10)
                    }
                }
            }
            .frame(maxWidth: 950, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.zip, .data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await installer.enqueue(urls) }
            case .failure(let error): installer.historyError = error.localizedDescription
            }
        }
        .sheet(item: $installer.clothingPresentation, onDismiss: { installer.clothingPickerDidDismiss() }) { presentation in
            ClothingImportPickerView(installer: installer, presentation: presentation, onCancel: { installer.dismissClothingPicker() }) { records in
                Task { await installer.installClothingSelection(presentation.id, records: records) }
            }
        }
    }
}

private struct ImportJobCard: View {
    let job: ModImportJob
    let installer: ModInstallerModel
    let openClothing: () -> Void
    @State private var variant = ""

    private var accent: CyberAccent {
        switch job.phase {
        case .installed, .ready, .restored: .green
        case .failed: .red
        case .blocked, .waiting, .choosing, .choosingClothes: .amber
        default: .cyan
        }
    }
    var body: some View {
        CyberPanel(accent: accent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if job.phase == .working { ProgressView().controlSize(.small) }
                    else { Image(systemName: icon).foregroundStyle(accent.color) }
                    Text(job.url.lastPathComponent).font(.headline).lineLimit(2)
                    Spacer()
                    Text(label).font(.caption.weight(.semibold)).foregroundStyle(accent.color)
                    RemoveModButton(label: "Remove \(job.url.lastPathComponent) from this list", disabled: installer.busy || job.phase == .working) {
                        Task { await installer.removeFromList(job.id) }
                    }
                }
                Text(job.message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                if let progress = job.previewProgress {
                    ClothingPreviewProgressView(progress: progress, retry: { installer.resumePreviewRendering(job.id) }, pause: { installer.cancelPreviewRendering(job.id) })
                }
                if job.clothingCatalog != nil {
                    Button("Choose clothes…", systemImage: "square.grid.2x2") { installer.showClothingPicker(job.id) }
                        .disabled(installer.busy)
                }
                if let contents = job.contents, !contents.preparedPieces.isEmpty || contents.archives.count > 1 {
                    ModPackageContentsView(contents: contents)
                    if !contents.preparedPieces.isEmpty {
                        Button("Choose garments in Clothing", systemImage: "tshirt", action: openClothing)
                            .disabled(installer.busy)
                    }
                }
                if let error = job.contentsError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
                if job.phase == .choosing {
                    Picker("Variant", selection: $variant) {
                        Text("Choose a variant…").tag("")
                        ForEach(job.variants, id: \.self) { Text($0).tag($0) }
                    }
                    Button("Install selected variant", systemImage: "square.and.arrow.down") {
                        Task { await installer.retry(job.id, variant: variant) }
                    }
                    .disabled(variant.isEmpty || installer.busy)
                }
                if [.failed, .blocked, .waiting].contains(job.phase) {
                    HStack {
                        Button("Retry", systemImage: "arrow.clockwise") { Task { await installer.retry(job.id) } }
                        if job.transaction != nil {
                            Button("Inspect again") { Task { await installer.retry(job.id, startOver: true) } }
                        }
                    }.disabled(installer.busy)
                }
                if job.transaction != nil && [.installed, .failed].contains(job.phase) {
                    Button("Restore previous files", systemImage: "arrow.uturn.backward") { Task { await installer.restore(job.id) } }
                        .disabled(installer.busy)
                    Text("Restore in reverse install order if several mods changed the same files.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    private var icon: String {
        switch job.phase {
        case .installed, .ready, .restored: "checkmark.circle.fill"
        case .blocked, .failed: "exclamationmark.circle"
        case .choosing, .choosingClothes: "list.bullet"
        default: "clock"
        }
    }
    private var label: String {
        switch job.phase {
        case .queued: "Queued"
        case .working: "Working"
        case .choosing: "Choose a variant"
        case .choosingClothes: "Choose clothes"
        case .waiting: "Needs setup"
        case .ready: "Ready"
        case .installed: "Installed"
        case .blocked: "Needs attention"
        case .failed: "Stopped"
        case .restored: "Restored"
        }
    }
}
