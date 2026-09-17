import AppKit
import SwiftUI
import Observation

@MainActor
func observeContinuously(_ apply: @escaping @MainActor @Sendable () -> Void) {
    withObservationTracking(apply) {
        Task { @MainActor in observeContinuously(apply) }
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class OverlayPresenter {
    private var breakWindows: [NSWindow] = []
    private var microWindow: NSWindow?
    private var idleWindow: NSWindow?

    private let manager: BreakManager
    private let settings: AppSettings

    init(manager: BreakManager, settings: AppSettings) {
        self.manager = manager
        self.settings = settings

        observeContinuously { [weak self] in self?.sync() }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.breakWindows.isEmpty else { return }
                self.teardownBreak()
                self.sync()
            }
        }
    }

    private func sync() {
        let resting = manager.isResting
        let micro = manager.activeMicroReminder
        let idle = manager.showIdleReturn

        if resting, breakWindows.isEmpty {
            presentBreak()
        } else if !resting, !breakWindows.isEmpty {
            teardownBreak()
        }

        if let micro, microWindow == nil {
            presentMicro(micro)
        } else if micro == nil, microWindow != nil {
            dismiss(&microWindow)
        }

        if idle, idleWindow == nil {
            presentIdle()
        } else if !idle, idleWindow != nil {
            dismiss(&idleWindow)
        }
    }

    // MARK: - Surfaces

    private func presentBreak() {
        guard case .resting(let kind) = manager.phase else { return }

        breakWindows = NSScreen.screens.map { screen in
            let window = OverlayWindow(
                contentRect: screen.frame, styleMask: .borderless,
                backing: .buffered, defer: false
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentView = NSHostingView(
                rootView: BreakOverlayView(kind: kind, manager: manager, settings: settings)
            )
            window.setFrame(screen.frame, display: true)
            return window
        }

        breakWindows.first?.makeKeyAndOrderFront(nil)
        breakWindows.dropFirst().forEach { $0.orderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func teardownBreak() {
        breakWindows.forEach(fadeOut)
        breakWindows = []
    }

    private func presentMicro(_ kind: MicroReminder) {
        guard let screen = NSScreen.main else { return }

        let size = CGSize(width: 384, height: 150)
        let frame = CGRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height - 120,
            width: size.width, height: size.height
        )

        let window = NSPanel(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.contentView = NSHostingView(rootView: MicroReminderView(kind: kind))
        window.orderFront(nil)
        microWindow = window
    }

    private func presentIdle() {
        guard let screen = NSScreen.main else { return }

        let size = CGSize(width: 380, height: 286)
        let frame = CGRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2,
            width: size.width, height: size.height
        )

        let window = OverlayWindow(
            contentRect: frame, styleMask: .borderless,
            backing: .buffered, defer: false
        )
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: IdleReturnView(manager: manager))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        idleWindow = window
    }

    // MARK: - Teardown

    private func dismiss(_ window: inout NSWindow?) {
        if let w = window { fadeOut(w) }
        window = nil
    }

    private func fadeOut(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            window.orderOut(nil)
        }
    }
}
