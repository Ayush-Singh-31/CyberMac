# Contributing

CyberMac is a source-only developer preview. Keep changes conservative and easy to audit.

Before opening a PR:

- Run `swift test`.
- Do not add bundled runtimes, mods, or Cyberpunk game files.
- Keep `AppSafetyTests` passing.
- Add scanner tests for new mod categories.
- Add fixtures only if they are small and not copyrighted game files.
- Prefer source-only fixtures and synthetic XML snippets.
- Never add privileged write execution to the SwiftUI app.

If a change touches activation, restore, input patching, or bundle paths, include the relevant verification output in the PR description.
