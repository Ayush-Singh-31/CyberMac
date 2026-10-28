# Body mods: Unique V investigation and implementation sequence

28 October 2026. Research and implementation against the installed Mac App Store
game 2.5.0, build 5814786.13589799.

Current milestone: the Lethal Curves maximum shared preset is user-confirmed
working in inventory, Photo Mode, first person and motorcycle gameplay. The
adapter preserves native Mac rig data and applies separate authored preview and
gameplay transforms. V-only routing and other body presets remain unverified.
The sections below retain the investigation and successive test results.

## Conclusion

Unique V is a useful reference for a native body-rig adapter. Its ZIP is not
a complete body preset: it separates V's deformation rig from the shared NPC
rig and supplies neutral player rigs. Start with feminine V, consistent with
the working clothing workflow, and support one visible preset first.

The first implementation should apply the framework's rig redirects to the
current Mac player definitions. The downloaded PC 2.31 definitions contain
other platform/version differences, so installing them wholesale would also
replace unrelated Mac data. A full native framework port is not a prerequisite
for this archive-only approach.

## What was inspected

- Current package routing, automatic appearance installation, appearance archive
  planning/staging, clothing conversion, and clothing state/baseline handling.
- The selected ZIP contains exactly one 491,520-byte archive:
  `archive/pc/mod/zz_johnson_Framework_Unique_V_Body_Shape.archive`.
- The archive has **20 resources: 16 entity templates, two rigs, and two animation
  graphs**. There are no body meshes, skin textures, scripts, DLLs or XL manifests
  in this archive. Both feminine and masculine player rigs are included.
- All 20 resources were extracted and decoded with the existing Kraken and
  WolvenKit tooling. Four new paths identify the feminine/masculine
  `*_plr_deformations.rig` and `.animgraph` resources.
- CyberMac's native inspector matched the 16 existing resource identities across
  three official archives. Two identities occur in both engine and appearance
  archives, producing 18 matching archive entries. The four player rig/graph
  resources are new. No archive-index dependencies remained unresolved.
- All 18 matching official entity copies were extracted and decoded for static
  comparison. The framework redirects the shared deformation rig/graph paths in
  both entity components and compiled component data.
- For the feminine third-person player template, the comparison also found PC
  versus Mac cooking metadata, different compiled physics buffers and filters,
  and an animation list missing the Mac build's `glamdoc_female.anims` entry.
  These are concrete reasons to retain the current Mac entities.
- WolvenKit 8.18 warns that `PLATFORM_Mac` is unknown and represents it as
  `PLATFORM_None` in decoded JSON. A successful decode therefore does not
  establish a correct Mac entity write-back.
- REA re-inspected the actual ARM64 executable. Its digest matches the earlier
  investigation and it still exports the six TweakXLModLoader map/guard symbols.
  This establishes symbol presence, not successful local package loading.

The current archive plan targets:

| Official archive | Matching resource identities |
| --- | ---: |
| `content/basegame_1_engine.archive` | 2 |
| `content/basegame_4_appearance.archive` | 12 |
| `ep1/ep1_2_gamedata.archive` | 4 |

Local extracted assets, decoded JSON, comparisons, logs and REA evidence remain
under ignored `.research/body-mods-20261028/`. They are not distribution assets.

## Implementation sequence

1. **Build a Mac player-rig adapter.** Read the installed Mac player entities and
   deformation rig/graph. Create private player rig resources and apply the
   observed redirects to the matching feminine entity components, including
   compiled component data. Preserve the current animation lists, physics
   buffers, filters and cooking metadata. Make the writer preserve the Mac enum
   instead of emitting WolvenKit's unknown-enum fallback. First prove an entity
   can be rebuilt without unrelated semantic or embedded-buffer changes, then
   validate the exact rig-reference edits. Use the downloaded archive as the
   compatibility reference rather than the full replacement payload.

2. **Give new resources explicit destinations.** Extend `AppearancePatchPlan`
   and `AppearancePatchManager` to carry per-archive insertions. Today
   `newResourceTarget` is only set when there is one matched target; this package
   has three, so `canStage` is false. Assign the private rig/graph resources to a
   documented destination such as the appearance archive, retain replacements
   in the relevant archive copies, and verify all references resolve. Keep the
   first recipe limited to the required feminine resources.

3. **Make body and clothing changes share installed state.** Both workflows
   affect `basegame_4_appearance.archive`. Appearance staging currently demands
   sealed originals; clothing installation accepts its own recorded previous
   results. Neither tracks an independent body installation. Prepare archives
   from a known baseline plus the active clothing and body resource changes.
   Track resource ownership and conflicts so adding clothes, changing bodies,
   or removing a body preserves the other installed changes. Reuse the existing
   APFS copying, file transactions, Installer and verification machinery.

4. **Prove one visible V-only rig deformation.** The framework's neutral rig is
   not a visible body change. Use a small, deliberate deformation as the first
   end-to-end prototype. Check it on V in gameplay/body views, inventory,
   mirror/Photo Mode and relevant animations, with an NPC comparison. Identify
   which first-person resources require separate treatment; legacy framework
   coverage alone does not establish first-person support. The milestone is an
   observed shape change on V with existing clothes still available.

5. **Support one real body preset.** Select a concrete archive-only preset and
   record whether it changes rig transforms, body meshes, or both. Connect it to
   the player-only rig convention. A mesh body may also need matching textures,
   material paths, arm variants and garment-hiding behavior. The prototype can
   proceed before this choice; the complete preset adapter depends on its actual
   files. Treat full face/hair/NPC-character replacement as further adapters.

6. **Add clothing compatibility and refits.** Store the selected body identity
   and each garment's supported body/refit. Test the existing Lucy and Jinguji
   clothes with the first preset and add matching refits where required.
   Rig deformations can move skinned clothing, but that does not establish that
   every garment fits; a mesh silhouette change often needs a corresponding
   clothing mesh. Preserve independent inventory items while replacing their
   selected refit assets.

7. **Expose bodies through the existing import screen.** Add body/framework
   classification based on archive resource types and known paths. Show the
   required framework, one active body choice, applicable rig/mesh options and
   clothing compatibility in the existing details pane. Compose dependency
   changes into one prepared install. No separate research workflow should be
   required for ordinary supported body ZIPs.

8. **Verify switching and persistence.** Check body A to body B, return to
   vanilla, adding clothing after body installation, removing a body while
   retaining clothing, save/reload, and relaunch. Add focused tests for the
   multi-archive insertion plan, preservation of Mac entity data, and combined
   body/clothing state. In-game checks establish rendering and animation;
   structural checks establish prepared-file correctness.

Steps 1–4 are the first useful deliverable. Steps 5–8 turn that prototype into
normal body-mod support in CyberMac.

## Where REA helps

Use the existing resource parsers and WolvenKit first for asset adaptation.
If valid modified resources are ignored, REA can help locate archive selection,
player-entity instantiation, deformation-rig loading and caching behavior in
this exact executable. Its `native-macos` inspection supplies Mach-O evidence;
native pseudocode and cross-references require a configured analysis backend.

If a later preset requires ArchiveXL resource patches or dynamic customization,
inspect the actual required operations and choose either a static conversion
adapter or the smallest missing native runtime capability. Investigating all of
RED4ext/ArchiveXL/TweakXL before the first rig prototype would expand the task
without answering the immediate body-mod question.

## External references

- [Unique V author's description](https://www.nexusmods.com/cyberpunk2077/mods/3725):
  framework purpose, neutral default and legacy/ArchiveXL distinction.
- [Rig-mod authoring guide](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Modding-Docs/blob/main/modding-guides/npcs/rig-deforming-for-v/for-v-or-npc-how-to-make-a-rig-mod.md):
  player-only deformation paths and legacy framework integration.

## First implementation

The initial adapter is implemented in `BodyModInstaller.swift`,
`prepare_body_mod.py` and `body_asset_codec.py`. The original framework ZIP is
recognized by its archive digest, including when renamed. Its existing import
details offer **Original shape (Unique V)** and **Shoulder test (+20%)**.
The latter scales the two shoulder bones in the private deformation rig.

The adapter rebuilds the nine feminine entity copies from current Mac files,
clones the native feminine rig/graph into the framework's player paths, and
checks the complete rebuilt graphs against the expected edits. The Mac cooking
enum is restored with table/offset/checksum relocation. No PC entity or physics
payload is installed. The three explicitly targeted archives receive nine
replacement entity records and two private rig/graph resources.

`ManagedArchiveStore` records verified combined snapshots. Body preparation can
start with the current nine-item clothing library; clothing preparation accepts
the verified body result as its next baseline. Ordinary file restoration still
uses reverse installation order when later installs share an archive. Arbitrary
body preset conversion and automatic refits remain later milestones.

Validation completed:

- Rebuilt all 18 original Mac entity copies with no decoded graph differences,
  including their cooked physics buffers.
- Prepared the complete shoulder test against the actual installed game and
  its existing nine clothing additions in an isolated workspace. All 11 edited
  or cloned resources passed graph comparison.
- Checked the prepared archive indexes: 4,288 engine, 83,477 appearance and
  30,880 expansion records remained unchanged, with their existing segment and
  dependency tables retained. Only the intended nine entity copies changed;
  two private resources were added. Original game hashes remained unchanged.
- 638 core and 51 app tests passed, including shared-state/undo and external-edit
  regressions. Four additional Python codec tests passed.

The prepared test plan and evidence are under ignored
`.research/body-adapter-live/`. To prepare another isolated test:

```text
cybermac body prepare <framework.zip> --variant shoulders --out <plan.json>
```

Preparation does not install or launch the game. The user subsequently completed
the shoulder-test installation through Apple Installer. All three installed
archive hashes match the prepared body transaction. CyberMac initially reported
a false failure because it rejected the system's root:admin 0664 Installer
history permissions. That check is fixed, and reopening the rebuilt app recovered
the entry as Installed and saved its combined body/clothing archive state without
reinstalling. The remaining live check is to observe V, the existing clothes,
NPCs and animations in game. The visible result is not yet confirmed.

## First visual comparison and graph correction

The user's `With Mod.png` and `Without Mod.png` inventory screenshots do not
demonstrate convincing shoulder widening. Small pose differences prevent an
exact silhouette measurement. Treat the original shoulder test as visually
unsuccessful despite successful file installation and stable game launch.

Inspection found a concrete mismatch introduced by the adapter: it remapped the
animation graph's `staticCommandsRig` from `woman_base_deformations.rig` to
`female_plr_deformations.rig`. Both the original framework graph and the native
Mac graph retain the unmodified base-rig reference. The adapter now preserves
the full native graph unchanged while redirecting only player entities to their
private rig and graph resources.

A fresh three-archive shoulder plan was prepared successfully. Full graph
comparison confirms the corrected graph matches the native neutral graph, while
the previous generated graph does not. Both private shoulder scales still read
1.2 after rebuilding. Codec tests and local app packaging/signature checks pass.
Evidence is `.research/body-adapter-live/graph-reference-verification.json` and
`corrected-shoulder-plan.json`. No game files were changed for this correction.

This fixes a verified source mismatch; its role in the missing visible effect
remains an inference until a new in-game comparison. The user has already
restored the first body install. A fresh ZIP import is required to build a new
plan with the corrected graph rather than reusing a previously prepared plan.

## Lethal Curves authored maximum preset

The corrected shoulder test also received a user report of no discernible
change. The next diagnostic uses the actual Lethal Curves author data.
The supplied 2.1.1 download is a 1.95 GB Windows builder with 62,572 entries,
mostly preview images. It contains readable preset JSON; its executable and
Python bytecode are not executed by CyberMac.

`tools/import_lethal_curves.py` reads only the six default maximum-level TPP
presets (arms, buttocks, calves, chest, lower thighs and upper thighs), merges
their absolute transform values, and records source archive and entry hashes.
It produces `Resources/Lethal Curves Maximum - CyberMac.zip`, a roughly 1 KB
data-only package with 38 bone overrides. The authored preset alters deformation
joints rather than the earlier test's two main shoulder bones.

CyberMac recognizes the bounded data-only format and offers V-only and
**V + NPCs test** scopes. The shared-rig test is the recommended next diagnostic:
it replaces `woman_base_deformations.rig` in its two official owners instead of
depending on the still-unproven player-only redirects. This intentionally
affects feminine NPCs as well. Restoring the test recovers the preceding combined
clothing files. Cross-scope switches require restoration so a shared override
cannot remain hidden underneath a V-only preset. Existing private player-rig
resources block a shared test until the previous body is restored.

The real shared test prepared successfully in an isolated home. All 106 authored
axis values survived Mac rebuilding. The outputs retain all other rig data and
all unrelated archive entries (4,288 engine and 83,482 appearance records), with
no new resource identities. The actual game hashes stayed unchanged during
preparation. Evidence: `.research/lethal-curves/maximum-shared-plan.json` and
`maximum-preset-verification.json`. Six Python tests and the full 694-test Swift
suite passed before the final scope-tracking check; focused Swift tests also
cover preset routing, numeric validation and recovery behavior.

The user confirmed visible changes in inventory and photo mode. The same test
did not change the body seen looking down in first person or riding a motorcycle.
This establishes visible preview support, not complete gameplay support.

## Gameplay rig coverage correction

Inspection of the native `player_wa_fpp.ent` (including the expansion copy) shows
that its `deformations` component uses
`base\characters\entities\player\deformations_rigs_wa\player_woman_base_deformations.rig`,
hash `92869df7e9401972`, with a separate matching animation graph. The previous
shared test replaced only the `woman_base` rig. The live player entity also
contains the motorcycle animation sets, including third-person sportbike sets;
the resource coverage gap is therefore relevant to both reported views.

The Lethal Curves builder contains separate `player_woman` author presets for
all six groups. These differ from the preview presets (for example shoulder
translation is 0.2536 rather than 0.2405), so copying the preview rig over the
gameplay rig would be incorrect. The importer now retains both sets in separate
bounded dictionaries. The new `Lethal Curves Maximum Gameplay - CyberMac.zip`
contains 38 preview and 38 gameplay bone overrides from 12 authored source files.
Older data-only packages retain their existing behavior.

Both official copies of the native gameplay rig are edited from their original
Mac data, alongside the working preview rig. Skeletons, graphs, reference poses,
entity definitions and animations remain unchanged. This directly addresses the
verified missing resource; its visible gameplay result still needs a new test.
The shared variant can be installed over the preceding shared test, with the
preceding installed files retained as its recovery baseline.

Reference: [rig deformation guide, first-person troubleshooting](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Modding-Docs/blob/main/modding-guides/npcs/rig-deforming-for-v/README.md).
Local inspection and plans are in `.research/lethal-gameplay/`.

The real preparation passed: all 106 preview and 108 gameplay authored axis
values survived rebuilding, and the preview rig matches the previously visible
preset. Only the two intended resource records change in each archive; the other
4,287 engine and 83,481 appearance records and existing segment/dependency tables
are preserved. The current game files were not changed by preparation. Eight
Python tests and 46 focused Swift tests passed; the rebuilt app passed strict
signature verification. The new package is imported in the app with the shared
gameplay variant selected, awaiting the user's installation and comparison.

The user subsequently installed the corrected gameplay package and confirmed it
works after checking first person and motorcycle views. This establishes the
shared maximum preset on the Mac App Store 2.5 build as the first confirmed
gameplay body-mod milestone. V-only routing, other shapes and clothing refits
remain separate work; no broader compatibility is implied.
