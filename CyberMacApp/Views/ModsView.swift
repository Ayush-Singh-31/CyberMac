import CyberMacCore
import SwiftUI

struct ModsView: View {
    @ObservedObject var appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Mods")
                    .font(.largeTitle.weight(.semibold))
                GlassPanel {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 32))
                            .foregroundStyle(.cyan)
                        Text("Drop a mod archive")
                            .font(.headline)
                        Text(".zip only. CyberMac v0.1 supports redscript-only mods.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
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
        GlassPanel {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mod.displayName)
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
                Button {
                    Task { await appState.setMod(mod, enabled: mod.status != .enabled) }
                } label: {
                    Image(systemName: mod.status == .enabled ? "pause.fill" : "play.fill")
                }
                .help(mod.status == .enabled ? "Disable" : "Enable")
                .disabled(mod.status == .uninstalled)
                Button {
                    Task { await appState.uninstallMod(mod) }
                } label: {
                    Image(systemName: "trash")
                }
                .help("Uninstall")
                .disabled(mod.status == .uninstalled)
            }
        }
    }
}
