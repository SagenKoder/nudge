import Carbon.HIToolbox
import NudgeCore
import os

/// Global hotkeys via Carbon's RegisterEventHotKey. Unlike an event tap this
/// needs no extra permission and only ever sees the exact combos we register.
@MainActor
final class HotKeys {
    struct Binding {
        let keyCode: Int
        let action: Action
    }

    static let modifiers = UInt32(controlKey | optionKey)
    static let bindings = [
        Binding(keyCode: kVK_LeftArrow, action: .left),
        Binding(keyCode: kVK_RightArrow, action: .right),
        Binding(keyCode: kVK_UpArrow, action: .top),
        Binding(keyCode: kVK_DownArrow, action: .bottom),
        Binding(keyCode: kVK_Return, action: .maximize),
    ]

    private static let signature: OSType = 0x4E_55_44_47 // "NUDG"
    private static let log = Logger(subsystem: "com.sagenkoder.nudge", category: "hotkeys")

    // Carbon calls back through a C function pointer, which cannot capture context.
    private static var handler: ((Action) -> Void)?
    private var refs: [EventHotKeyRef] = []

    init(onPress: @escaping (Action) -> Void) {
        HotKeys.handler = onPress
    }

    /// Returns the number of hotkeys that could not be registered (taken by another app).
    @discardableResult
    func register() -> Int {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            let index = Int(id.id)
            guard id.signature == HotKeys.signature, HotKeys.bindings.indices.contains(index) else {
                return OSStatus(eventNotHandledErr)
            }
            // Carbon delivers hotkey events on the main run loop.
            MainActor.assumeIsolated { HotKeys.handler?(HotKeys.bindings[index].action) }
            return noErr
        }, 1, &eventType, nil, nil)

        var failures = 0
        for (index, binding) in HotKeys.bindings.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: HotKeys.signature, id: UInt32(index))
            let status = RegisterEventHotKey(
                UInt32(binding.keyCode), HotKeys.modifiers, id, GetApplicationEventTarget(), 0, &ref
            )
            if status == noErr, let ref {
                refs.append(ref)
            } else {
                failures += 1
                HotKeys.log.error("Could not register ⌃⌥ \(binding.action.rawValue, privacy: .public): \(status)")
            }
        }
        return failures
    }
}
