import AppKit
import Observation

/// Stato osservabile del brano in riproduzione, separato dalla UI.
@Observable
final class NowPlayingState {
    var isRunning = false
    var status: PlaybackStatus = .stopped
    var track: TrackInfo?
    var artwork: NSImage?
    /// Vero mentre l'isola va mostrata: cioè finché Spotify è aperto.
    var isPresentable = false

    var isPlaying: Bool { status == .playing }

    init() {}

    /// Stato fittizio per anteprime e impostazioni.
    static func sample(
        title: String = "Blinding Lights",
        artist: String = "The Weeknd",
        status: PlaybackStatus = .playing
    ) -> NowPlayingState {
        let state = NowPlayingState()
        state.isRunning = true
        state.status = status
        state.track = TrackInfo(title: title, artist: artist, album: "", artworkURL: nil,
                                uri: "spotify:track:0VjIjW4GlUZAMYd2vXMi3b")
        state.artwork = .sampleArtwork
        state.isPresentable = true
        return state
    }
}

/// Collega una `PlayerSource` allo stato osservabile e ne espone i comandi.
final class SpotifyController {
    let state = NowPlayingState()
    let source: PlayerSource

    private let artworkLoader = ArtworkLoader()

    init(source: PlayerSource = SpotifySource()) {
        self.source = source
        source.onSnapshot = { [weak self] in self?.apply($0) }
    }

    func start() {
        state.isRunning = source.isRunning
        source.start()
    }

    // MARK: Comandi

    func playPause() {
        // Risposta immediata nella UI; la notifica di Spotify conferma subito dopo.
        if state.isPlaying {
            state.status = .paused
        } else if state.track != nil {
            state.status = .playing
        }
        source.playPause()
    }

    func nextTrack() { source.nextTrack() }
    func previousTrack() { source.previousTrack() }

    var shareURL: URL? { state.track.flatMap(source.shareURL(for:)) }

    // MARK: Aggiornamenti

    private func apply(_ snapshot: PlayerSnapshot?) {
        guard let snapshot else {
            state.isRunning = false
            state.status = .stopped
            state.track = nil
            state.artwork = nil
            state.isPresentable = false
            return
        }

        state.isRunning = true
        if state.track?.uri != snapshot.track?.uri || state.track?.artworkURL != snapshot.track?.artworkURL {
            loadArtwork(for: snapshot.track)
        }
        state.track = snapshot.track
        state.status = snapshot.status
        updatePresentable()
    }

    /// L'isola resta visibile finché Spotify è aperto; in pausa l'equalizzatore si spegne.
    private func updatePresentable() {
        state.isPresentable = state.isRunning
    }

    private func loadArtwork(for track: TrackInfo?) {
        guard let url = track?.artworkURL else {
            state.artwork = nil
            return
        }
        Task {
            let image = await artworkLoader.image(for: url)
            if state.track?.artworkURL == url { state.artwork = image }
        }
    }
}

/// Scarica le copertine e tiene in memoria le più recenti.
final class ArtworkLoader {
    private var cache: [URL: NSImage] = [:]
    private var order: [URL] = []
    private let capacity = 24

    func image(for url: URL) async -> NSImage? {
        if let cached = cache[url] { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else { return nil }
        cache[url] = image
        order.append(url)
        if order.count > capacity { cache[order.removeFirst()] = nil }
        return image
    }
}

extension NSImage {
    /// Copertina finta per anteprime: sfumatura viola-arancio.
    static let sampleArtwork: NSImage = NSImage(size: NSSize(width: 120, height: 120), flipped: false) { rect in
        let gradient = NSGradient(colors: [.systemPurple, .systemPink, .systemOrange])
        gradient?.draw(in: rect, angle: -45)
        return true
    }
}
