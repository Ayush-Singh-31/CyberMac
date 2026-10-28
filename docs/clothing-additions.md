# Clothing additions

CyberMac turns supported clothing replacements into separate
inventory items. Select the pieces you want from a ZIP and equip them alongside
your existing clothes.

## Install clothes

1. Close the game and open **Install mods**.
2. Drop in a clothing ZIP or choose it from **Clothing**.
3. In **Choose your clothes**, filter by name or category and select your pieces.
4. Click **Install selected** and finish macOS Installer.
5. Launch the game, load a save and equip the new items from inventory.

Each garment has its own item record and assets. Different colours can coexist,
and the original garments remain available. Items already owned in a save are
kept when you change a later selection.

## Clothing collections

The importer discovers garments from the package's resources and the game's
clothing templates. Supported categories include outer torso, inner torso, legs, feet, head and face.

Saved wardrobe images are shown when available; other pieces display their names
and a placeholder. Selection and installation work without generating previews.
Inventory icons use the corresponding donor items.

See [tested workflows](../KNOWN_WORKING_MODS.md) for installation results.
CyberMac shows package requirements and available options during import.

## Setup

Configure the [conversion tools](building.md#clothing-and-body-conversion-tools)
and import a macOS redscript runtime before installing clothing additions.
Game 2.5 uses redscript 0.5.32 or newer. CyberMac compiles inventory delivery
together with your other enabled script mods.

## Restore an installation

Select the import and choose **Restore previous files**. When clothing and body
installs share archives, restore them in reverse installation order.

Restoration recovers the preceding game files. Unchecking a garment in a later
selection does not remove an item already stored in your save.

## Inspect and prepare from the command line

```sh
swift run cybermac clothing inspect-import --zip "/path/to/clothes.zip"
swift run cybermac clothing prepare-import --zip "/path/to/clothes.zip" \
  --records Items.CyberMac_Import_example --out "/path/to/plan.json"
```

Use the record IDs returned by inspection when preparing a selection. These
commands inspect and prepare files without applying the installation plan.

For an isolated workspace, pass `--home "/path/to/test-home"` to both commands
and configure its redscript runtime and base script cache.
