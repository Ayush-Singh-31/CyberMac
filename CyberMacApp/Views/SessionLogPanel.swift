import AppKit
import CyberMacCore
import SwiftUI

struct SessionLogPanel: View {
    let model: SessionLogCaptureModel
    @State private var marker = ""

    var body: some View {
        CyberPanel(accent: .cyan) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Game session recording").font(.title3.weight(.semibold))
                Text("Start before playing and keep CyberMac open. Records available game and CyberMac messages, plus markers you add. Internal inventory and clothing events are not instrumented yet.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button(model.isRecording ? "Stop recording" : "Start recording", systemImage: model.isRecording ? "stop.circle" : "record.circle") {
                        Task { if model.isRecording { await model.stop() } else { await model.start() } }
                    }
                    .buttonStyle(CyberButtonStyle(.primary, accent: .cyan))
                    .disabled(model.busy)
                    if let report = model.report {
                        Text("\(status(report.status)) · \(ByteCountFormatter.string(fromByteCount: Int64(report.capturedBytes), countStyle: .file))")
                            .foregroundStyle(.secondary)
                    }
                }
                if model.isRecording {
                    HStack {
                        TextField("Marker, e.g. equipped Lucy jacket", text: $marker)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { saveMarker() }
                        Button("Add marker") { saveMarker() }
                            .disabled(marker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Text("Local only · Up to 1 hour or 10 GB per session · Keeps the latest 3 sessions (up to 30 GB)")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = model.report?.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                if let error = model.errorMessage { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                if !model.recent.isEmpty {
                    DisclosureGroup("Recorded sessions") {
                        ForEach(model.recent, id: \.id) { report in
                            HStack {
                                Text(report.startedAt, style: .date)
                                Text(report.startedAt, style: .time)
                                Text(report.status == .recording && (model.report?.id != report.id || !model.isRecording)
                                     ? "Recording status unknown" : status(report.status)).foregroundStyle(.secondary)
                                Spacer()
                                Button("Show files") { NSWorkspace.shared.open(URL(fileURLWithPath: report.folderPath)) }
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }.padding(16)
        }
        .task {
            while !Task.isCancelled {
                model.refresh()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    private func saveMarker() { if model.addMarker(marker) { marker = "" } }
    private func status(_ value: GameSessionLogReport.Status) -> String {
        switch value {
        case .recording: "Recording available messages"
        case .stopped: "Stopped"
        case .completed: "Recording ended"
        case .sizeLimitReached: "Size limit reached"
        case .failed: "Capture failed"
        }
    }
}
