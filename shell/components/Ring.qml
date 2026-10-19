import QtQuick
import QtQuick.Shapes
import qs.config

// Fortschrittsring (0..1). Inhalt als Kinder in der Mitte.
Item {
    id: ring

    property real value: 0
    property real stroke: 8
    property color color: Theme.woodLight
    property color track: Theme.borderStrong
    default property alias content: center.data

    implicitWidth: 104
    implicitHeight: 104

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: ring.track
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: (ring.width - ring.stroke) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.color
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: (ring.width - ring.stroke) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, ring.value))
                // nur animieren, wenn man es sieht: im geschlossenen Dashboard (CPU/RAM/GPU alle paar s,
                // Fokus jede Sekunde) liefe sonst ständig eine Animation ins Leere
                Behavior on sweepAngle {
                    enabled: !!ring.Window.window && ring.Window.window.visible
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Column {
        id: center
        anchors.centerIn: parent
    }
}
