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
                    subtitle: ".zip only. CyberMac supports redscript mods and input mapping support."
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
                                    Text(scan.kind.displayName)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(scan.displayStatusLabel)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background((scan.sidecarInstallable ? CyberAccent.green.color : CyberAccent.amber.color).opacity(0.14), in: Capsule())
                            }
                            if scan.requiresInputMappingPatch {
                                Text("CyberMac can install the redscript file and prepare the required input XML patch. Manual copy and verification are required before the keybinds work.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text("Input patch required")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(CyberAccent.amber.color.opacity(0.14), in: Capsule())
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
                    Text(mod.type.displayName)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(mod.status.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
                Text("Script: \(bundleStatus)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusAccent.color.opacity(0.14), in: Capsule())
                if mod.requiresInputMappingPatch {
                    Text("Input: \(inputStatus)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(inputAccent.color.opacity(0.14), in: Capsule())
                }
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
            return "Active"
        }
        return "Needs activation"
    }

    private var inputStatus: String {
        guard mod.status == .enabled else { return "Disabled" }
        if inputActive { return "Active" }
        if inputPending { return "Pending" }
        switch mod.inputPatchState {
        case .active:
            return "Needs patch"
        case .prepared:
            return "Prepared"
        case .failed:
            return "Verify failed"
        case .outOfSync:
            return "Needs patch"
        case .required:
            return "Needs patch"
        case .notRequired:
            return "Not required"
        }
    }

    private var inputActive: Bool {
        appState.inputStatus?.activeInputPatchModIDs.contains(mod.id) == true
    }

    private var inputPending: Bool {
        appState.inputStatus?.pendingInputPatch?.modIDs.contains(mod.id) == true
    }

    private var statusAccent: CyberAccent {
        switch bundleStatus {
        case "Active":
            return .green
        case "Needs activation":
            return .amber
        default:
            return .neutral
        }
    }

    private var inputAccent: CyberAccent {
        switch inputStatus {
        case "Active":
            return .green
        case "Disabled", "Not required":
            return .neutral
        case "Verify failed":
            return .red
        default:
            return .amber
        }
    }
}
