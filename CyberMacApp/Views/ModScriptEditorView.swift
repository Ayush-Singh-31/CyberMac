import AppKit
import CyberMacCore
import SwiftUI

struct ModScriptEditorView: View {
    let mod: InstalledModManifest
    @ObservedObject var appState: CyberMacAppState

    @Environment(\.dismiss) private var dismiss
    @State private var scripts: [EditableScriptFile] = []
    @State private var selectedScript: EditableScriptFile?
    @State private var pendingSelection: EditableScriptFile?
    @State private var contents = ""
    @State private var savedContents = ""
    @State private var backupPath: String?
    @State private var successMessage: String?
    @State private var editorError: String?
    @State private var isListing = false
    @State private var isLoadingScript = false
    @State private var isSaving = false
    @State private var showingCloseConfirmation = false
    @State private var showingReloadConfirmation = false
    @State private var showingSelectionConfirmation = false

    private var isDirty: Bool {
        contents != savedContents
    }

    private var byteCount: Int {
        contents.utf8.count
    }

    private var isBusy: Bool {
        isListing || isLoadingScript || isSaving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            warningBanner
            if let successMessage {
                statusBanner(message: successMessage, accent: .green, systemImage: "checkmark.circle.fill")
            }
            if let editorError {
                statusBanner(message: editorError, accent: .red, systemImage: "xmark.octagon.fill")
            }
            editorLayout
            footer
        }
        .padding(24)
        .task {
            await loadScripts(selectFirst: true)
        }
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: $showingCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard changes", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This script has unsaved changes.")
        }
        .confirmationDialog(
            "Reload script?",
            isPresented: $showingReloadConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reload", role: .destructive) {
                Task { await reloadSelectedScript() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reloading discards unsaved changes in the editor.")
        }
        .confirmationDialog(
            "Switch scripts?",
            isPresented: $showingSelectionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard changes", role: .destructive) {
                guard let pendingSelection else { return }
                self.pendingSelection = nil
                Task { await loadScript(pendingSelection) }
            }
            Button("Cancel", role: .cancel) {
                pendingSelection = nil
            }
        } message: {
            Text("Switching scripts discards unsaved changes in the editor.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Edit scripts")
                    .font(.title2.weight(.semibold))
                Text(ModDisplayFormatter.displayName(for: mod))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isDirty {
                Label("Unsaved changes", systemImage: "pencil.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CyberAccent.amber.color)
            } else {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CyberAccent.green.color)
            }
        }
    }

    private var warningBanner: some View {
        statusBanner(
            message: "Saving edits marks scripts out of sync. Reactivate scripts in the Activation tab before launching the game.",
            accent: .amber,
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    private var editorLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            scriptList
                .frame(width: 260)
            editorPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 430)
    }

    private var scriptList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Files", systemImage: "doc.text")
                    .font(.headline)
                Spacer()
                if isListing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if scripts.isEmpty {
                Text(isListing ? "Loading scripts..." : "No editable .reds files found.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(scripts) { script in
                            scriptButton(script)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedScript?.relativePath ?? "No file selected")
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("\(byteCount) UTF-8 bytes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isLoadingScript {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            TextEditor(text: $contents)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .disabled(selectedScript == nil || isBusy)

            if let backupPath {
                Label("Backup: \(backupPath)", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                if isDirty {
                    showingReloadConfirmation = true
                } else {
                    Task { await reloadSelectedScript() }
                }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan, minWidth: 116))
            .disabled(selectedScript == nil || isBusy)

            Button {
                Task { await saveSelectedScript() }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .buttonStyle(CyberButtonStyle(.primary, accent: .green, minWidth: 116))
            .disabled(selectedScript == nil || !isDirty || isBusy)

            Button {
                revealSelectedInFinder()
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .buttonStyle(CyberButtonStyle(.secondary, accent: .blue, minWidth: 150))
            .disabled(selectedScript == nil)

            Spacer()

            Button {
                if isDirty {
                    showingCloseConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .buttonStyle(CyberButtonStyle(.secondary, accent: .neutral, minWidth: 116))
        }
    }

    private func scriptButton(_ script: EditableScriptFile) -> some View {
        Button {
            selectScript(script)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedScript?.id == script.id ? "doc.text.fill" : "doc.text")
                    .foregroundStyle(selectedScript?.id == script.id ? CyberAccent.cyan.color : .secondary)
                Text(script.relativePath)
                    .font(.callout)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedScript?.id == script.id ? CyberAccent.cyan.color.opacity(0.14) : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private func statusBanner(message: String, accent: CyberAccent, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(accent.color)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(accent.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.color.opacity(0.18), lineWidth: 1)
        }
    }

    private func selectScript(_ script: EditableScriptFile) {
        guard selectedScript?.id != script.id else { return }
        successMessage = nil
        editorError = nil
        if isDirty {
            pendingSelection = script
            showingSelectionConfirmation = true
        } else {
            Task { await loadScript(script) }
        }
    }

    @MainActor
    private func loadScripts(selectFirst: Bool) async {
        isListing = true
        defer { isListing = false }
        let files = await appState.listEditableScripts(for: mod.id)
        scripts = files

        guard selectFirst else { return }
        guard let first = files.first else {
            selectedScript = nil
            contents = ""
            savedContents = ""
            return
        }
        await loadScript(first)
    }

    @MainActor
    private func loadScript(_ script: EditableScriptFile) async {
        isLoadingScript = true
        defer { isLoadingScript = false }
        do {
            let loaded = try await appState.loadScript(modID: mod.id, relativePath: script.relativePath)
            selectedScript = script
            contents = loaded
            savedContents = loaded
            backupPath = nil
            successMessage = nil
            editorError = nil
        } catch is CancellationError {
        } catch {
            editorError = String(describing: error)
        }
    }

    @MainActor
    private func reloadSelectedScript() async {
        guard let selectedScript else { return }
        await loadScript(selectedScript)
    }

    @MainActor
    private func saveSelectedScript() async {
        guard let selectedScript, isDirty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let result = try await appState.saveScript(modID: mod.id, relativePath: selectedScript.relativePath, contents: contents)
            if let index = scripts.firstIndex(where: { $0.id == selectedScript.id }) {
                scripts[index] = result.file
            }
            self.selectedScript = result.file
            savedContents = contents
            backupPath = result.backupPath
            successMessage = "Script saved. Scripts are now out of sync. Reactivate scripts before launching the game."
            editorError = nil
        } catch is CancellationError {
        } catch {
            editorError = String(describing: error)
        }
    }

    @MainActor
    private func revealSelectedInFinder() {
        guard let selectedScript else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: selectedScript.absolutePath)])
    }
}
