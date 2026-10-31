#!/bin/bash
# Rilascio di una nuova versione di Atollo, tutto sul Mac: build Release, firma Developer ID,
# notarizzazione, .dmg per la prima installazione, .zip firmato per Sparkle, appcast.xml e Release su GitHub.
# La versione è MARKETING_VERSION nel progetto; le novità sono la sezione "## X.Y.Z" di CHANGELOG.md.
# Configurazione una tantum e procedura: docs/RELEASING.md
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
REPO="valerioceniccola/atollo"
NOTARY_PROFILE="atollo"
OUT="$ROOT/build/release"
DERIVED="$ROOT/build/DerivedData"

fail() { echo "✗ $*" >&2; exit 1; }
step() { echo; echo "▸ $*"; }

VERSION="$(grep -m1 'MARKETING_VERSION = ' Atollo.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);/\1/')"
# Sparkle confronta CFBundleVersion: un numero che cresce sempre, il conteggio dei commit.
BUILD="$(git rev-list --count HEAD)"
TAG="v$VERSION"

step "Controlli per Atollo $VERSION (build $BUILD)"
[ -z "$(git status --porcelain)" ] || fail "Ci sono modifiche non committate."
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || fail "Il rilascio si fa da main."
grep -qx "## $VERSION" CHANGELOG.md || fail "Manca la sezione \"## $VERSION\" in CHANGELOG.md."
gh auth status >/dev/null 2>&1 || fail "gh non è autenticato: gh auth login"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then fail "La Release $TAG esiste già."; fi
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "Manca il profilo di notarizzazione \"$NOTARY_PROFILE\" (vedi docs/RELEASING.md)."

# La Release punta a main su GitHub: dev'esserci e coincidere con questo commit (anche la prima volta).
git fetch -q origin main 2>/dev/null || true
if ! git rev-parse -q --verify origin/main >/dev/null || [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    step "Push di main su GitHub"
    git push -u origin main
fi

rm -rf "$OUT"; mkdir -p "$OUT"

step "Build e archivio Release"
xcodebuild -project Atollo.xcodeproj -scheme Atollo -configuration Release \
    -derivedDataPath "$DERIVED" -archivePath "$OUT/Atollo.xcarchive" \
    CURRENT_PROJECT_VERSION="$BUILD" archive -quiet

step "Esportazione firmata Developer ID"
xcodebuild -exportArchive -archivePath "$OUT/Atollo.xcarchive" \
    -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$OUT/export" -quiet
APP="$OUT/export/Atollo.app"
codesign --verify --deep --strict "$APP"

step "Notarizzazione dell'app"
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm "$OUT/notarize.zip"

step "Immagine disco per la prima installazione"
DMG="$OUT/Atollo-$VERSION.dmg"
mkdir -p "$OUT/dmg"
cp -R "$APP" "$OUT/dmg/"
ln -s /Applications "$OUT/dmg/Applicazioni"
hdiutil create -volname "Atollo $VERSION" -srcfolder "$OUT/dmg" -ov -format UDZO "$DMG" -quiet
codesign --sign "Developer ID Application" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

step "Pacchetto per gli aggiornamenti (Sparkle)"
ZIP="$OUT/Atollo-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
SPARKLE_BIN="$DERIVED/SourcePackages/artifacts/sparkle/Sparkle/bin"
SIGNATURE="$("$SPARKLE_BIN/sign_update" "$ZIP")"   # sparkle:edSignature="…" length="…"

# Novità della versione dal CHANGELOG: testo per la Release, elenco HTML per la finestra di Sparkle.
awk -v v="## $VERSION" '$0 == v {on=1; next} /^## / {on=0} on' CHANGELOG.md | sed '/^$/d' > "$OUT/notes.md"
NOTES_HTML="<ul>$(sed -E 's/^- (.*)/<li>\1<\/li>/' "$OUT/notes.md" | tr -d '\n')</ul>"

cat > "$OUT/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Atollo</title>
    <item>
      <title>Atollo $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>27.0</sparkle:minimumSystemVersion>
      <description><![CDATA[$NOTES_HTML]]></description>
      <enclosure url="https://github.com/$REPO/releases/download/$TAG/Atollo-$VERSION.zip" type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
XML

step "Release $TAG su GitHub"
gh release create "$TAG" "$DMG" "$ZIP" "$OUT/appcast.xml" --repo "$REPO" --target main \
    --title "Atollo $VERSION" --notes-file "$OUT/notes.md" --latest

echo
echo "✓ Atollo $VERSION pubblicata: https://github.com/$REPO/releases/tag/$TAG"
