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
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await appState.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var statusCards: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            StatusCard(title: "Game", status: gameStatus.text, systemImage: "gamecontroller", tint: gameStatus.color)
            StatusCard(title: "redscript", status: runtimeStatus.text, systemImage: "terminal", tint: runtimeStatus.color)
            StatusCard(title: "Cache", status: cacheStatus.text, systemImage: "archivebox", tint: cacheStatus.color)
            StatusCard(title: "Activation", status: activationStatus.text, systemImage: "bolt.circle", tint: activationStatus.color)
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
                PrimaryButton(title: primaryButtonTitle, systemImage: primaryButtonImage, disabled: primaryButtonDisabled) {
                    Task { await runPrimaryAction() }
                }
            }
        }
    }

    @ViewBuilder
    private var warnings: some View {
        if let report = appState.doctor, !report.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(report.warnings.indices, id: \.self) { index in
                    WarningBanner(message: report.warnings[index].message)
                }
            }
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
            return "Mods active"
        }
        return report.activation.enabledMods > 0 ? "Activation required" : "Ready for mods"
    }

    private var primaryDetail: String {
        guard let report = appState.doctor else { return "Loading the local health report." }
        if report.activation.enabledMods == 1 {
            return "1 enabled mod. Current bundle: \(report.cache.currentBundle.displayName)."
        }
        return "\(report.activation.enabledMods) enabled mods. Current bundle: \(report.cache.currentBundle.displayName)."
    }

    private var primaryButtonTitle: String {
        guard let report = appState.doctor else { return "Refresh" }
        if report.activation.state == .active { return "Launch game" }
        if report.activation.enabledMods > 0 && report.cache.currentBundle == .vanilla { return "Activate mods" }
        return "Refresh"
    }

    private var primaryButtonImage: String {
        primaryButtonTitle == "Launch game" ? "play.fill" : "arrow.clockwise"
    }

    private var primaryButtonDisabled: Bool {
        guard let report = appState.doctor else { return true }
        if report.activation.state == .active { return false }
        if primaryButtonTitle == "Refresh" { return false }
        return true
    }

    private func runPrimaryAction() async {
        if appState.doctor?.activation.state == .active {
            await appState.launchGame()
        } else {
            await appState.refresh()
        }
    }
}
