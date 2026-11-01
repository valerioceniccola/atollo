import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?
    private let makeView: () -> SettingsView

    init(makeView: @escaping () -> SettingsView) {
        self.makeView = makeView
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: makeView())
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: hosting)
            window.title = "Impostazioni di Atollo"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.bringToFront()
    }
}

extension NSWindow {
    /// Davanti a tutto, sullo Spazio attuale. Atollo non ha icona nel Dock: con l'attivazione
    /// cooperativa di macOS a volte `activate()` non basta e la finestra resterebbe dietro le altre.
    func bringToFront() {
        collectionBehavior.insert(.moveToActiveSpace)
        NSApp.activate()
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }
}
