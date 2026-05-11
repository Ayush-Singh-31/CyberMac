import CyberMacCore
import SwiftUI

struct HomeView: View {
    @ObservedObject var appState: CyberMacAppState

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                statusCards
                primaryPanel
                warnings
                diagnosticsDisclosure
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CyberMac")
                    .font(.largeTitle.weight(.semibold))
                HStack(spacing: 10) {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                    if let storefront = appState.doctor?.game.storefront, appState.doctor?.game.found == true {
                        Text(storefront)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
            }
            Spacer()
            Button {
                Task { await appState.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
            .help("Refresh CyberMac state")
        }
    }

    private var statusCards: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            StatusCard(title: "Game", status: gameStatus.text, systemImage: "gamecontroller", tint: gameStatus.color, accent: .green)
            StatusCard(title: "redscript", status: runtimeStatus.text, systemImage: "terminal", tint: runtimeStatus.color, accent: .cyan)
            StatusCard(title: "Cache", status: cacheStatus.text, systemImage: "archivebox", tint: cacheStatus.color, accent: .green)
            StatusCard(
                title: "Activation",
                status: activationStatus.text,
                systemImage: "bolt.circle",
                tint: activationStatus.color,
                accent: .blue,
                highlighted: appState.doctor?.activation.state == .active
            )
        }
    }

    private var primaryPanel: some View {
        GlassPanel {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(primaryTitle)
                        .font(.title3.weight(.semibold))
                    Text(primaryDetail)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                PrimaryButton(title: primaryButtonTitle, systemImage: primaryButtonImage, disabled: primaryButtonDisabled, accent: .blue) {
                    Task { await runPrimaryAction() }
                }
                .help(primaryButtonTitle)
            }
        }
    }

    @ViewBuilder
    private var warnings: some View {
        if let report = appState.doctor, !report.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(visibleWarnings(report).indices, id: \.self) { index in
                    let warning = visibleWarnings(report)[index]
                    WarningBanner(
                        message: warning.message,
                        title: warning.code.contains("input-loader") ? "Known input-loader issue detected" : "CyberMac warning",
                        kind: warning.code.contains("bundle") ? .blocked : .warning,
                        onDismiss: warning.code.contains("input-loader") ? { appState.dismissInputLoaderWarning() } : nil
                    )
                }
            }
        }
        if inputNeedsPatch {
            WarningBanner(
                message: "One or more enabled mods require keybind XML before they are fully active.",
                title: "Mods need input patch",
                kind: .warning
            )
        }
    }

    @ViewBuilder
    private var diagnosticsDisclosure: some View {
        if let report = appState.doctor {
            DisclosureGroup("Show diagnostics") {
                CommandBox(command: DoctorReportFormatter.format(report, developerMode: true))
                    .padding(.top, 8)
            }
            .padding(.top, 4)
        }
    }

    private var subtitle: String {
        guard let report = appState.doctor else { return "Checking local Cyberpunk state" }
        if let edition = report.game.edition {
            return "\(edition) detected"
        }
        return "Cyberpunk 2077 not detected"
    }

    private var gameStatus: (text: String, color: Color) {
        guard let report = appState.doctor else { return ("Checking", .secondary) }
        return report.game.found ? ("Ready", .green) : ("Missing", .orange)
    }

    private var runtimeStatus: (text: String, color: Color) {
        guard let report = appState.doctor else { return ("Checking", .secondary) }
        return report.runtime.ready ? ("Ready", .cyan) : ("Needs setup", .orange)
    }

    private var cacheStatus: (text: String, color: Color) {
        guard let report = appState.doctor else { return ("Checking", .secondary) }
        return report.cache.baseSnapshotPresent ? ("Ready", .green) : ("Missing", .orange)
    }

    private var activationStatus: (text: String, color: Color) {
        guard let report = appState.doctor else { return ("Checking", .secondary) }
        switch report.cache.currentBundle {
        case .cyberMacActive where report.activation.state == .active:
            return ("Active", .cyan)
        case .vanilla:
            return (report.activation.enabledMods > 0 ? "Needs activation" : "Vanilla", .orange)
        case .externallyChanged:
            return ("Blocked", .red)
        case .missing:
            return ("Missing", .red)
        case .cyberMacActive:
            return ("Out of sync", .orange)
        }
    }

    private var primaryTitle: String {
        guard let report = appState.doctor else { return "Checking CyberMac" }
        if !report.game.found { return "Game not found" }
        if !report.runtime.ready { return "Runtime setup needed" }
        if !report.cache.baseSnapshotPresent { return "Create a base cache snapshot" }
        if report.cache.currentBundle == .externallyChanged || report.cache.currentBundle == .missing {
            return "Activation blocked"
        }
        if report.activation.state == .active {
            if inputNeedsPatch {
                return "Mods need input patch"
            }
            return "Mods active"
        }
        return report.activation.enabledMods > 0 ? "Activation required" : "Ready for mods"
    }

    private var primaryDetail: String {
        guard let report = appState.doctor else { return "Loading the local health report." }
        if report.activation.enabledMods == 1 {
            let activeText = report.activation.state == .active ? "One mod is active." : "One mod is enabled."
            let inputText = inputNeedsPatch ? "\nInput mapping patch is required." : ""
            return "\(activeText)\nCurrent bundle: \(report.cache.currentBundle.displayName).\(inputText)"
        }
        let inputText = inputNeedsPatch ? "\nInput mapping patch is required." : ""
        return "\(report.activation.enabledMods) enabled mods.\nCurrent bundle: \(report.cache.currentBundle.displayName).\(inputText)"
    }

    private var primaryButtonTitle: String {
        guard let report = appState.doctor else { return "Refresh" }
        if report.activation.state == .active {
            if appState.inputStatus?.pendingInputPatch != nil { return "Verify input patch" }
            if inputNeedsPatch { return "Prepare input patch" }
            return "Launch game"
        }
        if report.activation.enabledMods > 0 && report.cache.currentBundle == .vanilla { return "Activate mods" }
        return "Refresh"
    }

    private var primaryButtonImage: String {
        switch primaryButtonTitle {
        case "Launch game":
            return "play.fill"
        case "Activate mods":
            return "bolt.fill"
        case "Prepare input patch":
            return "keyboard"
        case "Verify input patch":
            return "checkmark.seal"
        default:
            return "arrow.clockwise"
        }
    }

    private var primaryButtonDisabled: Bool {
        guard let report = appState.doctor else { return true }
        if report.activation.state == .active { return false }
        if primaryButtonTitle == "Activate mods" { return !report.activation.safeToProceedToActivation }
        if primaryButtonTitle == "Refresh" { return false }
        return true
    }

    private func runPrimaryAction() async {
        if primaryButtonTitle == "Verify input patch" {
            await appState.verifyInputPatch()
        } else if primaryButtonTitle == "Prepare input patch" {
            await appState.prepareInputPatch()
        } else if appState.doctor?.activation.state == .active {
            await appState.launchGame()
        } else if primaryButtonTitle == "Activate mods" {
            await appState.generateActivation()
        } else {
            await appState.refresh()
        }
    }

    private var inputNeedsPatch: Bool {
        guard let status = appState.inputStatus, status.requiredModCount > 0 else { return false }
        return Set(status.activeInputPatchModIDs) != Set(status.requiredMods.map(\.id))
    }

    private func visibleWarnings(_ report: DoctorReport) -> [DoctorWarning] {
        report.warnings.filter { warning in
            if warning.code.contains("input-loader"), appState.inputLoaderWarningDismissed {
                return false
            }
            return true
        }
    }
}
