# Atollo — brief di progetto

App macOS nativa (Swift/SwiftUI, Xcode 27, target macOS 27) che mostra il brano di **Spotify** in una piccola isola nella barra dei menu. Uso personale e per pochi amici; niente App Store.

## Ambito
- **Solo Spotify** (bundle ID `com.spotify.client`). Tutto è pensato e rifinito per Spotify.
- C'è un piccolo protocollo `PlayerSource`, implementato solo da `SpotifySource`, così in futuro si potrà aggiungere altro senza riscrivere. Non implementare altri player.

## Progetto e distribuzione
- App solo agente (`LSUIElement`, niente Dock), senza sandbox.
- Bundle ID `com.valerioceniccola.atollo`. Hardened Runtime attivo, firma Developer ID (team `PWKB5B45ND`), pronto per la notarizzazione.
- Entitlement `com.apple.security.automation.apple-events`; `NSAppleEventsUsageDescription` e un avviso chiaro prima della richiesta di Accessibilità.
- Rilasci con `scripts/release.sh` sul Mac (firma, notarizzazione, .dmg, .zip per Sparkle, Release su GitHub `valerioceniccola/atollo`); aggiornamenti con Sparkle. Procedura: `docs/RELEASING.md`. Nuove versioni solo quando Valerio lo chiede.

## Dati da Spotify
- ScriptingBridge: titolo, artista, URL della copertina, stato, `spotify url`.
- Aggiornamento solo a eventi con la notifica distribuita `com.spotify.client.PlaybackStateChanged` (più una seconda lettura poco dopo, perché Spotify a volte risponde ancora con lo stato precedente). Nessun timer: la posizione nel brano non serve.
- Comandi: play/pausa, avanti, indietro (dai tasti multimediali). Al cambio brano Spotify manda una pausa finta: una pausa vale solo se dura almeno 0,6 s.

## Architettura
- Modello osservabile (`SpotifyController` / `NowPlayingState`) separato dalla UI.
- Tutte le costanti estetiche (misure, raggi, font, opacità, durate, molle, velocità del marquee e dell'equalizzatore, colori) in `Theme.swift`.
- `#Preview` per gli stati: nascosta, visibile, testo lungo, in pausa, MacBook.

## UI — l'isola
- **Sempre nella barra dei menu, a sinistra delle altre icone.** Non imita il notch. Un `NSStatusItem` vuoto riserva lo spazio; l'isola è un pannello overlay (NSPanel non attivante, sopra la barra dei menu) agganciato al **bordo destro** di quell'elemento, così cambiando larghezza cresce solo verso sinistra con una sola animazione.
- Capsula di **vetro nativo scuro** (`glassEffect` con tinta nera più un velo nero sotto, per la leggibilità), alta circa il 70% della barra, con margine sopra e sotto. Nero neutro: niente tinte prese dallo sfondo.
- Lo spazio nella barra lo riserva un `NSStatusItem` largo esattamente quanto l'isola (attorno solo la spaziatura di sistema); la posizione si legge dal pulsante dell'elemento, non dalla sua finestra, e solo a barra ferma.
- **Visibile finché Spotify è aperto**, anche in pausa; sparisce quando Spotify si chiude. Compare e sparisce con un'animazione.
- Visibile anche a schermo intero e durante la condivisione dello schermo.
- Contenuto: copertina circolare (14 pt, concentrica con l'estremità della capsula), "Titolo · Artista" (titolo semibold, artista grigio), equalizzatore.
- **Larghezza decisa da noi**, non dall'utente: segue il testo tra 200 e 300 pt; oltre, marquee avanti e indietro (pausa di circa 1,5 s ai capi) con dissolvenza ai bordi.
- Animazioni a molla in stile Apple (response circa 0,45, damping circa 0,85). La finestra si allarga prima dell'animazione e si restringe solo a molla finita, così l'isola non scatta mai.
- **Cambio brano**: la copertina fa una dissolvenza incrociata; il titolo vecchio svanisce sul posto e il nuovo compare con una leggera sfocatura e pochi punti di spostamento. Discreto.
- **Pausa**: l'isola si fa compatta (solo copertina ed equalizzatore spento, barre basse e sbiadite, niente icona di pausa); il vetro resta lo stesso.
- **Spotify aperto o chiuso**: comparsa e scomparsa in dissolvenza rapida, sul posto.

### Interazione
- **Click sinistro**: porta Spotify in primo piano. Nessun effetto al passaggio del mouse.
- **Click destro**: menu con "Copia link del brano" (da `spotify url`, convertito in link `open.spotify.com`), separatore, "Impostazioni…".
- I click li riceve l'elemento nella barra dei menu sotto l'isola: la finestra dell'isola lascia passare il mouse.
- Riaprire l'app dal Finder mostra le impostazioni.

## Equalizzatore
- 4 barre arrotondate, centrate in verticale, **sempre decorative**.
- **Mai catturare l'audio**: niente process tap. La cattura fa comparire l'indicatore viola di registrazione di macOS, che non deve mai comparire.

### Colore dell'equalizzatore (Impostazioni)
Una riga di cerchietti come quella del colore di accento in Impostazioni di Sistema → Aspetto:
1. **Automatico (default)**: colore ricavato dallo sfondo della scrivania di quello schermo (`NSWorkspace.shared.desktopImageURL(for:)`), colore dominante ignorando i pixel quasi grigi o quasi neri, poi reso leggibile sul nero in OKLCH (luminosità minima circa 0,75, croma circa 0,08–0,16). Ricalcolato quando cambiano Spazio, schermo o sfondo. Ripiego: `controlAccentColor` schiarito con la stessa regola.
2. **Accento di sistema**: `NSColor.controlAccentColor`.
3. **Preimpostati**: systemBlue, systemPurple, systemPink, systemRed, systemOrange, systemYellow, systemGreen, systemGray (Grafite) e bianco, nelle varianti per l'aspetto scuro.

## Tasti multimediali solo per Spotify
- Intercetta play/pausa, avanti e indietro (CGEventTap sugli eventi `NSSystemDefined`, subtype 8) e inoltrali **solo** a Spotify, bloccando l'evento originale.
- Attivo solo se Spotify è aperto; altrimenti lascia passare i tasti.
- Gestisce la richiesta del permesso Accessibilità.
- AirPods e cuffie Bluetooth passano da MediaRemote all'app in riproduzione (di solito Spotify): non si dirottano, per non creare un secondo player in Centro di Controllo.

## Impostazioni (finestra SwiftUI)
- **Tasti multimediali solo per Spotify**: interruttore (acceso di default).
- **Colore equalizzatore**: vedi sopra, con anteprima dal vivo dell'isola.
- **Permessi**: la stessa lista della schermata di intro (Controllo di Spotify, Accessibilità) con stato e pulsante.
- **Apri al login**: interruttore (`SMAppService.mainApp`, spento di default).
- **Aggiornamenti**: versione installata, controllo automatico, "Controlla ora…".

## Intro
Al primo avvio: icona, breve descrizione, lista dei permessi con "Non concesso" finché non vengono dati. Le finestre di sistema compaiono solo premendo "Concedi"; l'isola parte appena il permesso per Spotify c'è.

## Icona
`Atollo/Atollo.icon` (Icon Composer): capsula nera con copertina circolare ed equalizzatore verde.
- Tutto salvato con `@AppStorage`.

## Fuori dalla prima versione (più avanti)
Testi sincronizzati (LRCLIB), "Mi piace" e coda tramite la Web API di Spotify, avviso al cambio brano.

## Da fare a ogni passo
Compila ed esegui per verificare. Su macOS 27 controlla che le API usate (status item, event tap, glass) funzionino ancora come previsto.
