import CyberMacCore
import SwiftUI

struct BackupsView: View {
    let appState: CyberMacAppState

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
                        CommandBox(command: command.displayCommand, title: "Manual restore required", collapsedByDefault: true)
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("Input config backups")
                        .font(.title2.weight(.semibold))
                    if let command = appState.commandToRun, appState.pendingInputConfigBackupID != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            CommandBox(command: command.displayCommand, title: "Manual input config restore required", collapsedByDefault: true)
                            HStack {
                                PrimaryButton(
                                    title: "I ran it, verify input restore",
                                    systemImage: "checkmark.seal",
                                    disabled: false,
                                    variant: .primary,
                                    accent: .green
                                ) {
                                    Task { await appState.verifyInputConfigRestore() }
                                }
                                .help("Verify that the input config restore command was applied")
                                Spacer()
                            }
                        }
                    }
                    if appState.inputBackups.isEmpty {
                        GlassPanel {
                            Text("No CyberMac input config backups found.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(appState.inputBackups, id: \.id) { backup in
                            InputBackupCard(backup: backup, developerMode: appState.developerMode) {
                                Task { await appState.prepareInputConfigRestore(backupID: backup.id) }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

private struct InputBackupCard: View {
    let backup: InputConfigBackupManifest
    let developerMode: Bool
    let restore: () -> Void

    var body: some View {
        CyberPanel(accent: .green) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input config backup")
                        .font(.headline)
                    Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                    Text("Restores inputContexts_mac.xml and inputUserMappings.xml")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if developerMode {
                        Text("Backup ID: \(backup.id)\nGame fingerprint: \(backup.gameFingerprintID)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Spacer()
                PrimaryButton(
                    title: "Restore input config",
                    systemImage: "arrow.uturn.backward",
                    disabled: false,
                    variant: .secondary,
                    accent: .green,
                    action: restore
                )
            }
        }
    }
}
