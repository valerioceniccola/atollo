import AppKit
import ImageIO
import Observation
import SwiftUI

/// Decide il colore dell'equalizzatore per ogni schermo secondo le impostazioni.
/// In automatico lo ricava dallo sfondo della scrivania di quello schermo.
@Observable
final class EqualizerColorProvider {
    private var wallpaperColors: [CGDirectDisplayID: NSColor] = [:]
    private var accent: NSColor = .controlAccentColor.resolved(for: .darkAqua)

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var wallpaperURLs: [CGDirectDisplayID: URL] = [:]
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var pollTimer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.refreshWallpapers(force: false) }
        observe(.default, NSApplication.didChangeScreenParametersNotification) { $0.refreshWallpapers(force: false) }
        observe(.default, NSColor.systemColorsDidChangeNotification) { $0.refreshAccent() }

        let timer = Timer(timeInterval: Theme.EqualizerColor.wallpaperPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshWallpapers(force: false) }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        refreshAccent()
        refreshWallpapers(force: true)
    }

    func color(for displayID: CGDirectDisplayID?, artworkColor: NSColor? = nil) -> Color {
        Color(nsColor: nsColor(for: displayID, artworkColor: artworkColor))
    }

    /// `artworkColor` è il colore della copertina in riproduzione: se manca (copertina quasi grigia)
    /// si ripiega sullo sfondo della scrivania.
    func nsColor(for displayID: CGDirectDisplayID?, artworkColor: NSColor? = nil) -> NSColor {
        switch settings.equalizerColor {
        case .artwork:
            if let artworkColor { return artworkColor }
            fallthrough
        case .automatic:
            if let displayID, let color = wallpaperColors[displayID] { return color }
            return Self.readable(accent)
        case .accent:
            return accent
        default:
            return settings.equalizerColor.presetColor ?? accent
        }
    }

    // MARK: Aggiornamenti

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ action: @escaping (EqualizerColorProvider) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        }
        observers.append((center, token))
    }

    private func refreshAccent() {
        accent = NSColor.controlAccentColor.resolved(for: .darkAqua)
    }

    private func refreshWallpapers(force: Bool) {
        var current: [CGDirectDisplayID: URL] = [:]
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let url = NSWorkspace.shared.desktopImageURL(for: screen) else { continue }
            current[id] = url
        }
        guard force || current != wallpaperURLs else { return }
        wallpaperURLs = current

        let known = Set(current.keys)
        wallpaperColors = wallpaperColors.filter { known.contains($0.key) }

        for (id, url) in current {
            Task.detached(priority: .utility) {
                let color = DominantColorExtractor.dominantColor(of: url)
                await MainActor.run { [weak self] in
                    guard let self, self.wallpaperURLs[id] == url else { return }
                    if let color { self.wallpaperColors[id] = color } else { self.wallpaperColors[id] = nil }
                }
            }
        }
    }

    private static func readable(_ color: NSColor) -> NSColor {
        OKLCH(color)?.readableOnBlack().nsColor ?? color
    }
}

/// Colore dominante di un'immagine (sfondo della scrivania o copertina), reso leggibile sul nero.
nonisolated enum DominantColorExtractor {
    static func dominantColor(of url: URL) -> NSColor? {
        thumbnail(of: url).flatMap(dominantColor(in:))
    }

    static func dominantColor(of image: NSImage) -> NSColor? {
        image.cgImage(forProposedRect: nil, context: nil, hints: nil).flatMap(dominantColor(in:))
    }

    static func dominantColor(in image: CGImage) -> NSColor? {
        let side = Theme.EqualizerColor.thumbnailSize
        let width = min(image.width, side), height = min(image.height, side)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Istogramma per tinta, pesato per croma; i pixel quasi grigi o quasi neri non contano.
        let buckets = Theme.EqualizerColor.hueBuckets
        var weights = [Double](repeating: 0, count: buckets)
        var sums = [(l: Double, a: Double, b: Double)](repeating: (0, 0, 0), count: buckets)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let color = OKLCH(red: Double(pixels[index]) / 255,
                              green: Double(pixels[index + 1]) / 255,
                              blue: Double(pixels[index + 2]) / 255)
            guard color.c >= Theme.EqualizerColor.grayChromaThreshold,
                  color.l >= Theme.EqualizerColor.darkLightnessThreshold else { continue }
            let bucket = min(Int(color.h / 360 * Double(buckets)), buckets - 1)
            let weight = color.c
            let radians = color.h * .pi / 180
            weights[bucket] += weight
            sums[bucket].l += color.l * weight
            sums[bucket].a += color.c * cos(radians) * weight
            sums[bucket].b += color.c * sin(radians) * weight
        }

        // Somma con le tinte vicine per non spezzare un colore a cavallo di due secchi.
        let scores = (0..<buckets).map { i in
            weights[i] + 0.5 * (weights[(i + buckets - 1) % buckets] + weights[(i + 1) % buckets])
        }
        guard let best = scores.indices.max(by: { scores[$0] < scores[$1] }), weights[best] > 0 else { return nil }

        let w = weights[best]
        let a = sums[best].a / w, b = sums[best].b / w
        var hue = atan2(b, a) * 180 / .pi
        if hue < 0 { hue += 360 }
        let dominant = OKLCH(l: sums[best].l / w, c: (a * a + b * b).squareRoot(), h: hue)
        return dominant.readableOnBlack().nsColor
    }

    private static func thumbnail(of url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Theme.EqualizerColor.thumbnailSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
