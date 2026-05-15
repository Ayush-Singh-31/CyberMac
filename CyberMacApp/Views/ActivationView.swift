import SwiftUI

struct ActivationView: View {
    let appState: CyberMacAppState

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
                inputMappingsPanel
                CyberPanel {
                    HStack(spacing: 12) {
                        PrimaryButton(title: "Verify activation", systemImage: "checkmark.seal", disabled: isBusy, variant: .secondary, accent: .blue) {
                            Task { await appState.verifyActivation() }
                        }
                        .help("Verify that the activation command was applied")
                        if appState.developerMode {
                            PrimaryButton(title: "Dry run", systemImage: "checklist", disabled: isBusy, variant: .secondary, accent: .cyan) {
                                Task { await appState.showActivationDryRun() }
                            }
                            .help("Preview activation commands")
                        }
                    }
                }
                if let command = appState.commandToRun {
                    CommandBox(command: command.displayCommand, title: command.title, collapsedByDefault: false)
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

    private var inputMappingsPanel: some View {
        CyberPanel(accent: inputAccent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Input mappings")
                            .font(.title3.weight(.semibold))
                        Text(inputDetail)
                            .foregroundStyle(.secondary)
                        Text("Status: \(inputStateText)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(inputAccent.color.opacity(0.14), in: Capsule())
                    }
                    Spacer()
                    PrimaryButton(
                        title: inputPrepareTitle,
                        systemImage: "keyboard",
                        disabled: isBusy || (appState.inputStatus?.requiredModCount ?? 0) == 0,
                        variant: .secondary,
                        accent: inputStateText == "Active" ? .blue : .amber
                    ) {
                        Task { await appState.prepareInputPatch() }
                    }
                    PrimaryButton(
                        title: "Verify input patch",
                        systemImage: "checkmark.seal",
                        disabled: isBusy || (appState.inputStatus?.pendingInputPatch == nil),
                        variant: .secondary,
                        accent: .green
                    ) {
                        Task { await appState.verifyInputPatch() }
                    }
                }
                if appState.inputStatus?.pendingInputPatch != nil {
                    Text("Manual input patch required. Copy and run the prepared commands in Terminal, then verify input patch.")
                        .font(.callout)
                        .foregroundStyle(CyberAccent.amber.color)
                }
            }
        }
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
        if isBusy { return true }
        guard let report = appState.doctor else { return true }
        if report.activation.state == .active { return false }
        return activationBlocked || report.activation.enabledMods == 0
    }

    private var isBusy: Bool {
        appState.currentTask != nil
    }

    private var inputDetail: String {
        if inputStateText == "Active" {
            return "Input mappings are active."
        }
        let count = appState.inputStatus?.requiredModCount ?? 0
        if count == 0 { return "No enabled mods require keybind XML." }
        if count == 1 { return "1 enabled mod requires keybind XML." }
        return "\(count) enabled mods require keybind XML."
    }

    private var inputPrepareTitle: String {
        inputStateText == "Active" ? "Rebuild input patch" : "Prepare input patch"
    }

    private var inputStateText: String {
        guard let status = appState.inputStatus else { return "unknown" }
        if status.requiredModCount == 0 { return "Not required" }
        if status.pendingInputPatch != nil { return "Manual copy pending" }
        if Set(status.activeInputPatchModIDs) == Set(status.requiredMods.map(\.id)) { return "Active" }
        return "Patch required"
    }

    private var inputAccent: CyberAccent {
        switch inputStateText {
        case "Active":
            return .green
        case "Not required":
            return .neutral
        case "Manual copy pending":
            return .blue
        default:
            return .amber
        }
    }

    private func runPrimaryAction() async {
        guard !isBusy else { return }
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
