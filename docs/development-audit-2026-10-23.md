# CyberMac development audit — 23 October 2026

## Result

The current working tree builds with Apple Swift 6.4 on Apple Silicon. All 523
existing XCTest tests passed: 505 core tests and 18 app tests, with zero failures.
Both the CLI and SwiftUI app were compiled by `swift test`. This was a debug
build; release packaging and visual inspection of the running desktop UI were
not performed.

Thirty additional CLI checks passed their expected exit codes, including scans
of 21 real mod ZIPs in the adjacent `Resources` folder. Scanner classifications
describe package structure and dependencies; they do not establish compatibility
with the newly downloaded game version.

The game at `/Applications/Cyberpunk 2077: Ultimate.app` and the real
`~/Library/Application Support/CyberMac` folder were absent during the audit.
No in-game results or compatibility with the reinstall's version are established.
The previous entries in `KNOWN_WORKING_MODS.md` remain historical observations.

## REA checkout

- Source: <https://github.com/morluto/rea>
- Local directory: `.research/rea/`
- Checked-out revision: `5d6b8a0ab693c03ab85cf0807d40bedf021e76d8`
- Package version: `6.7.0`
- `.research/` is ignored by the parent repository, including REA's nested Git
  metadata. REA remains an independent shallow checkout, not a submodule.
- Only source was downloaded. Dependencies and analysis engines were not
  installed, and no agent configuration was changed.
- Local Node is `v26.10.0`. This checkout declares
  `^22.23.4 || ^24.22.1 || >=26.12.1`, so a supported Node runtime is needed before
  setup. Native investigations also require a configured analysis provider.

## What passed

| Area | Evidence and limits |
| --- | --- |
| CLI and desktop compilation | Both products compiled in the debug test build. |
| Core workflows | 505 fixture-based tests cover activation, backups/restores, mod state, scanners, XML mappings, archive tooling, TweakDB staging, previews, and path handling. |
| App logic | 18 tests cover app state, archive filters, and Archive Lab content. These are not end-to-end GUI interaction tests. |
| Empty setup | Actual CLI doctor, empty mod/backup lists, and empty input-backup list completed against an isolated support directory. Doctor reported the missing game, runtimes, and cache and blocked activation. |
| Missing game | Activation dry-run and base-cache refresh dry-run returned the expected errors. |
| Runtime import | Existing redscript 0.5.31 and input-loader 1.0 ZIPs imported into the isolated test directory. Import success does not establish game-version compatibility. |
| Redscript executable | The imported native ARM64 `scc` returned its compilation help successfully with `compile --help`. Plain `--help`/`--version` return `not compile`; use compilation-mode help for this binary. Actual compilation against a fresh game cache still needs the game. |
| Real mod scanning | 11 packages were classified Supported, 1 Supported with input patch, 6 Experimental archive-only, 2 Untested, and 1 Unsupported framework. All scans completed; packages outside supported categories were not installed. |
| Experimental clothing tooling | Existing local changes compile and their fixture tests pass, including shared-resource and unresolved-safety refusal cases. In-game custom clothing remains unverified. |

CLI smoke tests used `CFFIXED_USER_HOME` pointing inside `.research/audit/`.
The real CyberMac support directory remained absent afterward. Runtime imports
and generated test data therefore did not recreate the user's live setup.

## Restart blockers and gaps

1. **The saved input-loader ZIP is known bad.** Importing
   `input-loader-mac-v1.0.zip-24529-1-0-1758768254.zip` triggers CyberMac's existing
   known-bad archive warning. Obtain a corrected compatible macOS input loader
   before testing input-mapping mods. Do not treat import success as validation.
   `RuntimeSummary.ready` currently checks installation and quarantine only, so
   its Ready state does not clear this warning.
2. **The old archive tool cannot currently execute here.**
   `../Probes/CyberMacArchivePatchTest/tools/cp77tools-x64` is a wrapper around
   `~/.dotnet-x64/tools/cp77tools`. Both that tool and its .NET host still exist
   and are x86_64 binaries. Invoking the wrapper fails with `Bad CPU type in
   executable`; a separate x86_64 execution probe also fails. Restore a working
   Intel execution environment or provide an ARM64-compatible archive tool
   before real extraction/repacking tests. Fixture tests use test doubles and do
   not establish this external tool's health.
3. **Setup still needs the CLI.** Settings shows detection and maintenance
   controls but has no runtime-import or base-cache-creation action. The README
   now includes the missing base-cache preparation step.
4. **Generated data needs rebuilding.** Deleted snapshots, backup files,
   manifests, archive catalogs, and preview indexes cannot be inferred from the
   source tree. A fresh installation can create new ones; deleted backups are
   not required for a new start.
5. **Custom clothing remains research.** The TweakDB writer preserves checksums
   rather than recomputing them and re-keys known-schema properties. ArchiveXL,
   TweakXL, Codeware, RED4ext, and general clothing/framework compatibility are
   not established. Start with one small controlled experiment after validating
   the basic script workflow.
6. **Some documentation predates the code.** The archive-preview roadmap's
   future-work list predates the current native XBM exporter. BC1, BC3, and BC7
   export paths have tests; unsupported compression formats and KARK payloads
   requiring an external Kraken library remain separate limitations. No real
   Kraken library was exercised in this audit.

The build also emits non-fatal warnings: legacy ZIPFoundation platform metadata,
the BC7 module's umbrella header, deprecated test ZIP initializers, and an
unnecessarily mutable test variable. These did not prevent compilation or tests.

## Resume after the download finishes

1. Finish installation and launch the unmodified game once. Record its actual
   storefront and version. Default detection scans `/Applications`; the CLI
   accepts `--game-app` for another location. The desktop app currently uses
   default detection.
2. Re-import an appropriate macOS redscript runtime into the real CyberMac home.
   Use a corrected input loader when testing mapping-dependent mods. The
   adjacent ZIPs survived deletion, but their presence does not prove they are
   suitable for the newly installed version.
3. Check the detected app and create a new base snapshot **before any modded
   files are copied into it**:

   ```sh
   swift run cybermac doctor
   swift run cybermac refresh-base-cache --dry-run
   swift run cybermac refresh-base-cache
   swift run cybermac cache-status
   ```

   Before that snapshot exists, an untouched new installation can be classified
   as externally changed because CyberMac has no known base hash yet. Do not
   attempt to restore a deleted backup; establish a base from the confirmed
   unmodified install.
4. Scan and install one simple redscript-only mod first. Run activation dry-run,
   generate the cache, review and manually run the printed copy command, then
   verify the activation:

   ```sh
   swift run cybermac scan /path/to/mod.zip
   swift run cybermac install /path/to/mod.zip
   swift run cybermac activate --dry-run
   swift run cybermac activate --bundle-mode
   # Manually run the exact copy command printed above.
   swift run cybermac activate --verify
   ```

5. Confirm that mod's actual behavior in-game. Matching file hashes establishes
   activation file placement, not gameplay success. Test input mappings next.
6. Before resuming archive experiments, restore working archive tooling and take
   new official-archive backups from this exact installation. Rebuild the
   catalog/preview index as needed; old paths and hashes must be revalidated.
7. Set up REA with a supported Node runtime and analysis provider. Begin with a
   focused read-only investigation of Mac TweakDB loading/checksum handling.

## Audit files and preservation

Local logs and test-only data are in the ignored `.research/audit/` directory:

- `swift-test.log`
- `fresh-doctor.log`
- `cli-smoke-results.json` and individual command logs
- `scc-help.log` and `cp77tools-help.log` (initial external-tool probes)
- `scc-compile-help.log` (successful `-compile -h` probe)
- `pre-existing-changes.patch` and `pre-existing-sha256.txt`

Four files already had substantial uncommitted changes when this audit began:
`AddonProbeManager.swift`, CLI `main.swift`, `AddonProbeManagerTests.swift`, and
`AddonProbeTweakDBCloneRecordStagerTests.swift`. Their contents were preserved and
their SHA-256 checks verified unchanged. Production code was not modified.
