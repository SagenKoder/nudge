import AppKit
import ApplicationServices
import SwiftUI

/// The only window Nudge has. It opens on first launch while the Accessibility
/// permission is missing, and whenever Nudge is opened again from Finder or Spotlight.
@MainActor
final class Panel {
    private let model: PanelModel
    private var window: NSWindow?

    init(hotKeys: HotKeys) {
        model = PanelModel(hotKeys: hotKeys)
    }

    /// `closeWhenReady` is for onboarding: the window goes away by itself once everything works.
    func show(closeWhenReady: Bool = false) {
        model.refresh()
        if closeWhenReady {
            model.onReady = { [weak self] in self?.window?.close() }
        } else {
            model.onReady = nil
        }

        if window == nil {
            let window = NSWindow(
                contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PanelView(model: model))
            window.center()
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [model] _ in
                MainActor.assumeIsolated { model.stopPolling() }
            }
            self.window = window
        }
        // LSUIElement apps are never frontmost on their own; without this the window opens behind everything.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        model.startPolling()
    }
}

@MainActor
final class PanelModel: ObservableObject {
    @Published var trusted = AXIsProcessTrusted()
    @Published var missing: [HotKeys.Binding] = []
    @Published var startAtLogin = LoginItem.isEnabled

    var onReady: (@MainActor @Sendable () -> Void)?
    var isReady: Bool { trusted && missing.isEmpty }

    let hotKeys: HotKeys
    private var timer: Timer?

    init(hotKeys: HotKeys) {
        self.hotKeys = hotKeys
    }

    func refresh() {
        trusted = AXIsProcessTrusted()
        missing = hotKeys.missing
        startAtLogin = LoginItem.isEnabled
    }

    /// macOS gives no callback when the user flips the Accessibility switch, so check every second.
    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        // Pick up shortcuts freed by an app that has since quit.
        if !hotKeys.missing.isEmpty { hotKeys.register() }
        refresh()
        if isReady, let onReady {
            self.onReady = nil
            stopPolling()
            // Leave the green check on screen for a moment before closing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: onReady)
        }
    }

    func openAccessibilitySettings() {
        // Adds Nudge to the list (switched off) so the user only has to flip it.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func setStartAtLogin(_ enabled: Bool) {
        LoginItem.setEnabled(enabled)
        startAtLogin = LoginItem.isEnabled
    }
}

struct PanelView: View {
    @ObservedObject var model: PanelModel

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nudge").font(.title2.bold())
                    Text("Version \(version)").font(.callout).foregroundStyle(.secondary)
                }
            }

            permissionRow
            if !model.missing.isEmpty { conflictRow }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(HotKeys.bindings, id: \.keyCode) { binding in
                        HStack {
                            Text("⌃ ⌥ \(binding.key)")
                                .font(.system(.body, design: .rounded).monospaced())
                                .frame(width: 70, alignment: .leading)
                            Text(binding.label)
                            Spacer()
                        }
                    }
                    Text("Press ← or → again to move to the next screen.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .padding(6)
            }

            HStack {
                Toggle("Start at login", isOn: Binding(
                    get: { model.startAtLogin },
                    set: { model.setStartAtLogin($0) }
                ))
                Spacer()
                Button("Quit Nudge") { NSApp.terminate(nil) }
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    @ViewBuilder private var permissionRow: some View {
        if model.trusted {
            Label("Nudge can move your windows.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("Nudge needs Accessibility access to move windows.", systemImage: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text("Click the button, then switch on Nudge in the list. This window notices by itself.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings") { model.openAccessibilitySettings() }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var conflictRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Another app is using some shortcuts.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Taken: \(model.missing.map { "⌃⌥\($0.key)" }.joined(separator: "  ")). Quit Rectangle or similar apps; Nudge picks them up automatically.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
