pragma Singleton
import QtQuick
import Quickshell

// Kleiner Rechner ohne eval: + - * / % ^ ! und Klammern, Komma oder Punkt als Dezimaltrenner.
// Wissenschaftlich: sin cos tan (Grad) asin acos atan, √/sqrt, ln, log, abs, π/pi, e. "2π" = 2·π.
Singleton {
    readonly property var funcs: ({
        sin: x => Math.sin(x * Math.PI / 180),
        cos: x => Math.cos(x * Math.PI / 180),
        tan: x => Math.tan(x * Math.PI / 180),
        asin: x => Math.asin(x) * 180 / Math.PI,
        acos: x => Math.acos(x) * 180 / Math.PI,
        atan: x => Math.atan(x) * 180 / Math.PI,
        sqrt: Math.sqrt,
        "√": Math.sqrt,
        ln: Math.log,
        log: Math.log10,
        abs: Math.abs
    })
    readonly property var consts: ({ pi: Math.PI, "π": Math.PI, e: Math.E })

    function factorial(n) {
        if (n < 0 || n > 170 || n !== Math.floor(n))
            return NaN;
        let r = 1;
        for (let i = 2; i <= n; i++)
            r *= i;
        return r;
    }

    // loose = true: auch ohne Operator rechnen (Modus "="), sonst nur echte Rechnungen (freie Suche)
    function evaluate(input: string, loose: bool): var {
        const src = input.toLowerCase().replace(/,/g, ".").replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-");
        if (!src || !/^[0-9+\-*/%^().!a-zπ√]+$/.test(src))
            return null;
        if (!loose && (!/[0-9]/.test(src) || !/[+\-*/%^!(]/.test(src)))
            return null;
        const tokens = src.match(/\d+\.?\d*|\.\d+|[a-z]+|π|√|[+\-*/%^()!]/g);
        if (!tokens || tokens.join("") !== src)
            return null;
        let pos = 0;
        const peek = () => tokens[pos];
        const next = () => tokens[pos++];
        const startsValue = t => t !== undefined && (/^[0-9.]/.test(t) || t === "(" || t === "π" || t === "√" || /^[a-z]/.test(t));
        function atom() {
            const t = next();
            if (t === "(") {
                const v = expr();
                if (peek() === ")")
                    next(); // offene Klammer am Ende ist ok (beim Tippen)
                else if (peek() !== undefined)
                    throw "klammer";
                return v;
            }
            if (t === "-")
                return -power();
            if (t === "+")
                return power();
            if (t !== undefined && funcs[t] !== undefined)
                return funcs[t](power());
            if (t !== undefined && consts[t] !== undefined)
                return consts[t];
            const n = parseFloat(t);
            if (isNaN(n))
                throw "zahl";
            return n;
        }
        function postfix() {
            let v = atom();
            while (peek() === "!") {
                next();
                v = factorial(v);
            }
            return v;
        }
        function power() {
            const b = postfix();
            if (peek() === "^") {
                next();
                return Math.pow(b, power());
            }
            return b;
        }
        function term() {
            let v = power();
            for (;;) {
                const p = peek();
                if (p === "*" || p === "/" || p === "%") {
                    const op = next();
                    const r = power();
                    v = op === "*" ? v * r : op === "/" ? v / r : v % r;
                } else if (startsValue(p)) {
                    v *= power(); // 2π, 3(4+1), 2sin(30)
                } else
                    return v;
            }
        }
        function expr() {
            let v = term();
            while (peek() === "+" || peek() === "-") {
                const op = next();
                const r = term();
                v = op === "+" ? v + r : v - r;
            }
            return v;
        }
        try {
            const v = expr();
            if (pos !== tokens.length || !isFinite(v))
                return null;
            return Math.round(v * 1e10) / 1e10;
        } catch (e) {
            return null;
        }
    }

    function format(v: real): string {
        return String(v);
    }
}
