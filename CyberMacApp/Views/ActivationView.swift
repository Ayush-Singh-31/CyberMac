import SwiftUI

struct ActivationView: View {
    @ObservedObject var appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Activation")
                    .font(.largeTitle.weight(.semibold))
                CyberPanel(accent: heroAccent, interactive: !primaryDisabled) {
                    HStack(alignment: .center, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(heroTitle)
                                .font(.title2.weight(.semibold))
                            Text(heroDetail)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        PrimaryButton(
                            title: primaryTitle,
                            systemImage: primaryIcon,
                            disabled: primaryDisabled,
                            variant: .primary,
                            accent: heroAccent
                        ) {
                            Task { await runPrimaryAction() }
                        }
                    }
                }
                CyberPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Current bundle", value: appState.doctor?.cache.currentBundle.displayName ?? "unknown")
                        DetailRow(label: "Enabled mods", value: "\(appState.doctor?.activation.enabledMods ?? 0)")
                        DetailRow(label: "Activation state", value: appState.doctor?.activation.state.rawValue ?? "unknown")
                        DetailRow(label: "Base snapshot", value: appState.doctor?.cache.baseSnapshotPresent == true ? "present" : "missing")
                    }
                }
                CyberPanel {
                    HStack(spacing: 12) {
                        PrimaryButton(title: "Verify activation", systemImage: "checkmark.seal", disabled: false, variant: .secondary, accent: .blue) {
                            Task { await appState.verifyActivation() }
                        }
                        .help("Verify that the activation command was applied")
                        if appState.developerMode {
                            PrimaryButton(title: "Dry run", systemImage: "checklist", disabled: false, variant: .secondary, accent: .cyan) {
                                Task { await appState.showActivationDryRun() }
                            }
                            .help("Preview activation commands")
                        }
                    }
                }
                if let command = appState.commandToRun {
                    CommandBox(command: command.command, title: command.title, collapsedByDefault: false)
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

    private var heroTitle: String {
        guard let report = appState.doctor else { return "Checking activation" }
        if report.cache.currentBundle == .externallyChanged || report.cache.currentBundle == .missing {
            return "Activation blocked"
        }
        if report.activation.state == .active {
            return "Mods are active"
        }
        if report.activation.enabledMods > 0 {
            return "Activation required"
        }
        return "Vanilla state"
    }

    private var heroDetail: String {
        guard let report = appState.doctor else { return "Loading current bundle state." }
        if report.cache.currentBundle == .externallyChanged || report.cache.currentBundle == .missing {
            return "CyberMac detected an unsafe bundle state. Restore a backup or inspect diagnostics before activating."
        }
        if report.activation.state == .active {
            return "\(modCountText(report.activation.enabledMods, active: true)) compiled into the game script cache."
        }
        if report.activation.enabledMods > 0 {
            return "Enabled mods have changed. Generate a new script cache to apply them."
        }
        return "No CyberMac activation is currently applied."
    }

    private var heroAccent: CyberAccent {
        guard let report = appState.doctor else { return .neutral }
        if report.cache.currentBundle == .externallyChanged || report.cache.currentBundle == .missing { return .red }
        if report.activation.state == .active { return .blue }
        if report.activation.enabledMods > 0 { return .amber }
        return .green
    }

    private var primaryTitle: String {
        if appState.doctor?.activation.state == .active { return "Launch game" }
        return "Generate activation"
    }

    private var primaryIcon: String {
        primaryTitle == "Launch game" ? "play.fill" : "bolt.fill"
    }

    private var primaryDisabled: Bool {
        guard let report = appState.doctor else { return true }
        if report.activation.state == .active { return false }
        return activationBlocked || report.activation.enabledMods == 0
    }

    private func runPrimaryAction() async {
        if appState.doctor?.activation.state == .active {
            await appState.launchGame()
        } else {
            await appState.generateActivation()
        }
    }

    private func modCountText(_ count: Int, active: Bool) -> String {
        if count == 1 {
            return active ? "One enabled mod is" : "One enabled mod"
        }
        return "\(count) enabled mods are"
    }
}
