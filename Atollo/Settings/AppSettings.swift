import AppKit
import Observation

enum SettingsKey {
    static let mediaKeysOnlySpotify = "mediaKeysOnlySpotify"
    static let equalizerColor = "equalizerColor"
    static let islandAppearance = "islandAppearance"
    static let openAtLogin = "openAtLogin"
    static let didPromptAccessibility = "didPromptAccessibility"
    static let didCompleteOnboarding = "didCompleteOnboarding"
}

enum IslandAppearance: String, CaseIterable, Identifiable {
    case dark, light
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dark: "Scuro"
        case .light: "Chiaro"
        }
    }
    var palette: Theme.Palette { self == .dark ? .dark : .light }
}

enum EqualizerColorChoice: String, CaseIterable, Identifiable {
    case automatic, accent, blue, purple, pink, red, orange, yellow, green, graphite, white

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatico (dallo sfondo)"
        case .accent: "Accento di sistema"
        case .blue: "Blu"
        case .purple: "Viola"
        case .pink: "Rosa"
        case .red: "Rosso"
        case .orange: "Arancione"
        case .yellow: "Giallo"
        case .green: "Verde"
        case .graphite: "Grafite"
        case .white: "Bianco"
        }
    }

    /// Colore fisso (variante per l'aspetto scuro); `nil` per automatico e accento.
    var presetColor: NSColor? {
        let base: NSColor
        switch self {
        case .automatic, .accent: return nil
        case .blue: base = .systemBlue
        case .purple: base = .systemPurple
        case .pink: base = .systemPink
        case .red: base = .systemRed
        case .orange: base = .systemOrange
        case .yellow: base = .systemYellow
        case .green: base = .systemGreen
        case .graphite: base = .systemGray
        case .white: return .white
        }
        return base.resolved(for: .darkAqua)
    }
}

extension NSColor {
    /// Il colore dinamico risolto per un aspetto preciso, in sRGB.
    func resolved(for appearanceName: NSAppearance.Name) -> NSColor {
        var result = self
        NSAppearance(named: appearanceName)?.performAsCurrentDrawingAppearance {
            result = self.usingColorSpace(.sRGB) ?? self
        }
        return result
    }
}

/// Impostazioni lette da `UserDefaults` (le stesse chiavi usate da `@AppStorage`
/// nella finestra Impostazioni), osservabili dal resto dell'app.
@Observable
final class AppSettings {
    private(set) var mediaKeysOnlySpotify = true
    private(set) var equalizerColor = EqualizerColorChoice.automatic
    private(set) var islandAppearance = IslandAppearance.dark

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observer: NSObjectProtocol?

    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            SettingsKey.mediaKeysOnlySpotify: true,
            SettingsKey.equalizerColor: EqualizerColorChoice.automatic.rawValue,
            SettingsKey.islandAppearance: IslandAppearance.dark.rawValue,
            SettingsKey.openAtLogin: false,
        ])
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.registerDefaults(defaults)
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    private func reload() {
        let mediaKeys = defaults.bool(forKey: SettingsKey.mediaKeysOnlySpotify)
        if mediaKeys != mediaKeysOnlySpotify { mediaKeysOnlySpotify = mediaKeys }

        let color = EqualizerColorChoice(rawValue: defaults.string(forKey: SettingsKey.equalizerColor) ?? "") ?? .automatic
        if color != equalizerColor { equalizerColor = color }

        let appearance = IslandAppearance(rawValue: defaults.string(forKey: SettingsKey.islandAppearance) ?? "") ?? .dark
        if appearance != islandAppearance { islandAppearance = appearance }
    }
}

nonisolated extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
