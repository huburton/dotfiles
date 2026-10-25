import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true

    // Current state from Hyprland; refreshed on config reloads and monitor changes
    property var monitors: []

    Process {
        id: getMonitors
        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).sort((a, b) => a.x - b.x || a.y - b.y);
                } catch (e) {
                    console.error("[DisplaysConfig] Error parsing monitors:", e);
                }
            }
        }
    }

    // Correction des franges QD-OLED de l'AOC : service oled-fringe (~/.local/bin/oled-fringe),
    // état dans ~/.config/hypr/oled-fringe.json
    readonly property string oledBin: `${Quickshell.env("HOME")}/.local/bin/oled-fringe`
    property var oled: ({ enabled: true, strength: 100, preset: "complet" })

    FileView {
        id: oledState
        path: `${Quickshell.env("HOME")}/.config/hypr/oled-fringe.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.oled = JSON.parse(oledState.text());
            } catch (e) {
                console.error("[DisplaysConfig] oled-fringe.json:", e);
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["configreloaded", "monitoradded", "monitorremoved"].includes(event.name))
                getMonitors.running = true;
        }
    }

    ContentSection {
        icon: "monitor"
        title: "Écrans"

        Repeater {
            model: root.monitors

            delegate: RowLayout {
                id: monitorRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 12

                MaterialSymbol {
                    text: monitorRow.modelData.focused ? "desktop_windows" : "monitor"
                    iconSize: Appearance.font.pixelSize.hugeass
                    color: Appearance.colors.colOnLayer1
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.normal
                        text: `${monitorRow.modelData.name} — ${monitorRow.modelData.make} ${monitorRow.modelData.model}`
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        text: `${monitorRow.modelData.width}×${monitorRow.modelData.height} @ ${Math.round(monitorRow.modelData.refreshRate)} Hz`
                            + ` · échelle ${Number(monitorRow.modelData.scale.toFixed(2)).toLocaleString(Qt.locale("fr_FR"))}`
                            + ` · position ${monitorRow.modelData.x}, ${monitorRow.modelData.y}`
                    }
                }
            }
        }

        RippleButtonWithIcon {
            materialIcon: "display_settings"
            mainText: "Disposition, résolution et fréquence…"
            onClicked: Quickshell.execDetached([`${Quickshell.env("HOME")}/.local/bin/wdisplays-persist`])
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            text: "Ouvre wdisplays (aussi : Super + Ctrl + D). « Apply » applique tout de suite ; la disposition est enregistrée automatiquement et gardée au redémarrage."
        }
    }

    ContentSection {
        icon: "texture"
        title: "Correction OLED (écran AOC)"

        ConfigSwitch {
            buttonIcon: "format_color_text"
            text: "Corriger le liseré rouge sous le texte"
            checked: root.oled.enabled
            onCheckedChanged: {
                if (checked === root.oled.enabled) return;
                Quickshell.execDetached([root.oledBin, checked ? "on" : "off"]);
            }
        }

        ConfigRow {
            enabled: root.oled.enabled
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: root.oled.preset
                onSelected: newValue => Quickshell.execDetached([root.oledBin, "preset", newValue])
                options: [
                    {
                        displayName: "Complète",
                        icon: "blur_on",
                        value: "complet"
                    },
                    {
                        displayName: "Nette",
                        icon: "deblur",
                        value: "net"
                    }
                ]
            }
            ConfigSpinBox {
                icon: "tune"
                text: "Intensité (%)"
                from: 0
                to: 200
                stepSize: 10
                value: root.oled.strength
                onValueChanged: {
                    if (value === root.oled.strength) return;
                    Quickshell.execDetached([root.oledBin, "strength", String(value)]);
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            text: "La dalle QD-OLED a ses sous-pixels en triangle (vert en haut, rouge et bleu en bas) : sans correction, un texte clair a un liseré vert au-dessus et rouge en dessous. La correction recale chaque couleur, uniquement sur l'AOC, et se coupe toute seule en plein écran (jeux, vidéos). « Nette » touche moins à la netteté, « Complète » corrige aussi les bords gauche/droite."
        }
    }
}
