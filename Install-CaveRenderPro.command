#!/usr/bin/env bash
# Installateur CaveRenderPro pour macOS — double-cliquez pour lancer

set -e
export LANG=fr_FR.UTF-8

echo ""
echo "  ═════════════════════════════════════════════"
echo "     Installation de CaveRenderPro sur Mac"
echo "  ═════════════════════════════════════════════"
echo ""

# Répertoire de travail (dans le dossier Téléchargements pour être facile à trouver)
INSTALL_DIR="${HOME}/Téléchargements/CaveRenderPro-install"
CRP_URL="https://www.caverender.de/CaveRenderPro/CaveRenderPro.zip"
JAVAFX_BASE="https://download.java.net/java/GA/javafx23.0.2/512f2f157741485abda37a0a95f69984//3"
APP_NAME="CaveRenderPro.app"

# Détection de l’architecture (Apple Silicon ou Intel)
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  JAVAFX_URL="${JAVAFX_BASE}/openjfx-23.0.2_macos-aarch64_bin-sdk.tar.gz"
else
  JAVAFX_URL="${JAVAFX_BASE}/openjfx-23.0.2_macos-x64_bin-sdk.tar.gz"
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ─── 1. Java ─────────────────────────────────────────
echo "  [1/4] Vérification de Java…"
JAVA_OK=0
if command -v java &>/dev/null; then
  JAVA_VERSION=$(java -version 2>&1 | head -1)
  if java -version 2>&1 | grep -qE "version \"(1[7-9]|[2-9][0-9])"; then
    JAVA_OK=1
    echo "         Java trouvé : $JAVA_VERSION"
  fi
fi

if [[ $JAVA_OK -eq 0 ]]; then
  echo "         Java 17 ou plus récent est requis."
  if command -v brew &>/dev/null; then
    echo "         Installation de Java 21 via Homebrew…"
    brew install openjdk@21
    export JAVA_HOME="$(brew --prefix openjdk@21)"
    export PATH="$JAVA_HOME/bin:$PATH"
    JAVA_OK=1
    echo "         Java installé."
  else
    echo ""
    echo "  ⚠️  Homebrew n’est pas installé. Installez Java manuellement :"
    echo "     https://adoptium.net/temurin/releases/"
    echo "     Choisissez « macOS » et « JDK 21 » pour votre Mac."
    echo ""
    read -p "  Appuyez sur Entrée pour quitter…"
    exit 1
  fi
fi

# ─── 2. CaveRenderPro ────────────────────────────────
echo ""
echo "  [2/4] Téléchargement de CaveRenderPro…"
if [[ ! -f "CaveRenderPro.jar" ]]; then
  curl -L -o CaveRenderPro.zip "$CRP_URL"
  unzip -o CaveRenderPro.zip
  # Le zip peut mettre le jar à la racine ou dans un sous-dossier
  if [[ -f "CaveRenderPro.jar" ]]; then
    : # déjà au bon endroit
  elif [[ -d "CaveRenderPro" ]]; then
    cp -R CaveRenderPro/* . 2>/dev/null || true
  fi
  rm -f CaveRenderPro.zip
  echo "         CaveRenderPro téléchargé."
else
  echo "         Déjà présent, on continue."
fi

if [[ ! -f "CaveRenderPro.jar" ]]; then
  echo "  ⚠️  CaveRenderPro.jar introuvable après téléchargement."
  read -p "  Appuyez sur Entrée pour quitter…"
  exit 1
fi

# ─── 3. JavaFX ───────────────────────────────────────
echo ""
echo "  [3/4] Téléchargement de JavaFX pour Mac…"
JAVAFX_DIR="$INSTALL_DIR/javafx-sdk-23.0.2"
if [[ ! -d "$JAVAFX_DIR/lib" ]]; then
  JAVAFX_ARCHIVE="javafx-sdk.tar.gz"
  curl -L -o "$JAVAFX_ARCHIVE" "$JAVAFX_URL"
  tar -xzf "$JAVAFX_ARCHIVE"
  rm -f "$JAVAFX_ARCHIVE"
  # Renommer le dossier extrait en nom fixe
  EXTRACTED=$(find . -maxdepth 1 -type d -name "openjfx*" | head -1)
  if [[ -n "$EXTRACTED" ]]; then
    rm -rf "$JAVAFX_DIR"
    mv "$EXTRACTED" "$JAVAFX_DIR"
  fi
  echo "         JavaFX installé."
else
  echo "         JavaFX déjà présent."
fi

if [[ ! -d "$JAVAFX_DIR/lib" ]]; then
  echo "  ⚠️  JavaFX introuvable après téléchargement."
  read -p "  Appuyez sur Entrée pour quitter…"
  exit 1
fi

# ─── 4. Application Mac (.app) ────────────────────────
echo ""
echo "  [4/4] Création de l’application CaveRenderPro…"
APP_ROOT="$INSTALL_DIR/$APP_NAME"
rm -rf "$APP_ROOT"
mkdir -p "$APP_ROOT/Contents/MacOS"
mkdir -p "$APP_ROOT/Contents/Resources"

# Copier JAR et JavaFX dans l’app
cp CaveRenderPro.jar "$APP_ROOT/Contents/Resources/"
cp -R "$JAVAFX_DIR" "$APP_ROOT/Contents/Resources/"

# Script de lancement à l’intérieur du .app
LAUNCHER="$APP_ROOT/Contents/MacOS/CaveRenderPro"
cat > "$LAUNCHER" << 'LAUNCHER_SCRIPT'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
RESOURCES="$APP_ROOT/Contents/Resources"
JAR="$RESOURCES/CaveRenderPro.jar"
JAVAFX_LIB="$RESOURCES/javafx-sdk-23.0.2/lib"

if [[ -z "$JAVA_HOME" ]]; then
  JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null) || true
fi
if [[ -z "$JAVA_HOME" ]]; then
  [[ -d "/opt/homebrew/opt/openjdk@21" ]] && JAVA_HOME="/opt/homebrew/opt/openjdk@21"
  [[ -d "/usr/local/opt/openjdk@21" ]] && JAVA_HOME="/usr/local/opt/openjdk@21"
fi
if [[ -n "$JAVA_HOME" ]]; then
  JAVA_CMD="$JAVA_HOME/bin/java"
else
  JAVA_CMD="java"
fi
"$JAVA_CMD" \
  -Dprism.order=sw \
  -Dprism.text=t2k \
  -Djavafx.macosx.embedded=true \
  --module-path "$JAVAFX_LIB" \
  --add-modules javafx.controls,javafx.fxml,javafx.web \
  -jar "$JAR"
LAUNCHER_SCRIPT
chmod +x "$LAUNCHER"

# Info.plist pour que macOS reconnaisse l’app
cat > "$APP_ROOT/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>CaveRenderPro</string>
  <key>CFBundleIdentifier</key>
  <string>de.caverender.CaveRenderPro</string>
  <key>CFBundleName</key>
  <string>CaveRenderPro</string>
  <key>CFBundleDisplayName</key>
  <string>CaveRenderPro</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

# Copier dans /Applications
APPLICATIONS="/Applications"
if [[ -d "$APPLICATIONS" ]]; then
  rm -rf "$APPLICATIONS/$APP_NAME"
  cp -R "$APP_ROOT" "$APPLICATIONS/"
  echo "         Application installée dans « /Applications »."
else
  echo "         Dossier Applications non trouvé. L’app est dans :"
  echo "         $APP_ROOT"
fi

echo ""
echo "  ═════════════════════════════════════════════"
echo "     C’est prêt."
echo "     Ouvrez le Launchpad ou le dossier"
echo "     Applications et lancez « CaveRenderPro »."
echo "  ═════════════════════════════════════════════"
echo ""
read -p "  Appuyez sur Entrée pour fermer cette fenêtre…"
