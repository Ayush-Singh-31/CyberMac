import CyberMacCore
import Foundation

/// The only automatic privilege boundary. Input is a typed, verified file plan;
/// package text and the legacy manual-command panels never reach this runner.
struct SystemModInstaller: Sendable {
    let home: CyberMacHomeManager

    func apply(_ plan: ModInstallTransaction) throws {
        let game = try GameInstallDetector().detect(preferredAppPath: plan.gameApp)
        for file in plan.files {
            for path in [file.source, file.backup] {
                try PathSafety.validateContainedPath(URL(fileURLWithPath: path).resolvingSymlinksInPath(), in: home.homeURL.resolvingSymlinksInPath())
            }
        }
        // Revalidate decoded history against the actual game, including targets.
        _ = try ModInstallTransaction(game: game, files: plan.files)
        let remaining = try plan.files.filter {
            try PathSafety.sha256(url: URL(fileURLWithPath: $0.target)) != $0.installedSHA256
        }
        if remaining.isEmpty { try plan.verify(); return }
        let validated = try ModInstallTransaction(game: game, files: remaining)
        let script = """
        on run arguments
            do shell script (item 1 of arguments) with administrator privileges
        end run
        """
        let result = try ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", script, validated.command()], allowFailure: true)
        guard result.exitCode == 0 else {
            if result.stderr.contains("(-128)") {
                throw CyberMacError.invalidInput("Installation paused because the Mac password prompt was cancelled. Choose Retry whenever you are ready.")
            }
            throw CyberMacError.fileSystem("Installation stopped: \(result.stderr). Your recovery plan is saved in the installer history.")
        }
        try plan.verify()
    }
}
