# Reinstall check and next milestones — 24 October 2026

**Later update:** the 0.5.31 compiler failure recorded below was resolved for
the clothing helper by importing official redscript 0.5.32 and removing a
debug-only `LogChannel` dependency. Actual 2.5 helper compilation now succeeds;
see [the current appearance workflow](appearance-native-workflow.md).

The user has since confirmed the main priority: feminine V, custom clothes
first, then body shape and matching clothing refits. The
[appearance mod plan](appearance-mods-plan.md) is the current roadmap; the
generic script experiment below remains diagnostic evidence.

## Installed game

- Location: `/Applications/Cyberpunk2077.app`
- Display name: Cyberpunk 2077: Ultimate
- Storefront: Mac App Store; the receipt is present.
- Bundle identifier: `com.cdprojektred.cyberpunk`
- Version: `2.5.0`
- Build: `5814786.13589799`
- Script cache: 19,280,452 bytes.
- Base and expansion TweakDB blobs are present.

CyberMac detects the new app name through its existing fallback scan. The
previous hard-coded example path containing `Cyberpunk 2077: Ultimate.app` is
not this installation's actual path.

## Tests against the fresh files

Used `.research/reinstall-2026-10-24/isolated-user` as the test user directory.
The normal CyberMac support directory has not been initialized by these tests.

1. Doctor detected the installed game and reported missing runtimes/base cache.
2. The saved macOS redscript 0.5.31 ZIP imported into the isolated setup.
3. A fresh base-cache snapshot was created from the installed game.
4. Reset Attributes Always Available scanned as a supported redscript-only
   package and installed into the isolated sidecar.
5. Activation dry-run passed outside the restricted execution environment.
6. Actual activation generation failed: `Failed to load the original script
   cache`. A direct invocation with the copied cache supplied explicitly also
   failed with the same message outside the restricted environment. That rules
   out the simple omission of an explicit cache path as a sufficient fix, but
   does not establish the precise cause. Invocation/configuration and compiler
   compatibility with the 2.5 cache still need investigation.
7. The executable, script cache, and both TweakDB blobs were hashed before and
   after the experiments and all four hashes match. No generated cache was
   installed into the game.

The first restricted activation attempt reported less than 128 MB available
despite filesystem checks showing approximately 340 GiB available. The same
dry-run passed outside the restricted environment. This storage result should
not be treated as evidence that the user's disk is full or as a confirmed
production storage-check defect.

The prior 523 passing fixture tests remain useful; the real compilation failure
shows why they are insufficient to claim game-version compatibility.

## What 2.5 changes

CDPR's official patch notes explicitly list mod.io-backed cross-platform mod
support on Mac. This is a reason to investigate the new supported loading path
before extending the previous official-archive replacement experiments.
The notes describe a selection of mods, so they do not establish that arbitrary
Nexus archive/framework packages are compatible.

Sources:

- [Official 2.5 patch notes](https://www.cyberpunk.net/en/news/52120/check-out-whats-coming-to-night-city-in-the-edgerunners-2-update-for-cyberpunk-2077)
- [Official modding support page](https://www.cyberpunk.net/en/modding-support)

No mod.io account was connected, no subscription was changed, and no mod was
installed through the game. No mod-related directories were found in a limited
search of the game's existing macOS container. That is not a complete loader
analysis or evidence that the feature is absent.

## Recommended milestones

### 1. Establish one real 2.5 mod workflow

Resolve the cache-loading failure before expanding script-mod features. Check
the compiler's cache expectations, invocation, and upstream support for the
installed version. Keep a clean baseline and compare output from controlled
single-mod experiments. Success means compilation, verified manual activation,
observed behavior in-game, and a verified restore.

### 2. Investigate the official Mac mod loading route

Determine the supported package types, storage locations, and loading order of
the 2.5 mod.io integration. Test one documented compatible asset mod through
the game. Establish whether CyberMac can offer useful compatibility reporting,
profiles, asset inspection, or authoring/export assistance around that route.
Do not assume an undocumented management API or arbitrary framework support.

### 3. Build a version-aware setup screen

The desktop app currently lacks runtime import and base-snapshot creation.
A useful next product feature would detect version/storefront/path, show tested
capabilities and known runtime warnings, import runtimes, and create fresh
snapshots. Unknown compatibility should remain visibly untested. The known-bad
input-loader archive must not be presented as validated merely because it
imports successfully.

### 4. Resume deeper asset research after tool bring-up

REA is available as source in `.research/rea`, but still needs a supported Node
runtime and an analysis provider. The old Intel archive-repacking tool still
needs a working execution environment or compatible replacement. Use REA for a
specific unresolved loader/TweakDB question once simpler source-level checks
and supported loading paths have been evaluated.

## Evidence

Local command logs, compiler probes, test-only snapshots and before/after game
hashes are in the ignored `.research/reinstall-2026-10-24/` folder. Existing
uncommitted source/test changes were verified unchanged. This check made no
production code changes.
