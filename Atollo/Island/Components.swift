import SwiftUI

// MARK: Copertina

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                shape.fill(Theme.Colors.artworkPlaceholder)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }
}

// MARK: Titolo · Artista

/// "Titolo · Artista": titolo semibold bianco, artista grigio secondario.
struct TrackLineText: View {
    let title: String
    let artist: String

    var body: some View {
        let titleText = Text(title)
            .font(Theme.Typography.closedTitle)
            .foregroundStyle(Theme.Colors.primaryText)
        if artist.isEmpty {
            titleText
        } else {
            let artistText = Text(Theme.Typography.separator + artist)
                .font(Theme.Typography.closedArtist)
                .foregroundStyle(Theme.Colors.secondaryText)
            Text("\(titleText)\(artistText)")
        }
    }
}

// MARK: Marquee

/// Testo su una riga che, se non entra, scorre a sinistra fino alla fine, si ferma,
/// torna a destra, si ferma e ricomincia. Bordi sfumati con una mask.
struct MarqueeText<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    let content: Content

    @State private var contentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var fadesLeading = false

    init(alignment: HorizontalAlignment = .leading, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    private var overflow: CGFloat { max(contentWidth - containerWidth, 0) }
    private var isScrolling: Bool { overflow > 1 }

    var body: some View {
        // Il testo nascosto (troncato) dà solo altezza e spazio disponibile; quello vero, a misura
        // piena, sta in overlay: così non allarga mai il layout né spinge fuori gli altri elementi.
        content
            .lineLimit(1)
            .hidden()
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
            .overlay(alignment: isScrolling ? .leading : Alignment(horizontal: alignment, vertical: .center)) {
                content
                    .lineLimit(1)
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
                    .offset(x: offset)
            }
            .clipped()
            .mask { fadeMask }
            .task(id: ScrollKey(content: contentWidth, container: containerWidth)) { await scrollLoop() }
    }

    @ViewBuilder private var fadeMask: some View {
        if isScrolling {
            HStack(spacing: 0) {
                LinearGradient(colors: [fadesLeading ? .clear : .black, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Theme.Marquee.fadeWidth)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Theme.Marquee.fadeWidth)
            }
        } else {
            Rectangle()
        }
    }

    private func scrollLoop() async {
        offset = 0
        fadesLeading = false
        // Margine oltre la fine, così l'ultima lettera esce dalla sfumatura.
        let distance = overflow + Theme.Marquee.fadeWidth
        guard isScrolling else { return }
        let duration = Double(distance / Theme.Marquee.speed)

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Theme.Marquee.pause))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) { fadesLeading = true }
            withAnimation(.linear(duration: duration)) { offset = -distance }

            try? await Task.sleep(for: .seconds(duration + Theme.Marquee.pause))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: duration)) { offset = 0 }

            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) { fadesLeading = false }
        }
    }

    private struct ScrollKey: Equatable {
        var content: CGFloat
        var container: CGFloat
    }
}

// MARK: Equalizzatore

/// 4 barre arrotondate centrate in verticale, animate da sole mentre suona.
/// In pausa l'equalizzatore si spegne: barre basse e sbiadite, che scendono con una molla.
/// Non ascoltano l'audio: niente cattura, quindi niente indicatore viola di registrazione.
struct EqualizerView: View {
    let isPlaying: Bool
    let color: Color
    var height: CGFloat = Theme.Equalizer.height

    static var width: CGFloat {
        CGFloat(Theme.Equalizer.barCount) * Theme.Equalizer.barWidth
            + CGFloat(Theme.Equalizer.barCount - 1) * Theme.Equalizer.barSpacing
    }

    var body: some View {
        // Una sola vista per entrambi gli stati: così le barre scendono e risalgono animate.
        TimelineView(.animation(paused: !isPlaying)) { context in
            bars(isPlaying ? decorativeLevels(at: context.date) : Theme.Equalizer.offLevels)
        }
        .opacity(isPlaying ? 1 : Theme.Equalizer.offOpacity)
        .animation(Theme.Equalizer.stateAnimation, value: isPlaying)
        .frame(width: Self.width, height: height)
    }

    private func bars(_ values: [CGFloat]) -> some View {
        HStack(alignment: .center, spacing: Theme.Equalizer.barSpacing) {
            ForEach(0..<Theme.Equalizer.barCount, id: \.self) { index in
                let value = index < values.count ? values[index] : Theme.Equalizer.minLevel
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: Theme.Equalizer.barWidth,
                           height: max(Theme.Equalizer.barWidth, height * value.clamped(to: 0...1)))
            }
        }
        .frame(height: height)
    }

    private func decorativeLevels(at date: Date) -> [CGFloat] {
        let t = date.timeIntervalSinceReferenceDate
        return (0..<Theme.Equalizer.barCount).map { i in
            let primary = sin(t * Theme.Equalizer.decorativeSpeeds[i] + Theme.Equalizer.decorativePhases[i])
            let secondary = sin(t * Theme.Equalizer.decorativeSecondarySpeeds[i] + Theme.Equalizer.decorativePhases[i] * 2)
            return CGFloat(0.5 + 0.3 * primary + 0.15 * secondary)
        }
    }
}
