import ServiceManagement
import os

/// Start at login through SMAppService, so Nudge shows up (and can be switched off)
/// under System Settings → General → Login Items like any other app.
@MainActor
enum LoginItem {
    private static let log = Logger(subsystem: "com.sagenkoder.nudge", category: "login-item")
    private static let offeredKey = "LoginItemOffered"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Could not \(enabled ? "enable" : "disable", privacy: .public) login item: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Turns it on the first time Nudge runs. After that it is the user's choice,
    /// so switching it off in System Settings sticks.
    static func enableOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: offeredKey) else { return }
        defaults.set(true, forKey: offeredKey)
        setEnabled(true)
    }
}
