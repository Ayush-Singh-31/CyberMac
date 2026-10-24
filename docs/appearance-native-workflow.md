# Native appearance workflow — 24 October 2026

CyberMac now inspects and stages archive-only appearance mods using native Swift.
The first target is clothing on the original feminine V body. Body shapes and
matching clothing refits follow a successful visible clothing test.

**Confirmed result:** the user loaded a save and Lucy's jacket rendered correctly
when worn. The inventory/storage preview still showed the replaced vanilla
garment. The user then restored both original game files and both hash checks
passed. Item delivery is not independently established if the target was already
owned. Next: an independent item record and accurate inventory presentation.

Earlier installation recovery:
The first direct `cp -c` command removed the destination before macOS denied
cloning into the app. After granting Terminal App Management permission, the
original archive was restored. Both original game files now match their sealed
hashes. A false helper-integrity error in the recovery check was traced to
comparing relative and absolute file URLs; the helper and backup bytes matched.
The official 2.5 Mods/mod.io menu is available on this Mac, but no suitable
clothing package has been confirmed there yet.
The [official content guide](https://mod.io/g/cyberpunk-2077/r/mod-content-available-in-cross-platform-mod-support)
now documents built-in subsets of ArchiveXL and TweakDB YAML functionality;
these should be evaluated independently of the old native framework ports.

## What works in CyberMac

- Appearance Mods screen with ZIP/archive selection, explicit variant selection,
  inspection, preparation, recent experiments and install/restore verification.
- Native RDAR v12 reader with bounded tables, segment/range validation and CRC64.
- All sealed Mac archives are searched for every mod resource and dependency.
- Every affected official archive receives its matching replacement resources.
  New assets can be inserted when exactly one affected archive provides a clear
  destination. Missing dependencies and ambiguous destinations block staging.
- Donor payload bytes, flags, timestamps, SHA-1 fields and dependency lists are
  preserved. Segments and dependency offsets are rebased, records sorted, and
  index/header lengths and CRC regenerated. No external Intel archive tool or
  decompression is required.
- Full original archives are checked against SHA-256 values in the game's
  CodeResources table before preparing backups and separate outputs. Staged
  payloads and backup hashes are checked again. Hashing streams large files.
- Game/source changes invalidate the plan. Verification also rechecks the
  staged file and backup. File placement and gameplay success remain separate.

CyberMac writes to its own workspace. It prints manual installation and restore
commands; neither the app nor the new CLI modifies the game bundle. Keep the
game closed while manually copying either archive. Restore originals before a
game update, storefront repair, another experiment, or deleting backups. An
official resource change can affect bundle integrity; successful staging alone
does not establish that this App Store build will launch with it.

This first workflow prepares one experiment at a time. It does not combine mod
stacks or determine body/refit compatibility. A separate temporary inventory
helper can now be compiled for item IDs included in the clothing package.
Framework
packages are rejected rather than silently stripped down to archive files.
Direct `.archive` inputs have no external dependency manifest to inspect; check
the author's requirements too.

## Real Lucy jacket preparation

Installed game: `/Applications/Cyberpunk2077.app`, Mac App Store 2.5.0,
build `5814786.13589799`. The inspection read 57 official archives.

| Check | Result |
| --- | --- |
| Package | `Resources/Lucy/Jacket-4621-1-1654925475.zip` |
| Selected mod | `Edgerunners_Jacket/Edgerunners_Lucy_Jacket_xBaebsae.archive` |
| Existing resources | 2 in `basegame_4_appearance.archive` |
| New resources | 3, inserted into that same archive |
| Unresolved dependencies | 0 |
| Original size | 6,994,468,864 bytes |
| Original SHA-256 | `5a6e692e13e44e0b037d3150bd1d3e0a580369b1e1cb44d4fbc946ec6cf74ce5` |
| Staged SHA-256 | `c3bb96f0018124bbfc7f66321e9597308211b8ae2766c1e0ff2e209daa68d27d` |
| Package's existing garment ID | `Items.Vest_08_basic_01` |
| In-game result | User confirmed successful save load and correct worn Lucy jacket |
| Inventory/storage image | Original garment still shown |
| Restoration | Both original file hashes matched after the test |

Experiment: `a3313ac2-5766-4b38-8c45-3e6dd0484a76`.
Isolated home: `.research/appearance/native-workspace`.
Original backup: `official-archive-20261024-105716-5a6e692e13e4`.
At preparation completion, the original game archive matched its sealed hash.
The subsequent manual copy failed as described above; recovery is now verified.
A local test guide, with this experiment's exact placement
and verification commands, is in `.research/appearance/lucy-jacket-test.md`.

Evidence: `native-jacket-plan-v2.json`, `native-jacket-stage.json`, and
`native-original-verification.json` in `.research/appearance/`. These ignored
files and game-derived copies are local only and must not be committed.

The full Lucy clothes ZIP was also inspected: 24 resources, with six existing
matches and 18 new assets for the same appearance archive, and no unresolved
archived dependencies. Its package lists the top, pants and boots IDs recorded
in the appearance plan. It is a preparation candidate for the next experiment;
it has not been staged or tested in-game. Inspecting either package does not
establish whether the 2022 assets render correctly on this newer game build.

## Use

```sh
swift run CyberMacApp
```

Open Appearance Mods, choose the clothing ZIP, inspect compatibility, then
prepare the test. Collections with several archives require choosing one
variant. Expand the prepared install/restore commands and keep the backup.

Equivalent CLI:

```sh
swift run cybermac appearance inspect "/path/to/clothing.zip"
swift run cybermac appearance stage <experiment-id>
swift run cybermac appearance prepare-delivery <experiment-id> --redscript-zip "/path/to/redscript-v0.5.32-macos.zip"
# Run the printed install command manually, with the game closed.
swift run cybermac appearance verify <experiment-id>
swift run cybermac appearance verify-delivery <experiment-id>
# Launch and equip the garment; inspect its actual appearance.
# Close the game and manually run the printed restore command.
swift run cybermac appearance verify <experiment-id> --restore
swift run cybermac appearance verify-delivery <experiment-id> --restore
```

Use the same `--home` value on every command for isolated experiments. For a
collection, pass `--archive-entry "path/inside/package.archive"` to inspect.
The first visible test must equip the package's target garment on feminine V,
confirm the replacement, and then confirm the original after restoration.
Existing wardrobe/transmog selection can conceal the equipped item's appearance.

## Current community progress

These are primary-source reports, not proof of compatibility with this exact
App Store build:

- [Archive Loader](https://github.com/JoshuSnuff/cp2077-macos-archive-loader)
  reports working archive-only mods by patching official archives around a
  game session and restoring the originals. Reviewed commit
  `0b1b9c088319034e77d82d3a6bcb7b3100a4c69b`.
- [Mac Archive Patcher](https://github.com/brunoformagio/cp2077-mac-archive-patcher)
  implements native archive record transplantation and describes plugin and
  official-archive override routes. Reviewed commit
  `f619246bf18558b62b06230b5d47f23cb7c65a44`.
- [NightCity Console](https://github.com/ysrdevs/nightcity-console-mac) documents
  an in-game console and native framework work, but its README targets Steam
  2.3.1. The [ArchiveXL port](https://github.com/dbc-hbin/cp2077-archive-xl-macos)
  lists 2.31. Their offsets are not validated for App Store 2.5 here.
- [CDPR's 2.5 announcement](https://www.cyberpunk.net/en/news/52120/check-out-whats-coming-to-night-city-in-the-edgerunners-2-update-for-cyberpunk-2077)
  describes official mod.io integration including Mac. This does not establish
  that arbitrary legacy Nexus or ArchiveXL clothing loads through that menu.

Reference checkouts are under ignored `.research/`. Relevant MIT notices and
attribution are preserved in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
REA remains available for focused unresolved resource/loader research; no full
reverse-engineering pass was needed for this implementation.

## Validation

The current full suite passes 560 tests: 542 core and 18 app tests, including
22 archive/appearance and 10 session-recorder tests. Coverage includes malformed archives, full donor metadata/dependencies,
duplicate owners, new assets, ZIP variants, framework rejection, stale inputs,
tampered files, workspace boundaries, and fixture install/restore checks.
The CLI also completed actual Lucy jacket inspection, backup, staging, and
original-file verification against the installed game before the failed copy.
An independent Python binary reader confirmed all five donor payloads and
dependency lists, unchanged metadata for the other 83,417 original resources,
sorted hashes, and byte-for-byte preservation of the original payload region.
Its evidence is `.research/appearance/independent-jacket-validation.json`.

The app target builds. Automated UI interaction was unavailable because macOS
Computer Use permissions were not granted. The user has now confirmed a visible
gameplay test and subsequent original restoration. The redscript 2.5 cache-loading failure was resolved by importing
the official 0.5.32 Mac release, whose notes explicitly add 2.5 bundle support.
The item helper also needed its undeclared `LogChannel` calls removed. The
corrected helper has now compiled against the actual 2.5 cache and been
decompiled to confirm its grant call and already-owned-item guard.

## Getting the garment

Appearance Mods now offers **Prepare item delivery…** after inspection. Choose
the official versioned redscript Mac ZIP. The helper compiles in a workspace
owned by that appearance experiment, with its own sealed-hash-verified original
script backup; other installed script mods are not mixed into this first test.
The app prints separate install and restore commands for the script cache.

For the prepared Lucy jacket, one helper call targets the same existing garment
as the archive replacement. When installed, it is intended to supply a missing
garment as V attaches, skipping an already-owned garment. This avoids requiring
the player to find a specific vendor or recognize an internal item code.
Delivery remains unverified until the game is loaded with that helper installed.

Local manifest: `.research/appearance/native-jacket-delivery.json`.
Original scripts SHA-256:
`7a5a798fe88c5e4afd64b91e265deccd091c2c5c94241003a11abbd70fb6785c`.
Prepared helper SHA-256:
`4fe88dcb06d3a7d015d7cd4e121ae5f486af3f258a725469fd240b588d3c2ce7`.
The failed installation did not reach the script-copy step; original scripts
still match their sealed hash. No saves were edited during preparation.

Runtime source: [redscript 0.5.32](https://github.com/jac3km4/redscript/releases/tag/v0.5.32).
The downloaded Mac ZIP matched its published GitHub asset SHA-256
`b9df6cc0144d786dff9590eb6db913d20744055ab694e52fc8c4584eaee39a8a`.
It is retained locally under `.research/appearance/item-delivery/`, not bundled.

## Storage policy

The user explicitly requested minimal disk usage. Keep one active large clothing
experiment and reuse one verified original per affected archive. Backup and
staging now explicitly use APFS copy-on-write clones; a non-cloning volume must
not silently fall back to a physical copy larger than 500 MB. Prepared archive
permissions match the original so clone-based installation remains readable.
The generated install and restore commands clone into a fresh temporary folder
beside the source, verify its full hash, and then use a same-volume rename into
the game. They never clone directly over a destination: macOS `cp -c` can remove
that destination before a clone fails. Clone/hash/permission failures before
the rename therefore leave the destination intact. Temporary clones are cleaned
up. Existing experiments regenerate commands when loaded; CLI users can obtain
updated commands with `appearance commands <experiment-id> --home <workspace>`.
Terminal needs permission under **System Settings → Privacy & Security →
App Management** to modify the game app, in addition to administrator access.
[Apple describes this permission here](https://support.apple.com/en-au/guide/mac-help/mchl211c911f/mac).
Clones protect original bytes independently when another clone is edited.
Reported per-file sizes and `du` can count shared blocks multiple times.

The existing Lucy original backup and output were converted/confirmed as clones
of the original plus the append-only patch. Their hashes and paths are unchanged;
the game was not modified during that preparation. Cleaned obsolete Xcode/Intel/index builds, duplicate
test workspaces and script dumps, npm/download caches and inactive inspections.
Full REA evidence and symbol inventories were losslessly compressed. Net free
space recovered was about 2.05 GB after rebuilding only the current native CLI
under `.build/out` and removing the obsolete ARM64 build. Source files, original
Resources ZIPs, REA runtime and current test/restore files were retained.
Details are in `.research/appearance/storage-cleanup.json` and
`storage-compaction.json`.

User-run `Install Lucy Test.command` and `Restore Lucy Test.command` in
`.research/appearance/` provide the same verified two-file test without creating
additional backups. The install script checks the build, originals and outputs;
the restore script checks the build and original hashes. Both refuse a running
game. The first installation failed; original recovery is verified, while a
successful installation, save loading and worn jacket appearance are now confirmed.
Five command-execution regressions exercise clone
failure, hash failure, rename semantics, a missing destination, and symlinks;
the focused appearance and placement run passes all 27 tests. The additional
regression covers equivalent relative and absolute workspace URLs during helper
verification. Both original game files were also verified with a relative CLI
workspace path after this fix.

## Runtime observations and next record experiment

The inventory image and worn model have separate resource/data references.
The observed old thumbnail is consistent with replacing garment assets without
changing the inventory icon mapping. See the modding documentation for
[inventory preview icons](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Modding-Docs/blob/main/modding-guides/custom-icons-and-ui/adding-items-preview-images/README.md).

A separate item needs a registered unique TweakDB ID, appearance/resource links
that do not overwrite the original, and its own name/icon mapping. Giving two
copies of the same ID is still two copies of the same item definition. Our
existing binary clone stager labels its output checksum-unverified and writer-
incomplete; successful offline parsing is not engine registration. Prefer testing
one vanilla-record clone through the supported loader before converting Lucy
to a standalone addition.

Diagnostics now has a bounded session recorder for available macOS/CyberMac
messages, automatic game launch/exit markers, and manual action markers. It keeps
three sessions capped at 10 GB/one hour each (up to 30 GB total), records failures explicitly, and
does not change the game or system logging configuration. Private game-container
logs were permission-denied during investigation and are not collected. Internal
inventory/equip events still need a proven logging bridge; the `LogChannel`
declaration is missing from this vanilla cache. That compile error does not
establish absence of a native implementation. Recording accessible messages does not establish
that every game operation is visible.

Recorder verification includes the actual macOS log source, bounded pipe reads,
source errors, manual stopping, size limits and forced termination, markers,
single-capture locking, retention, and invalid persisted reports. The first real
gameplay capture subsequently completed: 103 seconds, 29.94 MB, 26,470 structured
messages and five lifecycle/user markers. It stopped normally below the raised
10 GB cap. About half the messages were AppKit gesture diagnostics; no recorded
TweakDB, ArchiveXL, redscript or garment-equip messages were found. Eight Apple-
framework error entries did not identify a clothing failure. This validates the
recorder during play, while item/record tracing still needs targeted instrumentation.

## Read-only equip probe

`redscript equip-probe prepare` now creates one isolated, temporary script-cache
test for the verified Mac App Store 2.5 build. It requires the official redscript
0.5.32 CLI (SHA-256 pinned), an existing verified original script restore copy,
a new output directory, and one to eight item IDs. It creates no new backup,
does not stage an appearance archive, and never writes to the game automatically.
The generated cache is about 17 MB.

```sh
cybermac redscript equip-probe prepare \
  --compiler /path/to/redscript-cli-aarch64-darwin \
  --original-cache /path/to/existing-backup/final.redscripts \
  --out-dir /path/to/new-equip-test \
  --item Items.Vest_08_basic_01 \
  --item Items.CyberMac_Probe_Missing_20261024 \
  --game-app /Applications/Cyberpunk2077.app
```

The local test uses a vanilla record and a deliberately nonexistent ID as a
negative control; the latter is not a newly registered clothing item. No items,
money, quest facts, or persistent fields are added. On equipment restoration,
the probe reads actual `GetItemRecord` presence and aggregate inventory quantity
for the requested IDs. Missing records and unavailable transaction systems have
distinct output values. It wraps the game's slot-specific equip method, always
calls the original method, and observes at most 32 callbacks per restoration.
These can include weapons or automatic equips as well as clothing. Output includes
the numeric record hash, debug name, exact-instance quantity, appearance name,
and immediate before/after `IsEquipped` values. Immediate state is not evidence
that a visual model has finished loading or rendered correctly.

The original cache already declares `FTLog`; the probe calls it with the prefix
`[CyberMacEquipProbe/v1]`. It also posts a twelve-second `SimpleScreenMessage`
through the game's notification blackboard: a readiness message after restore
and a short data summary after each observed equip. The native log sink, Mac
notification visibility and hook timing remain **unverified in gameplay**.
The [redscript logging documentation](https://wiki.redmodding.org/scripting-cyberpunk/redscript/common-patterns/logging)
also describes native logging declarations, but does not prove this build's
messages will enter our macOS log stream. If notifications appear but the recorder
has no probe prefix, the logging bridge is still missing.

For the test, fully quit the game and run the generated **Install Equip Probe.command**.
It verifies the exact game executable, original restore copy, prepared cache and
current game scripts before using the existing verified clone-and-rename placement
helper. It stops if the game is running or the process check fails. The restore
command only accepts the expected original or probe cache and does not require
the compiled probe file to remain intact.

Start CyberMac session recording, launch the game normally and load a manual save.
Equip a different ordinary clothing item, close inventory immediately and watch
for a notification. Record a manual marker when doing so. No Lucy installation
is needed for this baseline. Fully quit and run **Restore Equip Probe.command**
afterward. Avoid overwriting the reference manual save. Retain the recording
for checking the probe prefix and actual event data.

Validation: generated source compiled against the original 2.5 cache; streamed
decompilation confirmed both wrapper/proxy chains preserve the original methods,
and the record lookups, quantity queries, native log call and notification update
are present. This establishes preparation, not runtime compatibility.
