import SwiftUI

extension EnvironmentValues {
    /// Colori dell'isola (aspetto scuro o chiaro).
    @Entry var islandPalette: Theme.Palette = .dark
}

// MARK: Copertina

struct ArtworkView: View {
    @Environment(\.islandPalette) private var palette
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        // Raggio pari a metà lato: cerchio vero (lo stile continuo lo deformerebbe).
        let shape = RoundedRectangle(cornerRadius: min(radius, size / 2),
                                     style: radius >= size / 2 ? .circular : .continuous)
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                shape.fill(palette.artworkPlaceholder)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        // Un filo interno del colore del testo, come le copertine di Musica: invisibile di solito,
        // disegna il cerchio quando la copertina ha lo stesso colore dello sfondo (nera su nero, bianca su bianco).
        .overlay(shape.strokeBorder(palette.primaryText.opacity(Theme.Capsule.artStrokeOpacity),
                                    lineWidth: Theme.Capsule.artStrokeWidth))
    }
}

// MARK: Titolo · Artista

/// "Titolo · Artista": titolo semibold bianco, artista grigio secondario.
struct TrackLineText: View {
    @Environment(\.islandPalette) private var palette
    let title: String
    let artist: String

    var body: some View {
        let titleText = Text(title)
            .font(Theme.Typography.closedTitle)
            .foregroundStyle(palette.primaryText)
        if artist.isEmpty {
            titleText
        } else {
            let artistText = Text(Theme.Typography.separator + artist)
                .font(Theme.Typography.closedArtist)
                .foregroundStyle(palette.secondaryText)
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
        EqualizerBars(isPlaying: isPlaying, color: NSColor(color), height: height)
            .opacity(isPlaying ? 1 : Theme.Equalizer.offOpacity)
            .animation(Theme.Equalizer.stateAnimation, value: isPlaying)
            .frame(width: Self.width, height: height)
    }
}

/// Le barre sono livelli Core Animation con animazioni ripetute: le muove il sistema grafico,
/// senza ridisegnare la vista a ogni fotogramma. Animarle da SwiftUI (TimelineView) ricalcolava
/// tutto Atollo fino a 120 volte al secondo: decine di punti di CPU mentre la musica suona.
private struct EqualizerBars: NSViewRepresentable {
    let isPlaying: Bool
    let color: NSColor
    let height: CGFloat

    func makeNSView(context: Context) -> EqualizerBarsView { EqualizerBarsView() }

    func updateNSView(_ view: EqualizerBarsView, context: Context) {
        view.update(isPlaying: isPlaying, color: color, height: height)
    }
}

private final class EqualizerBarsView: NSView {
    private var bars: [CALayer] = []
    private var isPlaying: Bool?
    private var height: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for _ in 0..<Theme.Equalizer.barCount {
            let bar = CALayer()
            bar.cornerRadius = Theme.Equalizer.barWidth / 2
            bar.cornerCurve = .continuous
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            let x = CGFloat(index) * (Theme.Equalizer.barWidth + Theme.Equalizer.barSpacing)
            bar.bounds = CGRect(x: 0, y: 0, width: Theme.Equalizer.barWidth, height: height)
            bar.position = CGPoint(x: x + Theme.Equalizer.barWidth / 2, y: bounds.midY)
        }
        CATransaction.commit()
    }

    func update(isPlaying: Bool, color: NSColor, height: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let cgColor = color.cgColor
        bars.forEach { $0.backgroundColor = cgColor }
        CATransaction.commit()
        if self.height != height {
            self.height = height
            needsLayout = true
        }
        guard self.isPlaying != isPlaying else { return }
        self.isPlaying = isPlaying
        for (index, bar) in bars.enumerated() { animate(bar, index: index, playing: isPlaying) }
    }

    /// In riproduzione ogni barra segue una sua sequenza di altezze casuali e ricomincia dopo qualche
    /// secondo, con durate diverse per barra: il ritorno non si nota. In pausa scende piano
    /// al livello spento e resta ferma.
    private func animate(_ bar: CALayer, index: Int, playing: Bool) {
        let key = "transform.scale.y"
        let current = (bar.presentation()?.value(forKeyPath: key) as? CGFloat) ?? Theme.Equalizer.offLevels[index]
        bar.removeAllAnimations()
        guard playing else {
            let settle = CABasicAnimation(keyPath: key)
            settle.fromValue = current
            settle.toValue = Theme.Equalizer.offLevels[index]
            settle.duration = 0.3
            settle.timingFunction = CAMediaTimingFunction(name: .easeOut)
            bar.setValue(Theme.Equalizer.offLevels[index], forKeyPath: key)
            bar.add(settle, forKey: "settle")
            return
        }
        // Sequenza chiusa: l'ultimo valore è uguale al primo, così il giro riparte senza scatto.
        let steps = Theme.Equalizer.decorativeSteps
        var levels = (0..<steps).map { _ in
            CGFloat.random(in: Theme.Equalizer.decorativeLow...1)
        }
        levels.append(levels[0])
        let pulse = CAKeyframeAnimation(keyPath: key)
        pulse.values = levels
        pulse.calculationMode = .cubic
        pulse.duration = Theme.Equalizer.decorativeLoopDurations[index]
        pulse.repeatCount = .infinity
        pulse.beginTime = CACurrentMediaTime() - Double.random(in: 0..<pulse.duration)
        // Altezza "a riposo" sotto l'animazione: è quella che si vede nella copia ferma che macOS
        // mostra sulla barra degli altri monitor (una foto di Atollo, senza animazioni).
        bar.setValue(Theme.Equalizer.stillLevels[index], forKeyPath: key)
        bar.add(pulse, forKey: "pulse")
    }
}
