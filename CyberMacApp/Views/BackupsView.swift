import SwiftUI

struct BackupsView: View {
    @ObservedObject var appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Backups")
                    .font(.largeTitle.weight(.semibold))
                CyberPanel(accent: .green, interactive: true) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Restore vanilla state")
                                .font(.title3.weight(.semibold))
                            Text("Reverts Cyberpunk's script cache to the latest clean backup. Active CyberMac script changes stay inactive until you activate again.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        PrimaryButton(
                            title: "Prepare restore command",
                            systemImage: "arrow.uturn.backward",
                            disabled: appState.backups.isEmpty,
                            variant: .primary,
                            accent: .green
                        ) {
                            Task { await appState.prepareLatestVanillaRestore() }
                        }
                        .help("Prepare restore command for the newest vanilla backup")
                    }
                }

                if let command = appState.commandToRun, appState.pendingRestoreBackupID != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        CommandBox(command: command.command, title: "Manual restore required", collapsedByDefault: true)
                        HStack {
                            PrimaryButton(
                                title: "I ran it, verify restore",
                                systemImage: "checkmark.seal",
                                disabled: false,
                                variant: .primary,
                                accent: .green
                            ) {
                                Task { await appState.verifyRestore() }
                            }
                            .help("Verify that the restore command was applied")
                            Spacer()
                        }
                    }
                }

                if appState.backups.isEmpty {
                    GlassPanel {
                        Text("No CyberMac bundle backups found.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(appState.backups, id: \.id) { backup in
                        BackupCard(
                            backup: backup,
                            developerMode: appState.developerMode,
                            backupPath: appState.backupDirectoryPath(id: backup.id)
                        ) {
                            Task { await appState.prepareRestore(backupID: backup.id) }
                        }
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}
