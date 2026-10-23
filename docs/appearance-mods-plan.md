# CyberMac appearance mod plan

## User priority — confirmed 24 October 2026

Target feminine V. Get custom clothing working first, then support changes to
body shape with clothing fitted to the selected body. Custom skin textures,
hair, faces and complete character appearances are part of the broader goal.

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

### Preparation completed

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
start replacing shipped official archives merely because this first path fails.

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

REA is relevant for a specific unresolved loader/resource question. Existing
working frameworks and source documentation should be evaluated before
attempting a fresh port of the entire ecosystem.
