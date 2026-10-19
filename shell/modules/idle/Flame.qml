import QtQuick
import QtQuick.Shapes

// Eine flache Flamme (ein Tropfen), Spitze pendelt über „sway“ (0..1 der Breite). Keine Verläufe, kein Glühen.
Shape {
    id: f

    property real fw: 100
    property real fh: 160
    property real sway: 0.5
    property color fill: "red"

    width: fw
    height: fh
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: f.fill
        strokeWidth: -1
        startX: f.fw * 0.5
        startY: f.fh
        PathCubic {
            x: f.fw * f.sway
            y: 0
            control1X: f.fw * 1.12
            control1Y: f.fh * 0.78
            control2X: f.fw * 0.78
            control2Y: f.fh * 0.3
        }
        PathCubic {
            x: f.fw * 0.5
            y: f.fh
            control1X: f.fw * 0.22
            control1Y: f.fh * 0.36
            control2X: -f.fw * 0.12
            control2Y: f.fh * 0.78
        }
    }
}
