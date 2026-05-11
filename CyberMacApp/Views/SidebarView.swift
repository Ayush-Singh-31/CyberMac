import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppScreen?

    var body: some View {
        List(AppScreen.allCases, selection: $selection) { screen in
            Label(screen.rawValue, systemImage: screen.systemImage)
                .tag(screen)
        }
        .navigationTitle("CyberMac")
        .frame(minWidth: 220)
    }
}
