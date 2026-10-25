// Arctis headset battery widget (via `headsetcontrol -b -o json`).
// Shown in the main bar only. Fires a notification when battery ≤ 20%.
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property int batteryLevel: -1
    property string batteryStatus: "unknown"
    property bool connected: false
    property bool lowNotified: false

    implicitWidth: connected ? row.implicitWidth : 0
    implicitHeight: Appearance.sizes.barHeight
    visible: connected

    Timer {
        id: pollTimer
        interval: 60000  // 1 min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pollProcess.running = true
    }

    Process {
        id: pollProcess
        command: ["headsetcontrol", "-b", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const dev = data.devices?.[0];
                    if (!dev) { root.connected = false; return; }
                    const bat = dev.battery ?? {};
                    root.batteryStatus = bat.status ?? "unknown";
                    root.connected = bat.status === "BATTERY_AVAILABLE" || bat.status === "BATTERY_CHARGING";
                    if (root.connected) {
                        root.batteryLevel = bat.level ?? -1;
                        if (root.batteryLevel > 0 && root.batteryLevel <= 20 && !root.lowNotified) {
                            Quickshell.execDetached(["notify-send", "-a", "Headset", "-u", "critical",
                                "Arctis batterie faible", `Il reste ${root.batteryLevel}% — pense à charger.`]);
                            root.lowNotified = true;
                        } else if (root.batteryLevel > 25) {
                            root.lowNotified = false;
                        }
                    }
                } catch (e) {
                    root.connected = false;
                }
            }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            text: root.batteryStatus === "BATTERY_CHARGING" ? "headset_mic" :
                  root.batteryLevel <= 20 ? "battery_alert" :
                  root.batteryLevel <= 40 ? "battery_2_bar" :
                  root.batteryLevel <= 60 ? "battery_4_bar" :
                  root.batteryLevel <= 80 ? "battery_5_bar" : "battery_full"
            iconSize: Appearance.font.pixelSize.larger
            color: root.batteryLevel <= 20 ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer0
        }

        StyledText {
            text: root.batteryLevel >= 0 ? `${root.batteryLevel}%` : "—"
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.batteryLevel <= 20 ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer0
        }
    }
}
