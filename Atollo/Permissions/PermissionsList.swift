import SwiftUI

/// I permessi che servono ad Atollo, ciascuno con il suo stato e il pulsante per concederlo.
/// Usata dalla schermata di intro e dalle Impostazioni.
struct PermissionsList: View {
    let center: PermissionsCenter

    var body: some View {
        VStack(spacing: Theme.Onboarding.rowSpacing) {
            if !center.isSpotifyInstalled {
                PermissionRow(
                    symbol: "exclamationmark.triangle.fill", tint: .orange,
                    title: "Spotify non è installato",
                    detail: "Atollo funziona solo con l'app Spotify per Mac.",
                    status: .notGranted, statusText: "Mancante"
                ) {
                    Button("Scarica…") {
                        if let url = URL(string: "https://www.spotify.com/download/mac/") { NSWorkspace.shared.open(url) }
                    }
                }
            }

            PermissionRow(
                symbol: "music.note", tint: .green,
                title: "Controllo di Spotify",
                detail: "Per leggere il brano in riproduzione e mandare play/pausa, avanti e indietro.",
                status: center.automation, statusText: statusText(center.automation, unavailable: "Da verificare")
            ) {
                automationAction
            }

            PermissionRow(
                symbol: "keyboard", tint: .blue,
                title: "Accessibilità",
                detail: "Per mandare i tasti multimediali della tastiera solo a Spotify. Atollo non legge nient'altro di quello che scrivi.",
                status: center.accessibility, statusText: statusText(center.accessibility)
            ) {
                if center.accessibility != .granted {
                    Button(center.accessibility == .notDetermined ? "Concedi" : "Apri Impostazioni…") {
                        center.requestAccessibility()
                    }
                }
            }
        }
        .onAppear { center.startWatching() }
        .onDisappear { center.stopWatching() }
    }

    @ViewBuilder private var automationAction: some View {
        switch center.automation {
        case .granted:
            EmptyView()
        case .notDetermined:
            Button("Concedi") { center.requestAutomation() }
                .disabled(center.isRequestingAutomation)
        case .notGranted:
            Button("Apri Impostazioni…") { AutomationPermission.openSystemSettings() }
        case .unavailable:
            Button("Apri Spotify") { center.openSpotify() }
                .disabled(!center.isSpotifyInstalled)
        }
    }

    private func statusText(_ status: PermissionStatus, unavailable: String = "Non concesso") -> String {
        switch status {
        case .granted: "Concesso"
        case .notGranted, .notDetermined: "Non concesso"
        case .unavailable: unavailable
        }
    }
}

private struct PermissionRow<Action: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let status: PermissionStatus
    let statusText: String
    @ViewBuilder let action: Action

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Theme.Onboarding.iconSize, height: Theme.Onboarding.iconSize)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    StatusBadge(isGranted: status == .granted, text: statusText)
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                action
                    .controlSize(.small)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.25), value: status)
    }
}

private struct StatusBadge: View {
    let isGranted: Bool
    let text: String

    var body: some View {
        Label(text, systemImage: isGranted ? "checkmark.circle.fill" : "circle.dashed")
            .font(.caption.weight(.medium))
            .foregroundStyle(isGranted ? Color.green : Color.secondary)
            .labelStyle(.titleAndIcon)
            .contentTransition(.symbolEffect(.replace))
    }
}
