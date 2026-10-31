import ServiceManagement
import SwiftUI

/// Schermata di intro al primo avvio: logo, cosa fa Atollo, permessi da concedere.
/// Le finestre di sistema compaiono solo quando l'utente preme "Concedi".
struct OnboardingView: View {
    let permissions: PermissionsCenter
    let onFinish: () -> Void

    @AppStorage(SettingsKey.openAtLogin) private var openAtLogin = false

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
                Text("Permessi")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                PermissionsList(center: permissions)
            }
            .padding(Theme.Onboarding.cardPadding)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 26)

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

            Text("Puoi ritrovare questi permessi nelle Impostazioni, col click destro sull'isola.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 10)
        }
        .padding(Theme.Onboarding.padding)
        .frame(width: Theme.Onboarding.width)
        .fixedSize(horizontal: false, vertical: true)
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
