import CyberMacCore
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var appState: CyberMacAppState

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
                    Button {
                        Task { await appState.exportDiagnostics() }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                if let report = appState.doctor {
                    CommandBox(command: DoctorReportFormatter.format(report, developerMode: true))
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
}
