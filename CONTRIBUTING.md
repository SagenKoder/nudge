# Contributing

Thanks for wanting to help. Nudge is deliberately tiny: five shortcuts, no settings beyond
"start at login". Bug fixes and better behaviour in specific apps are very welcome. For new
features, please open an issue first so we can agree it fits before you spend time on it.

## Development

Requires macOS 13+ and Xcode 16+ (or the matching Command Line Tools).

```sh
swift test       # unit tests for the layout logic (Sources/NudgeCore)
make install     # build, sign, copy to /Applications and launch
make logs        # stream Nudge's log while you try things
```

`make install` signs with your Apple Development certificate if you have one, so the
Accessibility permission survives rebuilds. Without one it signs ad-hoc, and macOS asks for
the permission again after each rebuild.

## Code layout

- `Sources/NudgeCore`: pure geometry, no AppKit. Anything that decides *where* a window goes
  belongs here, with a test in `Tests/NudgeCoreTests`.
- `Sources/Nudge`: the app. Hotkeys, the Accessibility calls that move windows, the login item
  and the one window.

## Pull requests

- Keep them small and focused, and say how you tested by hand (which apps, how many screens).
- `swift test` must pass; CI runs it on every PR.
- Add a line under "Unreleased" in `CHANGELOG.md` for anything users will notice.

## Releasing (maintainer)

1. Move the "Unreleased" notes in `CHANGELOG.md` under the new version and commit.
2. `git tag -s v1.2.3 -m "Nudge 1.2.3" && git push origin v1.2.3`
3. The Release workflow builds, signs, notarizes and publishes the DMG.
4. Update the cask in [SagenKoder/homebrew-tap](https://github.com/SagenKoder/homebrew-tap)
   with the new version and the SHA-256 from the release's `SHA256SUMS`.

By contributing you agree that your contributions are licensed under the MIT License.
