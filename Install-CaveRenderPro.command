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
INSTALL_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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

# ─── 1. Java (CaveRenderPro nécessite Java 25) ───────
echo "  [1/4] Vérification de Java…"
JAVA_OK=0
if command -v java &>/dev/null; then
  JAVA_VERSION=$(java -version 2>&1 | head -1)
  # Class file 69.0 = Java 25 ; on accepte 25 ou plus récent
  if java -version 2>&1 | grep -qE "version \"(25|[3-9][0-9])"; then
    JAVA_OK=1
    echo "         Java trouvé : $JAVA_VERSION"
  fi
fi

if [[ $JAVA_OK -eq 0 ]]; then
  echo "         CaveRenderPro nécessite Java 25 ou plus récent."
  if command -v brew &>/dev/null; then
    echo "         Installation de Java 25 via Homebrew (Temurin)…"
    brew install --cask temurin@25
    export JAVA_HOME=$(/usr/libexec/java_home -v 25 2>/dev/null)
    export PATH="$JAVA_HOME/bin:$PATH"
    JAVA_OK=1
    echo "         Java 25 installé."
  else
    # Sans Homebrew : téléchargement Temurin via l’API Adoptium
    # 1) Essai .pkg (sudo) ; 2) Sinon .tar.gz (sans sudo, JDK inclus dans l’app)
    ADOPTIUM_ARCH="x64"
    [[ "$ARCH" == "arm64" ]] && ADOPTIUM_ARCH="aarch64"
    ADOPTIUM_API="https://api.adoptium.net/v3/assets/feature_releases/25/ga?os=mac&architecture=$ADOPTIUM_ARCH&image_type=jdk"
    ADOPTIUM_JSON=$(curl -sL "$ADOPTIUM_API" 2>/dev/null)
    JAVA_PKG_URL=$(echo "$ADOPTIUM_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data and data[0].get('binaries') and data[0]['binaries'][0].get('installer', {}).get('link'):
        print(data[0]['binaries'][0]['installer']['link'])
except Exception: pass
" 2>/dev/null)
    JAVA_TGZ_URL=$(echo "$ADOPTIUM_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data and data[0].get('binaries') and data[0]['binaries'][0].get('package', {}).get('link'):
        print(data[0]['binaries'][0]['package']['link'])
except Exception: pass
" 2>/dev/null)

    # Essai 1 : installation .pkg (demande mot de passe admin)
    if [[ $JAVA_OK -eq 0 ]] && [[ -n "$JAVA_PKG_URL" ]]; then
      echo "         Téléchargement de Java 25 (Temurin)…"
      JAVA_PKG_FILE="$INSTALL_DIR/temurin25.pkg"
      if curl -L -o "$JAVA_PKG_FILE" "$JAVA_PKG_URL" && [[ -f "$JAVA_PKG_FILE" ]]; then
        echo "         Installation du JDK (mot de passe administrateur demandé)…"
        if sudo installer -pkg "$JAVA_PKG_FILE" -target / 2>/dev/null; then
          rm -f "$JAVA_PKG_FILE"
          export JAVA_HOME=$(/usr/libexec/java_home -v 25 2>/dev/null)
          export PATH="$JAVA_HOME/bin:$PATH"
          JAVA_OK=1
          echo "         Java 25 installé."
        else
          rm -f "$JAVA_PKG_FILE"
          echo "         Installation .pkg annulée ou échouée (pas de souci, on essaie sans mot de passe)."
        fi
      else
        echo "         Téléchargement du .pkg échoué."
      fi
    fi

    # Essai 2 : .tar.gz sans sudo (JDK sera inclus dans l’app CaveRenderPro)
    if [[ $JAVA_OK -eq 0 ]] && [[ -n "$JAVA_TGZ_URL" ]]; then
      echo "         Téléchargement de Java 25 en mode portable (sans mot de passe)…"
      JAVA_TGZ_FILE="$INSTALL_DIR/temurin25.tar.gz"
      if curl -L -o "$JAVA_TGZ_FILE" "$JAVA_TGZ_URL" && [[ -f "$JAVA_TGZ_FILE" ]]; then
        echo "         Extraction du JDK…"
        tar -xzf "$JAVA_TGZ_FILE" -C "$INSTALL_DIR" 2>/dev/null
        rm -f "$JAVA_TGZ_FILE"
        JDK_TOP=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "*.jdk" 2>/dev/null | head -1)
        if [[ -n "$JDK_TOP" ]] && [[ -d "$JDK_TOP/Contents/Home" ]]; then
          export JAVA_HOME="$JDK_TOP/Contents/Home"
          export PATH="$JAVA_HOME/bin:$PATH"
          BUNDLED_JDK_DIR="$JDK_TOP"
          JAVA_OK=1
          echo "         Java 25 prêt (inclus dans l’application, pas d’installation système)."
        elif [[ -n "$JDK_TOP" ]] && [[ -x "$JDK_TOP/bin/java" ]]; then
          export JAVA_HOME="$JDK_TOP"
          export PATH="$JAVA_HOME/bin:$PATH"
          BUNDLED_JDK_DIR="$JDK_TOP"
          JAVA_OK=1
          echo "         Java 25 prêt (inclus dans l’application)."
        else
          echo "         Structure du JDK extrait inattendue."
        fi
      else
        echo "         Échec du téléchargement du JDK."
      fi
    fi

    if [[ $JAVA_OK -eq 0 ]]; then
      echo ""
      echo "  ⚠️  Java 25 n’a pas pu être installé (réseau ou droits insuffisants)."
      echo "     Installez-le à la main puis relancez ce script :"
      echo "     https://adoptium.net/temurin/releases/?version=25"
      echo ""
      read -p "  Ouvrir la page dans le navigateur ? (o/n) " -n 1 OPEN_BROWSER
      echo ""
      if [[ "$OPEN_BROWSER" =~ [oOyY] ]]; then
        open "https://adoptium.net/temurin/releases/?version=25&os=macos" 2>/dev/null || true
      fi
      read -p "  Appuyez sur Entrée pour quitter…"
      exit 1
    fi
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
# Si on a un JDK portable (sans sudo), l’inclure dans l’app pour qu’elle soit autonome
if [[ -n "$BUNDLED_JDK_DIR" ]] && [[ -d "$BUNDLED_JDK_DIR" ]]; then
  rm -rf "$APP_ROOT/Contents/Resources/jdk"
  cp -R "$BUNDLED_JDK_DIR" "$APP_ROOT/Contents/Resources/jdk"
fi

# Icône (favicon « C » du site caverender.de)
ICONSET_DIR="$INSTALL_DIR/AppIcon.iconset"
if [[ -f "$INSTALL_SCRIPT_DIR/CaveRenderPro.icns" ]]; then
  cp "$INSTALL_SCRIPT_DIR/CaveRenderPro.icns" "$APP_ROOT/Contents/Resources/"
elif [[ -f "$INSTALL_DIR/CaveRenderPro.icns" ]]; then
  cp "$INSTALL_DIR/CaveRenderPro.icns" "$APP_ROOT/Contents/Resources/"
else
  echo "         Téléchargement de l’icône…"
  curl -sL -o "$INSTALL_DIR/favicon.ico" "https://www.caverender.de/CaveRenderPro/favicon.ico"
  if [[ -f "$INSTALL_DIR/favicon.ico" ]]; then
    sips -s format png "$INSTALL_DIR/favicon.ico" --out "$INSTALL_DIR/favicon.png" 2>/dev/null
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    for s in 16 32 128 256 512; do
      sips -z $s $s "$INSTALL_DIR/favicon.png" --out "$ICONSET_DIR/icon_${s}x${s}.png" 2>/dev/null
      d=$((s*2))
      sips -z $d $d "$INSTALL_DIR/favicon.png" --out "$ICONSET_DIR/icon_${s}x${s}@2x.png" 2>/dev/null
    done
    if iconutil -c icns -o "$INSTALL_DIR/CaveRenderPro.icns" "$ICONSET_DIR" 2>/dev/null; then
      cp "$INSTALL_DIR/CaveRenderPro.icns" "$APP_ROOT/Contents/Resources/"
    fi
    rm -rf "$ICONSET_DIR" "$INSTALL_DIR/favicon.ico" "$INSTALL_DIR/favicon.png"
  fi
fi

# Script de lancement à l’intérieur du .app
LAUNCHER="$APP_ROOT/Contents/MacOS/CaveRenderPro"
cat > "$LAUNCHER" << 'LAUNCHER_SCRIPT'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
RESOURCES="$APP_ROOT/Contents/Resources"
JAR="$RESOURCES/CaveRenderPro.jar"
JAVAFX_LIB="$RESOURCES/javafx-sdk-23.0.2/lib"
LOG_FILE="$HOME/Library/Logs/CaveRenderPro.log"

mkdir -p "$(dirname "$LOG_FILE")"
exec >> "$LOG_FILE" 2>&1
echo "--- $(date) ---"

# Trouver Java 25+ uniquement (on ignore les anciennes versions comme Java 14)
check_java_25() {
  local jhome="$1"
  [[ -z "$jhome" ]] && return 1
  [[ ! -x "$jhome/bin/java" ]] && return 1
  local ver=$("$jhome/bin/java" -version 2>&1 | grep -oE '"([0-9]+)' | head -1 | tr -d '"')
  [[ -n "$ver" ]] && [[ "$ver" -ge 25 ]] && return 0
  return 1
}
JAVA_HOME=""
if check_java_25 "$RESOURCES/jdk/Contents/Home"; then
  JAVA_HOME="$RESOURCES/jdk/Contents/Home"
elif check_java_25 "$RESOURCES/jdk"; then
  JAVA_HOME="$RESOURCES/jdk"
fi
if [[ -z "$JAVA_HOME" ]]; then
  for j in "$(/usr/libexec/java_home -v 25 2>/dev/null)" "$(/usr/libexec/java_home -v 24 2>/dev/null)" "$(/usr/libexec/java_home 2>/dev/null)"; do
    [[ -z "$j" ]] && continue
    if check_java_25 "$j"; then JAVA_HOME="$j"; break; fi
  done
fi
if [[ -z "$JAVA_HOME" ]]; then
  for j in /opt/homebrew/opt/openjdk /usr/local/opt/openjdk /opt/homebrew/opt/openjdk@21 /usr/local/opt/openjdk@21; do
    [[ -d "$j" ]] && check_java_25 "$j" && JAVA_HOME="$j" && break
  done
fi
if [[ -n "$JAVA_HOME" ]]; then
  JAVA_CMD="$JAVA_HOME/bin/java"
else
  JAVA_CMD="java"
fi

if [[ ! -x "$JAVA_CMD" ]] && ! command -v java &>/dev/null; then
  osascript -e "display alert \"CaveRenderPro\" message \"Java est introuvable. Installez Java 25 (adoptium.net/temurin, version 25) ou relancez le script d'installation.\" as critical"
  exit 1
fi
JAVA_VER=$("$JAVA_CMD" -version 2>&1 | grep -oE '"([0-9]+)' | head -1 | tr -d '"')
if [[ -n "$JAVA_VER" ]] && [[ "$JAVA_VER" -lt 25 ]]; then
  osascript -e "display alert \"CaveRenderPro\" message \"Java 25 ou plus récent est requis (trouvé: Java $JAVA_VER). L’app ignore les anciennes versions. Réinstallez avec le script pour inclure Java 25 dans l’app, ou installez Java 25 (adoptium.net).\" as critical"
  exit 1
fi
if [[ ! -f "$JAR" ]]; then
  osascript -e "display alert \"CaveRenderPro\" message \"Fichier introuvable: CaveRenderPro.jar\" as critical"
  exit 1
fi
if [[ ! -d "$JAVAFX_LIB" ]]; then
  osascript -e "display alert \"CaveRenderPro\" message \"JavaFX introuvable dans l'application. Relancez le script d'installation.\" as critical"
  exit 1
fi

cd "$RESOURCES"
if ! "$JAVA_CMD" \
  -Dprism.order=sw \
  -Dprism.text=t2k \
  -Djavafx.macosx.embedded=true \
  --module-path "$JAVAFX_LIB" \
  --add-modules javafx.controls,javafx.fxml,javafx.web \
  -jar "$JAR"; then
  osascript -e "display alert \"CaveRenderPro a quitté avec une erreur\" message \"Consultez le fichier:\n$LOG_FILE\" as critical"
  exit 1
fi
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
  <key>CFBundleIconFile</key>
  <string>CaveRenderPro</string>
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
