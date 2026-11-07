import AppKit
import Observation
import SwiftUI

/// Stato di Atollo nella barra dei menu: contenuto e larghezza.
///
/// `presentation` e `closedWidth` dicono come deve essere; i valori `displayed…` come è disegnato adesso.
/// È `IslandManager` a portare i secondi verso i primi: la larghezza cambia di colpo insieme
/// all'elemento della barra (come tutte le icone), la comparsa con una dissolvenza.
@Observable
final class IslandModel {
    enum Presentation: Equatable { case hidden, visible }

    var geometry: IslandGeometry

    let nowPlaying: NowPlayingState
    let settings: AppSettings
    @ObservationIgnored let colors: EqualizerColorProvider?
    @ObservationIgnored weak var controller: SpotifyController?

    /// La barra dei menu ha il testo bianco: il tema Trasparente fa lo stesso.
    var isDarkMenuBar = true

    // MARK: Stato disegnato (lo aggiorna IslandManager)

    var displayedPresentation: Presentation = .hidden
    var displayedShapeSize: CGSize = .zero

    /// Per anteprime e impostazioni: forza uno stato senza elemento nella barra.
    var forcedPresentation: Presentation?

    init(geometry: IslandGeometry, nowPlaying: NowPlayingState, settings: AppSettings,
         colors: EqualizerColorProvider? = nil,
         controller: SpotifyController? = nil) {
        self.geometry = geometry
        self.nowPlaying = nowPlaying
        self.settings = settings
        self.colors = colors
        self.controller = controller
    }

    /// Visibile finché Spotify è aperto; se l'utente lo sceglie, solo mentre suona.
    var presentation: Presentation {
        if let forcedPresentation { return forcedPresentation }
        guard nowPlaying.isPresentable else { return .hidden }
        return settings.hidesWhenPaused && !nowPlaying.isPlaying ? .hidden : .visible
    }

    var renderedPresentation: Presentation { forcedPresentation ?? displayedPresentation }

    var renderedShapeSize: CGSize {
        forcedPresentation.map { shapeSize(for: $0) } ?? displayedShapeSize
    }

    // MARK: Testo ed equalizzatore

    var title: String { nowPlaying.track?.title ?? "Spotify" }

    /// Identità del brano e della copertina, per le transizioni al cambio.
    var trackID: String { nowPlaying.track.map { $0.uri.isEmpty ? $0.title : $0.uri } ?? "" }
    var artworkID: ObjectIdentifier? { nowPlaying.artwork.map(ObjectIdentifier.init) }
    var artist: String { nowPlaying.track?.artist ?? "" }

    var palette: Theme.Palette { settings.islandAppearance.palette(darkMenuBar: isDarkMenuBar) }

    var equalizerColor: Color { equalizerColor(for: palette) }

    /// Il colore scelto nelle Impostazioni, adattato a un aspetto (anche diverso da quello attuale,
    /// per le anteprime dei tre aspetti).
    func equalizerColor(for palette: Theme.Palette) -> Color {
        let color = colors?.nsColor(for: geometry.displayID, artworkColor: nowPlaying.artworkColor) ?? EqualizerColorChoice.blue.presetColor ?? .systemBlue
        guard palette.colorScheme == .light, var oklch = OKLCH(color) else { return Color(nsColor: color) }
        // I colori pensati per il nero sono chiari: con il testo scuro si scuriscono, stessa tinta.
        oklch.l = min(oklch.l, Theme.EqualizerColor.lightMaxLightness)
        oklch.c = max(oklch.c, Theme.EqualizerColor.lightMinChroma)
        return Color(nsColor: oklch.nsColor)
    }


    // MARK: Misure

    func shapeSize(for presentation: Presentation) -> CGSize {
        let height = geometry.capsuleHeight
        switch presentation {
        // Nascosta ha la stessa forma: compare e sparisce solo in dissolvenza.
        case .hidden, .visible: return CGSize(width: closedWidth, height: height)
        }
    }

    /// Margini ai lati del contenuto. Con la capsula la copertina è concentrica con l'estremità;
    /// senza capsula (Trasparente) niente margini: attorno basta la spaziatura di sistema, come per le altre icone.
    var leadingInset: CGFloat {
        palette.usesGlass ? geometry.contentInset + Theme.Capsule.extraLeadingInset : 0
    }

    var trailingInset: CGFloat {
        palette.usesGlass ? geometry.contentInset + Theme.Capsule.extraTrailingInset : 0
    }

    /// L'avviso compare con la ripetizione accesa, se l'utente lo vuole.
    var showsRepeatIcon: Bool { settings.showsRepeatIndicator && nowPlaying.isRepeating }

    /// Spazio dell'avviso di ripetizione, quando c'è.
    private var repeatWidth: CGFloat {
        showsRepeatIcon ? Theme.Capsule.repeatSpacing + Theme.Capsule.repeatIconWidth : 0
    }

    /// Il tratto dell'elemento su cui un clic spegne la ripetizione, invece di aprire Spotify:
    /// l'icona più metà dello spazio ai suoi lati.
    var repeatHitRange: ClosedRange<CGFloat>? {
        guard showsRepeatIcon else { return nil }
        let start = leadingInset + Theme.Capsule.artSize + Theme.Capsule.repeatSpacing / 2
        return start...(start + Theme.Capsule.repeatSpacing / 2 + Theme.Capsule.repeatIconWidth + Theme.Capsule.artTextSpacing / 2)
    }

    /// In pausa (o senza brano) l'isola si stringe a copertina e barre.
    var isCompact: Bool { !nowPlaying.isPlaying || nowPlaying.track == nil }

    /// Larghezza della capsula: compatta in pausa, altrimenti segue il testo fino alla massima.
    var closedWidth: CGFloat {
        let padding = leadingInset + trailingInset + repeatWidth
        if isCompact {
            return (padding + Theme.Capsule.artSize + Theme.Capsule.compactSpacing + EqualizerView.width).rounded(.up)
        }
        let fixed = padding + Theme.Capsule.artSize + EqualizerView.width
            + Theme.Capsule.artTextSpacing + Theme.Capsule.textEqualizerSpacing
        // Se il testo ci sta non scorre e non ha sfumature: basta un punto di margine per gli arrotondamenti.
        let ideal = fixed + textWidth + 1
        return min(ideal, Theme.Capsule.maxWidth).rounded(.up)
    }

    private var textWidth: CGFloat {
        let text = NSMutableAttributedString(string: title, attributes: [.font: Theme.Typography.nsClosedTitle])
        if !artist.isEmpty {
            text.append(NSAttributedString(string: Theme.Typography.separator + artist,
                                           attributes: [.font: Theme.Typography.nsClosedArtist]))
        }
        return ceil(text.size().width)
    }
}
