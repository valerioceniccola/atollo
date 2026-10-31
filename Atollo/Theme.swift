import AppKit
import SwiftUI

/// Tutte le costanti estetiche di Atollo. Niente numeri "magici" altrove.
nonisolated enum Theme {

    // MARK: Animazioni

    enum Motion {
        /// Molla principale stile Apple per apertura, chiusura e comparsa dell'isola.
        static let springResponse: Double = 0.45
        static let springDamping: Double = 0.85
        static var island: Animation { .spring(response: springResponse, dampingFraction: springDamping) }



        /// Quanto aspettare, dopo un'animazione di chiusura, prima di restringere la finestra.
        static let windowShrinkDelay: TimeInterval = 0.6

        /// Cambio brano: la copertina si dissolve nella nuova; il testo vecchio svanisce sul posto
        /// e il nuovo affiora con una leggera sfocatura e uno spostamento di pochi punti.
        static var trackChange: Animation { .easeInOut(duration: 0.4) }
        static var artworkChange: Animation { .easeInOut(duration: 0.35) }
        @MainActor static var trackTextTransition: AnyTransition {
            .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 3)).combined(with: AnyTransition(.blurReplace))
                    .animation(.easeOut(duration: 0.35).delay(0.12)),
                removal: .opacity.animation(.easeIn(duration: 0.18))
            )
        }
        static var pause: Animation { .easeInOut(duration: 0.3) }
    }

    // MARK: Isola (comune)

    enum Island {
        /// Vetro nativo (Liquid Glass) scurito, con un velo nero sotto per la leggibilità.
        static let glassTint = Color.black.opacity(0.7)
        static let backdrop = Color.black.opacity(0.55)
        /// Margine trasparente attorno all'isola nella finestra.
        static let windowMargin: CGFloat = 4
        /// In pausa tutta l'isola si fa appena più discreta.
        static let pausedOpacity: Double = 0.82
        /// In pausa copertina e testo si attenuano.
        static let pausedContentOpacity: Double = 0.55
        /// Scala dell'isola nascosta (compare crescendo dal suo centro).
        static let hiddenScale: CGFloat = 0.6
    }

    // MARK: Capsula nella barra dei menu

    enum Capsule {
        /// Altezza della capsula rispetto alla barra dei menu, con un tetto per le barre alte dei MacBook.
        /// Lascia respiro sopra e sotto rispetto alla barra.
        static let heightRatio: CGFloat = 0.7
        static let minHeight: CGFloat = 18
        static let maxHeight: CGFloat = 24
        static let fallbackMenuBarHeight: CGFloat = 24

        /// Si adatta al testo tra queste due misure; oltre, il testo scorre.
        static let minWidth: CGFloat = 200
        static let maxWidth: CGFloat = 300
        /// Spazio lasciato attorno all'isola tra le altre icone della barra dei menu.
        static let menuBarItemPadding: CGFloat = 4
        /// Distanza minima dai bordi dello schermo.
        static let screenEdgeInset: CGFloat = 8

        static let artSize: CGFloat = 14
        static let artRadius: CGFloat = 4
        static let itemSpacing: CGFloat = 7

    }

    // MARK: Testo

    enum Typography {
        static let closedSize: CGFloat = 12
        static let separator = " · "

        static var closedTitle: Font { .system(size: closedSize, weight: .semibold) }
        static var closedArtist: Font { .system(size: closedSize, weight: .regular) }

        static var nsClosedTitle: NSFont { .systemFont(ofSize: closedSize, weight: .semibold) }
        static var nsClosedArtist: NSFont { .systemFont(ofSize: closedSize, weight: .regular) }
    }

    // MARK: Marquee

    enum Marquee {
        /// Punti al secondo.
        static let speed: CGFloat = 28
        static let pause: TimeInterval = 1.5
        static let fadeWidth: CGFloat = 10
    }

    // MARK: Equalizzatore

    enum Equalizer {
        static let barCount = 4
        static let barWidth: CGFloat = 2.5
        static let barSpacing: CGFloat = 2
        static let height: CGFloat = 12
        static let minLevel: CGFloat = 0.18
        /// In pausa l'equalizzatore è spento: barre basse e sbiadite.
        static let offLevels: [CGFloat] = [0.2, 0.2, 0.2, 0.2]
        static let offOpacity: Double = 0.4
        /// Animazione decorativa: velocità (rad/s) e fasi per barra.
        static let decorativeSpeeds: [Double] = [7.1, 9.3, 6.2, 8.4]
        static let decorativeSecondarySpeeds: [Double] = [3.3, 2.1, 4.4, 2.7]
        static let decorativePhases: [Double] = [0, 1.7, 3.1, 4.6]
        static var stateAnimation: Animation { .spring(response: 0.4, dampingFraction: 0.8) }
    }


    // MARK: Colori

    enum Colors {
        static let primaryText = Color.white
        static let secondaryText = Color.white.opacity(0.7)
        static let artworkPlaceholder = Color.white.opacity(0.14)
    }

    // MARK: Colore dell'equalizzatore (automatico)

    enum EqualizerColor {
        static let minLightness: Double = 0.75
        static let minChroma: Double = 0.08
        static let maxChroma: Double = 0.16
        /// Pixel scartati perché quasi grigi o quasi neri (spazio OKLCH).
        static let grayChromaThreshold: Double = 0.035
        static let darkLightnessThreshold: Double = 0.22
        static let thumbnailSize: Int = 64
        static let hueBuckets = 24
        /// Controllo periodico dello sfondo (non esiste una notifica pubblica).
        static let wallpaperPollInterval: TimeInterval = 15
        static let swatchSize: CGFloat = 20
    }

    // MARK: Impostazioni

    enum Settings {
        static let windowWidth: CGFloat = 460
        static let previewHeight: CGFloat = 48
    }
}
