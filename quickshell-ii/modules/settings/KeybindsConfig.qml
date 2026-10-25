pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Searchable list of the live keybinds (same data as the cheatsheet, Super + :)
ContentPage {
    id: root
    forceWidth: true

    property string query: ""
    function normalize(text) {
        return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
    }
    function comboText(combo) {
        return [...Array.from(combo.mods), combo.key].join(" + ");
    }
    readonly property var sections: {
        const q = root.normalize(root.query.trim());
        // Service data arrives as QML lists: convert to real arrays before using array methods
        const all = Array.from(HyprlandKeybinds.keybinds.children ?? []).reduce((acc, column) => acc.concat(Array.from(column.children ?? [])), []);
        return all.map(section => {
            // Continuation lines (no comment) belong to the entry above them
            const entries = [];
            for (const e of Array.from(section.keybinds)) {
                if (e.comment === "" && entries.length > 0) entries[entries.length - 1].combos.push(...Array.from(e.combos));
                else entries.push({ comment: e.comment, combos: Array.from(e.combos) });
            }
            const matching = q === "" ? entries : entries.filter(e =>
                root.normalize(e.comment).includes(q) || e.combos.some(c => root.normalize(root.comboText(c)).includes(q)));
            return { name: section.name, entries: matching };
        }).filter(section => section.entries.length > 0 || root.normalize(section.name).includes(q) && q !== "");
    }

    ContentSection {
        icon: "keyboard"
        title: "Raccourcis clavier"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: "Rechercher (ex. capture, écran, Super + S…)"
                onTextChanged: root.query = text
            }
            RippleButtonWithIcon {
                materialIcon: "help"
                mainText: "Aide rapide (Super + :)"
                onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "cheatsheet", "open"])
            }
        }

        StyledText {
            visible: root.sections.length === 0
            color: Appearance.colors.colSubtext
            text: "Aucun raccourci ne correspond."
        }
    }

    Repeater {
        model: root.sections

        delegate: ContentSection {
            id: sectionItem
            required property var modelData
            title: modelData.name
            icon: ({ "Fenêtres": "select_window", "Workspaces": "view_carousel", "Applications": "apps",
                     "Interface": "dashboard", "Captures": "screenshot_region", "Outils": "build",
                     "Médias": "music_note", "Système": "settings", "Session": "power_settings_new" })[modelData.name] ?? "keyboard"

            Repeater {
                model: sectionItem.modelData.entries

                delegate: RowLayout {
                    id: entryRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12

                    StyledText {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        wrapMode: Text.WordWrap
                        color: Appearance.colors.colOnLayer1
                        text: entryRow.modelData.comment
                    }
                    Flow {
                        Layout.preferredWidth: Math.min(implicitWidth, 320)
                        Layout.maximumWidth: 320
                        spacing: 6
                        layoutDirection: Qt.RightToLeft
                        Repeater {
                            model: entryRow.modelData.combos
                            delegate: KeyboardKey {
                                required property var modelData
                                key: root.comboText(modelData)
                                pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }
                    }
                }
            }
        }
    }
}
