import ServiceManagement
import SwiftUI

/// Schermata di intro al primo avvio: logo, cosa fa Atollo, aspetto dell'isola, permessi da concedere.
/// Le finestre di sistema compaiono solo quando l'utente preme "Concedi".
struct OnboardingView: View {
    let permissions: PermissionsCenter
    let updater: Updater?
    let onFinish: () -> Void

    @AppStorage(SettingsKey.openAtLogin) private var openAtLogin = false
    @AppStorage(SettingsKey.islandAppearance) private var appearance = IslandAppearance.transparent
    @AppStorage(SettingsKey.capsuleAppearance) private var capsuleAppearance = IslandAppearance.dark

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                AtolloLogo()
                    .frame(width: Theme.Onboarding.logoSize, height: Theme.Onboarding.logoSize)
                Text("Benvenuto in Atollo")
                    .font(.system(size: 26, weight: .bold))
                Text("Il brano di Spotify nella barra dei menu: copertina, titolo e artista sempre a colpo d'occhio, e i tasti multimediali che vanno solo a Spotify.")
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
                            withAnimation(Theme.Motion.pause) {
                                appearance = option
                                if option != .transparent { capsuleAppearance = option }
                            }
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

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Apri al login", isOn: $openAtLogin)
                        .onChange(of: openAtLogin) { _, enabled in
                            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                            openAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    if let updater {
                        UpdateToggles(updater: updater)
                    }
                }
                .toggleStyle(.checkbox)
                Spacer()
                Button("Inizia", action: onFinish)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.top, 22)

            Text("Aspetto, permessi e aggiornamenti si cambiano anche dopo, dalle Impostazioni: click destro su Atollo nella barra dei menu.")
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
struct AppearanceOption: View {
    let appearance: IslandAppearance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let palette = appearance.palette()
        let capsule = Capsule(style: .continuous)
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.2, green: 0.36, blue: 0.48), Color(red: 0.34, green: 0.27, blue: 0.52)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    HStack(spacing: Theme.Capsule.itemSpacing) {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: Theme.Capsule.artSize, height: Theme.Capsule.artSize)
                        TrackLineText(title: "Gravity", artist: "")
                            .lineLimit(1)
                        EqualizerView(isPlaying: true, color: palette.colorScheme == .dark ? .green : Color(red: 0.1, green: 0.55, blue: 0.25),
                                      height: Theme.Equalizer.height)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 21)
                    .background(palette.backdrop, in: capsule)
                    .glassEffect(palette.usesGlass ? .regular.tint(palette.glassTint) : .identity, in: capsule)
                    .overlay(capsule.strokeBorder(palette.stroke, lineWidth: 0.5))
                    .environment(\.islandPalette, palette)
                    .environment(\.colorScheme, palette.colorScheme)
                    // Margine attorno alla capsula, dentro il riquadro.
                    .padding(.horizontal, Theme.Onboarding.previewInset)
                }
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : .primary.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
                }
                Text(appearance.choiceTitle)
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

/// Installare da soli gli aggiornamenti. Attivarlo accende anche il controllo automatico,
/// che senza non partirebbe mai.
private struct UpdateToggles: View {
    let updater: Updater

    var body: some View {
        Toggle("Aggiorna automaticamente", isOn: Binding(
            get: { updater.automaticallyChecks && updater.automaticallyDownloads },
            set: { enabled in
                if enabled { updater.automaticallyChecks = true }
                updater.automaticallyDownloads = enabled
            }
        ))
    }
}

#Preview("Intro") {
    OnboardingView(permissions: PermissionsCenter(), updater: nil, onFinish: {})
}

#Preview("Logo") {
    AtolloLogo().frame(width: 128, height: 128).padding()
}
