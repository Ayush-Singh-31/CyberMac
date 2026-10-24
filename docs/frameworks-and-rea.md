# Clothing frameworks and REA — 24 October 2026

## Question

Can we inspect the Mac game, adapt the missing native frameworks, and use the
new 2.5 Mods pipeline to support clothes and body shapes?

Yes, targeted investigation and native implementation are viable approaches.
The required work depends on the chosen mod. A Windows plugin cannot simply
be copied into an ARM64 Mac game, but a full framework rewrite is not required
for the saved Lucy replacer. Separate the smallest missing capabilities and
validate them against this exact build.

## What the components do

| Component | Role | Current evidence |
| --- | --- | --- |
| redscript | Compile script bytecode, including a helper that grants an existing item | Official 0.5.32 Mac compiler reads this game's 2.5 cache. The corrected Lucy helper compiles and decompiles successfully. Runtime execution remains unverified. |
| RED4ext / native bootstrap | Load native extensions and provide engine hooks/bindings | Existing Mac port work is documented for a different build. Its offsets and startup assumptions are not validated for this App Store 2.5 executable. |
| TweakXL-style loading | Create/clone item database records and change their properties | Official 2.5 docs describe built-in YAML support. The actual Mac binary exports state belonging to `game::data::TweakXLModLoader`. Local package loading and record registration remain untested here. |
| ArchiveXL-style loading | Connect resources, factories, appearances, localization and garment behavior | Official 2.5 supports a documented subset. Mac extension source also exists; neither establishes that every Windows clothing package works unchanged. |
| Garment assets/refits | Supply actual body meshes, textures and clothes fitted to that body | A runtime/framework port cannot replace the asset authoring and compatibility work. No body-shape package has been selected yet. |

Inventory delivery and database registration are different milestones. The Lucy
jacket uses the already-existing `Items.Vest_08_basic_01`. It needs assets loaded
and the garment made available to the player. A standalone add-on with a new
`Items.MyCustomJacket` record may additionally need record creation, appearance
and entity links, localization and other framework behavior.

## Actual REA investigation

REA 6.7.0 was installed as an isolated CLI under `.research/rea-tools/cli`, with
an official Node 24.22.1 runtime retained locally. No MCP/client configuration
was changed. This ran against the executable while the game remained closed:

```text
rea inspect-macho /Applications/Cyberpunk2077.app/Contents/MacOS/Cyberpunk2077 --json
```

REA's `native-macos` provider returned Evidence
`ev_4a2577385263a7bf5b850e80be3539de9c16ed91d328d4b07b567286ccce0a83`:

- Target digest:
  `8f4a88ad201f360772b3747f51701944f39b98b4ecbf7edc6271c1cc24932844`.
- Thin, little-endian 64-bit ARM64 Mach-O; macOS build metadata.
- UUID `038B50EB-A67E-375A-B07B-95F0C0463530`.
- Build metadata reports minimum macOS 26.4 and SDK 26.5.
- Exported symbols include the maps and their guard variables for:
  `game::data::TweakXLModLoader::s_parentMap`, `s_descendantMap`, and
  `s_extraFlats`.

Those six symbols are present in REA's returned export rows. A separate Xcode
`llvm-nm`/`llvm-cxxfilt` pass corroborated their names. Their addresses are linked
addresses for this executable, not runtime addresses or ready-to-use hooks.

**Observation:** the shipped Mac executable contains state named for an
integrated TweakXL-style loader. **Inference:** 2.5's native data-loading route is
a promising first target, consistent with the official YAML documentation.
**Unknown:** where/how an unpublished local package can enter that route and
whether it provides every required operation for a chosen clothing mod.
Symbols alone do not prove successful registration, a callable script API, or
runtime behavior. The inspected vanilla script API exposes TweakDB getters;
no setter/record-creation script bridge has been demonstrated by this work.

Full evidence is in `.research/rea-tools/game-macho-evidence.json.gz`; the compact
summary is `game-inspection-summary.json`. These are local, ignored artifacts.
REA warns that stripped or toolchain-hidden symbols can be absent from its
inventory; absence of a name is not proof of absent code.

REA's doctor reports that Hopper/Ghidra/IDA backends are not installed or
configured. Native Mach-O inspection works without them. Decompiling native
function bodies and tracing incoming references will require a suitable
backend; that part of the investigation has not run. The successful redscript
decompilation is a separate script-bytecode inspection, not native pseudocode.

The initial restricted REA attempt could not build its process-ownership helper
because compiler-cache writes were denied. The same read-only operation
succeeded with approved compiler-cache access. No target injection, mutation,
re-signing, protection bypass, or game launch was performed.

## Existing native work and official 2.5 capabilities

- [NightCity Console](https://github.com/ysrdevs/nightcity-console-mac) and its
  [Mac platform notes](https://github.com/ysrdevs/nightcity-console-mac/blob/main/docs/MACOS-MODDING-PLATFORM.md)
  describe native framework ports, an ARM64 runtime bridge, archive loading,
  record cloning and an item browser. Its documented supported target is
  Steam 2.3.1. That source is useful; its build-specific addresses are not a
  compatibility guarantee for App Store 2.5.
- The ArchiveXL Mac work is on
  [`codex/macos-cet-runtime`](https://github.com/dbc-hbin/cp2077-archive-xl-macos/tree/codex/macos-cet-runtime),
  inspected commit `1d59014894cf9662498e8aa749bd4c583d743333`. Its
  [CMake configuration](https://github.com/dbc-hbin/cp2077-archive-xl-macos/blob/1d59014894cf9662498e8aa749bd4c583d743333/CMakeLists.txt)
  builds an ARM64 dylib, and its
  [extension service](https://github.com/dbc-hbin/cp2077-archive-xl-macos/blob/1d59014894cf9662498e8aa749bd4c583d743333/src/App/Extensions/ExtensionService.cpp)
  enables Apple-side garment, factories, customization, mesh and resource-link
  extensions. Source presence does not prove those features work on this build.
- The [official content guide](https://mod.io/g/cyberpunk-2077/r/mod-content-available-in-cross-platform-mod-support)
  documents record addition/cloning/flat edits and supported ArchiveXL syntax
  such as factories, customization, localization and resource links. It lists
  restrictions for `.ent`, `.app`, `.morphtarget`, Resource Patch and animations.
  Its PC-versus-console wording does not clearly establish every Mac case.
  Test the actual Mac package rather than assuming identical support.

The user's official Mac catalogue currently offers cosmetic and gameplay mods
but no identified clothing candidate. Catalogue availability and engine loading
capability are separate. This does not prove that new clothing is impossible.

## Scoped next work

1. **Prove the existing-item path.** Install the prepared Lucy archive and
   matching compiled item helper with their backups; observe item delivery and
   visible replacement, then restore both. This test is ready for manual
   installation but has not been run in-game. Keep the game closed until the
   install and file-verification steps are complete.
2. **Prove the official loader independently.** Establish the documented package
   format and a private/local test route from an actual Mac package. Start with
   a harmless database-flat change, then one cloned garment record and an
   existing vanilla appearance. Observe load/disable behavior before adding
   custom meshes. Do not assume loose Nexus folders are recognized by mod.io.
3. **Implement only the missing bridge.** If the official route cannot express
   a required operation, use source from the existing ports and targeted REA
   function/xref analysis to adapt it for this exact App Store build. Keep it
   version-gated. A narrow record-registration or resource-loading feature is
   a better first deliverable than a claim to port every RED4ext plugin.
4. **Expand to standalone clothes and one body shape.** Select concrete packages,
   identify required garment/body features and refits, and validate them one at
   a time against the working loading route.

See [the native appearance workflow](appearance-native-workflow.md) for the
implemented archive and inventory-helper preparation. There are now 544 passing
tests; offline compilation and file integrity are verified, while visible
gameplay and a complete native framework port remain unverified.
