import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.models.hyprland
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true

    // Current values read from Hyprland; changes go through HyprlandConfig, which
    // applies them live and keeps them in ~/.config/hypr/shell-overrides.lua.
    property HyprlandConfigOption sensitivityOpt: HyprlandConfigOption { key: "input:sensitivity" }
    property HyprlandConfigOption accelProfileOpt: HyprlandConfigOption { key: "input:accel_profile" }
    property HyprlandConfigOption repeatDelayOpt: HyprlandConfigOption { key: "input:repeat_delay" }
    property HyprlandConfigOption repeatRateOpt: HyprlandConfigOption { key: "input:repeat_rate" }
    property HyprlandConfigOption numlockOpt: HyprlandConfigOption { key: "input:numlock_by_default" }
    property HyprlandConfigOption scrollFactorOpt: HyprlandConfigOption { key: "input:touchpad:scroll_factor" }
    property HyprlandConfigOption tapToClickOpt: HyprlandConfigOption { key: "input:touchpad:tap-to-click" }
    property HyprlandConfigOption naturalScrollOpt: HyprlandConfigOption { key: "input:touchpad:natural_scroll" }

    function apply(option, value) {
        option.value = value;
        HyprlandConfig.set(option.key, value);
    }

    // Cursor size lives in gsettings (the session script re-applies it at login)
    property int cursorSize: 24
    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "cursor-size"]
        stdout: StdioCollector {
            onStreamFinished: root.cursorSize = parseInt(text) || 24
        }
    }

    ContentSection {
        icon: "arrow_selector_tool"
        title: "Curseur"

        ConfigSpinBox {
            icon: "arrow_selector_tool"
            text: "Taille du curseur (px)"
            from: 12
            to: 64
            stepSize: 2
            value: root.cursorSize
            onValueChanged: {
                if (value === root.cursorSize) return;
                root.cursorSize = value;
                Quickshell.execDetached(["bash", "-c",
                    `hyprctl setcursor macos-tahoe-cursor ${value}; gsettings set org.gnome.desktop.interface cursor-size ${value}`]);
            }
        }
    }

    ContentSection {
        icon: "mouse"
        title: "Souris"

        ContentSubsection {
            title: "Sensibilité (−1 lent · 0 normal · +1 rapide)"
            ConfigSlider {
                buttonIcon: "speed"
                text: "Sensibilité"
                from: -1.0
                to: 1.0
                value: root.sensitivityOpt.value ?? 0
                usePercentTooltip: false
                onValueChanged: {
                    if (root.sensitivityOpt.value === undefined || Math.abs(value - root.sensitivityOpt.value) < 0.02) return;
                    root.apply(root.sensitivityOpt, Math.round(value * 100) / 100);
                }
            }
        }

        ContentSubsection {
            title: "Profil d'accélération"
            ConfigSelectionArray {
                currentValue: root.accelProfileOpt.value
                onSelected: newValue => root.apply(root.accelProfileOpt, newValue)
                options: [
                    { displayName: "Constant (idéal jeux)", icon: "trending_flat", value: "flat" },
                    { displayName: "Adaptatif", icon: "trending_up", value: "adaptive" }
                ]
            }
        }
    }

    ContentSection {
        icon: "keyboard"
        title: "Clavier"

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "timer"
                text: "Délai avant répétition (ms)"
                from: 100
                to: 1000
                stepSize: 25
                value: root.repeatDelayOpt.value ?? 250
                onValueChanged: {
                    if (root.repeatDelayOpt.value === undefined || value === root.repeatDelayOpt.value) return;
                    root.apply(root.repeatDelayOpt, value);
                }
            }
            ConfigSpinBox {
                icon: "keyboard_double_arrow_right"
                text: "Vitesse de répétition (/s)"
                from: 5
                to: 100
                stepSize: 5
                value: root.repeatRateOpt.value ?? 35
                onValueChanged: {
                    if (root.repeatRateOpt.value === undefined || value === root.repeatRateOpt.value) return;
                    root.apply(root.repeatRateOpt, value);
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "dialpad"
            text: "Verrouillage numérique activé au démarrage"
            checked: !!root.numlockOpt.value
            onCheckedChanged: {
                if (root.numlockOpt.value === undefined || checked === !!root.numlockOpt.value) return;
                root.apply(root.numlockOpt, checked ? 1 : 0);
            }
        }
    }

    ContentSection {
        icon: "touch_app"
        title: "Pavé tactile"

        ContentSubsection {
            title: "Vitesse de défilement (0,1 lent · 2,0 rapide)"
            ConfigSlider {
                buttonIcon: "swipe_vertical"
                text: "Défilement"
                from: 0.1
                to: 2.0
                value: root.scrollFactorOpt.value ?? 1
                usePercentTooltip: false
                onValueChanged: {
                    if (root.scrollFactorOpt.value === undefined || Math.abs(value - root.scrollFactorOpt.value) < 0.02) return;
                    root.apply(root.scrollFactorOpt, Math.round(value * 100) / 100);
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "touch_app"
            text: "Toucher pour cliquer"
            checked: !!root.tapToClickOpt.value
            onCheckedChanged: {
                if (root.tapToClickOpt.value === undefined || checked === !!root.tapToClickOpt.value) return;
                root.apply(root.tapToClickOpt, checked ? 1 : 0);
            }
        }

        ConfigSwitch {
            buttonIcon: "swap_vert"
            text: "Défilement naturel"
            checked: !!root.naturalScrollOpt.value
            onCheckedChanged: {
                if (root.naturalScrollOpt.value === undefined || checked === !!root.naturalScrollOpt.value) return;
                root.apply(root.naturalScrollOpt, checked ? 1 : 0);
            }
        }
    }
}
