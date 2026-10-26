# Nudge

A tiny macOS window snapper. No menu bar icon, no settings window, no donation prompts. Just five shortcuts.

| Shortcut | Action |
|---|---|
| ⌃⌥ ← | Left half |
| ⌃⌥ → | Right half |
| ⌃⌥ ↑ | Top half |
| ⌃⌥ ↓ | Bottom half |
| ⌃⌥ ↩ | Maximize |

Press ⌃⌥ ← again when a window is already on the left half, and it moves to the right half of the monitor to the left. ⌃⌥ → works the same way towards the right.

## Install

Requires macOS 13+ and Xcode or the Command Line Tools.

```sh
make install
```

This builds `Nudge.app`, copies it to `~/Applications`, and adds a LaunchAgent so it starts at login. The first time you use a shortcut, macOS asks you to allow Nudge under **System Settings → Privacy & Security → Accessibility**.

If you have an Apple Development certificate in your keychain, the app is signed with it, so the permission survives rebuilds. Without one it is ad-hoc signed, and macOS asks again after each rebuild.

Rectangle, Spectacle and similar tools that use the same shortcuts must be quit first. Otherwise the shortcuts are already taken.

## Other commands

```sh
make test       # unit tests for the layout logic
make restart    # restart the running app
make logs       # stream its logs
make uninstall  # stop it and remove the app and LaunchAgent
```

## How it works

- `Sources/NudgeCore`: pure geometry. It works out which screen a window is on, where each half is, and when a repeat press should jump to the next monitor. It is fully unit tested.
- `Sources/Nudge`: global hotkeys through Carbon `RegisterEventHotKey` (no extra permission needed), and window moves through the Accessibility API.

## License

MIT
