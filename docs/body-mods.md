# Character customization

CyberMac supports character appearance changes through body preset packages.
It prepares presets using the installed game's native resources, with separate
settings for character previews and gameplay.

## Install a preset

1. Close the game and open **Install mods**.
2. Import a body preset ZIP prepared for CyberMac and your game version.
3. Choose a variant from the options shown in the app.
4. Click **Install selected variant** and finish macOS Installer.
5. Launch the game and load your save.

Check the result in inventory, Photo Mode and gameplay. Clothing can affect how
an appearance change is displayed, so use the same outfit when comparing presets.

Set up the [conversion tools](building.md#clothing-and-body-conversion-tools)
before using this workflow.

## Variant scope

Presets can target the player or shared character resources. A shared variant
can also affect NPC appearances. Review the selected variant's scope before
installing, and restore the current preset before switching scopes.

## Restore a preset

Select the import and choose **Restore previous files**. If clothing or another
preset was installed afterward, restore those shared-file changes first.

CyberMac retains existing clothing changes when preparing a preset and verifies
the generated resources before installation.

## Prepare from the command line

```sh
swift run cybermac body prepare "/path/to/body-preset.zip" \
  --variant shared --out "/path/to/body-plan.json"
```

This command prepares an installation plan without applying it. Use
`--variant player` to prepare a player-specific plan.
