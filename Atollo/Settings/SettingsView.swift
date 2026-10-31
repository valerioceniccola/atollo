import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.mediaKeysOnlySpotify) private var mediaKeysOnlySpotify = true
    @AppStorage(SettingsKey.equalizerColor) private var equalizerColor = EqualizerColorChoice.automatic
    @AppStorage(SettingsKey.openAtLogin) private var openAtLogin = false

    @State private var previewModel: IslandModel
    @State private var loginError: String?
    private let colors: EqualizerColorProvider?
    private let permissions: PermissionsCenter
    private let updater: Updater?

    init(nowPlaying: NowPlayingState, settings: AppSettings, colors: EqualizerColorProvider?,
         permissions: PermissionsCenter, updater: Updater?) {
        self.colors = colors
        self.permissions = permissions
        self.updater = updater
        let model = IslandModel(geometry: .studioDisplay,
                                nowPlaying: nowPlaying.track == nil ? .sample() : nowPlaying,
                                settings: settings, colors: colors)
        model.forcedPresentation = .visible
        _previewModel = State(initialValue: model)
    }

    var body: some View {
        Form {
            Section("Permessi") {
                PermissionsList(center: permissions)
                    .padding(.vertical, 4)
            }

            Section {
                Toggle("Tasti multimediali solo per Spotify", isOn: $mediaKeysOnlySpotify)
            } footer: {
                Text("Play/pausa, avanti e indietro della tastiera vanno solo a Spotify quando è aperto. I comandi di AirPods e cuffie Bluetooth arrivano già all'app in riproduzione e non vengono intercettati.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                islandPreview
                colorPicker
            } header: {
                Text("Equalizzatore")
            }

            Section {
                Toggle("Apri al login", isOn: $openAtLogin)
                if let loginError {
                    Text(loginError).font(.footnote).foregroundStyle(.red)
                }
            }

            if let updater {
                UpdatesSection(updater: updater)
            }
        }
        .formStyle(.grouped)
        .frame(width: Theme.Settings.windowWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: openAtLogin) { _, enabled in setOpenAtLogin(enabled) }
        .onAppear {
            openAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: Anteprima dal vivo

    private var islandPreview: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [.indigo.opacity(0.8), .teal.opacity(0.8)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Rectangle()
                .fill(.black.opacity(0.25))
                .frame(height: previewModel.geometry.menuBarHeight)
            IslandView(model: previewModel)
        }
        .frame(height: Theme.Settings.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .allowsHitTesting(false)
    }

    // MARK: Cerchietti del colore

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ForEach(EqualizerColorChoice.allCases) { choice in
                    ColorSwatch(fill: swatchFill(for: choice), isSelected: equalizerColor == choice) {
                        equalizerColor = choice
                    }
                    .help(choice.title)
                }
            }
            Text(equalizerColor.title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func swatchFill(for choice: EqualizerColorChoice) -> AnyShapeStyle {
        switch choice {
        case .automatic:
            AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink, .red],
                                          center: .center))
        case .accent:
            AnyShapeStyle(Color(nsColor: NSColor.controlAccentColor.resolved(for: .darkAqua)))
        default:
            AnyShapeStyle(Color(nsColor: choice.presetColor ?? .systemBlue))
        }
    }

    // MARK: Apri al login

    private func setOpenAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        guard enabled != (service.status == .enabled) else { return }
        do {
            if enabled { try service.register() } else { try service.unregister() }
            loginError = nil
        } catch {
            loginError = "Non è stato possibile cambiare l'apertura al login: \(error.localizedDescription)"
            openAtLogin = service.status == .enabled
        }
    }
}

/// Un cerchietto come quelli del colore di accento in Impostazioni di Sistema → Aspetto.
private struct ColorSwatch: View {
    let fill: AnyShapeStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
                .overlay {
                    if isSelected {
                        Circle().fill(.white).frame(width: 6, height: 6)
                    }
                }
                .frame(width: Theme.EqualizerColor.swatchSize, height: Theme.EqualizerColor.swatchSize)
                .padding(2)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Color.secondary.opacity(0.5), lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(nowPlaying: .sample(), settings: AppSettings(), colors: nil, permissions: PermissionsCenter(),
                 updater: nil)
}

/// Versione installata e aggiornamenti.
private struct UpdatesSection: View {
    @Bindable var updater: Updater

    var body: some View {
        Section {
            LabeledContent("Versione", value: Updater.currentVersion)
            Toggle("Controlla gli aggiornamenti automaticamente", isOn: $updater.automaticallyChecks)
            LabeledContent("Aggiornamenti") {
                Button("Controlla ora…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
        } header: {
            Text("Aggiornamenti")
        } footer: {
            Text("Le versioni nuove arrivano dalle Release di GitHub, con le novità.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
