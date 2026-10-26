# Security

## Reporting a vulnerability

Please report security problems privately through
[GitHub's private vulnerability reporting](https://github.com/SagenKoder/nudge/security/advisories/new),
not as a public issue. You should get a reply within a week.

## What Nudge can access

Nudge needs the macOS **Accessibility** permission. That permission is broad: it allows an app to
read and control the windows of other apps. Nudge uses it only to read and set the position and
size of the focused window when you press one of its shortcuts.

- No network access: Nudge never connects to the internet. There is no telemetry, no update check
  and no crash reporting.
- No keylogging: shortcuts are registered with `RegisterEventHotKey`, so Nudge only ever sees its
  own five key combinations, never other typing.
- No stored data apart from one preference (whether it has set itself up to start at login).

## Verifying a download

Releases are built by GitHub Actions from a tagged commit, signed with a Developer ID certificate
and notarized by Apple. Each release carries a `SHA256SUMS` file and a build provenance attestation:

```sh
shasum -a 256 -c SHA256SUMS
gh attestation verify Nudge-1.0.0.dmg --repo SagenKoder/nudge
codesign -dv --verbose=2 /Applications/Nudge.app   # Authority=Developer ID Application: …
```
