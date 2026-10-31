import AppKit
import Observation

/// Un elemento vuoto nella barra dei menu che riserva lo spazio per l'isola tra le altre icone.
/// L'isola non è disegnata dentro l'elemento: ci si appoggia sopra, centrata su di lui.
@Observable
final class MenuBarAnchor {
    /// Cornice dell'elemento in coordinate globali, quando è nella barra dei menu.
    private(set) var frame: CGRect?

    @ObservationIgnored private var item: NSStatusItem?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func update(visible: Bool, width: CGFloat) {
        guard visible else {
            remove()
            return
        }
        let length = width + 2 * Theme.Capsule.menuBarItemPadding
        if let item {
            if item.length != length { item.length = length }
        } else {
            create(length: length)
        }
        refreshFrame()
    }

    private func create(length: CGFloat) {
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = "AtolloIsland"
        item.button?.title = ""
        item.button?.image = nil
        item.button?.isBordered = false
        self.item = item

        if let window = item.button?.window {
            let center = NotificationCenter.default
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didChangeScreenNotification] {
                observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refreshFrame() }
                })
            }
        }
        // La barra dei menu posiziona l'elemento un attimo dopo.
        DispatchQueue.main.async { [weak self] in self?.refreshFrame() }
    }

    private func remove() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        if frame != nil { frame = nil }
    }

    private func refreshFrame() {
        guard let window = item?.button?.window, window.frame.width > 0 else { return }
        let newFrame = window.frame
        if newFrame != frame { frame = newFrame }
    }
}
