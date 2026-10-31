import Foundation
import ScriptingBridge

// Interfaccia ScriptingBridge di Spotify, dal suo dizionario AppleScript (`sdef /Applications/Spotify.app`).
// SBApplication risolve questi selettori a runtime.

@objc nonisolated enum SpotifyPlayerState: AEKeyword {
    case stopped = 0x6B50_5353 // 'kPSS'
    case playing = 0x6B50_5350 // 'kPSP'
    case paused = 0x6B50_5370  // 'kPSp'
}

@objc nonisolated protocol SpotifyTrackScripting {
    @objc optional var name: String { get }
    @objc optional var artist: String { get }
    @objc optional var album: String { get }
    @objc optional var artworkUrl: String { get }
    @objc optional var spotifyUrl: String { get }
}

@objc nonisolated protocol SpotifyApplicationScripting {
    @objc optional var currentTrack: SpotifyTrackScripting { get }
    @objc optional var playerState: SpotifyPlayerState { get }
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func previousTrack()
}

nonisolated extension SBObject: SpotifyTrackScripting {}
nonisolated extension SBApplication: SpotifyApplicationScripting {}
