import AppKit
import CyberMacCore
import SwiftUI

enum ArchiveIndexContent {
    static let scopeLines = [
        "Archive Index is a small preview registry, not a 3D renderer.",
        "Previews are PNG/JPEG/WebP images attached to indexed asset paths.",
        "Use the CLI to build the index and import previews from a manifest."
    ]

    static let buildIndexCommand = "swift run cybermac archive-catalog index build --catalog-dir <catalog-path>"
    static let importManifestCommand = "swift run cybermac archive-preview import-manifest --manifest <manifest.json>"

    static let exampleQueries = [
        "crosshair",
        "main_menu",
        "lips_makeup",
        "tattoo_body",
        "garment",
        "hair",
        "player_female_average"
    ]
}

enum ArchiveIndexCategorySelection: Equatable, Hashable, Sendable {
    case any
    case anyVisual
    case specific(String)

    static let allCases: [ArchiveIndexCategorySelection] = [
        .any,
        .anyVisual,
        .specific("ui"),
        .specific("garment"),
        .specific("makeup"),
        .specific("hair"),
        .specific("skin"),
        .specific("tattoo"),
        .specific("weapon"),
        .specific("vehicle"),
        .specific("world"),
        .specific("audio"),
        .specific("unknown")
    ]

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .anyVisual: return "Any visual (no audio)"
        case .specific(let value): return value
        }
    }

    var resolvedCategoryFilter: String? {
        switch self {
        case .any, .anyVisual: return nil
        case .specific(let value): return value
        }
    }

    var resolvedExcludedCategoryFilter: String? {
        switch self {
        case .anyVisual: return "audio"
        case .any, .specific: return nil
        }
    }
}

enum ArchiveIndexExtensionSelection: Equatable, Hashable, Sendable {
    case any
    case specific(String)

    static let visualExtensions: [String] = [
        "xbm", "mesh", "mi", "mlsetup", "ent", "app",
        "inkatlas", "inkwidget", "inkanim", "wem"
    ]

    static let allCases: [ArchiveIndexExtensionSelection] = [.any] + visualExtensions.map(ArchiveIndexExtensionSelection.specific)

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .specific(let value): return value
        }
    }

    var resolvedExtensionFilter: String? {
        switch self {
        case .any: return nil
        case .specific(let value): return value
        }
    }
}

struct ArchiveIndexFilterState: Equatable, Sendable {
    var query: String
    var category: ArchiveIndexCategorySelection
    var ext: ArchiveIndexExtensionSelection
    var archive: String
    var onlyWithPreview: Bool

    static let `default` = ArchiveIndexFilterState(
        query: "",
        category: .anyVisual,
        ext: .any,
        archive: "",
        onlyWithPreview: false
    )

    var isDefault: Bool { self == Self.default }

    mutating func reset() {
        self = .default
    }

    var resolvedArchiveFilter: String? {
        let trimmed = archive.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ArchiveIndexView: View {
    let appState: CyberMacAppState

    @State private var indexStats: ArchiveCatalogIndexStatsReport?
    @State private var previewStats: AssetPreviewStatsReport?
    @State private var loadingStats = false
    @State private var filters: ArchiveIndexFilterState = .default
    @State private var matches: [AssetPreviewSearchMatch] = []
    @State private var searchError: String?
    @State private var lastQuery = ""
    @State private var isSearching = false

    private static let searchLimit = 50
    private let resultColumns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                scopePanel
                statsPanel
                searchPanel
                resultsPanel
            }
            .frame(maxWidth: 980, alignment: .leading)
        }
        .task {
            await loadStats()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Archive Index")
                    .font(.largeTitle.weight(.semibold))
                Text("Search indexed Cyberpunk archive assets and view any attached preview images.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var scopePanel: some View {
        CyberPanel(accent: .amber) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Scope and limitations", systemImage: "info.circle")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ArchiveIndexContent.scopeLines, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(CyberAccent.amber.color)
                                .frame(width: 12)
                            Text(line)
                                .textSelection(.enabled)
                        }
                    }
                }
                .font(.callout)
                CommandBox(
                    command: ArchiveIndexContent.buildIndexCommand,
                    title: "Build the index",
                    collapsedByDefault: true
                )
                CommandBox(
                    command: ArchiveIndexContent.importManifestCommand,
                    title: "Import a preview manifest",
                    collapsedByDefault: true
                )
            }
        }
    }

    private var statsPanel: some View {
        HStack(alignment: .top, spacing: 14) {
            indexStatsCard
            previewStatsCard
        }
    }

    private var indexStatsCard: some View {
        CyberPanel(accent: .cyan) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Index stats", systemImage: "shippingbox")
                    .font(.headline)
                if let stats = indexStats {
                    LabeledRow(label: "Archives", value: "\(stats.archiveCount)")
                    LabeledRow(label: "Asset rows", value: "\(stats.assetRowCount)")
                    LabeledRow(label: "Categories", value: "\(stats.countsByCategory.count)")
                    LabeledRow(label: "Extensions", value: "\(stats.countsByExtension.count)")
                } else if loadingStats {
                    Text("Loading…").foregroundStyle(.secondary)
                } else {
                    Text("No archive index found. Build one first using the CLI.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var previewStatsCard: some View {
        CyberPanel(accent: .green) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Preview stats", systemImage: "photo.on.rectangle")
                    .font(.headline)
                if let stats = previewStats {
                    LabeledRow(label: "Preview rows", value: "\(stats.totalPreviewRows)")
                    LabeledRow(label: "Assets with previews", value: "\(stats.distinctAssetsWithPreviews)")
                    LabeledRow(label: "Distinct kinds", value: "\(stats.countsByKind.count)")
                    LabeledRow(label: "Distinct statuses", value: "\(stats.countsByStatus.count)")
                } else if loadingStats {
                    Text("Loading…").foregroundStyle(.secondary)
                } else {
                    Text("No previews registered yet. Use archive-preview register or import-manifest.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var searchPanel: some View {
        CyberPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button {
                        clearFilters()
                    } label: {
                        Label("Clear filters", systemImage: "xmark.circle")
                            .font(.callout)
                    }
                    .disabled(filters.isDefault && matches.isEmpty)
                }
                HStack(spacing: 10) {
                    TextField("Search asset paths (e.g. crosshair, lips_makeup, hair)", text: $filters.query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await performSearch() } }
                    Button("Search") {
                        Task { await performSearch() }
                    }
                    .disabled(isSearching || filters.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                exampleChipsRow
                filterRow
                Toggle("Only assets with available previews", isOn: $filters.onlyWithPreview)
                    .font(.callout)
                if let searchError {
                    Text(searchError)
                        .font(.callout)
                        .foregroundStyle(CyberAccent.red.color)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var exampleChipsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Try")
                .font(.caption)
                .foregroundStyle(.secondary)
            WrappingHStack(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(ArchiveIndexContent.exampleQueries, id: \.self) { example in
                    Button {
                        filters.query = example
                        Task { await performSearch() }
                    } label: {
                        Text(example)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(CyberAccent.cyan.color.opacity(0.12), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(CyberAccent.cyan.color.opacity(0.22), lineWidth: 1)
                            }
                            .foregroundStyle(CyberAccent.cyan.color)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filterRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Category", selection: $filters.category) {
                        ForEach(ArchiveIndexCategorySelection.allCases, id: \.self) { selection in
                            Text(selection.displayName).tag(selection)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                HStack(spacing: 6) {
                    Text("Extension")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Extension", selection: $filters.ext) {
                        ForEach(ArchiveIndexExtensionSelection.allCases, id: \.self) { selection in
                            Text(selection.displayName).tag(selection)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Spacer()
            }
            HStack(spacing: 6) {
                Text("Archive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    "Optional: Data/archive/Mac/content/basegame_1_engine.archive",
                    text: $filters.archive
                )
                .textFieldStyle(.roundedBorder)
                .font(.callout)
            }
        }
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isSearching {
                Text("Searching…").foregroundStyle(.secondary)
            } else if !lastQuery.isEmpty && matches.isEmpty && searchError == nil {
                Text("No matches found for '\(lastQuery)'.")
                    .foregroundStyle(.secondary)
            }
            if !matches.isEmpty {
                HStack {
                    Text("Showing \(matches.count) result\(matches.count == 1 ? "" : "s")")
                        .font(.headline)
                    Spacer()
                    Text("Limit: \(Self.searchLimit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: resultColumns, alignment: .leading, spacing: 14) {
                    ForEach(Array(matches.enumerated()), id: \.offset) { _, match in
                        ArchiveIndexResultCard(match: match)
                    }
                }
            }
        }
    }

    private func loadStats() async {
        loadingStats = true
        async let index = appState.loadArchiveIndexStats()
        async let preview = appState.loadAssetPreviewStats()
        indexStats = await index
        previewStats = await preview
        loadingStats = false
    }

    private func clearFilters() {
        filters.reset()
        matches = []
        lastQuery = ""
        searchError = nil
    }

    private func performSearch() async {
        let trimmed = filters.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            let report = try await appState.searchArchiveIndex(
                query: trimmed,
                categoryFilter: filters.category.resolvedCategoryFilter,
                excludedCategoryFilter: filters.category.resolvedExcludedCategoryFilter,
                extensionFilter: filters.ext.resolvedExtensionFilter,
                archiveFilter: filters.resolvedArchiveFilter,
                onlyWithPreview: filters.onlyWithPreview,
                limit: Self.searchLimit
            )
            matches = report.matches
            lastQuery = trimmed
        } catch {
            matches = []
            lastQuery = trimmed
            searchError = String(describing: error)
        }
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold))
                .textSelection(.enabled)
        }
    }
}

struct ArchiveIndexResultCard: View {
    let match: AssetPreviewSearchMatch

    var body: some View {
        CyberPanel {
            VStack(alignment: .leading, spacing: 10) {
                previewBox
                VStack(alignment: .leading, spacing: 4) {
                    Text(URL(fileURLWithPath: match.assetPath).lastPathComponent)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Text(match.assetPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                HStack(spacing: 6) {
                    badge(text: match.assetExtension.uppercased(), accent: .cyan)
                    badge(text: match.category, accent: .blue)
                    if match.previewCount > 0 {
                        badge(text: "\(match.previewCount) preview\(match.previewCount == 1 ? "" : "s")", accent: .green)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Archive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(match.archivePath)
                        .font(.caption)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                HStack(spacing: 8) {
                    Button {
                        copyToPasteboard(match.assetPath)
                    } label: {
                        Label("Asset", systemImage: "doc.on.doc")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                    }
                    .controlSize(.small)
                    Button {
                        copyToPasteboard(match.archivePath)
                    } label: {
                        Label("Archive", systemImage: "doc.on.doc")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                    }
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var previewBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.18))
            if let path = match.firstPreviewPath, let image = loadPreviewImage(path: path) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(match.firstPreviewPath == nil ? "No preview" : "Preview missing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 140)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func loadPreviewImage(path: String) -> NSImage? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSImage(contentsOfFile: path)
    }

    private func badge(text: String, accent: CyberAccent) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(accent.color)
            .background(accent.color.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(accent.color.opacity(0.22), lineWidth: 1)
            }
    }

    private func copyToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}
