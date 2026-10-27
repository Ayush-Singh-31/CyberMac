import AppKit
import CyberMacCore
import Foundation

/// The only automatic privilege boundary. This local build uses Apple Installer
/// for administrator authorization and payload placement. It executes no mod code
/// and does not request Apple's restricted privileged-file-operations entitlement.
struct SystemModInstaller: Sendable {
    let home: CyberMacHomeManager

    static func needsAppManagement(_ detail: String) -> Bool {
        detail.localizedCaseInsensitiveContains("Operation not permitted") || detail.contains("Privacy & Security → App Management")
    }

    static func failureMessage(_ detail: String, filesUnchanged: Bool) -> String {
        let recovery = filesUnchanged ? "The planned game files are unchanged." : "Your recovery plan is saved in the installer history."
        if needsAppManagement(detail) {
            return "macOS denied the file replacement. If CyberMac is already enabled in Privacy & Security → App Management, leave it enabled; this error needs further diagnosis rather than another permission change. \(recovery)\n\nDetails: \(detail)"
        }
        return "Installation stopped: \(detail). \(recovery)"
    }

    static func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        if (error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError)
            || (error.domain == NSOSStatusErrorDomain && error.code == -60006) { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError { return isCancellation(underlying) }
        return false
    }

    private static func checkGameStopped(_ plan: ModInstallTransaction) throws {
        let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-x", plan.executableName], timeoutSeconds: 5, allowFailure: true)
        guard result.exitCode == 1 else {
            throw CyberMacError.invalidInput(result.exitCode == 0
                ? "Fully close Cyberpunk 2077 before installing or restoring mods."
                : "Could not check whether Cyberpunk is running. Try again before installing.")
        }
    }

    @MainActor
    private static func openInstaller(_ url: URL) async throws -> pid_t {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        let app = try await NSWorkspace.shared.open([url],
            withApplicationAt: URL(fileURLWithPath: "/System/Library/CoreServices/Installer.app"), configuration: configuration)
        return app.processIdentifier
    }

    @MainActor
    private static func installerRunning(_ pid: pid_t) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.isTerminated == false
    }

    func apply(_ plan: ModInstallTransaction) async throws {
        let package = try await BackgroundTaskRunner.run { [home] () -> ModInstallerPackage? in
            let game = try GameInstallDetector().detect(preferredAppPath: plan.gameApp)
            for file in plan.files {
                for path in [file.source, file.backup] {
                    try PathSafety.validateContainedPath(URL(fileURLWithPath: path).resolvingSymlinksInPath(), in: home.homeURL.resolvingSymlinksInPath())
                }
            }
            _ = try ModInstallTransaction(game: game, files: plan.files)
            let remaining = try plan.files.filter {
                try PathSafety.sha256(url: URL(fileURLWithPath: $0.target)) != $0.installedSHA256
            }
            if remaining.isEmpty { try plan.verify(); return nil }
            let validated = try ModInstallTransaction(game: game, files: remaining)
            try Self.checkGameStopped(validated)
            let package = try ModInstallerPackage.build(plan: validated, under: home.generatedURL.appendingPathComponent("installer-packages"))
            try package.verifyPackage()
            return package
        }
        guard let package else { return }
        do {
            let pid = try await Self.openInstaller(package.url)
            let deadline = Date().addingTimeInterval(15 * 60)
            while Date() < deadline {
                try Task.checkCancellation()
                // Receipt or system install history is committed after
                // postinstall succeeds. Game files must also pass verification.
                if try await BackgroundTaskRunner.run({ package.hasInstallationReceipt }) {
                    try await BackgroundTaskRunner.run { try plan.verify() }
                    return
                }
                if !(await Self.installerRunning(pid)) {
                    // Allow the system's success record to finish committing
                    // when Installer closes between the two checks.
                    try await Task.sleep(for: .milliseconds(500))
                    if try await BackgroundTaskRunner.run({ package.hasInstallationReceipt }) {
                        try await BackgroundTaskRunner.run { try plan.verify() }
                        return
                    }
                    throw CyberMacError.fileSystem("macOS Installer closed without completing this package. Choose Retry to reopen it. If Installer reported an error, its Installation Log has the details.")
                }
                try await Task.sleep(for: .seconds(2))
            }
            throw CyberMacError.fileSystem("Finish or close the macOS Installer window, then choose Retry. The prepared package and recovery files are saved.")
        } catch {
            if Self.isCancellation(error) {
                throw CyberMacError.invalidInput("Installation paused because the Mac password prompt was cancelled. Choose Retry whenever you are ready.")
            }
            let unchanged = await Task.detached {
                plan.files.allSatisfy { (try? PathSafety.sha256(url: URL(fileURLWithPath: $0.target))) == $0.originalSHA256 }
            }.value
            throw CyberMacError.fileSystem(Self.failureMessage(String(describing: error), filesUnchanged: unchanged))
        }
    }
}
