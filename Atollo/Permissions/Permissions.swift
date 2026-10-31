import AppKit
import ApplicationServices
import Observation

/// Stato di un permesso come lo mostra la lista: "Concesso", "Non concesso", o da verificare.
enum PermissionStatus: Equatable {
    case granted
    case notGranted
    /// Il sistema non l'ha ancora chiesto: "Concedi" mostra la sua finestra.
    case notDetermined
    /// Non verificabile adesso (l'Automazione richiede Spotify aperto).
    case unavailable
}

enum AccessibilityPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// La finestra di sistema compare solo la prima volta; dopo si va dritti in Impostazioni di Sistema.
    static func request() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: SettingsKey.didPromptAccessibility) else {
            openSystemSettings()
            return
        }
        defaults.set(true, forKey: SettingsKey.didPromptAccessibility)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Permesso di Automazione (Apple Event) verso Spotify.
nonisolated enum AutomationPermission {
    /// Interroga il sistema; con `ask` mostra la sua finestra se serve. Blocca: mai sul main thread.
    static func status(ask: Bool) -> PermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: SpotifySource.bundleID)
        guard let desc = target.aeDesc else { return .unavailable }
        switch AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, ask) {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .notGranted
        case OSStatus(errAEEventWouldRequireUserConsent): return .notDetermined
        default: return .unavailable // procNotFound: Spotify chiuso
        }
    }

    @MainActor static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Tiene aggiornato lo stato dei permessi mentre una schermata li mostra.
@Observable
final class PermissionsCenter {
    private(set) var accessibility: PermissionStatus = .notDetermined
    private(set) var automation: PermissionStatus = .unavailable
    private(set) var isSpotifyInstalled = true
    private(set) var isRequestingAutomation = false

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var watchers = 0
    @ObservationIgnored private let queue = DispatchQueue(label: "com.valerioceniccola.atollo.permissions")

    /// Chi mostra la lista chiama `startWatching` alla comparsa e `stopWatching` alla scomparsa.
    func startWatching() {
        watchers += 1
        refresh()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopWatching() {
        watchers = max(watchers - 1, 0)
        guard watchers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let trusted = AccessibilityPermission.isTrusted
        let prompted = UserDefaults.standard.bool(forKey: SettingsKey.didPromptAccessibility)
        set(\.accessibility, trusted ? .granted : (prompted ? .notGranted : .notDetermined))
        set(\.isSpotifyInstalled, NSWorkspace.shared.urlForApplication(withBundleIdentifier: SpotifySource.bundleID) != nil)

        guard !isRequestingAutomation else { return }
        queue.async { [weak self] in
            let status = AutomationPermission.status(ask: false)
            DispatchQueue.main.async { self?.set(\.automation, status) }
        }
    }

    // MARK: Azioni

    func requestAccessibility() {
        AccessibilityPermission.request()
        refresh()
    }

    func requestAutomation() {
        guard !isRequestingAutomation else { return }
        isRequestingAutomation = true
        queue.async { [weak self] in
            let status = AutomationPermission.status(ask: true)
            DispatchQueue.main.async {
                self?.isRequestingAutomation = false
                self?.set(\.automation, status)
            }
        }
    }

    func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SpotifySource.bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func set<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<PermissionsCenter, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
}
