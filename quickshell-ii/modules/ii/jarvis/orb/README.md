# Orbe Jarvis pour ii (Quick3D)

Portage dans Quickshell de l'orbe web `jarvis-orb.js` (composant web de Jarvis) : même réseau (même graine),
mêmes shaders GLSL, mêmes états et transitions. Utilisée par `../Jarvis.qml` quand `jarvis-ui.json` dit
`"style": "orb"`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `JarvisOrb.qml` | composant autonome (QtQuick + QtQuick3D, aucune dépendance à ii) : état, niveau, palette, réglages |
| `geometry.js` | construction du réseau (portage de `buildGeometry`), en cache par qualité |
| `shaders/*.vert, *.frag` | shaders Quick3D **générés** par `gen-shaders.py` à partir du JS web : ne pas les éditer à la main |
| `gen-shaders.py` | régénère `shaders/` depuis `jarvis-orb.js` (chemin en argument) |

## Réglages (`../jarvis-ui.json`, relu à chaud, sans recharger ii)

| Clé | Défaut | Effet |
|---|---|---|
| `style` | `"orb"` | `"pill"` = ancienne pastille (retour arrière immédiat) |
| `palette` | `"blue"` | `blue`, `gold` (film), `ii`, `cyan`, ou `{"deep":[r,g,b],"mid":[…],"hot":[…]}` (0..1) |
| `confirmPalette` | `"gold"` | teinte pendant une demande de confirmation |
| `size` | `220` | côté de l'orbe en px logiques |
| `quality` | `1` | 0 = 1100 nœuds … 4 = 180 nœuds (densité du réseau) |
| `intensity` | `1.0` | luminosité globale |
| `glowScale` | `1.0` | taille du halo du cœur |
| `lineWidth` | `1.0` | épaisseur des filaments |
| `ringBrightness` | `1.0` | anneaux HUD |
| `pointScale` | `1.0` | taille des nœuds et de la poussière |
| `backdrop` | `0.8` | disque sombre derrière l'orbe (contraste sur fond clair), 0 = aucun |
| `fps` | `60` | images/s de l'animation (plafond, quel que soit le rafraîchissement de l'écran) |

Pour aller plus loin (style « L'Ère d'Ultron ») : les cibles de chaque état sont dans `stateTargets`
(`JarvisOrb.qml`), les couleurs dans `palettes`, le rendu dans les shaders (à retoucher côté web puis
`gen-shaders.py`, pour garder les deux versions identiques).

## Fonctionnement

- Apparition : comme l'ancienne pastille (écoute, réflexion, parole, confirmation, puis 2,5 s après la réponse),
  fondu d'entrée/sortie. En veille, la fenêtre et la scène 3D n'existent pas : coût nul.
- Jamais sur un jeu : couche `top` (une fenêtre plein écran passe devant) et, si l'écran focalisé a une fenêtre
  plein écran, l'orbe va sur un autre écran libre (ou ne s'affiche pas).
- Niveau sonore : `$XDG_RUNTIME_DIR/jarvis/level` (nombre 0..1, écrit par le démon à ~16 Hz en écoute/parole),
  lu seulement quand l'orbe est affichée. Sans ce fichier : animation selon l'état, enveloppe de parole synthétique.
- Si l'orbe ne se charge pas (QtQuick3D absent, erreur QML), `Jarvis.qml` repasse tout seul sur la pastille.

## Différences techniques avec le web

- Quick3D n'a que des attributs standard : `aB` passe par `uv0`+`uv1`, les nœuds sont des quads (pas de `gl_PointCoord`).
- Pas d'inclinaison vers le pointeur ni de qualité adaptative (la qualité est fixée par `quality`).
- Cadence plafonnée par un Timer (`fps`) au lieu de requestAnimationFrame : l'écran principal est à 360 Hz.

## Test hors écran

Banc et comparaison côte à côte : `~/Projets/jarvis-orbe-dev/test/compare.sh` (Xvfb + Chromium headless,
rien ne s'affiche sur le bureau).
