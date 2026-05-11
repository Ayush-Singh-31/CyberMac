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
        NSPasteboard.general.setString(DoctorReportFormatter.format(report, developerMode: true), forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
