# CyberMac

CyberMac is experimental developer-preview software for Cyberpunk 2077: Ultimate on macOS. It has been tested locally on the Mac App Store version on Apple Silicon. It is not affiliated with CD Projekt Red, Nexus Mods, redscript, input-loader, or any mod author. Use at your own risk and keep backups.

## What it is

CyberMac is an experimental macOS mod manager for Cyberpunk 2077. The app opens on **Install mods**: drop ZIPs or choose files, and it identifies the package, prepares compatible files, backs up originals, installs through the macOS password prompt, and verifies the result. The CLI and Advanced tools retain their manual workflows.

Install mods shows imports on the left and the selected ZIP's details on the right. Choose clothes, variant selection, retry and recovery actions stay with that ZIP. **Browse all variants** keeps long clothing collections out of the import list, and the panes stack in narrower windows.

Multiple downloads are queued in order. A blocked or invalid package does not discard the rest. Runtime ZIPs use the same drop area; importing redscript resumes waiting script mods. Collections ask for one variant rather than installing conflicting alternatives. Installer history retains recovery plans and offers **Restore previous files**; restore changes in reverse install order when they share game files. Cancelled password prompts can be retried.

Every import row has a right-side **×** to remove it from the list. Removed entries stay under **Recently removed**, with **Put back** and any existing file-restoration action; their recovery plans and retained downloads are kept. Removing a list entry does not uninstall game files or change clothing selections. Removal is disabled while work is running and is saved across app restarts. Library mod rows also have a top-right **×**, using the existing confirmation to remove managed files and the manifest; previously activated scripts still require reactivation afterward.

Dropping a clothing ZIP opens **Choose your clothes**. Check individual garments, filter by category or name, then choose **Install selected**; new imports start with nothing selected. Compatible archive replacements are converted into independent item records and private assets, preserving the vanilla garments and allowing colour alternatives to coexist. Complete Apple's Installer, then load a save and equip the new inventory items. This flow does not require **Clothing → Play**. Other packs' selections and already-owned inventory items are kept.

Discovery reads the game's clothing templates and each archive's resources rather than relying only on pinned Lucy/Jinguji recipes. The local Jinguji collection has 214 archives and resolves to 232 garment/slot choices, including meshes usable in two slots. This count establishes discovery, not gameplay validation of every choice. Existing imports are upgraded when reopened. Finder metadata is ignored and repeated identical garments share one selector entry.

**Live Blender previews are paused.** Browsing and importing never launch a renderer. Existing saved wardrobe images remain visible; other garments show their names and a placeholder. Only selected clothes are converted. Game templates are cached as compressed metadata, and all selected item records are written in one batch per database. Large game archives use APFS clones and a small local Installer package, avoiding multi-gigabyte package compression.

The conversion adapter currently targets archive replacements for the six base-game feminine V clothing slots. Framework-dependent packages (ArchiveXL, TweakXL, RED4ext, custom body/refit rules) still need adapters; unsupported garments show an explanation. This is not universal support for every downloaded clothing ZIP. The generic Black and Carol bandeau additions are user-confirmed to appear in inventory and equip correctly. Other new variants need an in-game appearance check; the earlier seven prepared Lucy/Jinguji items retain their prior gameplay confirmation.

`scripts/build-app.sh` locates existing Python, WolvenKit CLI, .NET and ARM64 Kraken tools and records their paths in the app's conversion resources. Blender, NumPy and Pillow are not needed for the active import path. `CYBERMAC_PREVIEW_PYTHON`, `CYBERMAC_PREVIEW_DOTNET`, `CYBERMAC_PREVIEW_WOLVENKIT` and `CYBERMAC_PREVIEW_KRAKEN` can override discovery before building. No tooling is downloaded at import time. See [the clothing addition workflow](docs/clothing-additions.md) for validation and limits.

The sidebar keeps Install mods, Clothing, Library and Settings visible. Activation, archive research, backups, outfits and diagnostics are under **Advanced**.

All app screens and clothing dialogs share the same cyan actions, selection states, panel borders, spacing and typography. The sidebar uses native glass where available; cards use lightweight surfaces without a separate blur effect for every item. Reduced Motion and Reduced Transparency settings are respected.

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
original garments. The first isolated package rendered only in inventory and Photo Mode. The user
now confirms v2 renders Lucy throughout gameplay and preview views, with donor
images in the inventory slots. V2 uses unique appearance names, a valid default
and explicit donor icon lookup, and disables an active wardrobe set for the test. See the [Lucy duplicate workflow](docs/appearance-native-workflow.md#lucy-outfit-on-the-four-duplicates--25-october).

## Current support

Supported:

- redscript-only mods
- redscript + r6/input XML mods
- Mac App Store Cyberpunk 2077: Ultimate layout
- automatic final.redscripts activation through the system authorization prompt
- automatic input XML patching with backup and verification
- experimental archive-only clothing inspection and native patch staging, without external archive tools
- selective standalone additions from compatible feminine V clothing replacement ZIPs, using local conversion tools
- bounded, local session recording of accessible macOS/CyberMac messages from Diagnostics

Use redscript 0.5.32 or newer for 2.5. The old 0.5.31 compiler cannot load its
script cache. The clothing delivery helper now compiles against the actual
App Store 2.5 files and can be prepared from Appearance Mods. The jacket's worn
appearance is confirmed; a new grant is not independently established if the
target garment was already owned. Other script mods remain
individually dependent on their APIs and compatibility.

The ZIP installer checks the redscript version before compiling for game 2.5.
Failed new script imports stay in Library, disabled, so another mod can still
be installed. A health refresh can be dismissed with **Stop checking**.

The local build prepares a narrow `.pkg` containing only the planned game files
and opens Apple's Installer for authorization and placement. Finish its install
window; CyberMac waits for a package receipt or the successful script-only entry
in macOS's protected install history, then verifies the game files.
Package scripts are generated by CyberMac, never taken from mod downloads.
The original backups are retained. This avoids elevated-shell attribution
problems and does not depend on Apple's restricted privileged-file-operations
entitlement. If a permission is already enabled, repeatedly toggling it is not
an installation step. Errors are retained after Restore for diagnosis.

Unsupported:

- Cyber Engine Tweaks
- RED4ext
- Codeware
- ArchiveXL
- TweakXL
- Equipment-EX
- DLL / ASI
- REDmod-only mods
- arbitrary standalone clothing/body conversion and framework-dependent appearance add-ons
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

- Automatic installs use one typed file-plan boundary and the standard macOS administrator prompt; commands from package files or manual text panels are never executed.
- Generated files, retained downloads, backups and recovery history stay under `~/Library/Application Support/CyberMac`.
- Every replacement, backup and existing destination is checked before the first game write. Multi-file failures attempt rollback and retain their recovery plans.
- Installation and restoration verify SHA-256. Changes are refused while the game is running, when files differ from the expected state, or when the prepared clothing session is active.
- The first automatic script setup only snapshots a cache matching the game's resource seal. An existing clothing helper cannot become the vanilla baseline.
- The CLI and Advanced panels still generate manual installation commands for research workflows.

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

The four independent Lucy items are confirmed working locally across gameplay
and preview views. A combined Lucy/Jinguji developer package now prepares three
additional items: a black/silver corset, black Judy pants and chrome heels. The
user confirms both outfits work together, including Jinguji in all modes, and
the in-game CyberMac notification is visible. The new **Clothing** app screen
shows model-rendered previews, collection filters and per-piece selection. Its
launch button prepares the selected inventory grants and opens the verified
launcher in Terminal for the macOS password; originals restore after exit.
Seven native custom icons are prepared and still need their in-game display
check. Previews use the garments' source textures and material colours under
studio lighting, which can differ from the game's lighting.
This supports these specific saved
variants, not arbitrary Jinguji archives or body-shape mods. See the
[combined wardrobe workflow](docs/appearance-native-workflow.md#jinguji-alongside-lucy--26-october).

Build a double-clickable local app with `scripts/build-app.sh`; output is
`dist/CyberMac.app`. A prepared icon wardrobe is registered with
`cybermac clothing register --workspace <folder>` or opened from the Clothing
screen's menu. Registration references existing archives and restore files.
ZIP selection recognizes the saved Lucy packages and the three prepared Jinguji
variants; arbitrary new mod conversion is not exposed as a working app feature.

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
