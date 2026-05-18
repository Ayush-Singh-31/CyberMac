import CyberMacCore
import SwiftUI

struct OutfitsView: View {
    let appState: CyberMacAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Outfits")
                    .font(.largeTitle.weight(.semibold))
                Text("Manage outfit bundles produced via `cybermac outfit-bundle create`. CyberMac never runs privileged commands here — it prints them for you to copy into Terminal.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let command = appState.commandToRun,
                   command.title.hasPrefix("Install outfit archive")
                       || command.title.hasPrefix("Restore official archive")
                       || command.title.hasPrefix("Disable item-grant helper") {
                    CommandBox(command: command.displayCommand, title: command.title, collapsedByDefault: false)
                }

                if appState.outfitBundles.isEmpty {
                    GlassPanel {
                        VStack(spacing: 8) {
                            Image(systemName: "tshirt")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            Text("No outfit bundles yet")
                                .font(.callout.weight(.semibold))
                            Text("Run `cybermac outfit-bundle create …` to register a bundle here.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                } else {
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
