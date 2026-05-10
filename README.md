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
- manifest creation with `schemaVersion: 1`
- enable, disable, uninstall, and diagnostics commands

It intentionally does not write into the Cyberpunk `.app` bundle.

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

- `Supported`: redscript-only zip, no blocked markers, launch workflow verified
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
