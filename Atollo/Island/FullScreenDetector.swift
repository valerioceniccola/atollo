import AppKit
import Observation

/// Dice su quali schermi c'è un'app a schermo intero (video, giochi, Spazi a schermo intero).
/// Lì la barra dei menu si nasconde e Atollo con lei. La barra non avvisa quando si nasconde:
/// si guarda se una finestra copre tutto lo schermo quando cambiano Spazio o app, e ogni pochi secondi
/// per i giochi che passano a schermo intero solo a caricamento finito.
@Observable
final class FullScreenDetector {
    private(set) var fullScreenDisplays: Set<CGDirectDisplayID> = []

    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var pollTimer: Timer?

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            observe(workspace, name)
        }
        observe(.default, NSApplication.didChangeScreenParametersNotification)

        let timer = Timer(timeInterval: Theme.Capsule.fullScreenPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        refresh()
    }

    func isFullScreen(_ screen: NSScreen) -> Bool {
        screen.displayID.map(fullScreenDisplays.contains) ?? false
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRefresh() }
        }
        observers.append((center, token))
    }

    /// Subito e di nuovo a transizione finita: durante l'animazione dello Spazio le finestre
    /// non sono ancora al loro posto.
    private func scheduleRefresh() {
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Capsule.fullScreenSettleDelay) { [weak self] in
            self?.refresh()
        }
    }

    private func refresh() {
        let displays = Self.coveredDisplays()
        if displays != fullScreenDisplays { fullScreenDisplays = displays }
    }

    /// Schermi coperti per intero da una finestra di un'app, a qualsiasi livello: i giochi (anche quelli
    /// avviati con CrossOver) mettono la loro finestra sopra la barra dei menu.
    /// Bastano posizione, livello e proprietario: niente permesso di registrazione dello schermo.
    private static func coveredDisplays() -> Set<CGDirectDisplayID> {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[CFString: Any]] else { return [] }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let screens = NSScreen.screens.compactMap { screen in
            screen.displayID.map { ($0, CGDisplayBounds($0)) }
        }

        var covered = Set<CGDirectDisplayID>()
        for window in windows {
            // Le finestre invisibili (sovrapposizioni trasparenti di alcune app) non contano.
            guard let layer = window[kCGWindowLayer] as? Int, layer >= 0,
                  (window[kCGWindowAlpha] as? Double ?? 1) > 0,
                  let pid = window[kCGWindowOwnerPID] as? Int32, pid != ownPID,
                  let owner = window[kCGWindowOwnerName] as? String, !systemOwners.contains(owner),
                  let boundsInfo = window[kCGWindowBounds],
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo as! CFDictionary) else { continue }
            for (id, frame) in screens where bounds.insetBy(dx: -1, dy: -1).contains(frame) {
                covered.insert(id)
            }
        }
        return covered
    }

    /// Processi di sistema con finestre grandi quanto lo schermo che non sono schermo intero.
    private static let systemOwners: Set<String> = ["Dock", "Window Server", "WindowManager", "Control Center",
                                                    "Centro di Controllo", "Notification Center", "Centro Notifiche"]
}
