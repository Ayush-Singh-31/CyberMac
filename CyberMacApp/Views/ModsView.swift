import CyberMacCore
import SwiftUI

struct ModsView: View {
    @ObservedObject var appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Mods")
                    .font(.largeTitle.weight(.semibold))
                InteractiveDropZone(
                    title: "Drop a mod archive",
                    subtitle: ".zip only. CyberMac v0.1 supports redscript-only mods."
                ) { urls in
                    if let url = urls.first {
                        Task { await appState.scanMod(url: url) }
                    }
                }

                if let scan = appState.scanResult {
                    CyberPanel(accent: scan.sidecarInstallable ? .green : .amber) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scan.displayName)
                                        .font(.headline)
                                    Text(scan.kind.rawValue)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(scan.compatibilityStatus.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background((scan.sidecarInstallable ? CyberAccent.green.color : CyberAccent.amber.color).opacity(0.14), in: Capsule())
                            }
                            ForEach(scan.reasons, id: \.self) { reason in
                                Text(reason)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            if let block = scan.installBlockReason {
                                Text(block)
                                    .font(.callout)
                                    .foregroundStyle(CyberAccent.amber.color)
                            }
                            HStack {
                                PrimaryButton(
                                    title: "Install",
                                    systemImage: "square.and.arrow.down",
                                    disabled: !scan.sidecarInstallable,
                                    variant: .primary,
                                    accent: .cyan
                                ) {
                                    Task { await appState.installScannedMod() }
                                }
                                Spacer()
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Installed")
                        .font(.title2.weight(.semibold))
                    if appState.mods.isEmpty {
                        Text("No CyberMac-managed mods installed.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.mods, id: \.id) { mod in
                            ModRow(mod: mod, appState: appState)
                        }
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

private struct ModRow: View {
    let mod: InstalledModManifest
    @ObservedObject var appState: CyberMacAppState

    var body: some View {
        CyberPanel(accent: statusAccent) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ModDisplayFormatter.displayName(for: mod))
                        .font(.headline)
                    Text(mod.type.rawValue)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(mod.status.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
                Text(bundleStatus)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusAccent.color.opacity(0.14), in: Capsule())
                Button {
                    Task { await appState.setMod(mod, enabled: mod.status != .enabled) }
                } label: {
                    Label(mod.status == .enabled ? "Disable" : "Enable", systemImage: mod.status == .enabled ? "pause.circle.fill" : "play.circle.fill")
                }
                .buttonStyle(CyberButtonStyle(.secondary, accent: .cyan))
                .help(mod.status == .enabled ? "Disable mod" : "Enable mod")
                .disabled(mod.status == .uninstalled)
                Button {
                    Task { await appState.uninstallMod(mod) }
                } label: {
                    Label("Uninstall", systemImage: "trash")
                }
                .buttonStyle(CyberButtonStyle(.destructive, accent: .red))
                .help("Uninstall mod")
                .disabled(mod.status == .uninstalled)
            }
        }
    }

    private var bundleStatus: String {
        guard mod.status == .enabled else { return "Disabled" }
        if appState.doctor?.activation.state == .active,
           appState.doctor?.activation.activeModIDs.contains(mod.id) == true {
            return "Active in game"
        }
        return "Needs activation"
    }

    private var statusAccent: CyberAccent {
        switch bundleStatus {
        case "Active in game":
            return .green
        case "Needs activation":
            return .amber
        default:
            return .neutral
        }
    }
}
