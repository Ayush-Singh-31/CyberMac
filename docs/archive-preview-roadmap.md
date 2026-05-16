# Archive Preview Roadmap

This is a working notes file for the `archive-preview` subsystem inside CyberMac.

## What this is

`archive-preview` is a preview **registry** and **cache index**, not a renderer.

It lets CyberMac:

- Attach externally generated PNG / JPEG / WebP preview images to specific
  asset paths inside the archive catalog index (the same SQLite DB used by
  `archive-catalog index`).
- Search the index and surface "this asset has a preview" alongside path,
  extension, and category.
- Display those preview images inside the macOS app's **Archive Index** panel.

It does **not**:

- Decode Cyberpunk asset formats (`.xbm`, `.mesh`, `.material`, `.morphtarget`,
  `.inkatlas`, etc).
- Render meshes, materials, mannequins, or atlases.
- Mutate the game bundle or run external tools.
- Implement ArchiveXL / TweakXL / Codeware / RED4ext support.
- Install anything.

The constraint is intentional: preview generation for Cyberpunk assets is
non-trivial and often depends on external tools (WolvenKit, Noesis, Blender,
custom RTTI dumpers). The right division of labor is for those tools to
produce flat image files, and for CyberMac to point at them.

## SQLite shape

The `asset_previews` table lives in the same database as the archive catalog
index. Schema:

```
id            INTEGER PRIMARY KEY
asset_id      INTEGER NOT NULL  -> assets.id
preview_kind  TEXT NOT NULL
preview_path  TEXT NOT NULL
source_tool   TEXT
width         INTEGER
height        INTEGER
status        TEXT NOT NULL
created_at    TEXT NOT NULL
```

Unique key: `(asset_id, preview_kind, preview_path)`.

Suggested `preview_kind` values:

- `texture_thumbnail` — single decoded texture, usually from `.xbm`
- `atlas_sheet` — `.inkatlas` page as a flat image
- `mesh_render` — mesh rendered to a still image
- `material_reference` — single-material reference render
- `mannequin_render` — clothing/skin/hair item rendered on a base mannequin
- `external_reference` — anything else, e.g. a Nexus screenshot

Suggested `status` values:

- `available` — `preview_path` exists and was indexable
- `missing` — known target but image is not on disk yet
- `failed` — generation was attempted and failed

The current CLI only writes `available` rows. `missing` / `failed` are
reserved for future automation flows that try to generate previews and need
to record the result.

## CLI surface

```
cybermac archive-preview register \
    --asset-path <asset-path> \
    --archive <relative-official-archive-path> \
    --preview <path> \
    [--kind <preview-kind>] \
    [--source-tool <name>] \
    [--db <path>]

cybermac archive-preview import-manifest \
    --manifest <json-path> \
    [--db <path>]

cybermac archive-preview search <query> \
    [--category <category>] \
    [--ext <extension>] \
    [--archive <relative-official-archive-path>] \
    [--has-preview] \
    [--limit <n>] \
    [--db <path>]

cybermac archive-preview stats [--db <path>]
```

Manifest format:

```json
[
  {
    "archive": "Data/archive/Mac/content/basegame_1_engine.archive",
    "assetPath": "base\\gameplay\\gui\\widgets\\crosshair\\master_crosshair.xbm",
    "previewPath": "/absolute/or/relative/path/to/preview.png",
    "kind": "texture_thumbnail",
    "sourceTool": "manual"
  }
]
```

Relative `previewPath` values are resolved against the manifest file's
directory. Each row is registered independently; bad rows are reported but
do not abort the import.

A sample manifest fixture lives at
`Tests/Fixtures/sample-asset-previews-manifest.json`.

## macOS app surface

The app gains an **Archive Index** screen that:

- Loads `archive-catalog index` stats and `archive-preview` stats from the
  default DB path, if it exists.
- Provides a small search box that hits the registry's search API directly
  (no shell, no `cp77tools`, no bundle mutation).
- Lists up to 50 results in a grid, with a thumbnail when the asset has at
  least one `available` preview row, or a placeholder otherwise.
- Surfaces archive path, asset path, extension, category, and preview count.
- Has copy buttons for the asset path and the archive path.

This is intentionally read-only.

## Future work

These are explicitly **not** in this PR. Listed so future work has somewhere
to anchor:

- `.xbm` thumbnail generation directly from CyberMac (likely via a small
  Swift decoder, not via `cp77tools`).
- `.inkatlas` page extraction and per-slot bounding boxes.
- Headless mesh / material renders via Blender or a dedicated CLI.
- Mannequin renders for `garment` / `skin` / `hair` assets to support
  clothing replacer pickers.
- Material card view: linked `.mi` / `.mt` / texture references shown
  together with their previews.
- A "preview missing" workflow: enumerate `garment` / `makeup` / `tattoo`
  assets without previews, write a `missing` row, and produce a worklist
  manifest for an external generator.
- ArchiveXL / TweakXL aware indexing once those subsystems are supported.
