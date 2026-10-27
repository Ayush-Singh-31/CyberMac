# Selective clothing additions

Drop a clothing ZIP in **Install mods** or choose it from **Clothing**. CyberMac lists discovered garments in **Choose your clothes**. Select pieces and click **Install selected**, finish Apple's Installer, then load a save. The delivery helper grants missing selected items; equip them from inventory. Existing items in a save are kept, including items unchecked on a later import.

Live Blender previews are paused. Saved wardrobe images remain usable, and other cards show names and placeholders. Discovery and preparation never invoke Blender. A garment does not need an image to be selected.

## Current adapter

The adapter discovers archive replacements against the installed game's feminine V appearance graphs for outer torso, inner torso, legs, feet, head and face. It assigns private item IDs, entity/appearance names, material resource paths and factory rows. Different colours replacing the same vanilla mesh receive independent IDs. Vanilla resources are retained. Earlier prepared Lucy/Jinguji records are reused when that verified wardrobe is registered.

ZIP inspection shows individual archive entries, including several garments in one archive when they match different donor meshes. Shared meshes can offer different equipment slots. Finder resource forks are ignored; duplicate ZIP paths, links, unsafe paths and oversized inputs are rejected. Archives are decoded only after selection. Unsupported frameworks and missing templates produce explanations; they are not silently discarded.

ArchiveXL/TweakXL declarations, custom body/refit rules, masculine variants, outfit slots and arbitrary new asset layouts still need adapters. Finding a matching template is not a guarantee that a garment fits or renders correctly in gameplay. New inventory icons currently use donor icons; no new images are rendered.

## Preparation and recovery

The game supplies templates. A compressed metadata cache avoids re-decoding them on every drop. Only selected resources are converted, with round-trip graph checks and private paths. Each database is read, updated and verified once per selection batch, preserving the inherited item schema.

Preparation creates local APFS archive clones and recovery copies. The install plan covers the clothing factory archive, appearance archive, both TweakDBs and a script cache compiled with the user's other enabled redscript mods. Runtime and original-file checks run before preparation. No game files are modified during preparation.

Large installs use a small local Apple Installer package whose generated script validates local payloads and backups, replaces the planned files, and rolls back on failure. This avoids compressing the game's multi-gigabyte archives into a package. Package scripts come from CyberMac; downloaded scripts are not executed by Installer. CyberMac checks the package receipt or its exact identifier in macOS's protected install history, then verifies installed hashes before promoting the clothing library state. Script-only packages do not produce a `pkgutil` receipt. Completed clothing jobs affected by the former receipt check are reconciled on reopen only when their files and script activation verify, without reinstalling. **Restore previous files** uses the retained recovery plan; restore shared-file changes in reverse installation order.

The older **Clothing → Play** workflow remains for prepared session bundles. Finish an active legacy clothing session before using persistent additions.

## Validation

Local discovery of JingujiAllInOne resolves all 214 archives into 232 garment/slot choices. Some meshes match both torso slots. This is discovery coverage, not a claim that every variant was installed or tested in gameplay.

Pink and gold heel variants have been converted together in an isolated library, with private meshes, entities, appearances and independent records in both databases. The generated delivery script compiles with the four enabled local redscript mods. Original game files remain unchanged by this preparation check. These heel variants still require an interactive installation and gameplay check. The earlier seven pinned Lucy/Jinguji garments retain their existing gameplay confirmation.

The Black and Carol bandeau pair also passes complete isolated preparation and an actual Apple Installer installation: all five installed file hashes match and macOS records success. On 28 October 2026, the user confirmed both appear in inventory and equip correctly as separate additions. Their material paths change serialized material sizes, so round-trip validation checks contiguous material headers and compares the decoded material contents independently of regenerated offsets. Changed geometry, material contents, missing materials and invalid offsets still fail validation.

For a read-only preparation check using a separate home:

```sh
swift run cybermac clothing inspect-import --zip /path/to/clothes.zip --game-app /Applications/Cyberpunk2077.app --home /path/to/test-home
swift run cybermac clothing prepare-import --zip /path/to/clothes.zip --records Items.CyberMac_Import_example --game-app /Applications/Cyberpunk2077.app --home /path/to/test-home --out /path/to/plan.json
```

The test home needs a compatible macOS redscript runtime and verified base script cache. These commands retain the download and prepare local files but do not authorize or apply the install plan.
