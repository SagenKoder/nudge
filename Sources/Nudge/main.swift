import AppKit

// A background app: no Dock icon, no menu bar item (LSUIElement in Info.plist,
// .accessory here for when the binary is run outside the bundle).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    _ = WindowMover.ensureTrusted(prompt: true)

    let mover = WindowMover()
    let hotKeys = HotKeys { mover.perform($0) }
    if hotKeys.register() > 0 {
        FileHandle.standardError.write(Data("nudge: some hotkeys are taken by another app (Rectangle?)\n".utf8))
    }

    withExtendedLifetime(hotKeys) { app.run() }
}
