# Contributing to CyberMac

Thank you for helping improve CyberMac. Bug reports, mod compatibility reports
and pull requests are welcome.

## Report an issue

Use the [GitHub issue templates](https://github.com/Ayush-Singh-31/CyberMac/issues/new/choose)
and include:

- CyberMac version or commit.
- macOS version and Mac model.
- Cyberpunk 2077 version and storefront.
- Mod name, version and original download link.
- Steps to reproduce the issue and relevant diagnostic output.

For compatibility reports, describe the result in gameplay as well as inventory
or Photo Mode. Share logs and screenshots rather than game files.

## Development setup

Follow the [build guide](docs/building.md), then run:

```sh
swift test
python3 -B -m unittest discover -s tools -p 'test_*.py'
```

The Python suite uses Pillow for texture and preview tests.

## Pull requests

Keep each change focused and explain the behavior it improves. Include the
checks you ran, and add relevant tests for new package types or installation
behavior. Use small synthetic fixtures for archive, script and XML tests.

Installation changes should preserve the existing authorization, backup,
verification and recovery flow. Include verification results when changing
activation, input patches, game paths or restoration.

Keep local runtimes, downloaded mods, game assets and generated installation
files out of commits. Third-party contributions should retain their license
and attribution.
