import QtQuick

/** Éclat façon Claude (rayons orange qui ondulent doucement), ~20 fps. */
Item {
    id: root
    property bool active: true
    property color tint: "#d97757"
    property real t: 0
    implicitWidth: 20
    implicitHeight: 20

    Timer {
        interval: 50; repeat: true
        running: root.active && root.visible
        onTriggered: root.t += 0.05
    }

    Repeater {
        model: 10
        Item {
            required property int index
            anchors.centerIn: parent
            width: 1; height: 1
            rotation: index * 36 + root.t * 6
            Rectangle {
                readonly property real len: root.height * (0.30 + 0.17 * (0.5 + 0.5 * Math.sin(root.t * 1.6 + index * 1.3)))
                x: -width / 2
                y: -len
                width: Math.max(1.4, root.width * 0.1)
                height: len
                radius: width / 2
                color: root.tint
            }
        }
    }
}
