# CyberMac

CyberMac is experimental developer-preview software for Cyberpunk 2077: Ultimate on macOS. It has been tested locally on the Mac App Store version on Apple Silicon. It is not affiliated with CD Projekt Red, Nexus Mods, redscript, input-loader, or any mod author. Use at your own risk and keep backups.

## What it is

CyberMac is an experimental macOS mod manager focused on redscript-based Cyberpunk 2077 mods. It installs supported mods into a CyberMac-owned sidecar, compiles script caches with redscript, prepares manual copy commands, and verifies activation.

This is a source-only developer preview. CyberMac does not bundle redscript, input-loader, mods, Cyberpunk game files, or downloaded runtime files.

## Current support

Supported:

- redscript-only mods
- redscript + r6/input XML mods
- Mac App Store Cyberpunk 2077: Ultimate layout
- manual final.redscripts activation
- manual input XML patching with backup and verification

Unsupported:

- Cyber Engine Tweaks
- RED4ext
- Codeware
- ArchiveXL
- TweakXL
- Equipment-EX
- DLL / ASI
- REDmod-only mods
- most clothing, body, archive, vehicle, texture, and framework mods

## Safety model

- CyberMacApp does not run sudo.
- CyberMac generates commands for the user to run manually.
- CyberMac writes generated files under `~/Library/Application Support/CyberMac`.
- CyberMac backs up target files before preparing copy commands.
- CyberMac verifies SHA-256 after manual copy.
- CyberMac never edits the app bundle directly from the SwiftUI app.

## Requirements

- macOS on Apple Silicon
- Xcode / Swift toolchain
- Cyberpunk 2077: Ultimate Mac App Store version
- redscript macOS zip, imported by user
- input-loader macOS zip, imported by user, only needed for input mapping mods

Runtimes are not bundled.

## Install from source

This is not yet a double-click downloadable app. For now, run:

```bash
git clone https://github.com/Ayush-Singh-31/CyberMac.git
cd CyberMac
swift test
swift run CyberMacApp
```

For CLI help:

```bash
swift run cybermac help
```

If you want to test the UI, use SwiftPM. If you want to test compatibility, prefer CLI first.

## CLI usage

```bash
swift run cybermac doctor
swift run cybermac scan "$HOME/Downloads/mod.zip"
swift run cybermac install "$HOME/Downloads/mod.zip"
swift run cybermac activate --bundle-mode
# run printed sudo cp manually
swift run cybermac activate --verify
swift run cybermac launch-game
```

For input mapping:

```bash
swift run cybermac prepare-input-patch <mod-id>
# run printed sudo cp commands manually
swift run cybermac verify-input-patch
```

Common setup commands:

```bash
swift run cybermac import-redscript "$HOME/Downloads/redscript-macos.zip"
swift run cybermac import-input-loader "$HOME/Downloads/input-loader-macos.zip"
swift run cybermac clear-quarantine
swift run cybermac probe-redscript --compile
```

CyberMac expects the Mac App Store bundle at:

```text
/Applications/Cyberpunk 2077: Ultimate.app
```

CyberMac stores its sidecar files under:

```text
~/Library/Application Support/CyberMac
```

## Development status

v0.1 developer preview. API/UI may change. Source-only release.

## Contributing/testing

Please report:

- macOS version
- Cyberpunk version/storefront
- Apple Silicon model
- mod name/version
- scan output
- doctor output
- whether activation/input patch worked
- any scc errors

Do not upload copyrighted game files.
