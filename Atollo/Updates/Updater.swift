import Observation
import Sparkle

/// Aggiornamenti con Sparkle dalle Release di GitHub (`SUFeedURL` in Info.plist).
/// All'avvio e ogni 4 ore controlla se c'è una versione nuova e mostra le novità del CHANGELOG;
/// dalle Impostazioni si controlla a mano.
@Observable
final class Updater {
    private(set) var canCheckForUpdates = false
    var automaticallyChecks: Bool {
        get { access(keyPath: \.automaticallyChecks); return controller.updater.automaticallyChecksForUpdates }
        set {
            withMutation(keyPath: \.automaticallyChecks) {
                controller.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    @ObservationIgnored private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        canCheckForUpdates = controller.updater.canCheckForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// Versione installata, come la mostra la pagina Releases.
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
