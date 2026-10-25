pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Windows-like Alt+Tab over every window of every monitor, most recently used first.
 * Alt+Tab / Alt+Shift+Tab cycle, releasing Alt focuses the selection (which also
 * moves to its monitor), Escape cancels. A quick tap switches without showing
 * the switcher. Binds (binds.lua): Alt+Tab, Alt+Shift+Tab, and a transparent
 * Alt_L bind whose release commits.
 */
Scope {
    id: root
    property bool active: false // Alt still held after an Alt+Tab
    property bool shown: false  // switcher visible (after a short hold)
    property var windows: []    // snapshot taken when Alt+Tab starts
    property int index: 0
    property var targetScreen: null
    readonly property int showDelay: 120

    function snapshot() {
        root.windows = HyprlandData.windowList
            .filter(w => w.mapped && !w.hidden && !(w.workspace?.name ?? "").startsWith("special"))
            .sort((a, b) => a.focusHistoryID - b.focusHistoryID);
    }

    function start(step) {
        if (!root.active) {
            root.snapshot();
            if (root.windows.length === 0) return;
            root.targetScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null;
            root.index = step > 0 ? Math.min(1, root.windows.length - 1) : root.windows.length - 1;
            root.active = true;
            showTimer.restart();
        } else {
            root.select(root.index + step);
        }
    }

    function select(i) {
        const n = root.windows.length;
        if (n > 0) root.index = ((i % n) + n) % n;
    }

    function commit() {
        const win = root.windows[root.index];
        root.close();
        if (win) Hyprland.dispatch(`hl.dsp.focus({ window = "address:${win.address}" })`);
    }

    function close() {
        showTimer.stop();
        root.active = false;
        root.shown = false;
    }

    Timer {
        id: showTimer
        interval: root.showDelay
        onTriggered: if (root.active) root.shown = true
    }

    PanelWindow {
        id: switcherWindow
        visible: root.shown
        screen: root.targetScreen
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:altTab"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea { // Click outside cancels
            anchors.fill: parent
            onClicked: root.close()
        }

        StyledRectangularShadow {
            target: panel
        }
        Rectangle {
            id: panel
            anchors.centerIn: parent
            readonly property real padding: 16
            readonly property real maxWidth: (switcherWindow.screen?.width ?? 1920) * 0.9
            width: cards.width + padding * 2
            height: cards.implicitHeight + padding * 2
            radius: Appearance.rounding.windowRounding
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            focus: root.shown

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.commit();
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    root.select(root.index + 1);
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    root.select(root.index - 1);
                } else {
                    return;
                }
                event.accepted = true;
            }

            Flow {
                id: cards
                anchors.centerIn: parent
                width: Math.min(implicitWidthAllInRow, panel.maxWidth - panel.padding * 2)
                readonly property real cardWidth: 240
                readonly property real implicitWidthAllInRow: root.windows.length * (cardWidth + spacing) - spacing
                spacing: 10

                Repeater {
                    model: root.windows

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool selected: root.index === index
                        readonly property var toplevel: ToplevelManager.toplevels.values.find(t => `0x${t.HyprlandToplevel?.address}` === modelData.address) ?? null
                        width: cards.cardWidth
                        height: cardColumn.implicitHeight + 16
                        radius: Appearance.rounding.normal
                        color: selected ? Appearance.colors.colPrimaryContainer
                            : cardMouse.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1
                        border.width: selected ? 2 : 0
                        border.color: Appearance.colors.colPrimary

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.index = card.index;
                                root.commit();
                            }
                        }

                        Column {
                            id: cardColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 8
                            }
                            spacing: 8

                            Row { // Icon + title
                                width: parent.width
                                spacing: 8
                                Image {
                                    id: appIcon
                                    width: 22
                                    height: 22
                                    sourceSize: Qt.size(22, 22)
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: Quickshell.iconPath(AppSearch.guessIcon(card.modelData.class), "image-missing")
                                }
                                StyledText {
                                    width: parent.width - appIcon.width - parent.spacing
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    color: card.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                                    text: card.modelData.title || card.modelData.class
                                }
                            }

                            Rectangle { // Live thumbnail
                                width: parent.width
                                height: width * 9 / 16
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer2
                                clip: true
                                ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: root.shown ? card.toplevel : null
                                    live: true
                                }
                            }

                            StyledText { // Where the window is
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: card.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                                text: {
                                    const monitor = HyprlandData.monitors.find(m => m.id === card.modelData.monitor);
                                    return `${monitor?.name ?? "?"} · workspace ${card.modelData.workspace?.name ?? "?"}`;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    GlobalShortcut {
        name: "altTabNext"
        description: "Alt+Tab: next window (all monitors)"
        onPressed: root.start(1)
    }

    GlobalShortcut {
        name: "altTabPrevious"
        description: "Alt+Shift+Tab: previous window (all monitors)"
        onPressed: root.start(-1)
    }

    GlobalShortcut {
        name: "altTabRelease"
        description: "Alt released: focus the selected window"
        onReleased: if (root.active) root.commit()
    }
}
