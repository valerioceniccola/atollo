# Rilasciare una nuova versione di Atollo

Le versioni escono come **Release** di questa repository. Atollo controlla all'avvio e ogni 4 ore se ce n'è una nuova (Sparkle), mostra le novità e propone di installarla. Dalle Impostazioni si controlla anche a mano.

## Rilascio (ogni volta)

1. Alza la versione (`MARKETING_VERSION` nel progetto, es. `0.1.0` → `0.2.0`) e scrivi le novità in `CHANGELOG.md`, in una sezione `## 0.2.0` con frasi brevi per chi usa l'app.
2. Commit su `main`.
3. `scripts/release.sh`: fa push di `main`, costruisce in Release, firma con il certificato *Developer ID Application*, notarizza, crea `Atollo-0.2.0.dmg` (prima installazione) e `Atollo-0.2.0.zip` (aggiornamenti), firma lo zip per Sparkle, scrive `appcast.xml` e pubblica la Release `v0.2.0` con le novità.

In alternativa basta chiedere a Claude "rilascia la 0.2.0": fa lui tutti i passi.

Si costruisce sul Mac e non su GitHub Actions perché Atollo si compila con Xcode 27 (il Mac che costruisce deve avere macOS 27).

## Configurazione iniziale (una volta sola)

**Certificato** — *Developer ID Application: Valerio Ceniccola (PWKB5B45ND)* nel Portachiavi (c'è già).

**Notarizzazione** — un profilo nel Portachiavi con le credenziali per il servizio di Apple:

```bash
xcrun notarytool store-credentials atollo --apple-id TUA-EMAIL --team-id PWKB5B45ND
```

Chiede una *password specifica per le app* (account.apple.com › Accesso e sicurezza › Password specifiche per le app), non la password dell'Apple ID.

**Chiave degli aggiornamenti** — Sparkle accetta solo aggiornamenti firmati con la chiave EdDSA salvata nel Portachiavi ("Private key for signing Sparkle updates"); la parte pubblica è `SUPublicEDKey` in `Config/Info.plist`. **Fanne un backup**: senza, le versioni già installate non accetterebbero più aggiornamenti.

```bash
build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x atollo-sparkle-key.txt
```

Conserva il file in un posto sicuro (es. 1Password) e poi cancellalo.

## Prima installazione per un amico

Dalla pagina **Releases** scarica `Atollo-x.y.z.dmg`, aprilo e trascina Atollo in Applicazioni. Dalla volta successiva gli aggiornamenti arrivano da soli. Servono macOS 26 o successivo e Spotify per Mac.
