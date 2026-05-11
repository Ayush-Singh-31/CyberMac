import SwiftUI

struct BackupsView: View {
    @ObservedObject var appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Backups")
                    .font(.largeTitle.weight(.semibold))
                if appState.backups.isEmpty {
                    GlassPanel {
                        Text("No CyberMac bundle backups found.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(appState.backups, id: \.id) { backup in
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Backup \(backup.id)")
                                    .font(.headline)
                                DetailRow(label: "Created", value: backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                                DetailRow(label: "State", value: backup.priorState.rawValue)
                                DetailRow(label: "SHA", value: backup.sha256 ?? "absent")
                                DetailRow(label: "Game fingerprint", value: backup.gameFingerprintID)
                                HStack {
                                    PrimaryButton(title: "Restore", systemImage: "arrow.uturn.backward", disabled: false) {
                                        Task { await appState.prepareRestore(backupID: backup.id) }
                                    }
                                    PrimaryButton(title: "Verify Restore", systemImage: "checkmark.seal", disabled: appState.pendingRestoreBackupID != backup.id) {
                                        Task { await appState.verifyRestore() }
                                    }
                                }
                                .padding(.top, 6)
                            }
                        }
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
