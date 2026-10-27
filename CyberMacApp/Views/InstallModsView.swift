import CyberMacCore
import SwiftUI
import UniformTypeIdentifiers

struct InstallModsView: View {
    @Bindable var installer: ModInstallerModel
    let appState: CyberMacAppState
    let openClothing: () -> Void
    @State private var choosingFile = false
    @State private var selectedImportID: UUID?

    private var selectedImport: ModImportJob? {
        installer.visibleJobs.first { $0.id == selectedImportID } ?? installer.visibleJobs.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            gameControls
            Divider()
            GeometryReader { geometry in
                if geometry.size.width >= 760 {
                    HStack(alignment: .top, spacing: 24) {
                        ScrollView { importList.padding(3) }
                            .frame(maxWidth: .infinity)
                        Divider()
                        ScrollView { inspector.padding(.trailing, 3) }
                            .frame(width: 296)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            importList
                            Divider()
                            inspector
                        }.padding(3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: installer.visibleJobs.map(\.id)) { previous, current in
            if let newest = current.last, !previous.contains(newest) {
                selectedImportID = newest
            } else if let selectedImportID, !current.contains(selectedImportID) {
                self.selectedImportID = nil
            }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.zip, .data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): importFiles(urls)
            case .failure(let error): installer.historyError = error.localizedDescription
            }
        }
        .sheet(item: $installer.clothingPresentation, onDismiss: { installer.clothingPickerDidDismiss() }) { presentation in
            ClothingImportPickerView(installer: installer, presentation: presentation, onCancel: { installer.dismissClothingPicker() }) { records in
                Task { await installer.installClothingSelection(presentation.id, records: records) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            CyberPageTitle("Install mods", subtitle: "Drop your download. CyberMac identifies it and handles the setup.")
            Spacer(minLength: 12)
            Button("Clothing", systemImage: "tshirt", action: openClothing)
                .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
                .disabled(installer.busy)
        }
    }

    private var gameControls: some View {
        HStack(spacing: 18) {
            Label(appState.doctor?.game.found == true ? "Cyberpunk 2077 detected" : "Game not detected yet", systemImage: "gamecontroller")
                .font(.callout).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Button("Launch game", systemImage: "play.fill") { Task { await appState.launchGame() } }
                .buttonStyle(CyberButtonStyle(.primary, accent: .cyan))
                .disabled(installer.busy || appState.currentTask != nil || appState.doctor?.game.found != true)
        }
    }

    private var importList: some View {
        VStack(alignment: .leading, spacing: 24) {
            ImportDropZone(chooseFiles: { choosingFile = true }, onFiles: importFiles)
            Label("Backups and verification are automatic. macOS may ask for your password to update game files.", systemImage: "checkmark.shield")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error = installer.historyError {
                Text(error).foregroundStyle(.orange).textSelection(.enabled)
            }
            if installer.isLoadingHistory { ProgressView("Loading your imports…") }
            if installer.visibleJobs.contains(where: { $0.phase == .waiting }) {
                Link("Get the official macOS redscript release", destination: URL(string: "https://github.com/jac3km4/redscript/releases/latest")!)
            }
            Text("Your imports").font(.title2.weight(.semibold))
            if installer.visibleJobs.isEmpty {
                Text("If a download contains alternatives, you’ll choose a variant. Mods that need unavailable frameworks will show an explanation here.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(installer.visibleJobs.reversed()) { job in
                        ImportJobRow(job: job, selected: selectedImport?.id == job.id, installer: installer) {
                            selectedImportID = job.id
                        }
                    }
                }
                Text("× removes an entry from this list. To undo an installation in the game, use Restore previous files first.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            recentlyRemoved
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Import details").font(.callout).foregroundStyle(.secondary)
            if let job = selectedImport {
                ImportDetailsView(job: job, installer: installer, openClothing: openClothing)
                    .id(job.id)
            } else {
                Text("Select an import to view its details.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var recentlyRemoved: some View {
        if !installer.removedJobs.isEmpty {
            DisclosureGroup("Recently removed (\(installer.removedJobs.count))") {
                VStack(alignment: .leading, spacing: CyberStyle.sectionSpacing) {
                    Text("Removed entries keep their recovery files. Put an entry back to view its details or change its clothing selection.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(installer.removedJobs) { job in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(job.url.lastPathComponent).lineLimit(2)
                            if [.restored, .failed, .working].contains(job.phase) {
                                Text(job.message).font(.caption).foregroundStyle(.secondary).lineLimit(3).textSelection(.enabled)
                            }
                            HStack {
                                if job.transaction != nil && job.phase != .restored {
                                    Button("Restore previous files") { Task { await installer.restore(job.id) } }
                                }
                                Button("Put back") {
                                    Task {
                                        await installer.putBackInList(job.id)
                                        selectedImportID = job.id
                                    }
                                }
                            }.controlSize(.small)
                        }
                        .disabled(installer.busy)
                        Divider()
                    }
                }.padding(.top, 10)
            }
        }
    }

    private func importFiles(_ urls: [URL]) {
        selectedImportID = nil
        Task { await installer.enqueue(urls) }
    }
}

private struct ImportDropZone: View {
    let chooseFiles: () -> Void
    let onFiles: ([URL]) -> Void
    @State private var isTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CyberPanel(accent: .cyan, interactive: true) {
            HStack(spacing: 18) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "square.and.arrow.down")
                    .font(.system(size: 30)).foregroundStyle(CyberAccent.cyan.color)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drop ZIPs here").font(.headline)
                    Text("Scripts, clothing, appearance mods, or Mac runtime tools")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Or choose files…", action: chooseFiles).buttonStyle(.link)
                }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CyberStyle.panelRadius).stroke(CyberAccent.cyan.color.opacity(isTargeted ? 0.7 : 0), lineWidth: 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isTargeted)
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            onFiles(urls)
            return true
        } isTargeted: { isTargeted = $0 }
        .help("Drop a mod archive")
    }
}

private struct ImportJobRow: View {
    let job: ModImportJob
    let selected: Bool
    let installer: ModInstallerModel
    let select: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: select) {
                HStack(alignment: .top, spacing: 12) {
                    if job.phase == .working { ProgressView().controlSize(.small) }
                    else { Image(systemName: job.phase.importIcon).foregroundStyle(job.phase.importAccent.color) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(job.url.lastPathComponent).font(.headline).lineLimit(2)
                        if !selected {
                            Text(job.message).font(.callout).foregroundStyle(.secondary).lineLimit(3)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text(job.phase.importLabel).font(.caption.weight(.semibold)).foregroundStyle(job.phase.importAccent.color)
                }.padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(job.url.lastPathComponent), \(job.phase.importLabel)")
            .accessibilityValue(selected ? "Selected" : "")
            RemoveModButton(label: "Remove \(job.url.lastPathComponent) from this list", disabled: installer.busy || job.phase == .working) {
                Task { await installer.removeFromList(job.id) }
            }
        }
        .padding(16)
        .cyberSurface(radius: CyberStyle.rowRadius, selected: selected)
    }
}

private struct ImportDetailsView: View {
    @Environment(\.openURL) private var openURL
    let job: ModImportJob
    let installer: ModInstallerModel
    let openClothing: () -> Void
    @State private var variant = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(job.url.lastPathComponent).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(job.phase.importLabel).font(.caption.weight(.semibold)).foregroundStyle(job.phase.importAccent.color)
            }
            Text(job.message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            if job.phase != .installed, SystemModInstaller.needsAppManagement(job.lastFailure ?? job.message) {
                Button("Open App Management", systemImage: "lock.shield") {
                    openURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles")!)
                }
            }
            if job.phase != .failed, let failure = job.lastFailure {
                DisclosureGroup("Previous installation error") {
                    Text(failure).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            if installer.liveClothingPreviewsEnabled, let progress = job.previewProgress {
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
                Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
            }
            if job.phase == .choosing {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Variant", selection: $variant) {
                        Text("Choose a variant…").tag("")
                        ForEach(job.variants, id: \.self) { Text($0).tag($0) }
                    }
                    Button("Install selected variant", systemImage: "square.and.arrow.down") {
                        Task { await installer.retry(job.id, variant: variant) }
                    }.disabled(variant.isEmpty || installer.busy)
                }
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
                VStack(alignment: .leading, spacing: 8) {
                    Button("Restore previous files", systemImage: "arrow.uturn.backward") { Task { await installer.restore(job.id) } }
                        .disabled(installer.busy)
                    Text("Restore in reverse install order if several mods changed the same files.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private extension ModImportPhase {
    var importAccent: CyberAccent {
        switch self {
        case .installed, .ready, .restored: .green
        case .failed: .red
        case .blocked, .waiting, .choosing, .choosingClothes: .amber
        default: .cyan
        }
    }

    var importIcon: String {
        switch self {
        case .installed, .ready, .restored: "checkmark.circle.fill"
        case .blocked, .failed: "exclamationmark.circle"
        case .choosing, .choosingClothes: "list.bullet"
        default: "clock"
        }
    }

    var importLabel: String {
        switch self {
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
