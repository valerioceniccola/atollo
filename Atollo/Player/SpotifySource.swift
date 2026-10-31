import AppKit
import ScriptingBridge

/// Legge lo stato di Spotify via ScriptingBridge e lo aggiorna a eventi
/// (notifica distribuita `com.spotify.client.PlaybackStateChanged`).
final class SpotifySource: PlayerSource {
    nonisolated static let bundleID = "com.spotify.client"

    let bundleIdentifier = SpotifySource.bundleID
    var onSnapshot: ((PlayerSnapshot?) -> Void)?

    private let bridge = SpotifyBridge()
    private var observers: [NSObjectProtocol] = []
    private var refreshGeneration = 0

    var isRunning: Bool { SpotifyBridge.isSpotifyRunning }

    func start() {
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil, queue: .main
        ) { [weak self] note in
            let state = note.userInfo?["Player State"] as? String
            MainActor.assumeIsolated {
                Log.spotify.info("PlaybackStateChanged: \(state ?? "?", privacy: .public)")
                self?.refresh()
                // Subito dopo la notifica Spotify a volte risponde ancora con lo stato precedente.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.refresh() }
            }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard Self.isSpotify(note) else { return }
            // Appena aperto Spotify non risponde subito agli Apple Event.
            MainActor.assumeIsolated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.refresh() }
            }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard Self.isSpotify(note) else { return }
            MainActor.assumeIsolated {
                self?.refreshGeneration += 1
                self?.onSnapshot?(nil)
            }
        })

        refresh()
    }

    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        bridge.fetchSnapshot { [weak self] snapshot in
            guard let self, generation == self.refreshGeneration else { return }
            Log.spotify.info("snapshot: \(String(describing: snapshot?.status), privacy: .public) \(snapshot?.track?.title ?? "-", privacy: .public)")
            self.onSnapshot?(snapshot)
        }
    }

    func playPause() { bridge.perform { $0.playpause?() } }
    func nextTrack() { bridge.perform { $0.nextTrack?() } }
    func previousTrack() { bridge.perform { $0.previousTrack?() } }

    func shareURL(for track: TrackInfo) -> URL? {
        Self.openSpotifyURL(fromURI: track.uri)
    }

    /// `spotify:track:ID` → `https://open.spotify.com/track/ID`. I file locali non hanno link.
    static func openSpotifyURL(fromURI uri: String) -> URL? {
        if uri.hasPrefix("https://open.spotify.com/") { return URL(string: uri) }
        let parts = uri.split(separator: ":").map(String.init)
        guard parts.count >= 3, parts[0] == "spotify", parts[1] != "local" else { return nil }
        let path = parts.dropFirst().joined(separator: "/")
        return URL(string: "https://open.spotify.com/\(path)")
    }

    private static func isSpotify(_ note: Notification) -> Bool {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        return app?.bundleIdentifier == bundleID
    }
}

/// Tutte le chiamate ScriptingBridge passano da una coda seriale: gli Apple Event
/// sono sincroni e non devono mai bloccare il main thread.
nonisolated private final class SpotifyBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.valerioceniccola.atollo.spotify", qos: .userInitiated)
    private var application: SBApplication?

    static var isSpotifyRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: SpotifySource.bundleID).isEmpty
    }

    /// SBApplication apre Spotify se gli si manda un evento mentre è chiuso: va sempre controllato prima.
    private func app() -> SpotifyApplicationScripting? {
        guard Self.isSpotifyRunning else { return nil }
        if application == nil {
            application = SBApplication(bundleIdentifier: SpotifySource.bundleID)
        }
        return application
    }

    func fetchSnapshot(_ completion: @escaping @MainActor (PlayerSnapshot?) -> Void) {
        queue.async { [self] in
            let snapshot = readSnapshot()
            DispatchQueue.main.async { completion(snapshot) }
        }
    }

    func perform(_ command: @escaping @Sendable (SpotifyApplicationScripting) -> Void) {
        queue.async { [self] in
            guard let app = app() else { return }
            command(app)
        }
    }

    private func readSnapshot() -> PlayerSnapshot? {
        guard let app = app() else { return nil }
        let status: PlaybackStatus
        switch app.playerState {
        case .playing: status = .playing
        case .paused: status = .paused
        case .stopped, .none: status = .stopped
        }
        guard status != .stopped, let track = app.currentTrack else {
            return PlayerSnapshot(status: status, track: nil)
        }
        let info = TrackInfo(
            title: track.name ?? "",
            artist: track.artist ?? "",
            album: track.album ?? "",
            artworkURL: track.artworkUrl.flatMap { URL(string: $0) },
            uri: track.spotifyUrl ?? ""
        )
        // Brano non ancora caricato: meglio non mostrare un'isola vuota.
        guard !info.title.isEmpty || !info.uri.isEmpty else {
            return PlayerSnapshot(status: .stopped, track: nil)
        }
        return PlayerSnapshot(status: status, track: info)
    }

}
