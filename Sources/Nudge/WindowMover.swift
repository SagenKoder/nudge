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

    /// Short enough that heavy apps barely get to redraw mid-way, long enough to read as motion.
    private static let animationDuration: CFTimeInterval = 0.12
    private struct Animation {
        let window: AXUIElement
        let from: CGRect
        let to: CGRect
        let started: CFTimeInterval
        let completion: () -> Void
    }
    private var animation: Animation?
    private var timer: Timer?

    static func ensureTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func perform(_ action: Action) {
        guard WindowMover.ensureTrusted(prompt: true) else {
            WindowMover.log.error("Accessibility permission missing")
            return
        }
        // A press mid-animation first lands the previous move, so repeat presses still jump screens.
        finishAnimation()
        guard let window = focusedWindow(), let current = frame(of: window) else { return }

        let remembered = lastWindow.map { CFEqual($0, window) } == true ? lastMove : nil
        guard let target = Layout.target(
            for: action, window: current, screens: WindowMover.screens(), lastMove: remembered
        ) else { return }

        animate(window, from: current, to: target) { [self] in
            let result = frame(of: window)
            WindowMover.log.info("""
                \(action.rawValue, privacy: .public): \(String(describing: current), privacy: .public) \
                → \(String(describing: target), privacy: .public), got \(String(describing: result), privacy: .public), \
                repeat=\(remembered != nil, privacy: .public)
                """)
            lastWindow = window
            lastMove = result.map { LastMove(action: action, target: target, resultingFrame: $0) }
        }
    }

    // MARK: - Animation

    private func animate(_ window: AXUIElement, from: CGRect, to: CGRect, completion: @escaping () -> Void) {
        animation = Animation(window: window, from: from, to: to, started: CACurrentMediaTime(), completion: completion)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
    }

    private func step() {
        guard let animation else { return }
        let progress = (CACurrentMediaTime() - animation.started) / WindowMover.animationDuration
        guard progress < 1 else { return finishAnimation() }
        let frame = Layout.interpolate(from: animation.from, to: animation.to, progress: progress)
        write(frame.origin, kAXPositionAttribute, of: animation.window, as: .cgPoint)
        write(frame.size, kAXSizeAttribute, of: animation.window, as: .cgSize)
    }

    /// Jumps to the end frame exactly, then runs the completion.
    private func finishAnimation() {
        timer?.invalidate()
        timer = nil
        guard let animation else { return }
        self.animation = nil
        setFrame(animation.to, of: animation.window)
        animation.completion()
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
