import Foundation

public struct BundleStateResolver: Sendable {
    private let home: CyberMacHomeManager
    private let baseCacheManager: BaseCacheManager
    private let manifestStore: ManifestStore
    private let stateStore: StateStore
    private let fingerprintCache: FingerprintCacheStore

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.baseCacheManager = BaseCacheManager(home: home)
        self.manifestStore = ManifestStore(home: home)
        self.stateStore = StateStore(home: home)
        self.fingerprintCache = FingerprintCacheStore(home: home)
    }

    public func classify(gameInstall: GameInstall) throws -> BundleCacheClassification {
        let state = stateStore.load()
        let target = baseCacheManager.bundleCacheURL(gameInstall: gameInstall)
        let fingerprint = try baseCacheManager.fingerprint(gameInstall: gameInstall)
        let snapshot = try? baseCacheManager.loadSnapshot(id: fingerprint.id)
        let baseHash = try? baseCacheManager.currentSnapshotHash(for: gameInstall)
        let activeHash = state.activeBundleTargetHashes[target.path]
        let pendingHash = state.pendingExpectedHashes[target.path]
        let mirrorURL = home.overlayCacheURL.appendingPathComponent("final.redscripts")

        guard FileManager.default.fileExists(atPath: target.path) else {
            return BundleCacheClassification(
                kind: .missing,
                targetPath: target.path,
                currentSHA256: nil,
                baseSnapshotSHA256: baseHash ?? snapshot?.bundleCacheSHA256,
                activeSHA256: activeHash,
                pendingSHA256: pendingHash,
                baseSnapshotID: snapshot?.snapshotID,
                overlayMirrorPresent: FileManager.default.fileExists(atPath: mirrorURL.path)
            )
        }

        let currentHash = try fingerprintCache.sha256(url: target)
        let kind: BundleCacheKind
        if let baseHash, currentHash == baseHash {
            kind = .vanilla
        } else if let activeHash, currentHash == activeHash {
            kind = .cyberMacActive
        } else {
            kind = .externallyChanged
        }

        return BundleCacheClassification(
            kind: kind,
            targetPath: target.path,
            currentSHA256: currentHash,
            baseSnapshotSHA256: baseHash ?? snapshot?.bundleCacheSHA256,
            activeSHA256: activeHash,
            pendingSHA256: pendingHash,
            baseSnapshotID: snapshot?.snapshotID,
            overlayMirrorPresent: FileManager.default.fileExists(atPath: mirrorURL.path)
        )
    }

    public func snapshot(gameInstall: GameInstall, reconcile: Bool = true) throws -> BundleStateSnapshot {
        let bundle = try classify(gameInstall: gameInstall)
        let enabledMods = try manifestStore.list().filter { $0.status == .enabled }
        let enabledModIDs = enabledMods.map(\.id).sorted()

        var state = stateStore.load()
        let activeModIDs = state.activeModIDs.sorted()
        var activationState = state.activationState
        var changed = state.bundleChangedSinceLastActivation
        var blocked = false
        let nextStep: String

        switch bundle.kind {
        case .missing:
            activationState = .outOfSync
            changed = true
            blocked = true
            nextStep = "Restore a backup or inspect the missing bundle cache."
        case .externallyChanged:
            activationState = .outOfSync
            changed = true
            blocked = true
            nextStep = "Restore a backup or manually inspect before activation."
        case .vanilla:
            activationState = enabledModIDs.isEmpty ? .requiresBundleActivation : .outOfSync
            changed = false
            nextStep = enabledModIDs.isEmpty ? "Install a mod." : "Run cybermac activate --bundle-mode."

            if !state.activeBundleTargetHashes.isEmpty || state.bundleChangedSinceLastActivation {
                state.activeBundleTargetHashes = [:]
                state.pendingExpectedHashes = [:]
                state.pendingActivation = nil
                state.bundleChangedSinceLastActivation = false
            }
        case .cyberMacActive:
            activationState = enabledModIDs == activeModIDs ? .active : .outOfSync
            changed = false
            nextStep = activationState == .active ? "Launch game." : "Reactivate mods."
        }

        if reconcile {
            state.activationState = activationState
            state.bundleChangedSinceLastActivation = changed
            if changed {
                state.activationState = .outOfSync
            }
            try stateStore.save(state)
        }

        return BundleStateSnapshot(
            bundle: bundle,
            activationState: activationState,
            bundleChangedSinceLastActivation: changed,
            enabledMods: enabledMods,
            activeModIDs: activeModIDs,
            activationBlocked: blocked,
            nextStep: nextStep
        )
    }
}

public extension BundleCacheKind {
    var displayName: String {
        switch self {
        case .vanilla:
            return "vanilla"
        case .cyberMacActive:
            return "CyberMac active"
        case .externallyChanged:
            return "externally changed"
        case .missing:
            return "missing"
        }
    }
}
