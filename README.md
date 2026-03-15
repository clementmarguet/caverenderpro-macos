# CaveRenderPro — installation sur macOS

Script d’installation pour faire tourner [CaveRenderPro](https://www.caverender.de/) sur Mac (Apple Silicon et Intel), avec Java et JavaFX gérés automatiquement. L’application est installée dans le dossier **Applications** et se lance comme une app Mac classique.

## Installation en une commande

Ouvrez **Terminal** et collez :

```bash
curl -fsSL "https://raw.githubusercontent.com/clementmarguet/caverenderpro-macos/main/Install-CaveRenderPro.command" | sed 's/\r$//' > /tmp/Install-CaveRenderPro.command && chmod +x /tmp/Install-CaveRenderPro.command && /tmp/Install-CaveRenderPro.command
```


## Installation manuelle

1. Cloner ou télécharger ce dépôt.
2. Double-cliquer sur `Install-CaveRenderPro.command`.
3. Si macOS bloque l’exécution : **Préférences Système > Sécurité et confidentialité** → « Ouvrir quand même ».

Voir aussi `LISEZMOI.txt` pour le détail des étapes.

## Prérequis

- macOS (Apple Silicon ou Intel)
- Connexion Internet
- **Java 25** : le script l’installe via [Homebrew](https://brew.sh). Si Homebrew n’est pas installé, le script le propose (installation officielle, mot de passe admin demandé), puis installe Java 25 (Temurin).

## Licence

CaveRenderPro © Jochen Hartig — [caverender.de](https://www.caverender.de/).  
Ce dépôt ne contient que des scripts d’installation pour macOS.
