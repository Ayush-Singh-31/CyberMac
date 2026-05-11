import SwiftUI

@main
struct CyberMacDesktopApp: App {
    var body: some Scene {
        WindowGroup("CyberMac") {
            RootView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
    }
}
