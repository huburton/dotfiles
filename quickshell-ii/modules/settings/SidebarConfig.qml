pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Quick settings panel (right sidebar, Super+N): arrange its tiles, sliders and
// how it opens. Writes Config, which the running shell picks up live.
ContentPage {
    id: root
    forceWidth: true

    readonly property var tileInfo: ({
        "network": { name: "Internet", icon: "wifi" },
        "bluetooth": { name: "Bluetooth", icon: "bluetooth" },
        "audio": { name: "Sortie audio", icon: "volume_up" },
        "mic": { name: "Micro", icon: "mic" },
        "nightLight": { name: "Veilleuse", icon: "bedtime" },
        "darkMode": { name: "Mode sombre", icon: "contrast" },
        "idleInhibitor": { name: "Rester éveillé", icon: "coffee" },
        "powerProfile": { name: "Profil d'énergie", icon: "bolt" },
        "notifications": { name: "Notifications", icon: "notifications_active" },
        "gameMode": { name: "Mode jeu", icon: "gamepad" },
        "screenSnip": { name: "Capture d'écran", icon: "screenshot_region" },
        "colorPicker": { name: "Pipette", icon: "colorize" },
        "onScreenKeyboard": { name: "Clavier virtuel", icon: "keyboard" },
        "easyEffects": { name: "EasyEffects", icon: "graphic_eq" },
        "cloudflareWarp": { name: "Cloudflare WARP", icon: "cloud_lock" },
        "musicRecognition": { name: "Identifier la musique", icon: "music_note" },
        "antiFlashbang": { name: "Anti-éblouissement", icon: "flash_off" },
    })
    readonly property var tiles: (Config.options.sidebar.quickToggles.android.toggles ?? []).filter(t => t && root.tileInfo[t.type])
    readonly property var unusedTypes: Object.keys(root.tileInfo).filter(type => !root.tiles.some(t => t.type === type))

    // Always write a new array so the change is saved and seen by the shell
    function setTiles(list) {
        Config.options.sidebar.quickToggles.android.toggles = list.map(t => ({ type: t.type, size: t.size }));
    }
    function moveTile(index, offset) {
        const list = root.tiles.slice();
        const target = index + offset;
        if (target < 0 || target >= list.length) return;
        [list[index], list[target]] = [list[target], list[index]];
        root.setTiles(list);
    }
    function resizeTile(index) {
        const list = root.tiles.slice();
        list[index] = { type: list[index].type, size: 3 - list[index].size };
        root.setTiles(list);
    }
    function removeTile(index) {
        const list = root.tiles.slice();
        list.splice(index, 1);
        root.setTiles(list);
    }
    function addTile(type) {
        root.setTiles(root.tiles.concat([{ type: type, size: 1 }]));
    }

    ContentSection {
        icon: "dashboard_customize"
        title: "Tuiles du panneau rapide"

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            text: "Dans l'ordre d'affichage. Une tuile large (2) montre aussi son état et ouvre ses détails."
        }

        Repeater {
            model: root.tiles

            delegate: Rectangle {
                id: tileRow
                required property var modelData
                required property int index
                readonly property var info: root.tileInfo[modelData.type]
                Layout.fillWidth: true
                implicitHeight: 56
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 6
                    }
                    spacing: 10

                    Rectangle { // Icon in a tonal circle, like the tile itself
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimaryContainer
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: tileRow.info.icon
                            iconSize: 20
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: tileRow.info.name
                        color: Appearance.colors.colOnLayer1
                    }
                    RippleButton {
                        implicitHeight: 34
                        implicitWidth: sizeLabel.implicitWidth + 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colSecondaryContainer
                        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                        onClicked: root.resizeTile(tileRow.index)
                        contentItem: StyledText {
                            id: sizeLabel
                            horizontalAlignment: Text.AlignHCenter
                            color: Appearance.colors.colOnSecondaryContainer
                            text: tileRow.modelData.size > 1 ? "Large" : "Compacte"
                        }
                        StyledToolTip { text: "Changer la taille" }
                    }
                    Repeater {
                        model: [
                            { icon: "arrow_upward", tip: "Monter", enabled: tileRow.index > 0, action: () => root.moveTile(tileRow.index, -1) },
                            { icon: "arrow_downward", tip: "Descendre", enabled: tileRow.index < root.tiles.length - 1, action: () => root.moveTile(tileRow.index, 1) },
                            { icon: "close", tip: "Retirer", enabled: true, action: () => root.removeTile(tileRow.index) },
                        ]
                        delegate: RippleButton {
                            required property var modelData
                            implicitWidth: 34
                            implicitHeight: 34
                            buttonRadius: Appearance.rounding.full
                            enabled: modelData.enabled
                            onClicked: modelData.action()
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: parent.modelData.icon
                                iconSize: 20
                                opacity: parent.enabled ? 1 : 0.3
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledToolTip { text: parent.modelData.tip }
                        }
                    }
                }
            }
        }

        ContentSubsection {
            title: "Ajouter une tuile"
            visible: root.unusedTypes.length > 0

            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.unusedTypes
                    delegate: RippleButtonWithIcon {
                        required property string modelData
                        materialIcon: root.tileInfo[modelData].icon
                        mainText: root.tileInfo[modelData].name
                        onClicked: root.addTile(modelData)
                    }
                }
            }
        }

        RippleButtonWithIcon {
            materialIcon: "right_panel_open"
            mainText: "Voir le panneau (Super + N)"
            onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "sidebarRight", "open"])
        }
    }

    ContentSection {
        icon: "grid_view"
        title: "Disposition"

        ContentSubsection {
            title: "Style des tuiles"
            ConfigSelectionArray {
                currentValue: Config.options.sidebar.quickToggles.style
                onSelected: newValue => Config.options.sidebar.quickToggles.style = newValue
                options: [
                    { displayName: "Android", icon: "android", value: "android" },
                    { displayName: "Classique", icon: "radio_button_checked", value: "classic" }
                ]
            }
        }

        ConfigSpinBox {
            icon: "view_column"
            text: "Colonnes"
            from: 3
            to: 7
            stepSize: 1
            value: Config.options.sidebar.quickToggles.android.columns
            onValueChanged: Config.options.sidebar.quickToggles.android.columns = value
        }
    }

    ContentSection {
        icon: "tune"
        title: "Curseurs"

        ConfigSwitch {
            buttonIcon: "tune"
            text: "Afficher les curseurs"
            checked: Config.options.sidebar.quickSliders.enable
            onCheckedChanged: Config.options.sidebar.quickSliders.enable = checked
        }
        ConfigRow {
            uniform: true
            enabled: Config.options.sidebar.quickSliders.enable
            ConfigSwitch {
                buttonIcon: "volume_up"
                text: "Volume"
                checked: Config.options.sidebar.quickSliders.showVolume
                onCheckedChanged: Config.options.sidebar.quickSliders.showVolume = checked
            }
            ConfigSwitch {
                buttonIcon: "brightness_6"
                text: "Luminosité"
                checked: Config.options.sidebar.quickSliders.showBrightness
                onCheckedChanged: Config.options.sidebar.quickSliders.showBrightness = checked
            }
            ConfigSwitch {
                buttonIcon: "mic"
                text: "Micro"
                checked: Config.options.sidebar.quickSliders.showMic
                onCheckedChanged: Config.options.sidebar.quickSliders.showMic = checked
            }
        }
    }

    ContentSection {
        icon: "call_to_action"
        title: "Ouverture par le coin de l'écran"

        ConfigSwitch {
            buttonIcon: "open_in_new"
            text: "Ouvrir les panneaux depuis les coins supérieurs"
            checked: Config.options.sidebar.cornerOpen.enable
            onCheckedChanged: Config.options.sidebar.cornerOpen.enable = checked
        }
        ConfigRow {
            uniform: true
            enabled: Config.options.sidebar.cornerOpen.enable
            ConfigSwitch {
                buttonIcon: "mouse"
                text: "Au survol, sans clic"
                checked: Config.options.sidebar.cornerOpen.clickless
                onCheckedChanged: Config.options.sidebar.cornerOpen.clickless = checked
            }
            ConfigSwitch {
                buttonIcon: "swap_vert"
                text: "Molette dans le coin : volume / luminosité"
                checked: Config.options.sidebar.cornerOpen.valueScroll
                onCheckedChanged: Config.options.sidebar.cornerOpen.valueScroll = checked
            }
        }

        // Réglages fins, déplacés depuis Interface › Sidebars (13/10/2026) pour n'avoir qu'une page
        ContentSubsection {
            title: "Zone de déclenchement"
            enabled: Config.options.sidebar.cornerOpen.enable

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "vertical_align_bottom"
                    text: "Coins du bas au lieu du haut"
                    checked: Config.options.sidebar.cornerOpen.bottom
                    onCheckedChanged: Config.options.sidebar.cornerOpen.bottom = checked
                }
                ConfigSwitch {
                    buttonIcon: "visibility"
                    text: "Afficher la zone"
                    checked: Config.options.sidebar.cornerOpen.visualize
                    onCheckedChanged: Config.options.sidebar.cornerOpen.visualize = checked
                }
            }
            ConfigRow {
                ConfigSpinBox {
                    icon: "arrow_range"
                    text: "Largeur (px)"
                    value: Config.options.sidebar.cornerOpen.cornerRegionWidth
                    from: 1
                    to: 300
                    stepSize: 1
                    onValueChanged: Config.options.sidebar.cornerOpen.cornerRegionWidth = value
                }
                ConfigSpinBox {
                    icon: "height"
                    text: "Hauteur (px)"
                    value: Config.options.sidebar.cornerOpen.cornerRegionHeight
                    from: 1
                    to: 300
                    stepSize: 1
                    onValueChanged: Config.options.sidebar.cornerOpen.cornerRegionHeight = value
                }
            }
            ConfigRow {
                enabled: !Config.options.sidebar.cornerOpen.clickless
                ConfigSwitch {
                    buttonIcon: "highlight_mouse_cursor"
                    text: "Survol tout au bout du coin quand même"
                    checked: Config.options.sidebar.cornerOpen.clicklessCornerEnd
                    onCheckedChanged: Config.options.sidebar.cornerOpen.clicklessCornerEnd = checked
                }
                ConfigSpinBox {
                    icon: "arrow_cool_down"
                    text: "décalage vertical"
                    value: Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset
                    from: 0
                    to: 20
                    stepSize: 1
                    onValueChanged: Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset = value
                }
            }
        }
    }

    ContentSection {
        icon: "side_navigation"
        title: "Panneaux latéraux"

        ConfigSwitch {
            buttonIcon: "memory"
            text: "Garder le panneau de droite chargé (ouverture instantanée, ~15 Mo de RAM)"
            checked: Config.options.sidebar.keepRightSidebarLoaded
            onCheckedChanged: Config.options.sidebar.keepRightSidebarLoaded = checked
        }
        ConfigSwitch {
            buttonIcon: "translate"
            text: "Traducteur dans le panneau de gauche"
            checked: Config.options.sidebar.translator.enable
            onCheckedChanged: Config.options.sidebar.translator.enable = checked
        }
    }
}
