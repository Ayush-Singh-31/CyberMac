import SwiftUI

enum ArchiveLabBadgeKind: String, Equatable, Sendable {
    case experimental = "Experimental"
    case proven = "Proven"
    case blocked = "Blocked"
    case cliOnly = "CLI only"

    var accent: CyberAccent {
        switch self {
        case .experimental:
            return .amber
        case .proven:
            return .green
        case .blocked:
            return .red
        case .cliOnly:
            return .cyan
        }
    }
}

struct ArchiveLabCommandSnippet: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let command: String

    static let all: [ArchiveLabCommandSnippet] = [
        ArchiveLabCommandSnippet(
            id: "status",
            title: "Check official archive status",
            command: "swift run cybermac archive-patch status Data/archive/Mac/content/basegame_1_engine.archive"
        ),
        ArchiveLabCommandSnippet(
            id: "backup",
            title: "Backup official archive",
            command: "swift run cybermac archive-patch backup-official Data/archive/Mac/content/basegame_1_engine.archive"
        ),
        ArchiveLabCommandSnippet(
            id: "catalog-search",
            title: "Search catalog",
            command: "swift run cybermac archive-catalog search crosshair --catalog-dir \"$PROBE/catalog/archiveinfo\" --archive Data/archive/Mac/content/basegame_1_engine.archive --limit 80"
        ),
        ArchiveLabCommandSnippet(
            id: "stage-merge",
            title: "Stage exact-path merge",
            command: "swift run cybermac archive-patch stage-merge Data/archive/Mac/content/basegame_1_engine.archive --mod-archive \"/path/to/mod.archive\" --work-dir \"$PROBE/stage_merge\" --out \"$PROBE/staged.archive\" --cp77tools \"$HOME/.dotnet-x64/tools/cp77tools\""
        )
    ]
}

struct ArchiveLabProofItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String

    static let all: [ArchiveLabProofItem] = [
        ArchiveLabProofItem(
            id: "ui-texture-proof",
            title: "UI texture proof",
            detail: "basegame_1_engine.archive menu .xbm swap changed the main menu"
        ),
        ArchiveLabProofItem(
            id: "melee-hud-replacer",
            title: "Real Nexus proof",
            detail: "Melee HUD Replacer pc/mod archive was exact-path merged into basegame_1_engine.archive and worked in-game"
        )
    ]
}

struct ArchiveLabClassificationItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let badge: ArchiveLabBadgeKind

    static let all: [ArchiveLabClassificationItem] = [
        ArchiveLabClassificationItem(
            id: "exact-path-replacer",
            title: "Exact-path replacer",
            detail: "Best candidate",
            badge: .proven
        ),
        ArchiveLabClassificationItem(
            id: "ui-hud-replacer",
            title: "UI/HUD replacer",
            detail: "High priority",
            badge: .proven
        ),
        ArchiveLabClassificationItem(
            id: "texture-material-replacer",
            title: "Texture/material replacer",
            detail: "Possible",
            badge: .experimental
        ),
        ArchiveLabClassificationItem(
            id: "clothing-replacer",
            title: "Clothing replacer",
            detail: "Possible but slower",
            badge: .experimental
        ),
        ArchiveLabClassificationItem(
            id: "framework-addon",
            title: "ArchiveXL/TweakXL add-on",
            detail: "Blocked, possible donor assets only",
            badge: .blocked
        ),
        ArchiveLabClassificationItem(
            id: "native-runtime",
            title: "Native/CET/RED4ext/Codeware",
            detail: "Blocked with Equipment-EX",
            badge: .blocked
        )
    ]
}

enum ArchiveLabContent {
    static let scopeLines = [
        "Archive support is experimental",
        "Loose pc/mod archive installation is blocked on Mac",
        "Current supported research path: official archive patching",
        "Best-supported conversion type: exact-path replacer archives",
        "Framework add-ons are blocked for now: ArchiveXL, TweakXL, Codeware, RED4ext, Equipment-EX, CET"
    ]

    static let nextCandidates = [
        "Crosshair/HUD mods",
        "UI color/theme mods",
        "Main menu/audio replacers",
        "Makeup/eye/hair replacers",
        "Clothing replacers that replace vanilla items"
    ]
}

struct ArchiveLabView: View {
    private let proofColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                statusPanel
                provenWorkflows
                archiveTools
                classificationPanel
                nextCandidatesPanel
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Archive Lab")
                    .font(.largeTitle.weight(.semibold))
                Text("Small, manual research workflow for official archive patching and Nexus replacer conversion.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                ArchiveLabBadge(kind: .experimental)
                ArchiveLabBadge(kind: .cliOnly)
            }
        }
    }

    private var statusPanel: some View {
        CyberPanel(accent: .amber) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Status and scope", systemImage: "exclamationmark.triangle")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    ArchiveLabBadge(kind: .experimental)
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ArchiveLabContent.scopeLines, id: \.self) { line in
                        let isBlocked = line.localizedCaseInsensitiveContains("blocked")
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: isBlocked ? "nosign" : "checkmark.circle")
                                .foregroundStyle(isBlocked ? CyberAccent.red.color : CyberAccent.amber.color)
                                .frame(width: 18)
                            Text(line)
                                .textSelection(.enabled)
                        }
                    }
                }
                .font(.callout)
            }
        }
    }

    private var provenWorkflows: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Proven workflows", systemImage: "checkmark.seal")
            LazyVGrid(columns: proofColumns, spacing: 14) {
                ForEach(ArchiveLabProofItem.all) { proof in
                    CyberPanel(accent: .green) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(proof.title)
                                    .font(.headline)
                                Spacer()
                                ArchiveLabBadge(kind: .proven)
                            }
                            Text(proof.detail)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var archiveTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Archive tools", systemImage: "terminal")
            ForEach(ArchiveLabCommandSnippet.all) { snippet in
                CommandBox(command: snippet.command, title: snippet.title, collapsedByDefault: true)
            }
        }
    }

    private var classificationPanel: some View {
        CyberPanel(accent: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Mod classification", systemImage: "list.bullet.rectangle")
                VStack(spacing: 10) {
                    ForEach(ArchiveLabClassificationItem.all) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.callout.weight(.semibold))
                                Text(item.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            ArchiveLabBadge(kind: item.badge)
                        }
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) {
                            Divider().opacity(item.id == ArchiveLabClassificationItem.all.last?.id ? 0 : 0.35)
                        }
                    }
                }
            }
        }
    }

    private var nextCandidatesPanel: some View {
        CyberPanel(accent: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Next candidates", systemImage: "checklist")
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ArchiveLabContent.nextCandidates, id: \.self) { candidate in
                        HStack(spacing: 10) {
                            Image(systemName: "square")
                                .foregroundStyle(.secondary)
                            Text(candidate)
                                .textSelection(.enabled)
                            Spacer()
                        }
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                }
            }
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.semibold))
    }
}

private struct ArchiveLabBadge: View {
    let kind: ArchiveLabBadgeKind

    var body: some View {
        Text(kind.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(kind.accent.color)
            .background(kind.accent.color.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(kind.accent.color.opacity(0.20), lineWidth: 1)
            }
    }
}
