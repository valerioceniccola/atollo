import AppKit

/// Un'isola per ogni schermo, ricreate quando cambiano gli schermi.
/// Gestisce anche il menu del click destro.
final class IslandManager {
    private let controller: SpotifyController
    private let settings: AppSettings
    private let colors: EqualizerColorProvider
    private let openSettings: () -> Void

    private var islands: [CGDirectDisplayID: IslandWindowController] = [:]
    private let anchor = MenuBarAnchor()
    private var isStarted = false
    private var screenObserver: NSObjectProtocol?

    init(controller: SpotifyController, settings: AppSettings, colors: EqualizerColorProvider,
         openSettings: @escaping () -> Void) {
        self.controller = controller
        self.settings = settings
        self.colors = colors
        self.openSettings = openSettings
    }

    func start() {
        rebuildIslands()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildIslands() }
        }
        anchor.onRightClick = { [weak self] button in self?.showMenu(at: button) }
        anchor.onLeftClick = { [weak self] in self?.controller.activateSpotify() }
        isStarted = true
        observeAnchor()
    }

    // MARK: Posizione nella barra dei menu

    /// L'isola si posa su un elemento vuoto della barra dei menu, a sinistra delle altre icone:
    /// così è macOS a darle il posto e a spostarla quando le icone cambiano.
    private func observeAnchor() {
        withObservationTracking {
            updateAnchor()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observeAnchor() }
        }
    }

    private func updateAnchor() {
        let frame = anchor.frame
        let host = islands.values.first { island in frame.map { island.screen.frame.intersects($0) } ?? false }
            ?? islands.values.first { $0.screen == NSScreen.main }
            ?? islands.values.first
        anchor.update(visible: controller.state.isPresentable && host != nil, width: host?.model.closedWidth ?? 0)

        for island in islands.values {
            let maxX = island === host ? anchor.frame?.maxX : nil
            if island.model.anchorMaxX != maxX { island.model.anchorMaxX = maxX }
        }
    }

    // MARK: Schermi

    private func rebuildIslands() {
        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            seen.insert(id)
            if let island = islands[id] {
                island.update(screen: screen)
            } else {
                let model = IslandModel(geometry: IslandGeometry(screen: screen), nowPlaying: controller.state,
                                        settings: settings, colors: colors,
                                        controller: controller)
                islands[id] = IslandWindowController(screen: screen, model: model)
            }
        }
        for (id, island) in islands where !seen.contains(id) {
            island.invalidate()
            islands[id] = nil
        }
        if isStarted { updateAnchor() }
    }

    // MARK: Menu del click destro

    private func showMenu(at button: NSStatusBarButton) {
        let menu = NSMenu()
        let copy = NSMenuItem(title: "Copia link del brano", action: #selector(MenuTarget.copyLink), keyEquivalent: "")
        copy.isEnabled = controller.shareURL != nil
        let settingsItem = NSMenuItem(title: "Impostazioni…", action: #selector(MenuTarget.openSettings), keyEquivalent: ",")

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
        menu.items = [copy, .separator(), settingsItem]
        // Il target va tenuto vivo finché il menu è aperto.
        objc_setAssociatedObject(menu, &MenuTarget.key, target, .OBJC_ASSOCIATION_RETAIN)

        // Sotto l'isola, allineato al suo bordo sinistro, come i menu delle altre icone.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
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
