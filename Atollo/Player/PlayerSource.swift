import Foundation

nonisolated enum PlaybackStatus: Equatable, Sendable {
    case stopped, playing, paused
}

nonisolated struct TrackInfo: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?
    /// URI del brano, ad esempio `spotify:track:4uLU6hMCjMI75M1A2tKUQC`.
    var uri: String
}

nonisolated struct PlayerSnapshot: Equatable, Sendable {
    var status: PlaybackStatus
    var track: TrackInfo?
}

/// Un'app che riproduce musica. Oggi c'è solo `SpotifySource`; il protocollo esiste
/// perché in futuro si possa aggiungere altro senza riscrivere il resto.
protocol PlayerSource: AnyObject {
    var bundleIdentifier: String { get }
    var isRunning: Bool { get }

    /// Chiamato sul main thread a ogni cambiamento. `nil` significa che il player non è aperto.
    var onSnapshot: ((PlayerSnapshot?) -> Void)? { get set }

    func start()
    func refresh()

    func playPause()
    func nextTrack()
    func previousTrack()

    /// Link condivisibile del brano (es. `https://open.spotify.com/track/…`).
    func shareURL(for track: TrackInfo) -> URL?
}
