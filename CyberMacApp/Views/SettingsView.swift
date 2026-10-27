import SwiftUI

struct SettingsView: View {
    let appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CyberStyle.sectionSpacing) {
                CyberPageTitle("Settings", subtitle: "Manage CyberMac, game detection and storage.")
                Divider()
                settingsSection("Developer", accent: .purple) {
                    settingsToggle("Developer mode", isOn: developerBinding)
                    settingsToggle("Show raw hashes in UI", isOn: rawHashesBinding)
                }
                settingsSection("Storage", accent: .green) {
                    HStack {
                        Text("CyberMac folder")
                            .foregroundStyle(.secondary)
                        Spacer()
                        PrimaryButton(title: "Reveal", systemImage: "folder", disabled: false, variant: .secondary, accent: .green) {
                            appState.revealCyberMacFolder()
                        }
                        .help("Reveal CyberMac support folder")
                    }
                }
                settingsSection("Game", accent: .blue) {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Game path", value: appState.doctor?.game.appPath ?? "not detected")
                        DetailRow(label: "Bundle target", value: appState.doctor?.game.bundleTarget ?? "not detected")
                        HStack {
                            PrimaryButton(title: "Reveal game app", systemImage: "gamecontroller", disabled: appState.doctor?.game.found != true, variant: .secondary, accent: .blue) {
                                appState.revealGameApp()
                            }
                            .help("Reveal game app in Finder")
                            PrimaryButton(title: "Refresh detection", systemImage: "arrow.clockwise", disabled: false, variant: .secondary, accent: .cyan) {
                                Task { await appState.refresh() }
                            }
                            .help("Refresh detected game state")
                        }
                    }
                }
                settingsSection("Maintenance", accent: .amber) {
                    PrimaryButton(title: "Clear temporary activation outputs", systemImage: "trash", disabled: false, variant: .secondary, accent: .amber) {
                        Task { await appState.clearTemporaryActivationOutputs() }
                    }
                    .help("Clear temporary activation outputs")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var developerBinding: Binding<Bool> {
        Binding(
            get: { appState.developerMode },
            set: { appState.developerMode = $0 }
        )
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch).cyberCursor()
        }
    }

    private var rawHashesBinding: Binding<Bool> {
        Binding(
            get: { appState.showRawHashes },
            set: { appState.showRawHashes = $0 }
        )
    }

    private func settingsSection<Content: View>(_ title: String, accent: CyberAccent, @ViewBuilder content: () -> Content) -> some View {
        CyberPanel(accent: accent) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                content()
            }
        }
    }
}
