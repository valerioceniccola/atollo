import AppKit

/// Colore nello spazio OKLCH (Björn Ottosson). L in 0…1, C ≈ 0…0.4, H in gradi.
nonisolated struct OKLCH: Equatable, Sendable {
    var l: Double
    var c: Double
    var h: Double

    init(l: Double, c: Double, h: Double) {
        self.l = l
        self.c = c
        self.h = h
    }

    /// Da sRGB con componenti 0…1 (gamma compresa).
    init(red: Double, green: Double, blue: Double) {
        let lab = OKLCH.linearToOKLab(OKLCH.toLinear(red), OKLCH.toLinear(green), OKLCH.toLinear(blue))
        l = lab.l
        c = (lab.a * lab.a + lab.b * lab.b).squareRoot()
        let hue = atan2(lab.b, lab.a) * 180 / .pi
        h = hue < 0 ? hue + 360 : hue
    }

    init?(_ color: NSColor) {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        self.init(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }

    /// Regola di leggibilità sul nero: luminosità minima e croma entro un intervallo.
    func readableOnBlack() -> OKLCH {
        OKLCH(
            l: max(l, Theme.EqualizerColor.minLightness),
            c: c.clamped(to: Theme.EqualizerColor.minChroma...Theme.EqualizerColor.maxChroma),
            h: h
        )
    }

    /// In sRGB; se fuori gamut riduce la croma finché il colore non rientra.
    var nsColor: NSColor {
        var chroma = c
        var rgb = srgb(chroma: chroma)
        while !Self.inGamut(rgb), chroma > 0 {
            chroma -= 0.005
            rgb = srgb(chroma: max(chroma, 0))
        }
        return NSColor(srgbRed: rgb.0.clamped(to: 0...1), green: rgb.1.clamped(to: 0...1),
                       blue: rgb.2.clamped(to: 0...1), alpha: 1)
    }

    // MARK: Conversioni

    private func srgb(chroma: Double) -> (Double, Double, Double) {
        let radians = h * .pi / 180
        let a = chroma * cos(radians)
        let b = chroma * sin(radians)

        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let lc = l_ * l_ * l_, mc = m_ * m_ * m_, sc = s_ * s_ * s_

        let r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc
        return (Self.toGamma(r), Self.toGamma(g), Self.toGamma(bl))
    }

    private static func linearToOKLab(_ r: Double, _ g: Double, _ b: Double) -> (l: Double, a: Double, b: Double) {
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (
            0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    private static func toLinear(_ v: Double) -> Double {
        v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    private static func toGamma(_ v: Double) -> Double {
        v <= 0.0031308 ? 12.92 * v : 1.055 * pow(max(v, 0), 1 / 2.4) - 0.055
    }

    private static func inGamut(_ rgb: (Double, Double, Double)) -> Bool {
        let range = -0.0005...1.0005
        return range.contains(rgb.0) && range.contains(rgb.1) && range.contains(rgb.2)
    }
}
