# Atollo — brief di progetto

App macOS nativa (Swift/SwiftUI, Xcode 27, target macOS 26) che mostra il brano di **Spotify** nella barra dei menu. Uso personale e per pochi amici; niente App Store.

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
- **Un normale elemento della barra dei menu, a sinistra delle altre icone.** Non imita il notch. Il contenuto è disegnato **dentro** il suo `NSStatusItem`, come le altre icone: nessuna finestra propria, così macOS lo gestisce come tutte (schermo intero, notch, barra nascosta, più schermi, app che riordinano le icone).
- Capsula di **vetro nativo scuro** (`glassEffect` con tinta nera più un velo nero sotto, per la leggibilità), alta circa il 70% della barra, con margine sopra e sotto. Nero neutro: niente tinte prese dallo sfondo. In Impostazioni › Aspetto › Tema c'è anche un aspetto **chiaro**: vetro normale di macOS con un velo bianco al 90% e una tinta bianca al 20%, senza bordo come lo scuro, testo scuro ed equalizzatore scurito (stessa tinta). **Di default nessuna capsula (tema Trasparente)**; in Impostazioni › Aspetto e nell'intro tre riquadri uguali: Trasparente, Capsula scura, Capsula chiara. Il tema **Trasparente**: niente vetro, sfondo né bordo, solo copertina, testo ed equalizzatore sulla barra; il testo è bianco o scuro come quello della barra dei menu (lo dice l'aspetto del pulsante dell'elemento, che macOS adegua allo sfondo). Default: scuro.
- L'elemento è largo esattamente quanto il contenuto; attorno la spaziatura di sistema.
- **Visibile finché Spotify è aperto**, anche in pausa; sparisce quando Spotify si chiude. Compare e sparisce con un'animazione.
- A schermo intero sparisce con la barra dei menu, da sola; visibile durante la condivisione dello schermo.
- Con più monitor macOS mostra sugli altri una copia (un'immagine) di Atollo: la copia si schiarisce al 45%, come le icone spente delle barre non attive; sul monitor attivo resta piena.
- Contenuto: copertina circolare (14 pt, concentrica con l'estremità della capsula, con un filo interno di mezzo punto al 15% del colore del testo, perché si veda anche nera su nero o bianca su bianco), "Titolo · Artista" (titolo semibold, artista grigio), equalizzatore.
- **Larghezza decisa da noi**, non dall'utente: segue il testo fino a 270 pt, senza larghezza minima; oltre, marquee avanti e indietro (lento, pausa di 3 s ai capi) con dissolvenza ai bordi.
- I cambi di larghezza (pausa, cambio brano) sono di colpo, insieme all'elemento, come per tutte le icone della barra: macOS non sa animare la larghezza di un elemento (provato: lo ridimensiona dal lato sinistro e poi lo riallinea). Le transizioni di testo e copertina restano.
- **Cambio brano**: la copertina fa una dissolvenza incrociata; il titolo vecchio svanisce sul posto e il nuovo compare con una leggera sfocatura e pochi punti di spostamento. Discreto.
- **Pausa**: l'isola si fa compatta (solo copertina ed equalizzatore spento, barre basse e sbiadite, niente icona di pausa); il vetro resta lo stesso. Con "Nascondi quando Spotify è in pausa" (Impostazioni, spento di default) si stringe come sempre e verso la fine si dissolve, poi esce dalla barra; ricompare in dissolvenza quando riparte la musica.
- **Spotify aperto o chiuso**: comparsa e scomparsa in dissolvenza rapida, sul posto.

### Interazione
- **Click sinistro**: porta Spotify in primo piano. Nessun effetto al passaggio del mouse.
- **Click destro**: menu con "Copia link del brano" (da `spotify url`, convertito in link `open.spotify.com`), separatore, "Impostazioni…", "Esci da Atollo".
- I click li riceve il pulsante dell'elemento; il contenuto disegnato dentro lascia passare il mouse.
- Riaprire l'app dal Finder mostra le impostazioni.

## Equalizzatore
- 4 barre arrotondate, centrate in verticale, **sempre decorative**.
- Animate da Core Animation (livelli con animazioni a fotogrammi chiave di altezze casuali, ripetute ogni 4-6 s con durate diverse per barra): nessun ridisegno di SwiftUI per fotogramma, CPU vicina a zero mentre suona. Sulla copia degli altri monitor (un'immagine) le barre restano ferme ad altezze diverse.
- **Mai catturare l'audio**: niente process tap. La cattura fa comparire l'indicatore viola di registrazione di macOS, che non deve mai comparire.

### Colore dell'equalizzatore (Impostazioni)
Una riga di cerchietti come quella del colore di accento in Impostazioni di Sistema → Aspetto:
1. **Automatico (default)**: colore ricavato dallo sfondo della scrivania di quello schermo (`NSWorkspace.shared.desktopImageURL(for:)`), colore dominante ignorando i pixel quasi grigi o quasi neri, poi reso leggibile sul nero in OKLCH (luminosità minima circa 0,75, croma circa 0,08–0,16). Ricalcolato quando cambiano Spazio, schermo o sfondo. Ripiego: `controlAccentColor` schiarito con la stessa regola.
2. **Dalla copertina**: colore dominante della copertina in riproduzione, con la stessa regola di leggibilità; cambia a ogni brano. Se la copertina è quasi grigia si usa lo sfondo, come in Automatico.
3. **Accento di sistema**: `NSColor.controlAccentColor`.
4. **Preimpostati**: systemBlue, systemPurple, systemPink, systemRed, systemOrange, systemYellow, systemGreen, systemGray (Grafite) e bianco, nelle varianti per l'aspetto scuro.

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
Compila ed esegui per verificare. Su macOS 26 e 27 controlla che le API usate (status item, event tap, glass) funzionino ancora come previsto.
