import QtQuick
import QtQuick.Shapes

/**
 * Logo "Jarvis" : anneaux lumineux qui respirent et tournent en continu tant que `active`.
 * Animation pilotée par un Timer (phases cumulées) : vitesse variable sans redémarrage, ~30 fps.
 */
Item {
    id: root
    property bool active: true
    property string mode: "idle" // idle | listening | busy
    property real level: 0       // 0..1, niveau sonore pendant la dictée
    property color tint: "#6fd3ff"
    implicitWidth: 48
    implicitHeight: 48

    readonly property real spinSec: mode === "busy" ? 2.2 : mode === "listening" ? 4 : 16
    readonly property real breathSec: mode === "busy" ? 0.9 : mode === "listening" ? 1.1 : 3.2
    property real angle: 0
    property real bphase: 0
    readonly property real breath: 0.5 + 0.5 * Math.sin(bphase)
    readonly property real sw: Math.max(1.2, width / 22) // épaisseur de trait proportionnelle

    Timer {
        interval: 33; repeat: true
        running: root.active && root.visible && root.width > 0
        onTriggered: {
            root.angle = (root.angle + 0.033 * 360 / root.spinSec) % 360;
            root.bphase += 0.033 * 2 * Math.PI / root.breathSec;
        }
    }

    // halo
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * (0.9 + 0.12 * root.breath); height: width; radius: width / 2
        color: "transparent"
        border.width: Math.max(1, root.width / 48)
        border.color: root.tint
        opacity: 0.15 + 0.2 * root.breath
    }

    // arcs extérieurs (sens horaire)
    Item {
        anchors.fill: parent
        rotation: root.angle
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.tint; strokeWidth: root.sw; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width * 0.40; radiusY: root.height * 0.40; startAngle: 20; sweepAngle: 80 }
            }
            ShapePath {
                strokeColor: root.tint; strokeWidth: root.sw; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width * 0.40; radiusY: root.height * 0.40; startAngle: 140; sweepAngle: 80 }
            }
            ShapePath {
                strokeColor: root.tint; strokeWidth: root.sw; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width * 0.40; radiusY: root.height * 0.40; startAngle: 260; sweepAngle: 80 }
            }
        }
    }

    // arcs intérieurs (sens inverse, plus rapides)
    Item {
        anchors.fill: parent
        rotation: -root.angle * 1.7
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.tint; strokeWidth: root.sw * 0.75; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width * 0.29; radiusY: root.height * 0.29; startAngle: 60; sweepAngle: 110 }
            }
            ShapePath {
                strokeColor: root.tint; strokeWidth: root.sw * 0.75; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width * 0.29; radiusY: root.height * 0.29; startAngle: 240; sweepAngle: 110 }
            }
        }
    }

    // cœur
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * (0.17 + 0.04 * root.breath + 0.14 * root.level); height: width; radius: width / 2
        color: root.tint
        opacity: 0.5 + 0.3 * root.breath + 0.2 * root.level
    }
}
