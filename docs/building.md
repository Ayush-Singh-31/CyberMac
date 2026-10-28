# Building CyberMac

CyberMac uses Swift Package Manager. The desktop app is built with SwiftUI, and
the `cybermac` executable provides the command-line tools.

## Requirements

- macOS 15 or later on Apple Silicon.
- Xcode with the Swift 6 toolchain.
- Cyberpunk 2077: Ultimate from the Mac App Store for installation workflows.

## Build and run

```sh
git clone https://github.com/Ayush-Singh-31/CyberMac.git
cd CyberMac
swift build
swift run CyberMacApp
```

For command-line help:

```sh
swift run cybermac help
```

## Clothing and body conversion tools

Clothing and body preparation use Python, .NET, a macOS-compatible WolvenKit CLI
build and an ARM64 Kraken decompression library. Set the following environment
variables to the tools installed on your machine:

| Variable | Path to provide |
| --- | --- |
| `CYBERMAC_PREVIEW_PYTHON` | Python 3.11 or newer executable |
| `CYBERMAC_PREVIEW_DOTNET` | .NET executable compatible with your WolvenKit CLI build |
| `CYBERMAC_PREVIEW_WOLVENKIT` | `WolvenKit.CLI.dll` |
| `CYBERMAC_PREVIEW_KRAKEN` | ARM64 Kraken library exporting `Kraken_Decompress` |

The `PREVIEW` variable names are also used by the active conversion tools.

For example, set paths before configuring or building:

```sh
export CYBERMAC_PREVIEW_PYTHON="/path/to/python3"
export CYBERMAC_PREVIEW_DOTNET="/path/to/dotnet"
export CYBERMAC_PREVIEW_WOLVENKIT="/path/to/WolvenKit.CLI.dll"
export CYBERMAC_PREVIEW_KRAKEN="/path/to/libkraken.dylib"
python3 tools/configure_clothing_conversion.py --out .research/conversion-tools.json
```

The configuration records local tool paths. Tools are supplied separately;
the configuration script discovers existing installations.

## Build the macOS app

```sh
scripts/build-app.sh
```

The app is written to `dist/CyberMac.app`. The script packages CyberMac's
conversion scripts, records the configured tool paths and applies a local
ad-hoc signature. Use the resulting app on the machine where those tools are
configured.

## Run tests

```sh
swift test
python3 -B -m unittest discover -s tools -p 'test_*.py'
```

The Python texture and preview tests use Pillow. Active clothing and body
conversion do not require Blender or Pillow.

See [Contributing](../CONTRIBUTING.md) for pull request and test guidance.
