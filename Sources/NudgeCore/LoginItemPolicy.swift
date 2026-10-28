/// Decides whether Nudge should add itself to Login Items when it launches.
///
/// The user's wish is stored by Nudge; the system keeps the actual login item. They drift
/// apart when the app is removed and installed again (as `brew upgrade` does): the system
/// forgets the item, the wish stays. Re-adding it then is right. When the user switched it
/// off in System Settings the item still exists, only disabled, and must be left alone.
public enum LoginItemPolicy {
    /// Mirrors `SMAppService.Status`, which NudgeCore cannot import.
    public enum Status: Sendable {
        case notRegistered, enabled, requiresApproval, notFound
    }

    public static func shouldRegister(wantsStartAtLogin: Bool, status: Status) -> Bool {
        guard wantsStartAtLogin else { return false }
        switch status {
        case .notRegistered, .notFound: return true
        case .enabled, .requiresApproval: return false
        }
    }
}
