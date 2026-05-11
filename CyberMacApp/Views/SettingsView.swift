import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: CyberMacAppState
    @AppStorage("CyberMacDeveloperMode") private var developerMode = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.largeTitle.weight(.semibold))
                GlassPanel {
                    Toggle("Developer mode", isOn: $developerMode)
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Game path", value: appState.doctor?.game.appPath ?? "not detected")
                        DetailRow(label: "Bundle target", value: appState.doctor?.game.bundleTarget ?? "not detected")
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}
