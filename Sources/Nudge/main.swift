import AppKit

// A background app: no Dock icon, no menu bar item (LSUIElement in Info.plist,
// .accessory here for when the binary is run outside the bundle).
MainActor.assumeIsolated {
    if CommandLine.arguments.contains("--unregister-login-item") {
        // Used by `make uninstall`, since only the app itself can remove its login item.
        LoginItem.setEnabled(false)
        exit(0)
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
