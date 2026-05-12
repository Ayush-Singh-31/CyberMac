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
                    subtitle: "Supports redscript and input mapping mods."
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
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(appState.mods, id: \.id) { mod in
                                ModRow(mod: mod, appState: appState)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 1080, alignment: .leading)
        }
    }
}

private struct ModRow: View {
    let mod: InstalledModManifest
    @ObservedObject var appState: CyberMacAppState
    @State private var showingDeleteConfirmation = false

    var body: some View {
        CyberPanel(accent: rowAccent) {
            ViewThatFits(in: .horizontal) {
                wideLayout
                compactLayout
            }
        }
        .opacity(rowOpacity)
        .hoverGlow(rowAccent, enabled: true, scale: 1.006, cornerRadius: 24)
        .confirmationDialog(
            "Delete mod from CyberMac?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete permanently", role: .destructive) {
                Task { await appState.deleteMod(mod) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes CyberMac's stored files and manifest for this mod. It does not edit the game bundle. If this mod was previously activated, reactivate scripts afterward.")
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .center, spacing: 18) {
            leftZone
                .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
            pillZone
                .frame(width: 300, alignment: .leading)
            actionZone
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minHeight: 56)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            leftZone
            pillZone
            actionZone
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 82)
    }

    private var leftZone: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ModDisplayFormatter.displayName(for: mod))
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
            Text(mod.type.displayName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let substatusLine {
                Text(substatusLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(substatusAccent.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var pillZone: some View {
        WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(statusPills, id: \.label) { pill in
                StatusPill(label: pill.label, accent: pill.accent)
            }
        }
    }

    @ViewBuilder
    private var actionZone: some View {
        HStack(spacing: 10) {
            switch mod.status {
            case .enabled:
                actionButton("Disable", systemImage: "pause.circle.fill", variant: .secondary, accent: .cyan) {
                    Task { await appState.setMod(mod, enabled: false) }
                }
                actionButton("Uninstall", systemImage: "trash", variant: .destructive, accent: .red) {
                    Task { await appState.uninstallMod(mod) }
                }
                if appState.developerMode {
                    actionButton("Delete", systemImage: "xmark.bin", variant: .destructive, accent: .red) {
                        showingDeleteConfirmation = true
                    }
                }
            case .disabled:
                actionButton("Enable", systemImage: "play.circle.fill", variant: .primary, accent: .cyan) {
                    Task { await appState.setMod(mod, enabled: true) }
                }
                actionButton("Delete", systemImage: "xmark.bin", variant: .destructive, accent: .red) {
                    showingDeleteConfirmation = true
                }
            case .uninstalled:
                actionButton("Delete", systemImage: "xmark.bin", variant: .destructive, accent: .red) {
                    showingDeleteConfirmation = true
                }
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

    private var statusPills: [ModStatusPill] {
        var pills = [
            ModStatusPill(label: mod.status.rawValue, accent: lifecycleAccent)
        ]
        guard mod.status != .uninstalled else { return pills }

        pills.append(ModStatusPill(label: "Script: \(bundleStatus)", accent: statusAccent))
        if mod.requiresInputMappingPatch {
            pills.append(ModStatusPill(label: "Input: \(inputStatus)", accent: inputAccent))
        }
        return pills
    }

    private var substatusLine: String? {
        if mod.status == .uninstalled {
            return nil
        }
        if mod.status == .enabled, bundleStatus == "Needs activation" {
            return "Scripts need reactivation."
        }
        if mod.requiresInputMappingPatch, ["Needs patch", "Pending", "Out of sync"].contains(inputStatus) {
            return "Input mappings need patching."
        }
        return nil
    }

    private var substatusAccent: CyberAccent {
        if mod.status == .uninstalled { return .neutral }
        if mod.requiresInputMappingPatch, ["Needs patch", "Pending", "Out of sync"].contains(inputStatus) {
            return inputAccent
        }
        return statusAccent
    }

    private var inputStatus: String {
        guard mod.status == .enabled else { return "Out of sync" }
        if inputActive { return "Active" }
        if inputPending { return "Pending" }
        switch mod.inputPatchState {
        case .active:
            return "Needs patch"
        case .prepared:
            return "Pending"
        case .failed:
            return "Out of sync"
        case .outOfSync:
            return "Out of sync"
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

    private var lifecycleAccent: CyberAccent {
        switch mod.status {
        case .enabled:
            return .green
        case .disabled:
            return .neutral
        case .uninstalled:
            return .amber
        }
    }

    private var rowAccent: CyberAccent {
        if mod.status == .uninstalled { return .neutral }
        if mod.status == .disabled { return .neutral }
        return statusAccent
    }

    private var rowOpacity: Double {
        switch mod.status {
        case .enabled:
            return 1.0
        case .disabled:
            return 0.88
        case .uninstalled:
            return 0.72
        }
    }

    private var inputAccent: CyberAccent {
        switch inputStatus {
        case "Active":
            return .green
        case "Not required":
            return .neutral
        case "Out of sync":
            return .red
        default:
            return .amber
        }
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        variant: CyberButtonVariant,
        accent: CyberAccent,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(CyberButtonStyle(variant, accent: accent, minWidth: 118))
        .help(title)
    }
}

private struct ModStatusPill {
    let label: String
    let accent: CyberAccent
}

private struct StatusPill: View {
    let label: String
    let accent: CyberAccent

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accent.color.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(accent.color.opacity(0.22), lineWidth: 1)
            }
    }
}
