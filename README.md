# CyberMac

CyberMac is experimental developer-preview software for Cyberpunk 2077: Ultimate on macOS. It has been tested locally on the Mac App Store version on Apple Silicon. It is not affiliated with CD Projekt Red, Nexus Mods, redscript, input-loader, or any mod author. Use at your own risk and keep backups.

## What it is

CyberMac is an experimental macOS mod manager for Cyberpunk 2077. It inspects appearance archives, prepares backed-up clothing patches, and manages a separate redscript workflow. Installation commands are reviewed and run manually.

This is a source-only developer preview. CyberMac does not bundle redscript, input-loader, mods, Cyberpunk game files, or downloaded runtime files.

The current development priority is [appearance mods for feminine V](docs/appearance-mods-plan.md):
clothing first, followed by body shapes and matching clothing refits.
The new Appearance Mods screen and `appearance` CLI inspect real Mac archives,
prepare native patched copies with verified backups, and check manual installation
and restoration. The Lucy jacket has a user-confirmed successful save load
and worn appearance on Mac App Store 2.5, followed by verified original-file
restoration. Its inventory thumbnail still shows the replaced garment. Other
packages remain unverified. See the [implementation and first clothing test](docs/appearance-native-workflow.md).
The [framework and REA investigation](docs/frameworks-and-rea.md) distinguishes
existing-item delivery, new item registration, and the remaining native work.

The user reports that Lucy replacements already worked months earlier; the
current target is usable **standalone items**. `clothing prepare` now prepares
four independent clothing records, their inventory labels, automatic delivery
and equipment requests using actual inventory instance IDs. It also fixes
inherited item properties omitted by the earlier clone writer. The prepared
vanilla duplicate test received a player report of clothes automatically equipped;
exact item identities remain unconfirmed. The next package now connects those
four records to isolated **Lucy jacket, top, pants and boots** assets, preserving
original garments. It is prepared for one combined gameplay test; original
inventory icons remain. See the [Lucy duplicate workflow](docs/appearance-native-workflow.md#lucy-outfit-on-the-four-duplicates--25-october).

## Current support

Supported:

- redscript-only mods
- redscript + r6/input XML mods
- Mac App Store Cyberpunk 2077: Ultimate layout
- manual final.redscripts activation
- manual input XML patching with backup and verification
- experimental archive-only clothing inspection and native patch staging, without external archive tools
- bounded, local session recording of accessible macOS/CyberMac messages from Diagnostics

Use redscript 0.5.32 or newer for 2.5. The old 0.5.31 compiler cannot load its
script cache. The clothing delivery helper now compiles against the actual
App Store 2.5 files and can be prepared from Appearance Mods. The jacket's worn
appearance is confirmed; a new grant is not independently established if the
target garment was already owned. Other script mods remain
individually dependent on their APIs and compatibility.

Unsupported:

- Cyber Engine Tweaks
- RED4ext
- Codeware
- ArchiveXL
- TweakXL
- Equipment-EX
- DLL / ASI
- REDmod-only mods
- automatic installation of clothing/body mods and framework-dependent appearance add-ons
- simultaneous appearance mod stacks or automatic body/refit compatibility

## Record a test session

Open **Diagnostics → Start recording** before launching the game, and keep
CyberMac open. Add a marker such as “equipped Lucy jacket” to correlate an action
with available messages. Game launch/exit notifications are marked automatically
while CyberMac is open. Stop recording and use **Show files** to inspect the
local capture and its status report.

Each session stops after one hour or 10 GB (10,000,000,000 bytes). Only the latest
three sessions are retained, using up to 30 GB in total. Space is consumed as
messages arrive, not reserved in advance. Recording also stops when CyberMac closes normally. This collects
accessible macOS and CyberMac messages; it does not instrument every engine call,
inventory change, or clothing event, and does not read private game-container
logs. Empty output is not evidence of success. Source and storage failures are
reported explicitly. No game files, saves, or system logging settings are changed.

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
- redscript macOS zip (0.5.32+ for 2.5), imported by user for the script workflow
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

For archive-only appearance experiments:

```bash
swift run cybermac appearance inspect "/path/to/clothing.zip"
swift run cybermac appearance stage <experiment-id>
swift run cybermac appearance prepare-delivery <experiment-id> --redscript-zip "/path/to/redscript-v0.5.32-macos.zip"
# Close the game and review the printed install and restore commands.
# After manually copying the prepared file:
swift run cybermac appearance verify <experiment-id>
swift run cybermac appearance verify-delivery <experiment-id>
# After manually restoring the original:
swift run cybermac appearance verify <experiment-id> --restore
swift run cybermac appearance verify-delivery <experiment-id> --restore
```

Packages with several archive alternatives require `--archive-entry "entry/path.archive"`
on inspection. Use the same `--home "/path/to/workspace"` on every command when
testing in an isolated workspace. File verification is separate from observing
the clothing in-game.

If you want to test the UI, use SwiftPM. If you want to test compatibility, prefer CLI first.

## CLI usage

```bash
swift run cybermac doctor
swift run cybermac refresh-base-cache --dry-run
# After confirming this is an unmodified game installation:
swift run cybermac refresh-base-cache
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

For the fresh 2.5 installation results and next milestones, see the
[24 October 2026 reinstall check](docs/reinstall-check-2026-10-24.md). The
[23 October development audit](docs/development-audit-2026-10-23.md) records the
fixture tests and steps to resume after reinstalling the game.
Deleting CyberMac's support folder removes its installed runtimes, managed mods,
cache snapshots, indexes, and backups. Re-import runtimes and create a fresh base
cache from the unmodified installation before activating mods. Old backups are
not needed to start again. Runtime import and base-cache creation currently use
the CLI; the desktop app does not yet expose those setup actions.

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
