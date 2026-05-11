import SwiftUI

struct ActivationView: View {
    @ObservedObject var appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Activation")
                    .font(.largeTitle.weight(.semibold))
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Current bundle", value: appState.doctor?.cache.currentBundle.displayName ?? "unknown")
                        DetailRow(label: "Enabled mods", value: "\(appState.doctor?.activation.enabledMods ?? 0)")
                        DetailRow(label: "Activation state", value: appState.doctor?.activation.state.rawValue ?? "unknown")
                        DetailRow(label: "Base snapshot", value: appState.doctor?.cache.baseSnapshotPresent == true ? "present" : "missing")
                    }
                }
                GlassPanel {
                    HStack(spacing: 12) {
                        PrimaryButton(title: "Dry run", systemImage: "checklist", disabled: false) {
                            Task { await appState.showActivationDryRun() }
                        }
                        PrimaryButton(title: "Generate activation", systemImage: "bolt.fill", disabled: activationBlocked) {
                            Task { await appState.generateActivation() }
                        }
                        PrimaryButton(title: "Verify activation", systemImage: "checkmark.seal", disabled: false) {
                            Task { await appState.verifyActivation() }
                        }
                    }
                }
                if let command = appState.commandToRun {
                    CommandBox(command: command.command)
                } else {
                    GlassPanel {
                        Text("Activation and restore commands will appear here after CyberMac prepares them. Privileged copy and restore remain manual.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var activationBlocked: Bool {
        guard let report = appState.doctor else { return true }
        return report.cache.currentBundle == .externallyChanged || report.cache.currentBundle == .missing || !report.cache.baseSnapshotPresent
    }
}
