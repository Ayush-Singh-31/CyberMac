# CyberMac

CyberMac v0.1 is a local-first Cyberpunk 2077 macOS modding harness focused on the Mac App Store build and redscript-only mods.

This first pass is core-first. It provides:

- game install detection for `/Applications/Cyberpunk 2077: Ultimate.app`
- CyberMac sidecar workspace creation under `~/Library/Application Support/CyberMac`
- manual redscript runtime zip import
- manual input-loader zip import
- quarantine detection and clearing
- generated `launch_modded.sh`
- redscript compile probing
- conservative mod archive scanning
- sidecar installation for supported `.reds` mods
- base-cache snapshots and experimental bundle activation for generated `final.redscripts`
- manifest creation with `schemaVersion: 1`
- enable, disable, uninstall, and diagnostics commands

It never runs `sudo` or writes into the Cyberpunk `.app` bundle itself. Experimental bundle activation prints the exact manual `sudo cp` command needed to copy the generated `final.redscripts`.

## Requirements

- macOS on Apple Silicon
- Xcode command-line tools
- Swift Package Manager
- redscript macOS zip, downloaded manually
- input-loader macOS zip, downloaded manually

## Build

From the repo root:

```bash
swift build
```

Run the built CLI:

```bash
.build/debug/cybermac help
```

Optional convenience alias while developing:

```bash
alias cybermac='swift run cybermac'
```

## First run workflow

```bash
swift run cybermac init-home
swift run cybermac doctor
```

Expected detection on Ayush's machine:

```text
App path: /Applications/Cyberpunk 2077: Ultimate.app
Storefront: Mac App Store
Executable: Contents/MacOS/Cyberpunk2077
Data path: Contents/Data
```

## Runtime setup

After downloading the required macOS zips:

```bash
swift run cybermac import-redscript ~/Downloads/redscript*.zip
swift run cybermac import-input-loader ~/Downloads/input*.zip
swift run cybermac clear-quarantine
swift run cybermac probe-redscript
```

Run the compile probe only after the runtimes are imported:

```bash
swift run cybermac probe-redscript --compile
```

If the compile probe succeeds, generate the launch script:

```bash
swift run cybermac generate-launch-script
swift run cybermac launch-test
```

To actually start the game through the generated script:

```bash
swift run cybermac launch-test --run
```

## Mod scanning

```bash
swift run cybermac scan ~/Downloads/SomeMod.zip
```

The scanner uses three compatibility statuses:

- `Supported`: redscript-only zip, no blocked markers
- `Unsupported`: known v0.1 blocker such as `.dll`, `.asi`, CET, RED4ext, ArchiveXL, TweakXL, or Codeware
- `Untested`: layout or mod type not safely installable by v0.1

## Installing redscript-only mods

Only supported redscript-only mods can be installed:

```bash
swift run cybermac install ~/Downloads/SomeRedscriptMod.zip
swift run cybermac list-mods
```

Installed `.reds` files are copied into:

```text
~/Library/Application Support/CyberMac/game-overlay/r6/scripts/<mod-id>/
```

CyberMac keeps a manifest in:

```text
~/Library/Application Support/CyberMac/manifests/<mod-id>.json
```

Installing, enabling, disabling, or uninstalling marks activation `outOfSync`. The game will not see sidecar changes until bundle activation is run.

## Base cache and activation

CyberMac compiles from a mini game-script root:

```text
~/Library/Application Support/CyberMac/game-overlay/
  r6/scripts/
  r6/cache/final.redscripts
```

The durable clean input is stored separately:

```text
~/Library/Application Support/CyberMac/base-cache/<game-fingerprint-id>/final.redscripts
```

Typical activation workflow:

```bash
swift run cybermac cache-status
swift run cybermac refresh-base-cache
swift run cybermac activate --dry-run
swift run cybermac activate --bundle-mode
# manually run the printed sudo cp command
swift run cybermac activate --verify
```

Only this bundle target is in scope for v0.1 activation:

```text
Contents/Data/r6/cache/final.redscripts
```

CyberMac does not copy `final.redscripts.ts`, `.bk` files, `r6/scripts/`, input-loader files, or redscript runtime files into the bundle.

Bundle activation remains experimental behind `--bundle-mode` until one activation+launch cycle and one restore+launch cycle succeed with no `amfid`, `taskgated`, or `syspolicyd` errors recorded in diagnostics, then another developer or user reproduces both on a separate machine.

## Backups and restore

Every `activate --bundle-mode` creates a backup manifest under:

```text
~/Library/Application Support/CyberMac/backups/<backup-id>/
```

Restore commands are manual too:

```bash
swift run cybermac list-backups
swift run cybermac restore --dry-run <backup-id>
swift run cybermac restore <backup-id>
# manually run the printed sudo command
swift run cybermac restore --verify <backup-id>
```

## Managing mods

```bash
swift run cybermac disable <mod-id>
swift run cybermac enable <mod-id>
swift run cybermac uninstall <mod-id>
```

CyberMac only removes or moves files it installed itself.

## Diagnostics

```bash
swift run cybermac diagnostics
```

Reports are exported to:

```text
~/Library/Application Support/CyberMac/diagnostics/
```

User home paths are redacted in diagnostic output.

## v0.1 non-goals

CyberMac v0.1 does not support:

- CET mods
- RED4ext mods
- ArchiveXL mods
- TweakXL mods
- Codeware mods
- AMM
- Equipment-EX
- Virtual Atelier
- `.archive` clothing, texture, or replacement mods
- Nexus login
- automatic downloads
- Steam, GOG, or Epic installs
- sandboxed App Store distribution
