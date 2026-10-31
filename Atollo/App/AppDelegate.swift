import AppKit

@main
enum AtolloMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var spotify = SpotifyController()
    private lazy var colors = EqualizerColorProvider(settings: settings)
    private lazy var mediaKeys = MediaKeyInterceptor(controller: spotify, settings: settings)
    private lazy var settingsWindow = SettingsWindowController { [unowned self] in
        SettingsView(nowPlaying: spotify.state, settings: settings, colors: colors)
    }
    private lazy var islands = IslandManager(
        controller: spotify, settings: settings, colors: colors,
        openSettings: { [unowned self] in settingsWindow.show() }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.makeMainMenu()
        spotify.start()
        colors.start()
        islands.start()
        mediaKeys.start()
    }

    /// Senza Dock né barra dei menu: riaprire l'app dal Finder mostra le impostazioni.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }

    /// Serve solo per le scorciatoie (⌘W, ⌘Q, copia/incolla) nella finestra Impostazioni.
    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Chiudi finestra", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Esci da Atollo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Modifica")
        editMenu.addItem(withTitle: "Copia", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Incolla", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Seleziona tutto", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)
        return main
    }
}
