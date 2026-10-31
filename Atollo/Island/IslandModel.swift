import AppKit
import Observation
import SwiftUI

/// Stato di un'isola su uno schermo: forma e posizione. Col click sinistro non fa nulla;
/// il click destro apre il menu (lo gestisce `IslandManager`).
///
/// `presentation` e `shapeSize(for:)` dicono come l'isola *deve* essere;
/// i valori `displayed…` dicono come è disegnata adesso. È il window controller a portare
/// i secondi verso i primi, dentro `withAnimation`, dopo aver preparato la finestra:
/// così l'isola non viene mai tagliata né scatta mentre cambia forma.
@Observable
final class IslandModel {
    enum Presentation: Equatable { case hidden, visible }

    var geometry: IslandGeometry

    let nowPlaying: NowPlayingState
    let settings: AppSettings
    @ObservationIgnored let colors: EqualizerColorProvider?
    @ObservationIgnored weak var controller: SpotifyController?

    /// Bordo destro dell'elemento riservato nella barra dei menu, in coordinate globali.
    /// È il bordo che resta fermo quando l'elemento cambia larghezza: agganciando lì l'isola,
    /// un cambio di larghezza è una sola animazione verso sinistra, senza correzioni dopo.
    /// `nil` se l'elemento non è su questo schermo: allora l'isola qui non si mostra.
    var anchorMaxX: CGFloat?

    // MARK: Stato disegnato (lo aggiorna il window controller)

    var displayedPresentation: Presentation = .hidden
    var displayedShapeSize: CGSize = .zero
    /// Centro dell'isola disegnata e centro della finestra, in coordinate globali.
    var displayedMidX: CGFloat = 0
    var windowMidX: CGFloat = 0

    /// Per anteprime e impostazioni: forza uno stato senza finestra.
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

    /// Visibile finché Spotify è aperto, sullo schermo che ha l'elemento nella barra dei menu.
    var presentation: Presentation {
        if let forcedPresentation { return forcedPresentation }
        guard nowPlaying.isPresentable, anchorMaxX != nil else { return .hidden }
        return .visible
    }

    var renderedPresentation: Presentation { forcedPresentation ?? displayedPresentation }

    var renderedShapeSize: CGSize {
        forcedPresentation.map { shapeSize(for: $0) } ?? displayedShapeSize
    }

    /// Spostamento orizzontale dell'isola dentro la finestra.
    var renderedOffsetX: CGFloat { forcedPresentation == nil ? displayedMidX - windowMidX : 0 }

    /// Centro voluto in coordinate globali: a filo del bordo destro dell'elemento, senza uscire dallo schermo.
    func targetMidX(for presentation: Presentation) -> CGFloat {
        let width = shapeSize(for: presentation).width
        let anchor = anchorMaxX.map { $0 - Theme.Capsule.menuBarItemPadding - width / 2 } ?? geometry.screenFrame.midX
        let half = width / 2 + Theme.Capsule.screenEdgeInset
        let screen = geometry.screenFrame
        guard screen.width > 2 * half else { return screen.midX }
        return anchor.clamped(to: (screen.minX + half)...(screen.maxX - half))
    }

    // MARK: Testo ed equalizzatore

    var title: String { nowPlaying.track?.title ?? "Spotify" }

    /// Identità del brano e della copertina, per le transizioni al cambio.
    var trackID: String { nowPlaying.track.map { $0.uri.isEmpty ? $0.title : $0.uri } ?? "" }
    var artworkID: ObjectIdentifier? { nowPlaying.artwork.map(ObjectIdentifier.init) }
    var artist: String { nowPlaying.track?.artist ?? "" }

    var equalizerColor: Color {
        colors?.color(for: geometry.displayID) ?? Color(nsColor: EqualizerColorChoice.blue.presetColor ?? .systemBlue)
    }


    // MARK: Misure

    func shapeSize(for presentation: Presentation) -> CGSize {
        let height = geometry.capsuleHeight
        switch presentation {
        case .hidden: return CGSize(width: height, height: height)
        case .visible: return CGSize(width: closedWidth, height: height)
        }
    }

    /// Dimensione della finestra che contiene l'isola, compresi i margini.
    func windowSize(for presentation: Presentation) -> CGSize {
        let shape = shapeSize(for: presentation)
        let margin = Theme.Island.windowMargin
        return CGSize(
            width: (shape.width + 2 * margin).rounded(.up),
            height: (geometry.topInset + shape.height + margin).rounded(.up)
        )
    }

    /// Larghezza della capsula chiusa: segue il testo tra la minima e la massima.
    var closedWidth: CGFloat {
        let height = geometry.capsuleHeight
        let padding = (height - Theme.Capsule.artSize) / 2 + 1
        let fixed = 2 * padding + Theme.Capsule.artSize + EqualizerView.width + 2 * Theme.Capsule.itemSpacing
        let ideal = fixed + textWidth + Theme.Marquee.fadeWidth / 2
        return ideal.clamped(to: Theme.Capsule.minWidth...Theme.Capsule.maxWidth).rounded(.up)
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
