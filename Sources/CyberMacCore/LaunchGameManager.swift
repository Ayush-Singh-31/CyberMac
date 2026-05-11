import Foundation

public struct LaunchGameManager: Sendable {
    private let home: CyberMacHomeManager
    private let detector: GameInstallDetector
    private let resolver: BundleStateResolver

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.detector = GameInstallDetector()
        self.resolver = BundleStateResolver(home: home)
    }

    public func makeLaunchPlan(policy: LaunchPolicy, preferredAppPath: String? = nil) throws -> LaunchGamePlan {
        let gameInstall = try detector.detect(preferredAppPath: preferredAppPath)
        return try makeLaunchPlan(gameInstall: gameInstall, policy: policy)
    }

    public func makeLaunchPlan(gameInstall: GameInstall, policy: LaunchPolicy) throws -> LaunchGamePlan {
        try home.bootstrap()
        let snapshot = try resolver.snapshot(gameInstall: gameInstall)
        let command = "/usr/bin/open \(PathSafety.shellDoubleQuoted(gameInstall.appURL.path))"
        var warnings: [String] = []
        var canLaunch = false
        var refusalReason: String?

        switch snapshot.bundle.kind {
        case .cyberMacActive:
            canLaunch = true
            if snapshot.activationState != .active {
                warnings.append("Enabled mods changed since the last verified activation. The game will launch with the last active bundle.")
            }
        case .vanilla:
            if snapshot.enabledMods.isEmpty {
                canLaunch = policy != .requireActive
                if policy == .requireActive {
                    refusalReason = "CyberMac activation is required, but the current bundle is vanilla."
                }
            } else if policy == .vanillaOK {
                canLaunch = true
                warnings.append("Installed CyberMac mods are enabled but not active in the current vanilla bundle.")
            } else {
                refusalReason = "Game is currently vanilla, but CyberMac has enabled mods that have not been activated."
            }
        case .externallyChanged:
            refusalReason = "Bundle final.redscripts does not match the base snapshot or the last CyberMac activation."
        case .missing:
            refusalReason = "Bundle final.redscripts is missing."
        }

        if policy == .requireActive && snapshot.bundle.kind != .cyberMacActive {
            canLaunch = false
            refusalReason = refusalReason ?? "CyberMac active bundle is required."
        }

        return LaunchGamePlan(
            appURL: gameInstall.appURL,
            bundleKind: snapshot.bundle.kind,
            activationState: snapshot.activationState,
            enabledMods: snapshot.enabledMods,
            commandPreview: command,
            warnings: warnings,
            canLaunch: canLaunch,
            refusalReason: refusalReason
        )
    }

    public func launch(plan: LaunchGamePlan, waitUntilExit: Bool = true) throws {
        guard plan.canLaunch else {
            throw CyberMacError.unsupported(plan.refusalReason ?? "Launch is not allowed for the current CyberMac state.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [plan.appURL.path]
        try process.run()
        if waitUntilExit {
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw CyberMacError.processFailed(command: plan.commandPreview, exitCode: process.terminationStatus, stderr: "")
            }
        }
    }
}
