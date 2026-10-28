import AppKit
import NudgeCore
import ServiceManagement
import os

/// Start at login through SMAppService, so Nudge shows up (and can be switched off)
/// under System Settings → General → Login Items like any other app.
@MainActor
enum LoginItem {
    private static let log = Logger(subsystem: "com.sagenkoder.nudge", category: "login-item")
    /// What the user wants; on unless they switched it off in Nudge's window.
    private static let wantedKey = "StartAtLogin"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    private static var wanted: Bool {
        get { UserDefaults.standard.object(forKey: wantedKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: wantedKey) }
    }

    /// Called on every launch: puts the login item back after a reinstall or upgrade removed it.
    static func restoreIfWanted() {
        UserDefaults.standard.removeObject(forKey: "LoginItemOffered") // used by 1.0.0
        if LoginItemPolicy.shouldRegister(wantsStartAtLogin: wanted, status: policyStatus) {
            register()
        }
    }

    /// The "Start at login" switch in Nudge's window.
    static func setEnabled(_ enabled: Bool) {
        wanted = enabled
        if enabled {
            register()
            // Switched off in System Settings before: only the user can turn it back on there.
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } else {
            unregister()
        }
    }

    /// For `--unregister-login-item` (make uninstall): removes the item without changing the wish.
    static func unregister() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            log.error("Could not remove login item: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func register() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            log.error("Could not add login item: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static var policyStatus: LoginItemPolicy.Status {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        default: .notRegistered
        }
    }
}
