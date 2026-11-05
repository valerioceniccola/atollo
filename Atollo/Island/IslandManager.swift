import AppKit
import SwiftUI

/// Atollo nella barra dei menu: un `NSStatusItem` che disegna il contenuto dentro di sé,
/// come le altre icone. Segue la barra in tutto (schermo intero, notch, barra nascosta, più schermi,
/// app che riordinano le icone) senza finestre proprie. Gestisce anche i click e il menu del click destro.
final class IslandManager {
    private let controller: SpotifyController
    private let settings: AppSettings
    private let colors: EqualizerColorProvider
    private let openSettings: () -> Void

    private let model: IslandModel
    private var item: NSStatusItem?
    private var hostingView: IslandHostingView?
    private let clickTarget = ClickTarget()
    private var removeTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?
    private var growWork: DispatchWorkItem?

    init(controller: SpotifyController, settings: AppSettings, colors: EqualizerColorProvider,
         openSettings: @escaping () -> Void) {
        self.controller = controller
        self.settings = settings
        self.colors = colors
        self.openSettings = openSettings
        model = IslandModel(geometry: IslandGeometry(screen: NSScreen.main ?? NSScreen.screens[0]),
                            nowPlaying: controller.state, settings: settings, colors: colors,
                            controller: controller)
    }

    func start() {
        clickTarget.onLeftClick = { [weak self] in self?.controller.activateSpotify() }
        clickTarget.onRightClick = { [weak self] button in self?.showMenu(at: button) }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateGeometry() }
        })
        // macOS rifà a volte la copia per l'altro monitor: si ricontrolla dopo ogni giro dell'app,
        // costa due confronti.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didUpdateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dimInactiveCopies() }
        })
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = model.presentation
            _ = model.closedWidth
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observe() }
        }
        sync()
    }

    // MARK: Comparsa e larghezza

    private func sync() {
        let width = model.closedWidth

        // Sparire: dissolvenza sul posto, poi via l'elemento dalla barra. Se è la pausa a nasconderlo
        // (Spotify resta aperto), si stringe come sempre e si dissolve verso la fine.
        guard model.presentation == .visible else {
            guard item != nil, removeTask == nil else { return }
            let isPausing = model.nowPlaying.isPresentable
            if isPausing { applyWidth(width) }
            removeTask = Task { [weak self] in
                if isPausing {
                    try? await Task.sleep(for: .seconds(Theme.Motion.pauseHideDelay))
                    guard !Task.isCancelled else { return }
                }
                guard let self else { return }
                withAnimation(Theme.Motion.fade) { self.model.displayedPresentation = .hidden }
                try? await Task.sleep(for: .seconds(Theme.Motion.fadeDuration))
                guard !Task.isCancelled else { return }
                self.removeItem()
            }
            return
        }

        removeTask?.cancel()
        removeTask = nil

        // Comparire: l'elemento nasce già della sua larghezza, il contenuto entra in dissolvenza.
        guard item != nil else {
            createItem(width: width)
            applyWidth(width)
            DispatchQueue.main.async { [weak self] in
                withAnimation(Theme.Motion.fade) { self?.model.displayedPresentation = .visible }
            }
            return
        }

        if model.displayedPresentation == .hidden {
            withAnimation(Theme.Motion.fade) { model.displayedPresentation = .visible }
        }
        // Cambio di larghezza: di colpo, insieme all'elemento, come fanno tutte le icone della barra.
        // Testo e copertina hanno già le loro dissolvenze.
        applyWidth(width)
    }

    private func applyWidth(_ width: CGFloat) {
        growWork?.cancel()
        growWork = nil
        let size = CGSize(width: width, height: model.geometry.capsuleHeight)
        guard let item, model.displayedShapeSize.width > 0, width > model.displayedShapeSize.width else {
            // Più stretto (o primo giro): contenuto ed elemento insieme. macOS lo fa scivolare
            // verso destra insieme alle icone a sinistra; il contenuto riempie l'elemento e lo segue.
            withoutAnimation { model.displayedShapeSize = size }
            if let item, item.length != width { item.length = width }
            return
        }

        // Più largo: macOS fa partire l'elemento allargato dalla posizione di prima e lo fa scivolare
        // a sinistra (circa 0,3 s), e in quel tempo coprirebbe le icone a destra. Il contenuto resta
        // largo come prima, appoggiato a sinistra, e scivola con le icone; a barra ferma si allarga
        // verso destra con la molla, dentro l'elemento.
        if item.length != width { item.length = width }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.growWork = nil
            withAnimation(Theme.Motion.island) { self.model.displayedShapeSize = size }
        }
        growWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Capsule.menuBarSlideDuration, execute: work)
    }

    // MARK: Elemento nella barra dei menu

    private func createItem(width: CGFloat) {
        let item = NSStatusBar.system.statusItem(withLength: width)
        // Lo stesso nome di sempre: macOS ricorda la posizione scelta con ⌘ e trascinamento.
        item.autosaveName = "AtolloIsland"
        guard let button = item.button else { return }
        button.title = ""
        button.image = nil
        button.isBordered = false
        // Nessuna evidenziazione: sinistro apre Spotify, destro apre il menu.
        (button.cell as? NSButtonCell)?.highlightsBy = []
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = clickTarget
        button.action = #selector(ClickTarget.clicked(_:))

        let hostingView = IslandHostingView(rootView: IslandView(model: model))
        hostingView.frame = button.bounds
        hostingView.autoresizingMask = [.width, .height]
        button.addSubview(hostingView)

        self.item = item
        self.hostingView = hostingView
        withoutAnimation { model.displayedPresentation = .hidden }

        // Testo bianco o scuro come la barra: macOS adegua l'aspetto del pulsante allo sfondo.
        appearanceObservation = button.observe(\.effectiveAppearance, options: [.initial, .new]) { button, _ in
            let isDark = button.effectiveAppearance.bestMatch(from: [.vibrantDark, .vibrantLight, .darkAqua, .aqua])
                .map { $0 == .vibrantDark || $0 == .darkAqua } ?? true
            Task { @MainActor [weak self] in
                guard let self, self.model.isDarkMenuBar != isDark else { return }
                self.model.isDarkMenuBar = isDark
            }
        }
        // Con più monitor macOS dà all'elemento una finestra per barra e sposta il pulsante in quella
        // del monitor attivo; nelle altre resta una copia. Quando il pulsante cambia finestra
        // si aggiornano misure e copie.
        hostingView.onWindowChange = { [weak self] in
            self?.updateGeometry()
            self?.dimInactiveCopies()
        }
        updateGeometry()
        dimInactiveCopies()
        // La copia per l'altro monitor macOS la crea poco dopo l'elemento.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.dimInactiveCopies() }
    }

    private func removeItem() {
        removeTask = nil
        appearanceObservation = nil
        growWork?.cancel()
        growWork = nil
        hostingView?.removeFromSuperview()
        hostingView = nil
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        // Il prossimo elemento nasce già della sua larghezza, senza allargarsi.
        withoutAnimation { model.displayedShapeSize = .zero }
    }

    /// Sui monitor non attivi macOS spegne le icone della barra; le copie di Atollo si schiariscono
    /// allo stesso modo. Le copie sono un'immagine del pulsante dentro la finestra della barra di
    /// quel monitor: si schiarisce il loro contenuto (l'opacità della finestra macOS la ignora).
    /// Quella con il pulsante (monitor attivo) resta piena.
    private func dimInactiveCopies() {
        guard let live = item?.button?.window else { return }
        for window in NSApp.windows where String(describing: type(of: window)).contains("StatusBarWindow") {
            guard let content = window.contentView else { continue }
            let alpha = window === live ? 1 : Theme.Capsule.inactiveMenuBarOpacity
            if content.alphaValue != alpha { content.alphaValue = alpha }
        }
    }

    /// Altezza della barra e colore dell'equalizzatore dipendono dallo schermo su cui è l'elemento.
    private func updateGeometry() {
        guard let screen = item?.button?.window?.screen ?? NSScreen.main else { return }
        let geometry = IslandGeometry(screen: screen)
        guard geometry != model.geometry else { return }
        withoutAnimation { model.geometry = geometry }
        applyWidth(model.closedWidth)
    }

    private func withoutAnimation(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }

    // MARK: Menu del click destro

    private func showMenu(at button: NSStatusBarButton) {
        let menu = NSMenu()
        let copy = NSMenuItem(title: "Copia link del brano", action: #selector(MenuTarget.copyLink), keyEquivalent: "")
        copy.isEnabled = controller.shareURL != nil
        let settingsItem = NSMenuItem(title: "Impostazioni…", action: #selector(MenuTarget.openSettings), keyEquivalent: ",")
        let quit = NSMenuItem(title: "Esci da Atollo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp

        let target = MenuTarget(
            copyLink: { [weak self] in
                guard let url = self?.controller.shareURL else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            },
            openSettings: { [weak self] in self?.openSettings() }
        )
        for item in [copy, settingsItem] { item.target = target }
        menu.autoenablesItems = false
        menu.items = [copy, .separator(), settingsItem, quit]
        // Il target va tenuto vivo finché il menu è aperto.
        objc_setAssociatedObject(menu, &MenuTarget.key, target, .OBJC_ASSOCIATION_RETAIN)

        // Sotto Atollo, allineato al suo bordo sinistro, come i menu delle altre icone.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }
}

/// Il contenuto dentro il pulsante della barra: solo da guardare, i click vanno al pulsante.
private final class IslandHostingView: NSHostingView<IslandView> {
    /// Il pulsante è passato alla finestra della barra di un altro monitor.
    var onWindowChange: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?()
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

private final class MenuTarget: NSObject {
    nonisolated(unsafe) static var key: UInt8 = 0
    private let copyLinkAction: () -> Void
    private let openSettingsAction: () -> Void

    init(copyLink: @escaping () -> Void, openSettings: @escaping () -> Void) {
        copyLinkAction = copyLink
        openSettingsAction = openSettings
    }

    @objc func copyLink() { copyLinkAction() }
    @objc func openSettings() { openSettingsAction() }
}
