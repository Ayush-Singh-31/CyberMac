import CyberMacCore
import SwiftUI

struct OutfitsView: View {
    let appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Outfits")
                    .font(.largeTitle.weight(.semibold))
                Text("Manage desired-state appearance profiles and legacy outfit bundles. CyberMac never runs privileged archive install commands here; it prints them for Terminal.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let command = appState.commandToRun,
                   command.title.hasPrefix("Install outfit profile")
                       || command.title.hasPrefix("Generate grant helper")
                       || command.title.hasPrefix("Install outfit archive")
                       || command.title.hasPrefix("Restore official archive")
                       || command.title.hasPrefix("Disable item-grant helper") {
                    CommandBox(command: command.displayCommand, title: command.title, collapsedByDefault: false)
                }

                if appState.outfitProfiles.isEmpty && appState.outfitBundles.isEmpty {
                    GlassPanel {
                        VStack(spacing: 8) {
                            Image(systemName: "tshirt")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            Text("No outfit profiles yet")
                                .font(.callout.weight(.semibold))
                            Text("Run `cybermac outfit profile create …` and `cybermac outfit piece add …` to register pieces.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                }

                if !appState.outfitProfiles.isEmpty {
                    sectionHeader("Appearance profiles")
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(appState.outfitProfiles, id: \.profile.id) { summary in
                            OutfitProfileCard(
                                summary: summary,
                                showRawHashes: appState.showRawHashes,
                                onTogglePiece: { piece, enabled in
                                    Task {
                                        await appState.setOutfitPiece(
                                            profileID: summary.profile.id,
                                            pieceID: piece.id,
                                            enabled: enabled
                                        )
                                    }
                                },
                                onInstall: {
                                    Task { await appState.showOutfitProfileInstallCommand(profileID: summary.profile.id) }
                                },
                                onGrant: {
                                    appState.showOutfitProfileGrantCommand(
                                        profileID: summary.profile.id,
                                        displayName: summary.profile.displayName
                                    )
                                },
                                onRestore: {
                                    Task { await appState.showOutfitProfileRestoreCommand(profileID: summary.profile.id) }
                                }
                            )
                        }
                    }
                }

                if !appState.outfitBundles.isEmpty {
                    sectionHeader("Legacy outfit bundles")
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(appState.outfitBundles, id: \.id) { bundle in
                            OutfitBundleCard(
                                bundle: bundle,
                                mods: appState.mods,
                                showRawHashes: appState.showRawHashes,
                                onInstall: { Task { await appState.showOutfitInstallCommand(for: bundle) } },
                                onRestore: { Task { await appState.showOutfitRestoreCommand(for: bundle) } },
                                onDisableGrant: { Task { await appState.showOutfitDisableGrantCommand(for: bundle) } }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: 1080, alignment: .leading)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .padding(.top, 4)
    }
}

private struct OutfitProfileCard: View {
    let summary: OutfitProfileSummary
    let showRawHashes: Bool
    let onTogglePiece: (OutfitPiece, Bool) -> Void
    let onInstall: () -> Void
    let onGrant: () -> Void
    let onRestore: () -> Void

    private var profile: OutfitProfile { summary.profile }
    private var pieces: [OutfitPiece] { profile.pieces.sorted { $0.installOrder == $1.installOrder ? $0.id < $1.id : $0.installOrder < $1.installOrder } }

    var body: some View {
        CyberPanel(accent: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.displayName)
                            .font(.headline)
                        Text("ID: \(profile.id)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Target: \(profile.targetArchiveRelativePath)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        metric("enabled", profile.enabledPieceIds.count)
                        metric("disabled", profile.disabledPieceIds.count)
                    }
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pristine backup")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(profile.pristineBackupId)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last build SHA-256")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(lastBuildSHA)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    Spacer()
                }

                if !summary.conflictWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Conflict warnings")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        ForEach(summary.conflictWarnings, id: \.assetPath) { conflict in
                            Text("\(conflict.assetPath): \(conflict.previousPieceId) -> \(conflict.winningPieceId)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                Divider()
                    .opacity(0.45)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(pieces, id: \.id) { piece in
                        OutfitPieceRow(piece: piece, onToggle: { enabled in onTogglePiece(piece, enabled) })
                    }
                }

                HStack(spacing: 12) {
                    PrimaryButton(
                        title: "Install archive",
                        systemImage: "doc.on.clipboard",
                        disabled: profile.lastBuiltArchivePath == nil,
                        variant: .primary,
                        accent: .cyan,
                        action: onInstall
                    )
                    PrimaryButton(
                        title: "Grant helper",
                        systemImage: "gift",
                        disabled: summary.enabledPieces.flatMap(\.itemIds).isEmpty,
                        variant: .secondary,
                        accent: .amber,
                        action: onGrant
                    )
                    PrimaryButton(
                        title: "Restore official",
                        systemImage: "arrow.uturn.backward",
                        disabled: false,
                        variant: .secondary,
                        accent: .green,
                        action: onRestore
                    )
                    Spacer()
                }
            }
        }
    }

    private var lastBuildSHA: String {
        guard let sha = profile.lastBuiltArchiveSHA256 else { return "not built" }
        return showRawHashes ? sha : shortSHA(sha)
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        Text("\(label): \(value)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.cyan.opacity(0.12), in: Capsule())
    }

    private func shortSHA(_ sha: String) -> String {
        guard sha.count > 16 else { return sha }
        return "\(sha.prefix(8))...\(sha.suffix(8))"
    }
}

private struct OutfitPieceRow: View {
    let piece: OutfitPiece
    let onToggle: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { piece.enabled },
                    set: { onToggle($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(piece.displayName)
                            .font(.callout.weight(.semibold))
                        Text("\(piece.id) | order \(piece.installOrder)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .toggleStyle(.switch)
                Spacer()
                HStack(spacing: 8) {
                    countPill("replace", piece.affectedAssets.replacedAssets.count)
                    countPill("add", piece.affectedAssets.addedAssets.count)
                }
            }
            if !piece.itemIds.isEmpty {
                Text(piece.itemIds.joined(separator: ", "))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }

    private func countPill(_ label: String, _ count: Int) -> some View {
        Text("\(label): \(count)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

private struct OutfitBundleCard: View {
    let bundle: CyberMacOutfitBundle
    let mods: [InstalledModManifest]
    let showRawHashes: Bool
    let onInstall: () -> Void
    let onRestore: () -> Void
    let onDisableGrant: () -> Void

    private var grantHelper: InstalledModManifest? {
        guard let modID = bundle.optionalItemGrantModID else { return nil }
        return mods.first(where: { $0.id == modID })
    }

    private var grantHelperLabel: String {
        guard let modID = bundle.optionalItemGrantModID else {
            return "no helper recorded"
        }
        if let mod = grantHelper {
            return "\(modID) (\(mod.status.rawValue))"
        }
        return "\(modID) (not installed)"
    }

    private var grantHelperAccent: CyberAccent {
        guard let mod = grantHelper else { return .amber }
        switch mod.status {
        case .enabled:
            return .amber
        case .disabled:
            return .green
        case .uninstalled:
            return .neutral
        }
    }

    var body: some View {
        CyberPanel(accent: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(bundle.displayName)
                            .font(.headline)
                        Text("ID: \(bundle.id)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Target: \(bundle.targetArchive)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    statusPill(label: bundle.status.rawValue, accent: .cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Item IDs (\(bundle.affectedItemIDs.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(bundle.affectedItemIDs.joined(separator: ", "))
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Affected assets (\(bundle.affectedAssets.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(bundle.affectedAssets, id: \.self) { asset in
                        Text(asset)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Patched SHA-256")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(showRawHashes ? bundle.patchedArchiveSHA256 : shortSHA(bundle.patchedArchiveSHA256))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text("\(bundle.patchedArchiveSizeBytes) bytes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Backup ID")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(bundle.backupID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grant helper")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        statusPill(label: grantHelperLabel, accent: grantHelperAccent)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    PrimaryButton(
                        title: "Install archive",
                        systemImage: "square.and.arrow.down",
                        disabled: false,
                        variant: .primary,
                        accent: .cyan,
                        action: onInstall
                    )
                    PrimaryButton(
                        title: "Restore official",
                        systemImage: "arrow.uturn.backward",
                        disabled: false,
                        variant: .secondary,
                        accent: .green,
                        action: onRestore
                    )
                    PrimaryButton(
                        title: "Disable item grant",
                        systemImage: "pause.circle",
                        disabled: bundle.optionalItemGrantModID == nil,
                        variant: .secondary,
                        accent: .amber,
                        action: onDisableGrant
                    )
                    Spacer()
                }
            }
        }
    }

    private func statusPill(label: String, accent: CyberAccent) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accent.color.opacity(0.14), in: Capsule())
    }

    private func shortSHA(_ sha: String) -> String {
        guard sha.count > 16 else { return sha }
        let prefix = sha.prefix(8)
        let suffix = sha.suffix(8)
        return "\(prefix)…\(suffix)"
    }
}
