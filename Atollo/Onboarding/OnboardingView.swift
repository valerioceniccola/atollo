import ServiceManagement
import SwiftUI

/// Schermata di intro al primo avvio: logo, cosa fa Atollo, aspetto dell'isola, permessi da concedere.
/// Le finestre di sistema compaiono solo quando l'utente preme "Concedi".
struct OnboardingView: View {
    let permissions: PermissionsCenter
    let onFinish: () -> Void

    @AppStorage(SettingsKey.openAtLogin) private var openAtLogin = false
    @AppStorage(SettingsKey.islandAppearance) private var appearance = IslandAppearance.dark

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                AtolloLogo()
                    .frame(width: Theme.Onboarding.logoSize, height: Theme.Onboarding.logoSize)
                Text("Benvenuto in Atollo")
                    .font(.system(size: 26, weight: .bold))
                Text("Il brano di Spotify in una piccola isola nella barra dei menu: copertina, titolo e artista sempre a colpo d'occhio, e i tasti multimediali che vanno solo a Spotify.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Aspetto")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(IslandAppearance.allCases) { option in
                        AppearanceOption(appearance: option, isSelected: appearance == option) {
                            withAnimation(Theme.Motion.pause) { appearance = option }
                        }
                    }
                }
            }
            .padding(Theme.Onboarding.cardPadding)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 26)

            VStack(alignment: .leading, spacing: 12) {
                Text("Permessi")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                PermissionsList(center: permissions)
            }
            .padding(Theme.Onboarding.cardPadding)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 12)

            HStack {
                Toggle("Apri al login", isOn: $openAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: openAtLogin) { _, enabled in
                        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        openAtLogin = SMAppService.mainApp.status == .enabled
                    }
                Spacer()
                Button("Inizia", action: onFinish)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.top, 22)

            Text("Aspetto e permessi si cambiano anche dopo, dalle Impostazioni: click destro sull'isola.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 10)
        }
        .padding(Theme.Onboarding.padding)
        .frame(width: Theme.Onboarding.width)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Un riquadro con l'isola nell'aspetto scelto, sopra uno sfondo da scrivania.
private struct AppearanceOption: View {
    let appearance: IslandAppearance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let palette = appearance.palette
        let capsule = Capsule(style: .continuous)
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.55, green: 0.78, blue: 0.86), Color(red: 0.7, green: 0.66, blue: 0.93)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    HStack(spacing: Theme.Capsule.itemSpacing) {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: Theme.Capsule.artSize, height: Theme.Capsule.artSize)
                        TrackLineText(title: "Gravity", artist: "Coldplay")
                            .lineLimit(1)
                        EqualizerView(isPlaying: true, color: appearance == .dark ? .green : Color(red: 0.1, green: 0.55, blue: 0.25),
                                      height: Theme.Equalizer.height)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 21)
                    .background(palette.backdrop, in: capsule)
                    .glassEffect(.regular.tint(palette.glassTint), in: capsule)
                    .overlay(capsule.strokeBorder(palette.stroke, lineWidth: 0.5))
                    .environment(\.islandPalette, palette)
                    .environment(\.colorScheme, palette.colorScheme)
                }
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : .primary.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
                }
                Text(appearance.title)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

/// Il logo di Atollo: la sua icona (`Atollo.icon`, fatta con Icon Composer).
struct AtolloLogo: View {
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
    }
}

#Preview("Intro") {
    OnboardingView(permissions: PermissionsCenter(), onFinish: {})
}

#Preview("Logo") {
    AtolloLogo().frame(width: 128, height: 128).padding()
}
