import QtQuick
import QtQuick.Shapes
import qs.config

// Profil-Icons aus design/claude-design/icons (+ Fun aus design/icons), 32er-Pfade skaliert
Item {
    id: g

    property string name
    property color color: Theme.text
    property int size: 18

    readonly property var paths: ({
        code: "M19 9.5l6 6.5-6 6.5M13 9.5l-6 6.5 6 6.5",
        office: "M6 11.5h20a2 2 0 0 1 2 2V24a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V13.5a2 2 0 0 1 2-2zM12 11.5V9a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2.5M4 17.5h24",
        fun: "M16 4.5c3 3.2 5.5 6 5.5 9.5a5.5 5.5 0 0 1-11 0c0-2.2 1.1-3.9 2.3-5 .2 2.1 1.1 3.3 2.4 3.3-.4-2.9.1-5.4.8-7.8zM7 27.5l18-4.5M25 27.5L7 23",
        projekt: "M5 10a2 2 0 0 1 2-2h5l2.5 2.5H25a2 2 0 0 1 2 2V24a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2z"
    })

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: g.size / 32; yScale: g.size / 32 }
        ShapePath {
            strokeColor: g.color
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: g.paths[g.name] || "" }
        }
    }
}
