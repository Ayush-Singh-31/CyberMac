# CyberMac appearance mod plan

## User priority — confirmed 24 October 2026

Target feminine V. Get custom clothing working first, then support changes to
body shape with clothing fitted to the selected body. Custom skin textures,
hair, faces and complete character appearances are part of the broader goal.

**Current result:** Lucy's jacket loaded and rendered correctly when worn on the
user's save. The inventory image remained the original garment. Both originals
were restored and verified afterward. Next experiments should distinguish
standalone item records, icons, and body/refit support from this proven replacer.
Diagnostics now includes a bounded recorder for available macOS/CyberMac logs;
internal game events are not automatically visible.
The next prepared test is a read-only equip probe: it checks selected item records
on save restoration and observes up to 32 equip callbacks, reporting item ID,
quantity, immediate equipped state and appearance name. It compiles against the
actual Mac 2.5 cache; native log delivery and on-screen notification delivery
still require a gameplay test. See [the test workflow](appearance-native-workflow.md#read-only-equip-probe).

Storage constraint: minimize local disk usage. Keep one active large experiment,
reuse verified originals, use APFS clones, clear redundant derived caches and
compress research evidence. Do not accumulate full game backups or download a
large decompiler toolchain without a concrete need. The current jacket needs no
new downloads before its test.

Earlier investigation: the user had the game running and confirmed the official 2.5 Mods
menu is present on their Mac. Prioritize validating that official loading route
before manually installing the staged official-archive patch. The user should
not need to recognize a garment from an internal item ID: reliable item
acquisition (a clearly labelled grant or a known vendor) is a prerequisite for
the first appearance test, together with a recognizable preview/label.
No item dispenser is installed in the game yet. The offline blocker has now
been resolved: official redscript 0.5.32 reads the 2.5 cache, and the helper was
corrected to avoid `LogChannel` calls without a declaration. Appearance Mods can
prepare a compiled inventory helper for a package's garment IDs, with verified
original script backups and manual install/restore commands. The real Lucy
jacket helper compiles and decompiles correctly. In-game delivery remains
unverified. See [native workflow](appearance-native-workflow.md#getting-the-garment).

Catalogue check follow-up: the user can browse the official menu but sees eyes,
lashes and gameplay/experience changes, with no clothing candidates. The public
[Mac catalogue](https://mod.io/g/cyberpunk-2077/m?platforms=mac) currently lists
44 of 51 mods; research has not identified a confirmed Mac Lucy/clothing entry.
Do not treat connecting the account or a clothing example in documentation as
proof that the corresponding clothing is available in that menu. Continue the
local clothing route while keeping official packaging as a separate research
option. Reliable item acquisition is still required before asking for an
in-game clothing test.

A native [Save Kit](https://github.com/ysrdevs/cyberpunk-savekit-mac) provides a
searchable item picker and separate-output save editing, but its README only
claims live validation on patch 2.3 (game version 2310). It is a research lead,
not a validated 2.5 dispenser. No save has been edited or tool installed.

The new [official content guide](https://mod.io/g/cyberpunk-2077/r/mod-content-available-in-cross-platform-mod-support)
documents partial ArchiveXL compatibility and TweakDB YAML support (new records,
clones and flat edits). This is a stronger route to investigate than the earlier
description of arbitrary framework support as wholly unknown. It remains a
subset: the guide calls out .ent/.app/.morphtarget and Resource Patch limitations,
and its PC-versus-console wording does not clearly establish each Mac case.
Verify a package's actual Mac availability rather than assuming those limits
apply identically to Windows, Mac and consoles. A vendor-stock tweak is one
candidate for item acquisition; it has not been implemented or verified here.

This supersedes the generic script-mod-first milestone in the reinstall check.
Script compilation, item grants and setup UI are supporting work when required
by an appearance experiment. A generic gameplay mod is not the main deliverable.

## First visible milestone: Lucy jacket

Use the existing `Resources/Lucy/Jacket-4621-1-1654925475.zip` as a small
candidate, followed by the saved Lucy clothing set. The package contains one
archive and its `Codes.txt` identifies the existing item
`Items.Vest_08_basic_01`. No framework manifests or scripts were found in the
package. That package inventory alone does not establish runtime compatibility.

The saved full clothing set references:

| Piece | Existing item named in the package |
| --- | --- |
| Top | `Items.Shirt_01_basic_01` |
| Pants | `Items.Pants_09_basic_01` |
| Boots | `Items.Boots_01_basic_01` |

Start with the original feminine body to isolate archive loading and garment
replacement from body compatibility and clothing refits.

### Native preparation implemented

The new Appearance Mods screen and `appearance inspect/stage/verify` commands
prepare a native archive patch with a verified original backup. On the actual
App Store 2.5 game, the Lucy jacket has two existing resource matches in
`basegame_4_appearance.archive` and three new resources. All five have been
staged into a separate copy and verified; the game archive is unchanged.
See [implementation and first clothing test](appearance-native-workflow.md).

The new assets are inserted only when exactly one official archive owns the
replacement resources. Multiple possible destinations or missing dependencies
block preparation. The Lucy jacket now has a user-confirmed visible success;
other packages and standalone records require their own tests.

### Earlier loose-archive preparation

- Assessed the Lucy clothes, Lucy jacket, Clothing Swap, and Jinguji packages.
- Prepared a loose-archive research probe for the jacket using the current
  CyberMac CLI, with an isolated research home.
- Probe ID: `archive-probe-20261024-003147`.
- Proposed location:
  `/Applications/Cyberpunk2077.app/Contents/Data/archive/Mac/mod/Edgerunners_Lucy_Jacket_xBaebsae.archive`.
- Proposed destination was absent when prepared.
- Archive SHA-256:
  `85a010c28a0ca96c689f5fde2f97ec6f3e5be583f7cc9fd2e89b93a3c73db9ab`.
- No archive was installed into the game. The loading path is unproven on this
  App Store 2.5 installation; preparing a probe does not add managed support.

Local evidence lives in the ignored `.research/appearance/` folder:
`package-assessments.json`, `first-clothing-test.json`, and
`lucy-jacket-probe.log`. The log contains proposed copy/removal commands only.
Its printed follow-up commands assume the default CyberMac home; verification
for this particular probe must use the same isolated home:

```sh
CFFIXED_USER_HOME="$PWD/.research/appearance/isolated-user" \
  .build/debug/cybermac archive-probe verify-copy archive-probe-20261024-003147
```

Use the same prefix for `verify-removal` and `record-result`.

### Success criteria

The target existing garment must be available and equipped on feminine V so the
visual test is meaningful. Verify the file placement, launch the game, observe
the changed garment, remove the probe and observe the original appearance.
Record file-copy verification separately from visible gameplay results.

If the loose archive has no effect, investigate the 2.5 loader before marking
the clothing itself incompatible. Previous no-effect probes predate this
installation and should not be generalized to all 2.5 loading routes. Do not
infer that every other loading route fails. The native staged-copy workflow
now provides a separately validated candidate, based on current Mac patcher
research; installation and restore remain manual.

## Second milestone: complete clothing sets

Once one visible replacement works, validate the saved top/pants/boots together.
Track conflicts between alternatives that replace the same vanilla garment or
shared resource. Packaging a folder of hundreds of variants is not equivalent
to enabling all of them at once.

## Third milestone: body shapes and matching refits

Select one concrete feminine body-shape mod. Inspect its dependencies, skeleton
and resource requirements, then validate it independently. Add clothes made or
refitted for that body. Record the body preset required by each garment and
test skin/material alignment, seams, clipping and first-person appearance.

The existing Resources inventory contains clothing candidates, but no chosen
body-shape package has been established yet. Defer body-mod selection until the
first clothing loading route is demonstrated.

## Loading routes to evaluate

1. **Official 2.5 integration.** CDPR documents mod.io-backed mod support on Mac.
   Determine supported package formats and how appearance mods load. This does
   not establish that arbitrary Nexus packages work through the official menu.
   [Official patch notes](https://www.cyberpunk.net/en/news/52120/check-out-whats-coming-to-night-city-in-the-edgerunners-2-update-for-cyberpunk-2077).
2. **Loose legacy replacements.** Revalidate loading on the actual App Store
   2.5 build with the single-jacket probe before building an installer around it.
3. **Native framework ports.** New projects provide research references for
   ArchiveXL/TweakXL-style support on Mac. The inspected NightCity Console README
   explicitly targets Steam 2.3.1, and the ArchiveXL fork lists 2.31. Their
   documentation does not establish compatibility with App Store 2.5. Do not
   install their version-specific offsets as though validated for this build.
   [NightCity Console](https://github.com/ysrdevs/nightcity-console-mac),
   [ArchiveXL fork](https://github.com/dbc-hbin/cp2077-archive-xl-macos).
4. **Native archive transplant.** Current Mac projects report archive-only
   mod loading through official archive patching. CyberMac now implements a
   bounded native reader and stages complete donor records and payloads into
   separate copies. The saved Lucy jacket has passed preparation against the
   actual 2.5 files; a visible gameplay test remains outstanding.
   [Archive loader](https://github.com/JoshuSnuff/cp2077-macos-archive-loader),
   [Mac archive patcher](https://github.com/brunoformagio/cp2077-mac-archive-patcher).

REA is relevant for a specific unresolved loader/resource question. Existing
working frameworks and source documentation should be evaluated before
attempting a fresh port of the entire ecosystem.
