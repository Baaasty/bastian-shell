import QtQuick
import qs.config

// Kleiner Verlaufsgraph (Fläche + Linie), Werte automatisch auf das Maximum skaliert
Canvas {
    id: graph

    property var values: []
    property var secondary: []
    property color color: Theme.woodLight
    property color secondaryColor: Theme.textFaint

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const all = values.concat(secondary);
        const max = Math.max(1, ...all) * 1.15;
        // so viele Punkte wie da sind (max. 60) -> der Verlauf nutzt von Anfang an die ganze Breite
        const n = Math.max(2, Math.min(60, Math.max(values.length, secondary.length)));
        const step = width / (n - 1);
        const y = v => height - (v / max) * height;
        const line = (vals, col, fill) => {
            if (vals.length < 2)
                return;
            const off = Math.max(0, n - vals.length) * step;
            ctx.beginPath();
            vals.forEach((v, i) => i === 0 ? ctx.moveTo(off, y(v)) : ctx.lineTo(off + i * step, y(v)));
            ctx.strokeStyle = col;
            ctx.lineWidth = 1.5;
            ctx.stroke();
            if (fill) {
                ctx.lineTo(off + (vals.length - 1) * step, height);
                ctx.lineTo(off, height);
                ctx.closePath();
                ctx.fillStyle = Qt.alpha(col, 0.16);
                ctx.fill();
            }
        };
        line(secondary, secondaryColor, false);
        line(values, color, true);
    }
}
