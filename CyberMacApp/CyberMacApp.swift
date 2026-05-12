import SwiftUI

@main
struct CyberMacDesktopApp: App {
    var body: some Scene {
        WindowGroup("CyberMac") {
            RootView()
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowResizability(.contentMinSize)
    }
}
