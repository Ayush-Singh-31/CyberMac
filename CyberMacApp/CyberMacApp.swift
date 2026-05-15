import AppKit
import SwiftUI

@main
struct CyberMacDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("CyberMac") {
            RootView()
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setDockIcon()
        NSApp.activate()
    }

    private func setDockIcon() {
        guard let url = Bundle.module.url(forResource: "CyberMacIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return
        }

        NSApp.applicationIconImage = image
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
