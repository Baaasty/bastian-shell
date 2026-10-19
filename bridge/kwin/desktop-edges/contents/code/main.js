// Desktop: Bildschirmkanten statt Hover-Streifen der Shell.
// Ein Layer-Surface am Rand würde Klicks schlucken (Fenster oben packen ginge nicht);
// KWin sieht die Maus, ohne etwas zu blockieren. Weiter geht es über die Kürzel-Datei der Desktop.
const MAIN = "DP-2";

function mainOutput(pos) {
    const out = workspace.screenAt(pos);
    return out && out.name === MAIN ? out : null;
}

function invoke(action) {
    callDBus("org.kde.kglobalaccel", "/component/desktop_shortcuts_desktop",
             "org.kde.kglobalaccel.Component", "invokeShortcut", action);
}

// 1) Mausposition: berührt der Zeiger die obere/untere Kante des Hauptmonitors, kommt die Leiste.
//    Gemeldet wird nur beim Ankommen an der Kante (nicht bei jeder Bewegung dort).
//    Oben zusätzlich: Verlässt die Maus den Streifen der Bar wieder, bekommt die Shell "leave-top"
//    (die Bar lässt Klicks durch, um Fenster darunter packen zu können, sieht die Maus dort also nicht).
const TOP_ZONE = 60;   // px ab Oberkante: Bar-Abstand + Bar-Höhe + Luft (BarWindow implicitHeight)
let atEdge = "";
let inTopZone = false;
workspace.cursorPosChanged.connect(function () {
    const pos = workspace.cursorPos;
    const out = mainOutput(pos);
    let edge = "";
    if (out) {
        const g = out.geometry;
        if (pos.y <= g.y + 1)
            edge = "top";
        else if (pos.y >= g.y + g.height - 2)
            edge = "bottom";
    }
    if (inTopZone && !(out && pos.y < out.geometry.y + TOP_ZONE)) {
        inTopZone = false;
        invoke("leave-top");
    }
    if (edge === atEdge)
        return;
    atEdge = edge;
    if (edge === "top") {
        inTopZone = true;
        invoke("reveal-top");
    } else if (edge === "bottom")
        invoke("reveal-bottom");
});

// 2) KWins Kanten-Erkennung zusätzlich (falls die Maus z. B. über Touch/Tablet an die Kante kommt)
const TOP = [KWin.ElectricTop, KWin.ElectricTopLeft, KWin.ElectricTopRight];
const BOTTOM = [KWin.ElectricBottom, KWin.ElectricBottomLeft, KWin.ElectricBottomRight];

for (const edge of TOP)
    registerScreenEdge(edge, function () {
        if (mainOutput(workspace.cursorPos)) {
            inTopZone = true;
            invoke("reveal-top");
        }
        return true;
    });
for (const edge of BOTTOM)
    registerScreenEdge(edge, function () {
        if (mainOutput(workspace.cursorPos))
            invoke("reveal-bottom");
        return true;
    });
