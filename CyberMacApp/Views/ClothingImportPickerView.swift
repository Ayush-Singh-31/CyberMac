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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose your clothes").font(.largeTitle.weight(.semibold))
                    Text(presentation.packageName).foregroundStyle(.secondary).lineLimit(2)
                    Text("Only the pieces you check will be added from this ZIP.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            }
            if let notice = catalog.notice {
                Text(notice).font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            if let progress {
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
            }.buttonStyle(.borderless)
            ScrollView {
                if visible.isEmpty {
                    ContentUnavailableView("No matching clothes", systemImage: "tshirt", description: Text("Try another category or search."))
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(visible) { item in
                            ClothingImportCard(item: item, selected: item.record.map { selected.contains($0) } ?? false, rendering: progress?.isActive == true) {
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
                    Text("These pieces will be used for your next Clothing → Play session. Items already in your save are not removed.")
                    Text("Fast previews use real garment shapes with approximate colours. Fabric patterns, shine and reflections are simplified.")
                    if catalog.items.contains(where: { $0.record == nil }) {
                        Text("Rendering previews does not install game files. Preview-only variants still need installation support.")
                    }
                }.font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Install selected (\(selected.count))", systemImage: "square.and.arrow.down") { onInstall(selected.sorted()) }
                    .buttonStyle(CyberButtonStyle(.primary, accent: .cyan))
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(26)
        .frame(minWidth: 920, idealWidth: 1040, minHeight: 760, idealHeight: 860)
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
                            Text(item.previewError != nil ? "Could not render preview" : (rendering ? "Loading preview…" : "Preview unavailable")).font(.caption)
                        }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    if item.canSelect {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(selected ? CyberAccent.cyan.color : .secondary).padding(10)
                    }
                }.frame(height: 190)
                Text(item.category).font(.caption).foregroundStyle(.secondary)
                Text(item.name).font(.headline).lineLimit(3).frame(height: 56, alignment: .topLeading)
                Text(item.canSelect ? (selected ? "Selected" : "Click to select") : (item.record == nil ? "Preview only" : "Open wardrobe first"))
                    .font(.caption.weight(.semibold)).foregroundStyle(item.canSelect ? CyberAccent.cyan.color : CyberAccent.amber.color)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? CyberAccent.cyan.color : Color.white.opacity(0.08), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .help(item.previewError ?? item.unavailableReason ?? item.name)
        .accessibilityLabel("\(item.name), \(item.canSelect ? (selected ? "selected" : "not selected") : "not ready")")
    }
}
