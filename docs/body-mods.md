# Body mods

CyberMac can prepare and install the Lethal Curves maximum body preset for
feminine V using the game's native Mac rigs. The gameplay preset has been tested
in inventory, Photo Mode, first person and while riding a motorcycle on the
Mac App Store 2.5 build.

## Prepare the preset

Download **Lethal Curves – Modular Rig Deform Builder 2.1.1** from its
[original mod page](https://www.nexusmods.com/cyberpunk2077/mods/23462).

From the CyberMac repository, run:

```sh
python3 tools/import_lethal_curves.py "/path/to/Lethal Curves builder.zip" \
  --out "/path/to/Lethal Curves Maximum Gameplay - CyberMac.zip"
```

The importer reads the author's maximum presets for arms, chest, buttocks,
upper thighs, lower thighs and calves. It creates a small data-only ZIP with
separate preview and gameplay values, without running the Windows builder.

Set up the [conversion tools](building.md#clothing-and-body-conversion-tools)
before installing the generated preset.

## Install in CyberMac

1. Close the game and open **Install mods**.
2. Import the generated **Lethal Curves Maximum Gameplay** ZIP.
3. Select **Lethal Curves maximum gameplay (V + NPCs test)**.
4. Click **Install selected variant** and finish macOS Installer.
5. Launch the game and load your save.

This tested variant changes the shared feminine rig, so it also affects feminine
NPCs. The **V only** variant is available for testing player-specific routing.
Restore the current body installation before switching between these scopes.

For a clear comparison, use close-fitting clothes and check the body in
inventory, first person and on a motorcycle.

## Restore

Select the import and choose **Restore previous files**. If clothing or another
body installation was added afterward, restore those shared-file changes first.

CyberMac retains existing clothing changes when preparing a body installation.
It rebuilds each native Mac rig with its corresponding authored values and
verifies the generated resources before installation.

## Preparation from the command line

```sh
swift run cybermac body prepare "/path/to/Lethal Curves Maximum Gameplay - CyberMac.zip" \
  --variant shared --out "/path/to/body-plan.json"
```

This command prepares an installation plan without applying it. Use `--variant player` to prepare the player-specific variant.

## Credits

The body preset data comes from Lethal Curves. CyberMac's rig adapter also uses
the [Unique V Body Shape framework](https://www.nexusmods.com/cyberpunk2077/mods/3725)
as a reference for player-specific rig routing. Obtain both projects from their
original authors.
