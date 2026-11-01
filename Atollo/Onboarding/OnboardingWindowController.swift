import AppKit
import SwiftUI

/// Finestra della schermata di intro: senza titolo, contenuto fino in cima.
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let permissions: PermissionsCenter
    private let onFinish: () -> Void

    init(permissions: PermissionsCenter, onFinish: @escaping () -> Void) {
        self.permissions = permissions
        self.onFinish = onFinish
    }

    func show() {
        if window == nil {
            let view = OnboardingView(permissions: permissions) { [weak self] in self?.finish() }
            let hosting = NSHostingController(rootView: view)
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        window?.bringToFront()
    }

    private func finish() {
        window?.close()
    }

    /// Chiudere la finestra vale come "Inizia".
    func windowWillClose(_ notification: Notification) {
        window = nil
        onFinish()
    }
}
