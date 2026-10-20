.pragma library

// Tooltip-Text („Resources · Super+Alt+R“) → Teile für KeyTip.qml: Kürzel-Abschnitte werden zu Tastenkappen,
// alles andere bleibt Text. So müssen die Chips weiter nur einen String liefern (Chip.tip, BarKeys.tipFor).
// Teil: { kind: "text", text } | { kind: "sep" } | { kind: "plus" } | { kind: "key", text, main }

const CHORD = /^(?:(?:Super|Alt|Ctrl|Shift)\+)+\S+$/;

function chord(seg) {
    const keys = seg.split("+");
    const out = [];
    keys.forEach((k, i) => {
        if (i > 0)
            out.push({ kind: "plus" });
        out.push({ kind: "key", text: k, main: i === keys.length - 1 });
    });
    return out;
}

function parts(text) {
    const out = [];
    String(text || "").split(" · ").forEach(raw => {
        const seg = raw.trim();
        if (seg === "")
            return;
        if (out.length)
            out.push({ kind: "sep" });
        if (CHORD.test(seg))
            out.push(...chord(seg));
        else
            out.push({ kind: "text", text: seg });
    });
    return out;
}
