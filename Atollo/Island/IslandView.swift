import SwiftUI

/// L'isola: una capsula di vetro scuro nella barra dei menu con copertina, "Titolo · Artista"
/// ed equalizzatore. Solo da guardare: l'unica interazione è il menu del click destro.
struct IslandView: View {
    let model: IslandModel

    var body: some View {
        // Forma e posizione arrivano già animate dal window controller (`withAnimation`).
        let presentation = model.renderedPresentation
        let size = model.renderedShapeSize
        let height = model.geometry.capsuleHeight
        let shape = Capsule(style: .continuous)
        let isPlaying = model.nowPlaying.isPlaying

        HStack(spacing: Theme.Capsule.itemSpacing) {
            Group {
                // Copertina e testo hanno un'identità per brano: al cambio entrano con una transizione.
                ZStack {
                    ArtworkView(image: model.nowPlaying.artwork, size: Theme.Capsule.artSize, radius: Theme.Capsule.artRadius)
                        .id(model.artworkID)
                        .transition(.opacity)
                }
                .animation(Theme.Motion.artworkChange, value: model.artworkID)

                // In pausa l'isola è compatta: niente testo, solo copertina e barre spente, affiancate.
                if !model.isCompact {
                    ZStack {
                        MarqueeText { TrackLineText(title: model.title, artist: model.artist) }
                            .id(model.trackID)
                            .transition(Theme.Motion.trackTextTransition)
                    }
                    .clipped()
                    .animation(Theme.Motion.trackChange, value: model.trackID)
                    .transition(.opacity.animation(Theme.Motion.compactText))
                }
            }

            EqualizerView(isPlaying: isPlaying, color: model.equalizerColor, height: Theme.Equalizer.height)
        }
        .padding(.horizontal, Theme.Capsule.horizontalInset)
        .frame(width: size.width, height: height)
        .animation(Theme.Motion.pause, value: isPlaying)
        // Vetro scuro con un velo nero sotto, sempre uguale: leggibile anche su sfondi chiari.
        .background(model.palette.backdrop, in: shape)
        .overlay(shape.strokeBorder(model.palette.stroke, lineWidth: 0.5))
        .glassEffect((model.palette.clearGlass ? Glass.clear : .regular).tint(model.palette.glassTint), in: shape)
        .animation(Theme.Motion.pause, value: model.palette)
        .clipShape(shape)
        .opacity(presentation == .hidden ? 0 : 1)
        .offset(x: model.renderedOffsetX)
        .padding(.top, model.geometry.topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.islandPalette, model.palette)
        .environment(\.colorScheme, model.palette.colorScheme)
    }
}

// MARK: - Anteprime

private struct IslandPreview: View {
    let model: IslandModel

    init(_ geometry: IslandGeometry, _ presentation: IslandModel.Presentation,
         title: String = "Blinding Lights", artist: String = "The Weeknd", status: PlaybackStatus = .playing) {
        model = IslandModel(geometry: geometry,
                            nowPlaying: .sample(title: title, artist: artist, status: status),
                            settings: AppSettings(defaults: UserDefaults(suiteName: "atollo.preview") ?? .standard))
        model.forcedPresentation = presentation
    }

    var body: some View {
        let window = model.windowSize
        ZStack(alignment: .top) {
            LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(.black.opacity(0.25))
                .frame(height: model.geometry.menuBarHeight)
            IslandView(model: model)
        }
        .frame(width: max(window.width + 120, 460), height: window.height + 30)
    }
}

#Preview("Nascosta") {
    IslandPreview(.studioDisplay, .hidden)
}

#Preview("Visibile") {
    IslandPreview(.studioDisplay, .visible)
}

#Preview("Testo lungo") {
    IslandPreview(.studioDisplay, .visible,
                  title: "Supercalifragilisticexpialidocious (Extended Orchestral Version)",
                  artist: "Julie Andrews, Dick Van Dyke")
}

#Preview("In pausa (compatta)") {
    IslandPreview(.studioDisplay, .visible, status: .paused)
}

#Preview("MacBook") {
    IslandPreview(.macBook, .visible, title: "Una canzone dal titolo molto lungo che non entra", artist: "Artista")
}
