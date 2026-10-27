import AppKit
import CyberMacCore
import SwiftUI

struct ClothingImportPickerView: View {
    let installer: ModInstallerModel
    let presentation: ClothingImportPresentation
    let onCancel: () -> Void
    let onInstall: ([String]) -> Void
    @State private var selected: Set<String>
    @State private var search = ""
    @State private var category = "All"
    @State private var readyOnly: Bool
    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 16)]

    init(installer: ModInstallerModel, presentation: ClothingImportPresentation, onCancel: @escaping () -> Void, onInstall: @escaping ([String]) -> Void) {
        self.installer = installer
        self.presentation = presentation; self.onCancel = onCancel; self.onInstall = onInstall
        _selected = State(initialValue: presentation.selectedRecords.intersection(Set(presentation.catalog.availableItems.compactMap(\.record))))
        _readyOnly = State(initialValue: false)
    }

    private var catalog: ClothingImportCatalog { installer.jobs.first { $0.id == presentation.id }?.clothingCatalog ?? presentation.catalog }
    private var progress: ClothingPreviewProgress? { installer.jobs.first { $0.id == presentation.id }?.previewProgress }

    private var visible: [ClothingImportCatalog.Item] {
        catalog.items.filter {
            (!readyOnly || $0.canSelect) && (category == "All" || $0.category == category) &&
            (search.isEmpty || ($0.name + " " + $0.category).localizedCaseInsensitiveContains(search))
        }
    }
    private var categories: [String] { Array(Set(catalog.items.map(\.category))).sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: CyberStyle.sectionSpacing) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    CyberPageTitle("Choose your clothes")
                    Text(presentation.packageName).foregroundStyle(.secondary).lineLimit(2)
                    Text("Only the pieces you check will be added from this ZIP.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            }
            Divider()
            if let notice = catalog.notice {
                Text(notice).font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            if installer.liveClothingPreviewsEnabled, let progress {
                ClothingPreviewProgressView(progress: progress, retry: { installer.resumePreviewRendering(presentation.id) }, pause: { installer.cancelPreviewRendering(presentation.id) })
            }
            Picker("Show clothes", selection: $readyOnly) {
                Text("Ready to install (\(catalog.availableItems.count))").tag(true)
                Text("All variants (\(catalog.items.count))").tag(false)
            }.pickerStyle(.segmented)
            HStack(spacing: 14) {
                TextField("Find a garment or colour…", text: $search).textFieldStyle(.roundedBorder)
                Picker("Category", selection: $category) {
                    Text("All").tag("All")
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }.frame(maxWidth: 250)
            }
            HStack {
                Text("\(selected.count) selected").font(.callout.weight(.semibold))
                Button("Select visible") { selected.formUnion(visible.filter(\.canSelect).compactMap(\.record)) }
                    .disabled(!visible.contains(where: \.canSelect))
                Button("Clear selection") { selected.removeAll() }.disabled(selected.isEmpty)
                Spacer()
            }.buttonStyle(CyberButtonStyle(.ghost)).controlSize(.small)
            ScrollView {
                if visible.isEmpty {
                    ContentUnavailableView("No matching clothes", systemImage: "tshirt", description: Text("Try another category or search."))
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(visible) { item in
                            ClothingImportCard(item: item, selected: item.record.map { selected.contains($0) } ?? false, rendering: installer.liveClothingPreviewsEnabled && progress?.isActive == true) {
                                guard item.canSelect, let record = item.record else { return }
                                if selected.contains(record) { selected.remove(record) } else { selected.insert(record) }
                            }
                            .onAppear { installer.requestPreview(presentation.id, archivePath: item.archivePath) }
                            .onDisappear { installer.releasePreview(presentation.id, archivePath: item.archivePath) }
                        }
                    }.padding(3)
                }
            }
            Divider()
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selections from other clothing packs are kept.")
                    Text("Chosen pieces are added as separate inventory items. Load a save after installation to receive them; items already in your save are kept.")
                    if installer.liveClothingPreviewsEnabled {
                        Text("Fast previews use real garment shapes with approximate colours. Fabric patterns, shine and reflections are simplified.")
                    } else {
                        Text("Live previews are paused. Saved images are shown when available; no Blender rendering runs while you browse.")
                    }
                }.font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Install selected (\(selected.count))", systemImage: "square.and.arrow.down") { onInstall(selected.sorted()) }
                    .buttonStyle(CyberButtonStyle(.primary, accent: .cyan))
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(CyberStyle.pagePadding)
        .frame(minWidth: 920, idealWidth: 1040, minHeight: 760, idealHeight: 860)
        .cyberSheet()
    }
}

private struct ClothingImportCard: View {
    let item: ClothingImportCatalog.Item
    let selected: Bool
    let rendering: Bool
    let toggle: () -> Void
    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.3))
                    if let url = item.previewURL, let image = NSImage(contentsOf: url) {
                        Image(nsImage: image).resizable().scaledToFit().padding(10)
                    } else {
                        VStack(spacing: 8) {
                            if rendering && item.previewError == nil { ProgressView() }
                            else { Image(systemName: "tshirt").font(.system(size: 34)) }
                            Text(item.previewError != nil ? "Could not render preview" : (rendering ? "Loading preview…" : "No saved image")).font(.caption)
                        }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    if item.canSelect {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(selected ? CyberAccent.cyan.color : .secondary).padding(10)
                    }
                }.frame(height: 190)
                Text(item.category).font(.caption).foregroundStyle(.secondary)
                Text(item.name).font(.headline).lineLimit(3).frame(height: 56, alignment: .topLeading)
                Text(item.canSelect ? (selected ? "Selected" : "Click to select") : "Not supported yet")
                    .font(.caption.weight(.semibold)).foregroundStyle(item.canSelect ? CyberAccent.cyan.color : CyberAccent.amber.color)
                if let reason = item.unavailableReason { Text(reason).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
            }
            .padding(12)
            .cyberSurface(selected: selected)
        }
        .buttonStyle(.plain)
        .help(item.previewError ?? item.unavailableReason ?? item.name)
        .accessibilityLabel("\(item.name), \(item.canSelect ? (selected ? "selected" : "not selected") : "not ready")")
    }
}
