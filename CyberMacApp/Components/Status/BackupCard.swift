import CyberMacCore
import SwiftUI

struct BackupCard: View {
    let backup: BundleBackupManifest
    let developerMode: Bool
    var backupPath: String?
    let onRestore: () -> Void

    private var summary: BackupDisplaySummary {
        BackupDisplayFormatter.summary(for: backup, developerMode: developerMode)
    }

    var body: some View {
        CyberPanel(accent: .green) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.title)
                            .font(.headline)
                        Text(summary.subtitle)
                            .foregroundStyle(.secondary)
                        Text(summary.detail)
                            .font(.callout)
                    }
                    Spacer()
                    Text(summary.safeLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(CyberAccent.green.color.opacity(0.14), in: Capsule())
                }

                HStack {
                    PrimaryButton(
                        title: backup.priorState == .present ? "Restore" : "Restore",
                        systemImage: "arrow.uturn.backward",
                        disabled: false,
                        variant: .secondary,
                        accent: .green,
                        action: onRestore
                    )
                    .help("Prepare restore command")
                    Spacer()
                }

                if developerMode {
                    DisclosureGroup("Technical details") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(summary.technicalDetails, id: \.label) { detail in
                                DetailRow(label: detail.label, value: detail.value)
                            }
                            if let backupPath {
                                DetailRow(label: "Backup path", value: backupPath)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .cyberCursor()
                }
            }
        }
    }
}
