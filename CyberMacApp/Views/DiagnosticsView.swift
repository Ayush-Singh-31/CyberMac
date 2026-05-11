import AppKit
import CyberMacCore
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var appState: CyberMacAppState
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Diagnostics")
                        .font(.largeTitle.weight(.semibold))
                    Spacer()
                    Button {
                        Task { await appState.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
                    .help("Refresh diagnostics")
                    Button {
                        copyDiagnostics()
                    } label: {
                        Label(copied ? "Copied" : "Copy diagnostics", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
                    .help("Copy diagnostic report")
                    Button {
                        Task { await appState.exportDiagnostics() }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(CyberButtonStyle(.primary, accent: .cyan))
                    .help("Export diagnostic report")
                }
                if let report = appState.doctor {
                    diagnosticsBox(DoctorReportFormatter.format(report, developerMode: true))
                } else {
                    GlassPanel {
                        Text("No diagnostic report loaded.")
                            .foregroundStyle(.secondary)
                    }
                }
                if let status = appState.inputStatus {
                    diagnosticsBox(inputDiagnosticsText(status))
                }
                if let command = appState.commandToRun {
                    CommandBox(command: command.command)
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func diagnosticsBox(_ text: String) -> some View {
        CyberPanel(accent: .cyan) {
            ScrollView([.vertical, .horizontal]) {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 420)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func copyDiagnostics() {
        guard let report = appState.doctor else { return }
        NSPasteboard.general.clearContents()
        let input = appState.inputStatus.map(inputDiagnosticsText) ?? ""
        NSPasteboard.general.setString([DoctorReportFormatter.format(report, developerMode: true), input].filter { !$0.isEmpty }.joined(separator: "\n\n"), forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }

    private func inputDiagnosticsText(_ status: InputPatchStatus) -> String {
        var lines: [String] = []
        lines.append("Input mappings")
        lines.append("  Required mods: \(status.requiredModCount)")
        lines.append("  Pending input patch: \(status.pendingInputPatch?.id ?? "none")")
        lines.append("  Active input patch mods: \(status.activeInputPatchModIDs.joined(separator: ", "))")
        lines.append("  Target inputContexts: \(status.targetInputContextsPath ?? "unknown")")
        lines.append("  Target inputUserMappings: \(status.targetInputUserMappingsPath ?? "unknown")")
        lines.append("  Next step: \(status.nextStep)")
        return lines.joined(separator: "\n")
    }
}
