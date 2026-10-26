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
        let key: String
        let label: String
    }

    static let modifiers = UInt32(controlKey | optionKey)
    static let bindings = [
        Binding(keyCode: kVK_LeftArrow, action: .left, key: "←", label: "Left half"),
        Binding(keyCode: kVK_RightArrow, action: .right, key: "→", label: "Right half"),
        Binding(keyCode: kVK_UpArrow, action: .top, key: "↑", label: "Top half"),
        Binding(keyCode: kVK_DownArrow, action: .bottom, key: "↓", label: "Bottom half"),
        Binding(keyCode: kVK_Return, action: .maximize, key: "↩", label: "Maximize"),
    ]

    private static let signature: OSType = 0x4E_55_44_47 // "NUDG"
    private static let log = Logger(subsystem: "com.sagenkoder.nudge", category: "hotkeys")

    // Carbon calls back through a C function pointer, which cannot capture context.
    private static var handler: ((Action) -> Void)?
    private var refs: [Int: EventHotKeyRef] = [:]
    private var handlerInstalled = false

    /// Shortcuts another app (e.g. Rectangle) already owns.
    var missing: [Binding] {
        HotKeys.bindings.indices.filter { refs[$0] == nil }.map { HotKeys.bindings[$0] }
    }

    init(onPress: @escaping (Action) -> Void) {
        HotKeys.handler = onPress
    }

    /// Registers every shortcut not yet held. Safe to call again after a conflicting app quits.
    func register() {
        installHandler()
        for (index, binding) in HotKeys.bindings.enumerated() where refs[index] == nil {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: HotKeys.signature, id: UInt32(index))
            let status = RegisterEventHotKey(
                UInt32(binding.keyCode), HotKeys.modifiers, id, GetApplicationEventTarget(), 0, &ref
            )
            if status == noErr, let ref {
                refs[index] = ref
            } else {
                HotKeys.log.error("Could not register ⌃⌥ \(binding.action.rawValue, privacy: .public): \(status)")
            }
        }
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
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
    }
}
