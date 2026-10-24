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

The first gameplay attempt (24 October, 21:29–21:31 Sydney) produced no visible
notification, according to the user, after equipping clothes and outfits. The
145-second recording completed normally: 40.18 MB and 35,481 structured events,
with no probe prefix, FTLog, redscript or TweakDB messages. Eleven Apple-framework
errors did not identify a clothing or script failure. The original script cache
was verified afterward. No installed-cache hash was recorded during the session,
so this result cannot distinguish cache loading, hook execution, notification
rendering and log delivery. The next experiment needs independent execution
evidence and a recorded installed-cache fingerprint before launch.

## Combined execution and equip test v2

Work is now packaged as a complete test pass. Preparation produces **Run Equip
Probe.command**, alongside separate install/restore commands for recovery. The
combined command performs the manual verified installation, starts recording,
verifies a startup filesystem trace, launches through normal LaunchServices,
waits for exit, and restores the original scripts. Do not start a second app
recording for this test; the command owns the same bounded session recorder.

The script changes cover separate evidence paths:

- A direct **CYBERMAC SCRIPT EXECUTED / MENU** marker replaces the main-menu
  version text. Hover callbacks repaint it after preserving the original calls.
- A direct **CYBERMAC SCRIPT EXECUTED / HUD** marker writes to an existing HUD
  text widget on initialization, without using the notification blackboard.
- Diagnostic notification text is rendered with `inkText.SetTextDirect` after
  the original update. The old widget code passes arbitrary text through
  `GetLocalizedText`; the new route removes that ambiguity without asserting
  it caused the first failed observation.
- Ordinary `EquipItem` and saved-wardrobe `EquipVisuals` are both observed.
  Wardrobe visuals bypass the original probe's equipment hook. Visual-slot
  hashes and physical equipped state are reported separately. The shared limit
  remains 32 observations per equipment restoration; no items or money are given.

The CLI records exact installed-cache and executable hashes immediately before
launch and records the cache again after exit in `probe-run.json`, next to the
usual session log. A read-only, administrator-authorized `fs_usage` source runs
for at most 180 seconds. It starts before launch, with unrelated filesystem rows
discarded in memory. Path-named game script-file rows are retained (at most 256
rows, 4 KiB each), plus bounded diagnostics and counts. The updated recorder also
keeps up to 2,048 game filesystem rows (4 KiB each), including unnamed file reads
and mmap calls. Context sampling exhaustion is reported separately from actual
trace loss; script-path retention continues after that sample fills. A unique control-file access
must appear before launching; permission failures or a missing control stop the
test before the game opens. Named `fs_usage` filters may resolve only processes
already running, so the capture must not depend on that filter finding a future
game process. Attribution uses the trailing process name, not a path containing
the game name. Its numeric suffix is a thread identifier, not a PID.

Incomplete lines, output exhaustion, source diagnostics, or buffer-loss messages
mark trace evidence incomplete. File opens establish access, not VM validation
or execution; absence of captured messages remains ambiguous. The direct menu
marker is the independent execution observation. If the game remains open or
the cache changes unexpectedly, automatic restoration refuses to overwrite it
and the separate restore command remains available.

An independent [2.3.1 Mac investigation](https://github.com/FOX-cOSMIC/cp2077-mac-mods/blob/main/docs/FACTS.md)
reports native script loading and execution in F-050–F-052, correcting its own
earlier negative result. It motivates this approach; its offsets and gameplay
results are not evidence for our App Store 2.5 build.

Offline verification compiled v2 against the real cache and checked all eight
wrapper/proxy chains. Seven preserved bodies match their source decompilation;
the menu initializer's opcode sequence also matches after function-local slot
renaming, including the exact original static superclass-call target. The source
decompiler displays that call as `this` after proxy renaming, so opcode inspection
was needed before treating it as preserved. The private validation evidence stays
in the ignored experiment directory. Actual menu/HUD rendering and privileged
startup tracing required the combined runtime test described below.


## 24 October 22:11 session result

Session `a3a85e93-54af-4f8a-83f7-8d1422010ef7` recorded a normal 84-second
launch/play/exit cycle, 31,659,276 log bytes and 28,019 structured events. The
compiled v2 cache matched SHA-256
`62187866234d009e5197265ae7142467a4899d92c1112731b7bf6b6dd36dd4f8`
both before launch and after exit. The original cache was restored and its
original hash verified afterward.

The startup trace saw its prelaunch control and 2,437 game filesystem events,
with no retained script-path rows and no detected source loss. The log contained
no probe messages. The user **did not notice** the menu/HUD marker: visual
execution is unknown, not a confirmed negative. Eleven Apple-framework errors
did not identify a script or clothing failure.

The old trace discarded game rows that lacked `redscripts` in their text.
Apple's [fs_usage implementation](https://raw.githubusercontent.com/apple-oss-distributions/system_cmds/main/fs_usage/fs_usage.c)
can omit a pathname when no VFS lookup accompanies a file-descriptor event.
Those discarded rows cannot be reconstructed. This result establishes no
retained path-named script access, not that the game never read the cache.
The updated bounded game-context sample preserves such events for inspection;
it still cannot identify a file from an unnamed descriptor alone.

## Explicit script-file test v3

Read-only ARM64 inspection of **this exact App Store 2.5 executable**, SHA-256
`8f4a88ad201f360772b3747f51701944f39b98b4ecbf7edc6271c1cc24932844`,
identified an explicit file route that bypasses default filename resolution.
These are unslid addresses in that executable, not offsets to use on another
build and not instructions to patch it.

| Location | Observed behavior |
| --- | --- |
| `0x1014b0bf4`, `0x1014b0dc0` | Native argument parser accepts a single `-key=value` argument. Both `-` and `/` are option prefixes; a separate absolute path can be parsed as another option. |
| `0x103ab1c58`–`0x103ab1cf8` | Looks up `scriptsBlobPath`, constructs a path, writes settings `+0x18`. Relative paths resolve against the working directory. |
| `0x103ab153c`, `0x103ac4f04`, `0x101d8b36c` | Transports the same application settings into engine initialization. The derived engine method calls base initialization with the same settings pointer. |
| `0x103ac5614`–`0x103ac5630` | Copies settings `+0x18` into engine `+0x170`, then calls the boot script dispatcher. |
| `0x103ac0b38` | Nonempty engine `+0x170` is queried and passed directly to blob loader `0x103ac0fdc`, without appending a filename. Empty selects the default resolver. |
| `0x103ac0cfc` | Default resolver constructs variant filenames. Global `0x107fdac88` is a fallback **directory** operand, separate from the explicit file field. |

The exact option is one argv value:
`-scriptsBlobPath=/absolute/path/to/cybermac-equip-probe.redscripts`.
This proves the static parser/loader route exists. LaunchServices delivery,
sandbox access, VM acceptance and visible execution still need runtime evidence.
It does not establish why v2 produced no captured output.

New preparation emits a v3 manifest and manual commands. The test places an APFS
clone of the compiled cache at
`Contents/Data/r6/cache/cybermac-equip-probe.redscripts` inside the game, so it
uses a location already containing game data. It does **not** replace
`final.redscripts`. Placement uses an exclusive hard link from a separately
verified temporary clone; an existing destination cannot be overwritten.

**Run Equip Probe.command** performs placement, starts the verified trace and
recorder, launches through `open -W <app> --args <single-option-value>`, waits for
exit, then removes only the expected auxiliary file after verifying its hash.
The original script cache is verified before launch and after exit. Open games,
unknown contents or changed originals stop cleanup for review. The separate
**Restore Equip Probe.command** is the recovery cleanup if the combined command
is interrupted; it never restores over an unknown file. Older v2 manifests
remain runnable with their original replacement workflow.

The source and its eight wrapper chains are unchanged from v2. The experiment
changes the loading route, while improving capture coverage. It grants no items,
changes no quest facts and creates no large backups. Keep the reference manual
save untouched. At the main menu, inspect the version text for
**CYBERMAC SCRIPT EXECUTED / MENU**; then load a save, equip one ordinary garment
and one saved wardrobe outfit, and quit normally. Visible rendering and record
checks must be assessed separately from the presence of an auxiliary file.

Offline verification: all 577 repository tests passed (559 core, 18 app), including
exclusive-placement collisions, fixed-path/argument validation and unnamed trace
events. All three generated commands passed shell syntax checks. The newly
compiled cache was independently checked for all eight preserved wrapper/proxy
chains, including the menu superclass-call opcodes. Its SHA-256 is
`f968e5c01fe40043d682f83578cc5f3ce51ee2743685bdd3d103907d5a3bf4b2`.
Original game scripts still match the original hash; no auxiliary cache has been
installed or game launched during this preparation. The obsolete v2 generated
cache was removed after validation; its source, reports and recovery script remain.


## Confirmed menu execution — 25 October 10:02 session

The user explicitly saw **CYBERMAC SCRIPT EXECUTED / MENU**, including after
returning from gameplay to the main menu. That text is intentionally confined to
the main-menu version widget; it is not a desktop notification or a gameplay
pause-menu control. Seeing it again on return is expected. **Custom redscript
execution in the main menu is now confirmed** on the exact App Store 2.5 build
using the explicit auxiliary-cache workflow. This does not establish which
other loading routes would work or why earlier attempts were inconclusive.

Session `7a7c4df5-a1af-436b-bc0f-6ed2a04a3cdd` ran on 25 October 2026,
10:02:12–10:04:29 Sydney. Recording stopped normally at 55,645,626 bytes,
with 49,021 structured events. The auxiliary cache hash matched the prepared
`f968e5c0…` bytes before launch and after exit. The original cache hash matched
`7a5a798f…` afterward and on review; the auxiliary file is now absent, confirming
cleanup. No new original-file backup was needed.

No `CyberMacEquipProbe`, `FTLog`, `record_check`, equip or wardrobe diagnostic
messages were captured. There were zero unified-log events whose sender image
was the main game executable; five came from its App Store services library,
and the remainder came from system libraries/frameworks. Nine error events were
from Apple frameworks and did not identify a script or clothing failure.
Consequently this recording does not establish gameplay-hook execution, record
existence, item acquisition or the destination of FTLog output. The user's
visible menu result is independent evidence that the script executed despite
those empty log searches.

The file trace observed its control and 2,630 game filesystem events with no
detected source loss, but no script-path rows. Its bounded 2,048-row context
sample filled during the first 0.82 seconds; sampling truncation is explicit.
This trace cannot override the visible execution result or establish that the
auxiliary file was never loaded. No further menu-only gameplay test is needed.
The next implementation should make gameplay record/delivery results observable
through the now-proven script route rather than relying on unified-log output.
The complete local analysis is retained under the ignored research directory;
raw session evidence was not changed.


## Standalone clothing records and delivery — 25 October

The user clarified that Lucy replacement success predates this work by about
five months. Earlier duplicates existed but were not equippable and displayed
incorrectly in inventory/storage. That history changes the acceptance target:
a new item must be a usable inventory/equipment object, not merely a database
row or another successful replacement. Deleted old experiment artifacts prevent
attributing that earlier failure to one proven cause.

A concrete clone defect was found in the current source. `Item_Record` inherits
seven properties from `BaseObject_Record` which the clone schema did not include:
`statModifierGroups`, `effectors`, `statPools`, `statModifiers`, `weakspots`,
`objectActions`, and `savable`. Their existence is corroborated by the actual
2.5 cached RTTI getters; the real donor items contain these flats. The expanded
schema also checks `questFactPreventDualWield` and lower-case `craftingData`.
Copying now includes 90 materialized flats per actual donor, including its 11
stat modifiers, one modifier group and two object actions. False/empty values
are preserved. The schema contains 91 candidate property names; it is not a
claim that every possible future item schema is covered.

The new `clothing prepare` command prepares all four independent pieces:

| Piece | Donor record | New record |
| --- | --- | --- |
| Jacket | `Items.Vest_08_basic_01` | `Items.CyberMac_Standalone_Jacket` |
| Top | `Items.Shirt_01_basic_01` | `Items.CyberMac_Standalone_Top` |
| Pants | `Items.Pants_09_basic_01` | `Items.CyberMac_Standalone_Pants` |
| Boots | `Items.Boots_01_basic_01` | `Items.CyberMac_Standalone_Boots` |

These keep the donor visuals and icon references. The originals retain their
own IDs and data. Custom appearance isolation remains separate from this record
and equipment repair. The script requests CyberMac Jacket/Top/Pants/Boots labels
only for the four new records, through the normal live and record-based inventory
data builders; actual display still requires the game test.

On player attachment the helper schedules delivery after three seconds. It
checks runtime record existence, grants only missing items, obtains each actual
inventory instance through `GetItemDataByTDBID`, checks equippability and queues
`EquipRequest` with that instance's `GetID()`, including its seed. It does not
try to equip a bare TweakDB record ID. A second callback checks actual equipment
two seconds later and requests a direct-text game message reporting inventory
and equipped counts. It never reports successful equipment solely because a
request was queued. An active wardrobe outfit can mask equipped physical clothes;
the helper preserves the selected wardrobe rather than silently removing it.
No currency, quest facts, stats, appearance archives or original garment records
are changed by the helper.

Preparation pins the exact supported executable, original script cache and
compiler, and verifies both databases against the app's resource seals. It
reuses their typed value pools, adds the four records and their flat keys, and
keeps original query/group-tag bytes. Each original database gets one small APFS
restore clone; intermediate generated databases are removed. The whole local
workspace is approximately 208 MB logically, with clone sharing for originals.
No additional multi-gigabyte archive backup is created.

The generated **Run New Clothing.command** checks the game is closed, verifies
all inputs before placement, installs both database files through verified
same-volume placement, exclusively creates `cybermac-standalone.redscripts`, and
launches with its single explicit script-file option. Its exit handler invokes
**Restore New Clothing.command**, which prechecks both originals/current hashes
and the auxiliary hash before restoring. Unknown files or an open game stop
recovery for review. Recovery does not depend on generated database payloads.
Interruptions have the same standalone recovery command. Process-check errors
are distinguished from a closed game. The main `final.redscripts` stays intact.

Keep the reference manual save untouched. Saving custom items and then launching
without their records is not a supported cleanup path; use the clothing command
on future modded launches. The command restores game files, not inventory changes
already written into a save.

Offline checks against the real files independently found:

- Base: all 196,423 original records and 3,005,358 flat keys preserved.
- EP1: all 213,586 original records and 3,434,633 flat keys preserved.
- Each final file adds exactly four records and 360 flat keys. Every cloned
  value index matches its donor; all typed value-pool bytes are unchanged.
- Original query/group-tag bytes are unchanged. Both input files still match
  their original resource seals after preparation; no game files were installed.
- The official compiler accepted the helper. Streamed bytecode inspection
  verified all four wrapper/proxy chains preserve the full original operation
  sequences and static/native call targets, allowing function-local slot IDs and
  unordered declaration headers to differ.
- Compiled helper SHA-256:
  `69eebf2fd39c5052d9f464f931cf9a7fabad0dafdcaaad36e55d53924193cc98`.

The offline writer still preserves the original records-checksum header rather
than claiming a verified recomputation. Runtime acceptance, UI label rendering,
new-item visibility and successful equipment require this combined test. The
missing inherited flats are fixed; the old in-game symptom is not yet marked
resolved. No additional menu-only test is needed.

Final validation: all 580 tests passed (562 core, 18 app). New coverage executes
the generated shell preflight with closed/open/error process results, preserves
false and array-valued inherited properties, and checks quoted paths and recovery
without generated payloads. Both actual prepared commands also pass syntax
checks. Database and script audits remain local ignored artifacts. The current
prepared command is `.research/standalone-clothing/Run New Clothing.command`.

### First player report from the four-item run — 25 October

The user reported opening the game and finding several clothes already equipped.
This is consistent with the helper's automatic delivery and equipment step
running. The report does not identify the individual records, CyberMac labels,
or the helper's inventory/equipment counts, so those details and save persistence
remain unconfirmed. This is useful player-observed progress beyond the earlier
menu marker, rather than independent proof of every item acceptance condition.

After this run, both installed TweakDB files matched their original hashes, the
auxiliary `cybermac-standalone.redscripts` was absent, and `final.redscripts`
matched its original hash. Cleanup is therefore verified. This launcher does not
start the diagnostic recorder; no new recording exists for this clothing run.

The next clothing milestone is distinct custom appearances for these new records
while preserving the donor garments. This package still uses the donors' vanilla
visuals and icons; the old Lucy replacement is not that milestone.
