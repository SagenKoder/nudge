import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mover = WindowMover()
    private lazy var hotKeys = HotKeys { [mover] in mover.perform($0) }
    private lazy var panel = Panel(hotKeys: hotKeys)

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKeys.register()
        LoginItem.enableOnFirstLaunch()
        mover.onMissingPermission = { [weak self] in self?.panel.show(closeWhenReady: true) }

        if !AXIsProcessTrusted() || !hotKeys.missing.isEmpty {
            panel.show(closeWhenReady: true)
        }
    }

    /// Opening Nudge again (Finder, Spotlight, `open -a Nudge`) is the way to reach its settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panel.show()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
