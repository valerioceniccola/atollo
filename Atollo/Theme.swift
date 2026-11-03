import AppKit
import SwiftUI

/// Tutte le costanti estetiche di Atollo. Niente numeri "magici" altrove.
nonisolated enum Theme {

    // MARK: Animazioni

    enum Motion {
        /// Molla con cui il contenuto si allarga a barra ferma: un rimbalzo appena accennato.
        static var island: Animation { .spring(response: 0.3, dampingFraction: 0.72) }

        /// Comparsa e scomparsa (Spotify aperto o chiuso): dissolvenza morbida, sul posto.
        static let fadeDuration: TimeInterval = 0.2
        static var fade: Animation { .easeInOut(duration: fadeDuration) }

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
        /// Il testo sparisce in fretta quando l'isola si fa compatta.
        static var compactText: Animation { .easeInOut(duration: 0.2) }
        /// Quanto deve durare una pausa per essere mostrata (al cambio brano Spotify ne manda una finta).
        static let pauseConfirmDelay: TimeInterval = 0.6
    }

    // MARK: Isola (comune)

    enum Island {
        /// Vetro nativo (Liquid Glass) scurito, con un velo nero sotto per la leggibilità.
        static let glassTint = Color.black.opacity(0.7)
        static let backdrop = Color.black.opacity(0.9)
    }

    // MARK: Capsula nella barra dei menu

    enum Capsule {
        /// Altezza della capsula rispetto alla barra dei menu, con un tetto per le barre alte dei MacBook.
        /// Lascia respiro sopra e sotto rispetto alla barra.
        static let heightRatio: CGFloat = 0.7
        static let minHeight: CGFloat = 18
        static let maxHeight: CGFloat = 24
        static let fallbackMenuBarHeight: CGFloat = 24

        /// Quanto dura lo scivolamento con cui macOS riposiziona un elemento della barra che si allarga.
        static let menuBarSlideDuration: TimeInterval = 0.32
        /// Segue il testo fino a questa larghezza; oltre, il testo scorre.
        static let maxWidth: CGFloat = 270

        static let artSize: CGFloat = 14
        /// Copertina circolare: con lo stesso margine sopra, sotto e a sinistra è concentrica
        /// con l'estremità della capsula.
        static let artRadius: CGFloat = artSize / 2
        static let artStrokeWidth: CGFloat = 0.5
        static let artStrokeOpacity: Double = 0.15
        /// Sulla barra di un monitor non attivo, come le altre icone spente.
        static let inactiveMenuBarOpacity: CGFloat = 0.45
        static let itemSpacing: CGFloat = 7
        /// Con il testo: copertina un filo più staccata, equalizzatore un po' più vicino all'artista.
        static let artTextSpacing: CGFloat = 8.5
        static let textEqualizerSpacing: CGFloat = 5
        /// In pausa, tra copertina ed equalizzatore spento.
        static let compactSpacing: CGFloat = 8.5
        /// Margine aggiuntivo ai lati del contenuto, oltre a quello della copertina:
        /// appena un filo a sinistra, un po' di più a destra dopo l'equalizzatore.
        static let extraLeadingInset: CGFloat = 0.5
        static let extraTrailingInset: CGFloat = 3

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
        static let speed: CGFloat = 18
        static let pause: TimeInterval = 3
        static let fadeWidth: CGFloat = 10
    }

    // MARK: Equalizzatore

    enum Equalizer {
        static let barCount = 4
        static let barWidth: CGFloat = 2.5
        static let barSpacing: CGFloat = 2
        static let height: CGFloat = 12
        /// In pausa l'equalizzatore è spento: barre basse e sbiadite.
        static let offLevels: [CGFloat] = [0.2, 0.2, 0.2, 0.2]
        static let offOpacity: Double = 0.4
        /// Animazione decorativa: ogni barra segue altezze casuali tra il livello basso e il massimo,
        /// circa sei al secondo, e ricomincia dopo qualche secondo. Durate diverse per barra,
        /// così non si muovono mai insieme e il giro non si riconosce.
        static let decorativeLow: CGFloat = 0.25
        static let decorativeSteps = 28
        static let decorativeLoopDurations: [CFTimeInterval] = [4.7, 5.3, 4.3, 5.9]
        /// Barre ferme ma in riproduzione (copia sugli altri monitor): altezze diverse, come una foto.
        static let stillLevels: [CGFloat] = [0.55, 0.9, 0.45, 0.7]
        static var stateAnimation: Animation { .spring(response: 0.4, dampingFraction: 0.8) }
    }


    // MARK: Colori

    /// Colori dell'isola nei due aspetti: scuro (vetro nero, testo bianco) e chiaro (vetro chiaro, testo scuro).
    struct Palette: Equatable {
        var primaryText: Color
        var secondaryText: Color
        var artworkPlaceholder: Color
        var backdrop: Color
        var glassTint: Color
        /// Vetro trasparente (`Glass.clear`) invece di quello normale.
        var clearGlass: Bool
        /// Senza vetro (tema Trasparente): solo il contenuto, sulla barra.
        var usesGlass = true
        /// Filo sul bordo della capsula.
        var stroke: Color
        var colorScheme: ColorScheme

        static let dark = Palette(
            primaryText: .white,
            secondaryText: .white.opacity(0.7),
            artworkPlaceholder: .white.opacity(0.14),
            backdrop: Island.backdrop,
            glassTint: Island.glassTint,
            clearGlass: false,
            stroke: .clear,
            colorScheme: .dark
        )

        static let light = Palette(
            primaryText: Color(red: 0.11, green: 0.11, blue: 0.12),
            secondaryText: Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.6),
            artworkPlaceholder: .black.opacity(0.1),
            // Velo quasi bianco sotto il vetro, senza bordo come quello scuro.
            backdrop: .white.opacity(0.9),
            glassTint: .white.opacity(0.2),
            clearGlass: false,
            stroke: .clear,
            colorScheme: .light
        )

        /// Trasparente: niente capsula, solo il contenuto, con il colore del testo della barra dei menu.
        static let transparentOnDark = Palette(
            primaryText: .white,
            secondaryText: .white.opacity(0.7),
            artworkPlaceholder: .white.opacity(0.14),
            backdrop: .clear,
            glassTint: .clear,
            clearGlass: false,
            usesGlass: false,
            stroke: .clear,
            colorScheme: .dark
        )

        static let transparentOnLight = Palette(
            primaryText: light.primaryText,
            secondaryText: light.secondaryText,
            artworkPlaceholder: .black.opacity(0.1),
            backdrop: .clear,
            glassTint: .clear,
            clearGlass: false,
            usesGlass: false,
            stroke: .clear,
            colorScheme: .light
        )
    }

    // MARK: Colore dell'equalizzatore (automatico)

    enum EqualizerColor {
        /// Sull'isola chiara il colore va scurito per restare leggibile.
        static let lightMaxLightness: Double = 0.58
        static let lightMinChroma: Double = 0.1
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

    // MARK: Schermata di intro

    enum Onboarding {
        static let width: CGFloat = 500
        static let padding: CGFloat = 32
        static let cardPadding: CGFloat = 18
        /// Margine dentro i riquadri dell'aspetto, attorno alla capsula d'esempio.
        static let previewInset: CGFloat = 12
        static let logoSize: CGFloat = 96
        static let iconSize: CGFloat = 28
        static let rowSpacing: CGFloat = 16
    }

    // MARK: Impostazioni

    enum Settings {
        static let windowWidth: CGFloat = 460
        static let previewHeight: CGFloat = 48
    }
}
