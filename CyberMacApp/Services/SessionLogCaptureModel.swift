import AppKit
import CyberMacCore
import Foundation
import Observation

@MainActor
@Observable
final class SessionLogCaptureModel {
    var report: GameSessionLogReport?
    var recent: [GameSessionLogReport] = []
    var isRecording = false
    var busy = false
    var errorMessage: String?
    @ObservationIgnored private let recorder: GameSessionLogRecorder

    init(recorder: GameSessionLogRecorder = .shared) { self.recorder = recorder }

    func start() async {
        busy = true; errorMessage = nil
        defer { busy = false; refresh() }
        do {
            let recorder = recorder
            report = try await Task.detached(priority: .utility) {
                try recorder.start(game: GameInstallDetector().detect())
            }.value
            let running = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.cdprojektred.cyberpunk" }
            try recorder.addMarker(running ? "Game was already running when capture began." : "Capture began before game launch.")
        } catch { errorMessage = String(describing: error) }
    }

    func stop() async {
        busy = true
        let recorder = recorder
        report = await Task.detached(priority: .utility) { recorder.stop() }.value
        busy = false; refresh()
    }

    func refresh() {
        report = recorder.snapshot(); isRecording = recorder.isRecording
        do { recent = try recorder.recent() }
        catch { errorMessage = "Could not read recorded sessions: \(error)" }
    }

    func addMarker(_ marker: String) -> Bool {
        do { try recorder.addMarker(marker); refresh(); return true }
        catch { errorMessage = String(describing: error); return false }
    }

    func recordGameLifecycle(_ notification: Notification) {
        guard recorder.isRecording,
              let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              application.bundleIdentifier == "com.cdprojektred.cyberpunk" else { return }
        let action = notification.name == NSWorkspace.didLaunchApplicationNotification ? "launched" : "exited"
        _ = addMarker("Game \(action); process \(application.processIdentifier).")
    }

    func stopForTermination() { report = recorder.stop() }
}
