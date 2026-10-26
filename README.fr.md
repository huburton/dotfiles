# dotfiles : mon bureau Arch Linux + Hyprland

*[English version](README.md)*

La configuration du PC que j'utilise tous les jours : Arch Linux, Hyprland configuré en **Lua**, un shell
[Quickshell](https://quickshell.org) basé sur [illogical-impulse](https://github.com/end-4/dots-hyprland) (ii)
d'end-4, trois écrans et une NVIDIA RTX 5080, en double démarrage avec Windows sous Secure Boot.

C'est l'instantané d'une machine qui tourne, pas un installateur. Les chemins, les noms d'écrans et les codes
de touches correspondent à mon matériel : adaptez-les avant de réutiliser quoi que ce soit.

## À quoi ça ressemble

![Les trois écrans dans leur disposition réelle](docs/img/desktop-three-monitors.webp)

*Images enregistrées le 26/09/2026, placées comme les écrans sur le bureau : l'ultrawide 34" en haut (mon
tableau de bord), le 27" QD-OLED en bas à gauche (kitty), le 27" 144 Hz en bas à droite (btop). Deux zones
privées du tableau de bord sont floutées.*

![Espaces de travail par écran](docs/img/workspaces.svg)

| Écran principal (QD-OLED, 360 Hz) | Écran latéral |
|---|---|
| ![kitty sur l'écran OLED](docs/img/oled-main-kitty.webp) | ![btop sur l'écran latéral](docs/img/side-monitor-btop.webp) |

## Ce qu'il contient

| Partie | Rôle |
|---|---|
| `hypr/hyprland.lua`, `config.lua`, `binds.lua` | Toute la configuration de Hyprland en Lua : réglages, règles de fenêtres, plus de 160 raccourcis. Chaque raccourci porte une `description = "Section\|Texte"` que le shell lit en direct pour construire l'aide-mémoire. |
| `hypr/workspaces.lua` | Espaces de travail par écran (1–10, 11–20, 21–30) et une petite API Lua utilisée par les raccourcis et le shell. |
| `hypr/tests/workspaces-test.py` | Test de non-régression avec de vraies entrées clavier et souris : 155 vérifications sur les trois écrans. |
| `hypr/monitors-<hostname>.lua` | Disposition des écrans par machine, écrite par `bin/hypr-monitors-save` pendant que `wdisplays` est ouvert. |
| `hypr/shaders/qdoled-fringe.frag` + `bin/oled-fringe` | Correction des franges colorées de la dalle QD-OLED. |
| `bin/wallpaper-video` | Fond d'écran vidéo avec garde-fous GPU/CPU et repli sur une image fixe. |
| `bin/oled-screensaver`, `hypr/hypridle.conf` | Économiseur d'écran après deux minutes d'inactivité, rien de plus. |
| `bin/session-daemons`, `bin/hyprland-conf-session` | Démarrage et surveillance de la session, reverrouillage après un plantage du shell. |
| `bin/ai-mode`, `bin/pc-status` | Confier le GPU à un serveur de LLM local, puis le récupérer. |
| `system/sbin/maj-auto` + unités | Mises à jour automatiques, le groupe du noyau étant installé à l'extinction puis vérifié. |
| `quickshell-ii/` | Seulement les fichiers que j'ai ajoutés à ii. Voir [`quickshell-ii/README.md`](quickshell-ii/README.md). |
| `docs/secure-boot.md` | La chaîne shim → GRUB → image noyau unifiée. |

## Ce que j'ai adapté, en détail

### 1. Hyprland en Lua, sur hyprland-git

**Problème.** J'utilise Hyprland compilé depuis git pour avoir la configuration en Lua. Cette version ne lit plus
du tout les fichiers `.conf` ni les lignes `source=` : toute la configuration de ii, écrite en `.conf`, était
ignorée sans le moindre message.

**Ce qui ne marchait pas.** Plusieurs choses échouent sans erreur :
- les clés d'options Lua inconnues sont ignorées : `window.move{ silent = true }` ne fait rien (l'option s'appelle
  `follow = false`), et l'option de raccourci `repeat_key` ne fait rien (elle s'appelle `repeating`) ;
  `hyprctl eval` détecte les mauvais types et les clés manquantes, pas les clés inconnues ;
- `hyprctl dispatch X` exécute maintenant `return hl.dispatch(X)` : l'ancienne syntaxe texte ne marche plus, et
  chaque appel doit passer du Lua, par exemple `hyprctl dispatch 'hl.dsp.focus({ workspace = "3" })'` ;
- les arguments numériques de `hl.dsp.window.fullscreen(n)` sont ignorés : la fenêtre passe toujours en plein
  écran. Pour maximiser, c'est `{ mode = "maximized" }` ;
- dans `hyprctl monitors all -j`, le champ `disabled` vaut `true` pour les écrans actifs sur cette version. Lui
  avoir fait confiance a écrit un jour `disabled = true` pour les trois écrans, et le rechargement suivant les a
  tous éteints.

**Solution.** `hyprland.lua` charge `config.lua`, `workspaces.lua`, `binds.lua`, les surcharges du shell, puis
`monitors-<hostname>.lua` (avec `monitors.lua` en repli), parce que `~/.config` est partagé en NFS avec mon
portable. Les 21 appels de dispatch du QML du shell ont été portés vers les dispatchers Lua. L'outil qui
enregistre les écrans ne se fie qu'à `hyprctl monitors -j` (les sorties actives), et un fichier d'écrans généré
est comparé à l'état réel avant tout rechargement.

### 2. Des espaces de travail attachés à un écran

**Problème.** Avec trois écrans, Hyprland gère par défaut une seule liste globale d'espaces de travail :
Super+3 peut amener l'espace 3 sur l'écran qui a le focus, et la disposition se dérègle au fil de la journée.

**Solution.** Chaque écran possède dix numéros, comme les Spaces de macOS : l'ultrawide 1–10, l'écran latéral
11–20, l'OLED 21–30 (schéma ci-dessus). `workspaces.lua` déclare les règles et une API globale `hypr_ws` :
`go(n)` ouvre l'espace *n* de l'écran **sous la souris**, `move(n)` envoie la fenêtre active vers l'espace *n* de
son propre écran, `rel(±1)` avance ou recule dans la plage sans boucler, et `focus_id(id)` affiche un numéro sur
l'écran qui le possède et le ramène s'il est mal placé. Tout tourne dans l'état Lua de Hyprland : un raccourci
ne coûte aucun aller-retour `hyprctl`. La barre et la vue d'ensemble du shell utilisent la même API.

**Côté shell.** Sur cette version, les objets d'espaces de travail Hyprland de Quickshell sont faux : le JSON ne
contient pas l'identifiant de l'espace, si bien que chaque écran annonce l'espace actif comme le sien. Le shell lit
donc `hyprctl … -j` lui-même (`services/HyprlandData.qml`), avec des fonctions par écran. Son rafraîchissement est
regroupé (120 ms) : un titre de fenêtre animé (l'indicateur d'attente d'un terminal) déclenche environ quatre
événements par seconde et lançait des dizaines de processus `hyprctl` par seconde.

### 3. Tester les raccourcis avec de vraies entrées

**Problème.** `wtype` envoie des touches à la fenêtre active, mais ne déclenche pas les raccourcis du compositeur :
il ne permet pas de les tester.

**Solution.** `hypr/tests/workspaces-test.py` pilote `ydotool` (entrées au niveau du noyau) et vérifie le résultat
avec `hyprctl -j` : rangée des chiffres et pavé numérique, variantes avec Shift et Alt, déplacements relatifs,
position de la souris sur chaque écran, clics sur la barre. 155 vérifications, environ trois minutes, sans toucher
à la souris ; les espaces de travail sont remis en place à la fin. Le test passait à 155/155 une fois le modèle
d'espaces de travail terminé.

### 4. AZERTY et codes de touches

Hyprland compare le keysym **sans Shift**. En AZERTY, la rangée des chiffres produit `&é"'(-è_çà` sans Shift :
`Super + 1` ne se déclenche donc jamais, et `/` ou `.` (au niveau Shift) ne correspondent jamais à
`Super + Slash` ou `Period`. Les raccourcis d'espaces de travail utilisent donc les codes de touches (`code:10` à
`code:19`), qui ne dépendent pas de la disposition. Un autre jeu de raccourcis fait se comporter Ctrl+Alt comme
AltGr, comme sous Windows : `Ctrl + Alt + code:N` envoie la même touche avec `MOD5`. Une solution au niveau de XKB
n'a pas marché : Zen ne tapait plus rien et kitty ignorait le niveau tant que Ctrl ou Alt étaient enfoncés.

### 5. Franges colorées sur la dalle QD-OLED

**Problème.** L'écran principal (un AOC à 360 Hz) a une dalle QD-OLED. Ses sous-pixels sont des triangles : vert en
haut, rouge en bas à gauche, bleu en bas à droite. Un texte clair sur fond sombre prend une bordure verte au-dessus
et magenta en dessous. Les polices étaient déjà rendues en niveaux de gris : le défaut vient de la géométrie de la
dalle, pas du rendu des polices.

**Solution.** `bin/oled-fringe` génère un shader d'écran Hyprland (`qdoled-fringe.frag`, vérifié avec
`glslangValidator`) qui rééchantillonne chaque canal de couleur à la position réelle de son sous-pixel, en lumière
linéaire. Il n'agit que si la taille de la texture correspond à la résolution de cet écran : les deux autres écrans
passent sans changement. L'orientation est déduite de `dFdy` sur les coordonnées de texture. Le preset `complet`
(vert −0,25 px, rouge et bleu +0,25 px à la verticale et ±0,20 px à l'horizontale) l'a emporté sur un preset plus
net lors d'une comparaison côte à côte ; `oled-fringe ab` alterne deux presets toutes les trois secondes pour ce
genre de comparaison.

Un service utilisateur gère ce réglage de shader. Il le réapplique après chaque rechargement de la configuration
(l'écran de verrouillage recharge la configuration à chaque verrouillage et déverrouillage), le retire tant qu'une
vraie fenêtre plein écran occupe cet écran (les jeux), et n'écrase jamais un autre shader, comme le filtre
anti-flashbang de ii. Les captures d'écran n'incluent pas le shader d'écran : l'effet ne se juge que sur l'écran
lui-même.

### 6. Fond d'écran vidéo avec garde-fous

**Problème.** Un soir, le fond d'écran (`mpvpaper`) a consommé 500 % de CPU. Une mise à jour des bibliothèques
NVIDIA avait été installée pendant la session : elles ne correspondaient plus au module noyau chargé, et chaque
nouveau `mpvpaper` décodait et affichait sur le CPU. En plus, ii lançait une instance par écran, environ 1,3 Go
de VRAM chacune, et l'économiseur d'écran en lançait trois de plus.

**Solution.** `bin/wallpaper-video` tourne comme service utilisateur et lance **un seul** `mpvpaper` pour toutes
les sorties (environ 1,5 Go de VRAM au total, en pause quand il est caché). Avant de démarrer, il vérifie que
`nvidia-smi` répond et qu'au moins 2 Go de VRAM sont libres. Il arrête le lecteur au-delà de 40 % d'un cœur sur
30 s, le relance au-delà de 2,5 Go de mémoire, espace les redémarrages en cas de plantages répétés et, dans tous
les cas d'échec, revient à une image fixe et envoie une seule notification. Le sélecteur de fond d'écran de ii
l'appelle au lieu de lancer ses propres lecteurs. La vraie cause, les mises à jour du pilote en pleine session,
est traitée par le script de mises à jour (section 8).

### 7. Surveillance de la session et reverrouillage

**Problème.** Si le shell (`qs`) plantait, la barre, les notifications et l'écran de verrouillage disparaissaient
jusqu'à la connexion suivante. S'il plantait pendant que l'écran était verrouillé, Hyprland restait sur sa page
« lock screen crashed ».

**Solution.** `bin/session-daemons` tient un fichier de verrou et fait tourner des boucles de maintien en vie
pour le shell, le démon d'inactivité, celui des scratchpads et l'historique du presse-papiers : un processus qui
s'arrête est relancé après une seconde, ou après dix s'il a vécu moins de trente secondes. L'écran de
verrouillage écrit un fichier témoin dans `$XDG_RUNTIME_DIR` tant qu'il est actif ; un shell qui démarre alors que
ce témoin existe se verrouille aussitôt. Testé avec `kill -9` sur le shell : les barres sont revenues sur les trois
écrans. Un contrôle de santé de la barre (via `hyprctl layers`) a remplacé un ancien redémarrage à l'aveugle
au bout de cinq secondes.

### 8. Mises à jour automatiques, avec le noyau vérifié avant le démarrage suivant

**Problème.** Tout mettre à jour en pleine session casse des choses : les bibliothèques NVIDIA ne correspondent
plus au module chargé, un nouveau Qt ne correspond plus au shell en cours, un nouveau `hyprctl` ne correspond plus
au Hyprland en cours. À l'inverse, l'image noyau unifiée doit être reconstruite et signée, sinon le démarrage
suivant échoue sous Secure Boot.

**Solution.** `system/sbin/maj-auto`, lancé par systemd :
- `fond` (minuteur toutes les heures, vrai passage au plus toutes les 20 h) : ne fait rien pendant un jeu ou
  pendant `pacman`, se met en pause quand une actualité d'Arch annonce une intervention manuelle, installe tout
  sauf un « groupe à redémarrage » (noyau, NVIDIA, Hyprland, Qt, Quickshell) qu'il se contente de télécharger,
  met à jour les Flatpaks et envoie une notification ;
- `extinction` (à l'arrêt de la machine) : installe le groupe à redémarrage, puis vérifie que le module DKMS
  NVIDIA existe pour le nouveau noyau (sinon il le reconstruit), que l'UKI contient bien cette version du noyau (sa
  section `.uname`, sinon reconstruction avec `mkinitcpio -P`) et qu'elle est signée. Le résultat s'affiche en
  notification à la connexion suivante ;
- les paquets AUR ne sont jamais mis à jour automatiquement, seulement signalés.

### 9. Double démarrage avec Secure Boot

L'anti-triche d'un jeu côté Windows exige Secure Boot : Linux démarre donc avec Secure Boot actif, via
shim → GRUB → une image noyau unifiée signée. Les détails (modules GRUB embarqués, SBAT, pourquoi une UKI a réglé
un écran noir, hooks de re-signature) sont dans [`docs/secure-boot.md`](docs/secure-boot.md).

### 10. Partager le GPU avec un LLM local

**Problème.** La RTX 5080 sert aussi un modèle de langage local pour mes autres projets. Le modèle a besoin de
presque toute la VRAM, et le fond d'écran vidéo en prend 1,5 Go.

**Solution.** `bin/ai-mode on` met en pause le fond d'écran vidéo (image fixe, VRAM libérée) ; `ai-mode off` le
relance, et le service de fond d'écran attend qu'il y ait assez de VRAM libre. `bin/pc-status` expose l'état en
HTTP à mon serveur maison, protégé par la clé du serveur de modèles local, et active le mode IA de lui-même quand
l'économiseur d'écran de l'OLED tourne depuis dix minutes. En mode IA, l'économiseur ne couvre que l'écran OLED,
avec une petite vidéo décodée par le CPU.

## Petites choses

- Lanceur d'applications : celui de ii n'a pas de liste d'exclusion, donc `bin/hide-apps` écrit des copies
  masquées des fichiers `.desktop` que je ne veux pas voir ; une unité « path » le relance à chaque changement de
  paquets.
- Les écrans se règlent avec `wdisplays`, qui applique une disposition en direct mais n'enregistre rien ;
  `bin/wdisplays-persist` enregistre la disposition en cours toutes les deux secondes tant qu'il est ouvert.
- Les commentaires sont en partie en français, la langue dans laquelle je travaille.

## Arborescence

```
hypr/            Hyprland (Lua), shader, tests
bin/             session and desktop scripts (~/.local/bin)
systemd/user/    user units for the services above
system/          root-owned parts (updates), installed by hand
quickshell-ii/   my additions to end-4's illogical-impulse shell
docs/            Secure Boot notes, images
```

## Licence

GPL-3.0, comme illogical-impulse, puisque `quickshell-ii/` s'appuie dessus. Voir [LICENSE](LICENSE).
