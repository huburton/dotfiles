import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.ii.onScreenDisplay

OsdValueIndicator {
    id: root

    property real currentLevel: 0
    property real maxLevel: 3

    icon: "keyboard"
    rotateIcon: false
    scaleIcon: true
    name: "Rétroéclairage clavier"
    value: maxLevel > 0 ? currentLevel / maxLevel : 0

    FileView {
        id: levelFile
        path: "/sys/class/leds/asus::kbd_backlight/brightness"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const v = parseInt(text().trim());
            if (!isNaN(v)) root.currentLevel = v;
        }
    }

    FileView {
        id: maxFile
        path: "/sys/class/leds/asus::kbd_backlight/max_brightness"
        onLoaded: {
            const v = parseInt(text().trim());
            if (!isNaN(v) && v > 0) root.maxLevel = v;
        }
        Component.onCompleted: reload()
    }

    Component.onCompleted: {
        levelFile.reload();
        maxFile.reload();
    }
}
