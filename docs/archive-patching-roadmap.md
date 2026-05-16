# Official Archive Patching Roadmap

CyberMac must not claim archive-only mod support. Loose `.archive` install paths were tested on the Mac App Store build and did not produce a working loader path.

The viable research track is controlled replacement of official Mac archives. A manual experiment replaced a repacked official archive and the game launched with a visible main-menu asset change. This proves official archive replacement can work for vanilla replacement research, but it does not make generic archive mods safe or supported.

## Current Safety Model

- CyberMac may inspect official archives, CodeResources membership, hashes, and CyberMac-managed official archive backups.
- CyberMac may print manual commands for backup/restore workflows.
- CyberMac must not run WolvenKit.
- CyberMac must not run `sudo`.
- CyberMac must not automatically write into the game bundle.
- Any official archive replacement or restore must remain a deliberate manual copy followed by hash verification.

## Supported Research Commands

- `archive-patch backup-official <relative-archive-path>` creates a CyberMac backup of a CodeResources-listed official archive.
- `archive-patch list-backups` lists CyberMac official archive backups.
- `archive-patch restore-official <backup-id> --dry-run` prints the manual restore command only.
- `archive-patch restore-official <backup-id> --verify` verifies the current official archive hash after a manual restore.
- `archive-patch preflight <relative-archive-path>` prints detailed read-only archive and backup state.
- `archive-patch manual-plan <relative-archive-path>` prints a controlled manual experiment checklist.
- `archive-patch status <relative-archive-path>` prints a compact read-only state label.

## Status Labels

- `PRISTINE`: current archive hash matches the newest matching CyberMac official backup.
- `MODIFIED`: current archive exists but differs from the newest matching CyberMac official backup.
- `UNKNOWN_BACKUP`: current archive exists and is CodeResources-listed, but CyberMac has no matching official backup.
- `MISSING`: the CodeResources-listed official archive is absent from the game bundle.

## Near-Term Scope

Keep this track focused on small, reversible, manually verified vanilla replacement experiments. Start with visible UI or menu asset changes where failures are easy to recognize and restore.

Do not add a patch manifest system yet. Do not add automatic install. Do not add ArchiveXL, TweakXL, RED4ext, or loose archive Phase C behavior as part of this track.

## Future Work

- Record manual experiment outcomes in a CyberMac-managed research log.
- Define a minimal patch manifest only after repeated manual experiments identify stable archive-level behavior.
- Design a guarded install flow only if backup, preflight, manual restore, and verification remain reliable across multiple official archives.
- Keep all game-bundle writes explicit, reviewable, and user-run until there is a proven safe migration path.
