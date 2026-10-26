import AppKit
import CyberMacCore
import SwiftUI
import UniformTypeIdentifiers

struct ClothingWardrobeView: View {
    let onImportZIP: (URL) -> Void
    @State private var model = ClothingWardrobeModel()
    @State private var showAdvanced = false
    private let columns = [GridItem(.adaptive(minimum: 205, maximum: 280), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your wardrobe").font(.largeTitle.weight(.semibold))
                    Text("Choose your clothes. Keep every original item.").foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Open prepared wardrobe…") { chooseWorkspace() }
                    Button("Advanced appearance tools…") { showAdvanced = true }
                    if model.wardrobe != nil { Button("Restore original game files") { model.restore() } }
                } label: { Image(systemName: "ellipsis.circle").font(.title2) }
                .menuStyle(.borderlessButton).frame(width: 32)
            }
            if model.wardrobe != nil {
                HStack(spacing: 12) {
                    TextField("Find clothes…", text: $model.search).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                    Picker("Collection", selection: $model.collection) {
                        Text("All").tag("All"); Text("Lucy").tag("Lucy"); Text("Jinguji").tag("Jinguji")
                    }.pickerStyle(.segmented).frame(maxWidth: 290)
                    Spacer()
                    Button("Select from ZIP…", systemImage: "plus") { chooseZIP() }
                }
                HStack(spacing: 14) {
                    Text("\(model.selected.count) selected").font(.callout.weight(.semibold))
                    Button("Select visible") { model.selectVisible() }
                    Button("Clear selection") { model.selected.removeAll() }
                    Spacer()
                    Text("Feminine V · Original body").font(.caption).foregroundStyle(.secondary)
                }.buttonStyle(.borderless)
                ScrollView {
                    if model.visibleItems.isEmpty {
                        ContentUnavailableView.search(text: model.search)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            ForEach(model.visibleItems) { item in card(item) }
                        }
                    }
                    if let wardrobe = model.wardrobe {
                        Text(wardrobe.previewStyle)
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
                    }
                    Text("ZIP selection supports the prepared Lucy set and three Jinguji pieces. Other variants need conversion first.")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                }
                footer
            } else if model.busy == nil {
                ContentUnavailableView {
                    Label("Open your clothing wardrobe", systemImage: "tshirt")
                } description: {
                    Text("Open the prepared wardrobe folder to browse its rendered previews and launch with your chosen pieces. No large files are copied.")
                } actions: {
                    Button("Open wardrobe…") { chooseWorkspace() }.buttonStyle(.borderedProminent)
                }
            }
            if let message = model.message { Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
            if let error = model.error { Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
        }
        .disabled(model.busy != nil)
        .overlay { if let busy = model.busy { ProgressOverlay(title: busy) } }
        .task {
            await model.load()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3)) } catch { break }
                await model.refreshStatus()
            }
        }
        .sheet(isPresented: $showAdvanced) {
            VStack { HStack { Spacer(); Button("Done") { showAdvanced = false } }; AppearanceModsView() }
                .padding().frame(minWidth: 900, minHeight: 700)
        }
    }

    private func card(_ item: ClothingWardrobeItem) -> some View {
        let selected = model.selected.contains(item.id)
        let accent = item.collection == "Lucy" ? CyberAccent.cyan : .purple
        return Button { model.toggle(item.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.40))
                    if let image = NSImage(contentsOf: item.previewURL) {
                        Image(nsImage: image).resizable().scaledToFit().padding(10)
                    }
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title2).foregroundStyle(selected ? accent.color : .secondary)
                        .padding(10)
                }.frame(height: 190)
                HStack {
                    Text(item.collection.uppercased()).font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(accent.color)
                    Spacer(); Text(item.slot).font(.caption2).foregroundStyle(.secondary)
                }
                Text(item.name.replacingOccurrences(of: item.collection + " ", with: ""))
                    .font(.headline).lineLimit(2).frame(height: 42, alignment: .topLeading)
            }
            .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? accent.color.opacity(0.8) : Color.white.opacity(0.08), lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain)
         .accessibilityLabel("\(item.name), \(item.slot), \(selected ? "selected" : "not selected")")
         .disabled(model.session?.isActive == true)
    }

    private var footer: some View {
        CyberPanel(accent: .cyan) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(statusTitle).font(.headline)
                    Text("Selected pieces are added to inventory. Equip them yourself; an active wardrobe outfit can hide them.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Original game files restore after exit. Keep your reference save untouched.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.selected.isEmpty ? "Play without new items" : "Add selected & play", systemImage: "play.fill") {
                    Task { await model.play() }
                }.buttonStyle(CyberButtonStyle(.primary, accent: .cyan)).disabled(!model.canPlay)
            }
        }
    }
    private var statusTitle: String {
        switch model.session {
        case .preparing: "Checking and installing clothes…"
        case .playing: "Game session running"
        case .restoring: "Restoring original game files…"
        case .finished: "Original game files restored"
        case .failed: "Session stopped—check Terminal for details"
        case nil: "Ready when you are"
        }
    }
    private func chooseWorkspace() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.title = "Choose the prepared wardrobe folder"
        if panel.runModal() == .OK, let url = panel.url { Task { await model.openWorkspace(url) } }
    }
    private func chooseZIP() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.zip]; panel.title = "Select a supported clothing ZIP"
        if panel.runModal() == .OK, let url = panel.url { onImportZIP(url) }
    }
}
