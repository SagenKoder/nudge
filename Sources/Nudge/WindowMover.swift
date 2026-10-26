import AppKit
import ApplicationServices
import NudgeCore
import os

/// Moves the focused window of the frontmost app through the Accessibility API.
@MainActor
final class WindowMover {
    private static let log = Logger(subsystem: "com.sagenkoder.nudge", category: "mover")

    private var lastWindow: AXUIElement?
    private var lastMove: LastMove?

    static func ensureTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func perform(_ action: Action) {
        guard WindowMover.ensureTrusted(prompt: true) else {
            WindowMover.log.error("Accessibility permission missing")
            return
        }
        guard let window = focusedWindow(), let current = frame(of: window) else { return }

        let remembered = lastWindow.map { CFEqual($0, window) } == true ? lastMove : nil
        guard let target = Layout.target(
            for: action, window: current, screens: WindowMover.screens(), lastMove: remembered
        ) else { return }

        setFrame(target, of: window)

        lastWindow = window
        lastMove = frame(of: window).map { LastMove(action: action, resultingFrame: $0) }
    }

    // MARK: - Screens

    /// NSScreen frames converted to Accessibility space (top-left of the primary screen).
    private static func screens() -> [Screen] {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return [] }
        return NSScreen.screens.map {
            Screen(
                frame: Layout.flip($0.frame, primaryScreenHeight: primaryHeight),
                visibleFrame: Layout.flip($0.visibleFrame, primaryScreenHeight: primaryHeight)
            )
        }
    }

    // MARK: - Accessibility

    private func focusedWindow() -> AXUIElement? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position: CGPoint = read(kAXPositionAttribute, of: window, as: .cgPoint),
              let size: CGSize = read(kAXSizeAttribute, of: window, as: .cgSize)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func setFrame(_ frame: CGRect, of window: AXUIElement) {
        // Apps with "enhanced user interface" on (set by e.g. VoiceOver) animate and
        // fight AX resizes; switch it off on the app for the duration of the move.
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let app = AXUIElementCreateApplication(pid)
        let enhanced = "AXEnhancedUserInterface" as CFString
        var wasEnhanced: CFTypeRef?
        AXUIElementCopyAttributeValue(app, enhanced, &wasEnhanced)
        let restoreEnhanced = (wasEnhanced as? Bool) == true
        if restoreEnhanced { AXUIElementSetAttributeValue(app, enhanced, kCFBooleanFalse) }
        defer { if restoreEnhanced { AXUIElementSetAttributeValue(app, enhanced, kCFBooleanTrue) } }

        // Size, move, size again: the first resize can be clamped by the old screen's
        // bounds when moving between monitors of different sizes.
        write(frame.size, kAXSizeAttribute, of: window, as: .cgSize)
        write(frame.origin, kAXPositionAttribute, of: window, as: .cgPoint)
        write(frame.size, kAXSizeAttribute, of: window, as: .cgSize)
    }

    private func read<T: BitwiseCopyable>(_ attribute: String, of element: AXUIElement, as type: AXValueType) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        return AXValueGetValue(value as! AXValue, type, pointer) ? pointer.pointee : nil
    }

    private func write<T: BitwiseCopyable>(_ value: T, _ attribute: String, of element: AXUIElement, as type: AXValueType) {
        var value = value
        guard let axValue = AXValueCreate(type, &value) else { return }
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
        if result != .success {
            WindowMover.log.debug("Setting \(attribute, privacy: .public) failed: \(result.rawValue)")
        }
    }
}
