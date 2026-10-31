import AppKit
import Observation

/// Un elemento vuoto nella barra dei menu che riserva lo spazio per l'isola tra le altre icone.
/// L'isola non è disegnata dentro l'elemento: ci si appoggia sopra e lascia passare i click,
/// così il click destro arriva all'elemento, che apre il menu.
@Observable
final class MenuBarAnchor {
    /// Cornice dell'elemento in coordinate globali, quando è nella barra dei menu.
    private(set) var frame: CGRect?

    @ObservationIgnored private var item: NSStatusItem?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var pendingRefresh: DispatchWorkItem?
    @ObservationIgnored private let clickTarget = ClickTarget()

    /// Click destro sull'isola (cioè sull'elemento sotto di lei).
    @ObservationIgnored var onRightClick: ((NSStatusBarButton) -> Void)? {
        get { clickTarget.onRightClick }
        set { clickTarget.onRightClick = newValue }
    }

    /// Click sinistro sull'isola.
    @ObservationIgnored var onLeftClick: (() -> Void)? {
        get { clickTarget.onLeftClick }
        set { clickTarget.onLeftClick = newValue }
    }

    func update(visible: Bool, width: CGFloat) {
        guard visible else {
            remove()
            return
        }
        let length = width + 2 * Theme.Capsule.menuBarItemPadding
        if let item {
            if item.length != length { item.length = length }
            scheduleRefresh()
        } else {
            create(length: length)
        }
    }

    private func create(length: CGFloat) {
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = "AtolloIsland"
        item.button?.title = ""
        item.button?.image = nil
        item.button?.isBordered = false
        // Nessuna evidenziazione: sinistro apre Spotify, destro apre il menu.
        (item.button?.cell as? NSButtonCell)?.highlightsBy = []
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.target = clickTarget
        item.button?.action = #selector(ClickTarget.clicked(_:))
        self.item = item

        if let window = item.button?.window {
            let center = NotificationCenter.default
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didChangeScreenNotification] {
                observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleRefresh() }
                })
            }
        }
        scheduleRefresh()
    }

    private func remove() {
        pendingRefresh?.cancel()
        pendingRefresh = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        if frame != nil { frame = nil }
    }

    /// Quando l'elemento nasce o cambia larghezza, macOS ridispone la barra dei menu e per un
    /// istante lo mette in posizioni provvisorie. La posizione si legge solo a barra ferma,
    /// altrimenti l'isola salterebbe avanti e indietro.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshFrame() }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Capsule.menuBarSettleDelay, execute: work)
    }

    private func refreshFrame() {
        pendingRefresh = nil
        // La finestra dell'elemento ha un margine di sistema attorno al pulsante:
        // conta solo il pulsante, cioè lo spazio riservato davvero all'isola.
        guard let button = item?.button, let window = button.window, button.bounds.width > 0 else { return }
        let newFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        if newFrame != frame { frame = newFrame }
    }
}

private final class ClickTarget: NSObject {
    var onRightClick: ((NSStatusBarButton) -> Void)?
    var onLeftClick: (() -> Void)?

    @objc func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            onRightClick?(sender)
        } else {
            onLeftClick?()
        }
    }
}
