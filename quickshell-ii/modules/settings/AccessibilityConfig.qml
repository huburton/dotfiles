import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.models.hyprland
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true

    property HyprlandConfigOption zoomOpt: HyprlandConfigOption { key: "cursor:zoom_factor" }
    property HyprlandConfigOption animationsOpt: HyprlandConfigOption { key: "animations:enabled" }

    ContentSection {
        icon: "zoom_in"
        title: "Loupe"

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            text: "Agrandit l'écran autour du curseur. Aussi : Super + = / Super + − (ou + / − du pavé numérique)."
        }
        ConfigSlider {
            buttonIcon: "zoom_in"
            text: "Agrandissement"
            from: 1.0
            to: 3.0
            usePercentTooltip: false
            value: root.zoomOpt.value ?? 1
            onValueChanged: {
                if (root.zoomOpt.value === undefined || Math.abs(value - root.zoomOpt.value) < 0.02) return;
                root.zoomOpt.value = value;
                // Live only, like the zoom keys: it resets when the session restarts
                Quickshell.execDetached(["hyprctl", "eval", `hl.config({ cursor = { zoom_factor = ${value.toFixed(2)} } })`]);
            }
        }
    }

    ContentSection {
        icon: "visibility"
        title: "Vision et confort"

        ConfigSwitch {
            buttonIcon: "animation"
            text: "Réduire les animations"
            checked: root.animationsOpt.value !== undefined && !root.animationsOpt.value
            onCheckedChanged: {
                if (root.animationsOpt.value === undefined || checked === !root.animationsOpt.value) return;
                root.animationsOpt.value = !checked;
                if (checked) HyprlandConfig.set("animations:enabled", 0);
                else HyprlandConfig.reset("animations:enabled");
            }
        }
        ConfigSwitch {
            buttonIcon: "opacity"
            text: "Transparence des panneaux (désactiver pour plus de lisibilité)"
            checked: Config.options.appearance.transparency.enable
            onCheckedChanged: Config.options.appearance.transparency.enable = checked
        }
        RippleButtonWithIcon {
            materialIcon: "bedtime"
            mainText: "Veilleuse (filtre lumière bleue) : dans le panneau rapide"
            onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "sidebarRight", "open"])
        }
    }

    ContentSection {
        icon: "keyboard"
        title: "Saisie"

        RippleButtonWithIcon {
            materialIcon: "keyboard"
            mainText: "Clavier virtuel (Super + K)"
            onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "osk", "toggle"])
        }
        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            text: "Taille du curseur, vitesse de la souris et répétition des touches : page « Souris et clavier »."
        }
    }
}
