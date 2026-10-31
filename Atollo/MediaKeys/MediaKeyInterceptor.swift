import AppKit
import ApplicationServices
import Observation

/// Intercetta play/pausa, avanti e indietro della tastiera (eventi `NSSystemDefined`,
/// subtype 8) e li manda solo a Spotify, bloccando l'evento originale.
/// Attivo solo se l'impostazione è accesa e Spotify è aperto; altrimenti i tasti passano.
///
/// Le AirPods e le cuffie Bluetooth non generano questi eventi: i loro comandi arrivano
/// da MediaRemote all'app "In riproduzione" (di solito Spotify stesso), quindi qui non si toccano.
final class MediaKeyInterceptor {
    private enum Key: Int32 {
        case play = 16      // NX_KEYTYPE_PLAY
        case next = 17      // NX_KEYTYPE_NEXT
        case previous = 18  // NX_KEYTYPE_PREVIOUS
        case fast = 19      // NX_KEYTYPE_FAST
        case rewind = 20    // NX_KEYTYPE_REWIND
    }

    private static let systemDefinedType: UInt32 = 14 // NX_SYSDEFINED
    private static let mediaKeySubtype: Int16 = 8

    private let controller: SpotifyController
    private let settings: AppSettings
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var trustTimer: Timer?

    init(controller: SpotifyController, settings: AppSettings) {
        self.controller = controller
        self.settings = settings
    }

    func start() {
        observeSettings()
    }

    private func observeSettings() {
        withObservationTracking {
            _ = settings.mediaKeysOnlySpotify
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observeSettings() }
        }
        settings.mediaKeysOnlySpotify ? enable() : disable()
    }

    // MARK: Event tap

    private func enable() {
        guard tap == nil else { return }
        Log.mediaKeys.info("enable, trusted=\(AccessibilityPermission.isTrusted, privacy: .public)")
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.requestIfNeeded()
            waitForTrust()
            return
        }
        trustTimer?.invalidate()
        trustTimer = nil

        let mask = CGEventMask(1) << CGEventMask(Self.systemDefinedType)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: mediaKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.mediaKeys.error("CGEvent.tapCreate fallito")
            waitForTrust()
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
    }

    private func disable() {
        trustTimer?.invalidate()
        trustTimer = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    /// Il permesso si concede in Impostazioni di Sistema: controlla finché non arriva.
    private func waitForTrust() {
        guard trustTimer == nil else { return }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AccessibilityPermission.isTrusted else { return }
                self.trustTimer?.invalidate()
                self.trustTimer = nil
                if self.settings.mediaKeysOnlySpotify { self.enable() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        trustTimer = timer
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == Self.systemDefinedType,
              settings.mediaKeysOnlySpotify, controller.source.isRunning,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == Self.mediaKeySubtype else {
            return Unmanaged.passUnretained(event)
        }

        let data = nsEvent.data1
        Log.mediaKeys.debug("tasto multimediale data1=\(data, privacy: .public)")
        guard let key = Key(rawValue: Int32((data & 0xFFFF_0000) >> 16)) else {
            return Unmanaged.passUnretained(event)
        }
        let flags = data & 0x0000_FFFF
        let isDown = ((flags & 0xFF00) >> 8) == 0x0A
        let isRepeat = (flags & 0x1) == 1

        if isDown, !isRepeat {
            switch key {
            case .play: controller.playPause()
            case .next, .fast: controller.nextTrack()
            case .previous, .rewind: controller.previousTrack()
            }
        }
        // Blocca sia la pressione sia il rilascio: il sistema non deve vederli.
        return nil
    }
}

nonisolated private func mediaKeyCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
    // Il tap è sul run loop principale.
    return MainActor.assumeIsolated { interceptor.handle(type: type, event: event) }
}

enum AccessibilityPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prima di mostrare la richiesta di sistema, spiega a cosa serve (una volta sola).
    static func requestIfNeeded() {
        guard !isTrusted else { return }
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: SettingsKey.didExplainAccessibility) {
            defaults.set(true, forKey: SettingsKey.didExplainAccessibility)
            let alert = NSAlert()
            alert.messageText = "Atollo vorrebbe usare i tasti multimediali"
            alert.informativeText = """
            Per mandare play/pausa, avanti e indietro della tastiera solo a Spotify, Atollo deve \
            poter leggere quei tasti. Serve il permesso Accessibilità: Atollo guarda solo i tasti \
            multimediali, mai quello che scrivi.

            Nella prossima finestra scegli "Apri Impostazioni di Sistema" e attiva Atollo in \
            Privacy e sicurezza → Accessibilità. Puoi anche spegnere la funzione nelle impostazioni di Atollo.
            """
            alert.addButton(withTitle: "Continua")
            alert.addButton(withTitle: "Non ora")
            NSApp.activate()
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
