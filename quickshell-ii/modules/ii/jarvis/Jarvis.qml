import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Interface de l'assistant vocal Jarvis (~/Projets/jarvis) : écoute / réflexion / réponse / confirmation.
// Le démon écrit son état dans $XDG_RUNTIME_DIR/jarvis/state.json ; clic = interrompre.
// Deux styles, au choix dans jarvis-ui.json (à côté de ce fichier, relu à chaud) :
//   "orb"  : l'orbe neuronale de la version web (orb/JarvisOrb.qml, Quick3D), texte dessous ;
//   "pill" : l'ancienne pastille (retour arrière). Si l'orbe ne se charge pas, la pastille prend le relais.
Scope {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property string jarvisState: "idle"
    property string heard: ""
    property string reply: ""
    property bool lingering: false // garde la dernière réponse affichée un instant après la fin
    readonly property bool active: jarvisState !== "idle" || lingering

    // --- Réglages (jarvis-ui.json) ; valeurs par défaut si le fichier manque ou est invalide
    readonly property var uiDefaults: ({
        style: "orb", palette: "blue", size: 220, quality: 1, intensity: 1.0,
        glowScale: 1.0, lineWidth: 1.0, ringBrightness: 1.0, pointScale: 1.0, backdrop: 0.8, fps: 60,
        confirmPalette: "gold"
    })
    property var ui: uiDefaults
    property bool orbFailed: false
    readonly property bool useOrb: ui.style !== "pill" && !orbFailed

    // L'orbe ne se pose jamais sur un écran occupé par une fenêtre en plein écran (jeu) :
    // écran focalisé sinon un autre écran libre, sinon rien.
    readonly property var orbScreen: {
        const f = root.focusedScreen;
        if (f && !HyprlandData.hasFullscreenOn(f.name)) return f;
        return Quickshell.screens.find(s => !HyprlandData.hasFullscreenOn(s.name)) ?? null;
    }

    readonly property var labels: ({
        "listening": "J'écoute…",
        "thinking": "Je réfléchis…",
        "speaking": "Jarvis",
        "confirm": "Confirmation",
        "idle": "Jarvis"
    })
    readonly property var icons: ({
        "listening": "mic",
        "thinking": "neurology",
        "speaking": "graphic_eq",
        "confirm": "help",
        "idle": "graphic_eq"
    })
    readonly property string shownText: (root.jarvisState === "speaking" || root.jarvisState === "confirm" || root.lingering)
        ? root.reply : root.heard

    function applyState(text) {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return; // lecture pendant l'écriture : on garde l'état précédent
        }
        if (root.jarvisState !== "idle" && d.state === "idle" && root.reply !== "") {
            root.lingering = true;
            lingerTimer.restart();
        }
        root.jarvisState = d.state ?? "idle";
        root.heard = d.heard ?? "";
        root.reply = d.reply ?? "";
    }

    function applyUi(text) {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            // lecture pendant l'écriture (fichier vide) ou faute de frappe : on garde les réglages en cours
            if (text.trim() !== "") console.warn("[jarvis] jarvis-ui.json invalide, réglages inchangés :", e);
            return;
        }
        root.ui = Object.assign({}, root.uiDefaults, d);
    }

    Timer {
        id: lingerTimer
        interval: 2500
        onTriggered: root.lingering = false
    }

    FileView {
        id: stateFile
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/jarvis/state.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyState(text())
    }

    Timer {
        // Filet de sécurité si une notification de fichier est manquée (tmpfs, lecture quasi gratuite)
        interval: 1000
        repeat: true
        running: true
        onTriggered: stateFile.reload()
    }

    FileView {
        id: uiFile
        path: Quickshell.shellPath("modules/ii/jarvis/jarvis-ui.json").toString().replace(/^file:\/\//, "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyUi(text())
        onLoadFailed: root.ui = root.uiDefaults
    }

    // --- Niveau sonore (micro en écoute, voix en réponse) : $XDG_RUNTIME_DIR/jarvis/level, un nombre 0..1
    // écrit par le démon à ~16 Hz. Lu seulement quand l'orbe est affichée en écoute/réponse.
    property real level: 0
    property bool levelAvailable: false
    readonly property bool wantsLevel: root.useOrb && (root.jarvisState === "listening" || root.jarvisState === "speaking" || root.jarvisState === "confirm")
    signal levelSample(real v)
    FileView {
        id: levelFile
        path: root.wantsLevel ? `${Quickshell.env("XDG_RUNTIME_DIR")}/jarvis/level` : ""
        watchChanges: root.wantsLevel
        onFileChanged: reload()
        onLoaded: {
            root.levelAvailable = true;
            const v = parseFloat(text());
            if (!isNaN(v)) root.levelSample(Math.max(0, Math.min(1, v)));
        }
        onLoadFailed: root.levelAvailable = false
    }
    Timer {
        // relève régulière (en plus de inotify) tant que le fichier existe et qu'on en a besoin
        interval: 66
        repeat: true
        running: root.wantsLevel && root.levelAvailable
        onTriggered: levelFile.reload()
    }

    // ------------------------------------------------------------------ Orbe
    // Garde la fenêtre 300 ms après la fin pour le fondu de sortie.
    property bool orbShown: false
    onActiveChanged: if (active) orbShown = true; else orbHideTimer.restart()
    Timer {
        id: orbHideTimer
        interval: 320
        onTriggered: if (!root.active) root.orbShown = false
    }

    LazyLoader {
        id: orbLoader
        active: root.useOrb && root.orbShown && root.orbScreen !== null

        component: PanelWindow {
            id: orbWindow
            color: "transparent"
            screen: root.orbScreen

            WlrLayershell.namespace: "quickshell:jarvis"
            // Top (pas Overlay) : un jeu en plein écran passe devant, en plus du choix d'écran ci-dessus.
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            anchors.top: true
            margins.top: Appearance.sizes.barHeight + 4
            mask: Region { item: content }

            readonly property int orbSize: root.ui.size ?? 220
            // Taille fixe (place pour 3 lignes de texte) : pas de redimensionnement de la surface à chaque phrase ;
            // la partie vide est transparente et ne prend pas les clics (mask).
            implicitWidth: Math.max(orbSize, 560) + 40
            implicitHeight: orbSize + 140

            Item {
                id: content
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: Math.max(orbArea.width, textCard.visible ? textCard.width : 0)
                height: orbArea.height + (textCard.visible ? textCard.height + 4 : 0)
                property bool entered: false
                Component.onCompleted: entered = true
                opacity: root.active && entered ? 1 : 0
                scale: root.active && entered ? 1 : 0.9
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["jarvis-ctl", "stop"])
                }

                Item {
                    id: orbArea
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: orbWindow.orbSize
                    height: orbWindow.orbSize

                    // Fond sombre radial : garde le contraste de l'orbe (rendu additif) sur un fond d'écran clair
                    Shape {
                        anchors.fill: parent
                        visible: (root.ui.backdrop ?? 0) > 0 && orbItemLoader.status === Loader.Ready
                        opacity: root.ui.backdrop ?? 0.8
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: -1
                            fillGradient: RadialGradient {
                                centerX: orbArea.width / 2; centerY: orbArea.height / 2
                                focalX: centerX; focalY: centerY
                                centerRadius: orbArea.width / 2
                                GradientStop { position: 0.0; color: "#e6020409" }
                                GradientStop { position: 0.62; color: "#99020409" }
                                GradientStop { position: 1.0; color: "#00020409" }
                            }
                            PathAngleArc {
                                centerX: orbArea.width / 2; centerY: orbArea.height / 2
                                radiusX: orbArea.width / 2; radiusY: orbArea.height / 2
                                startAngle: 0; sweepAngle: 360
                            }
                        }
                    }

                    Loader {
                        id: orbItemLoader
                        anchors.fill: parent
                        source: Qt.resolvedUrl("orb/JarvisOrb.qml")
                        onStatusChanged: if (status === Loader.Error) {
                            console.warn("[jarvis] orbe indisponible, retour à la pastille");
                            Qt.callLater(() => root.orbFailed = true); // hors de la liaison du LazyLoader
                        }
                        onLoaded: {
                            item.shaderBase = Quickshell.shellPath("modules/ii/jarvis/orb/shaders/");
                        }
                    }
                    Binding { target: orbItemLoader.item; when: orbItemLoader.status === Loader.Ready; property: "jarvisState"
                        value: root.jarvisState === "confirm" ? "listening" : root.jarvisState }
                    Binding { target: orbItemLoader.item; when: orbItemLoader.status === Loader.Ready; property: "orbPalette"
                        value: root.jarvisState === "confirm" ? (root.ui.confirmPalette ?? "gold") : (root.ui.palette ?? "blue") }
                    Binding { target: orbItemLoader.item; when: orbItemLoader.status === Loader.Ready; property: "quality"; value: root.ui.quality ?? 1 }
                    Binding { target: orbItemLoader.item; when: orbItemLoader.status === Loader.Ready; property: "intensity"; value: root.ui.intensity ?? 1 }
                    Binding { target: orbItemLoader.item; when: orbItemLoader.status === Loader.Ready; property: "glowScale"; value: root.ui.glowScale ?? 1 }
                    Binding { target: orbItemLoader.item; when: orbItemLoader.status === Loader.Ready; property: "lineWidth"; value: root.ui.lineWidth ?? 1 }
                    Binding { target: orbItemLoader.item; when: orbItemLoader.status === Loader.Ready; property: "ringBrightness"; value: root.ui.ringBrightness ?? 1 }
                    Binding { target: orbItemLoader.item; when: orbItemLoader.status === Loader.Ready; property: "pointScale"; value: root.ui.pointScale ?? 1 }
                    Binding { target: orbItemLoader.item; when: orbItemLoader.status === Loader.Ready; property: "fps"; value: root.ui.fps ?? 60 }
                    Connections {
                        target: root
                        function onLevelSample(v) { orbItemLoader.item?.setLevel(v); }
                    }
                }

                // Texte (ce que Jarvis a entendu, puis sa réponse) sous l'orbe
                Rectangle {
                    id: textCard
                    visible: root.shownText !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: orbArea.bottom
                    anchors.topMargin: 4
                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    radius: Appearance.rounding.normal
                    implicitWidth: Math.min(textCol.implicitWidth + 28, 560)
                    implicitHeight: textCol.implicitHeight + 16
                    width: implicitWidth
                    height: implicitHeight

                    ColumnLayout {
                        id: textCol
                        anchors.centerIn: parent
                        width: parent.width - 28
                        spacing: 1
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.labels[root.jarvisState] ?? "Jarvis"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 532
                            horizontalAlignment: Text.AlignHCenter
                            text: root.shownText
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ Ancienne pastille (style "pill")
    Loader {
        id: pillLoader
        active: root.active && !root.useOrb

        sourceComponent: PanelWindow {
            id: pillWindow
            color: "transparent"
            screen: root.focusedScreen

            WlrLayershell.namespace: "quickshell:jarvis"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            anchors.top: true
            margins.top: Appearance.sizes.barHeight + 10
            mask: Region { item: pill }

            implicitWidth: pill.implicitWidth + 30
            implicitHeight: pill.implicitHeight + 30

            StyledRectangularShadow {
                target: pill
            }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: height / 2
                implicitHeight: row.implicitHeight + 20
                implicitWidth: Math.min(row.implicitWidth + 28, 620)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["jarvis-ctl", "stop"])
                }

                RowLayout {
                    id: row
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    spacing: 12

                    Rectangle {
                        id: orb
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 38
                        implicitHeight: 38
                        radius: width / 2
                        color: root.jarvisState === "confirm" ? Appearance.colors.colError
                            : root.jarvisState === "thinking" ? Appearance.colors.colTertiary
                            : Appearance.colors.colPrimary

                        SequentialAnimation on scale {
                            running: root.jarvisState === "listening" || root.jarvisState === "speaking"
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 1.12; duration: 520; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutSine }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.icons[root.jarvisState] ?? "graphic_eq"
                            iconSize: 22
                            fill: 1
                            color: root.jarvisState === "confirm" ? Appearance.colors.colOnError
                                : root.jarvisState === "thinking" ? Appearance.colors.colOnTertiary
                                : Appearance.colors.colOnPrimary
                            RotationAnimation on rotation {
                                running: root.jarvisState === "thinking"
                                from: 0; to: 360; duration: 1600
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) parent.rotation = 0
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        StyledText {
                            text: root.labels[root.jarvisState] ?? "Jarvis"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 540
                            visible: text !== ""
                            text: root.shownText
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
