"""JSONC (VS-Code-Settings: Kommentare, Komma am Ende) gezielt ändern, ohne den Rest anzufassen.

Nur einzelne Schlüssel setzen/löschen; Kommentare, Reihenfolge und Einrückung bleiben.
Jede Änderung wird danach geparst und geprüft – sonst Abbruch (ValueError), nichts wird geschrieben.
"""
import json
import re

_LIT = re.compile(r"[-+0-9.eEa-zA-Z]+")


def _tokens(text):
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c in " \t\r\n﻿":
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(("comment", i, j))
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            if j < 0:
                raise ValueError("Block-Kommentar nicht geschlossen")
            out.append(("comment", i, j + 2))
            i = j + 2
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            if j >= n:
                raise ValueError("String nicht geschlossen")
            out.append(("string", i, j + 1))
            i = j + 1
        elif c in "{}[]:,":
            out.append((c, i, i + 1))
            i += 1
        else:
            m = _LIT.match(text, i)
            if not m:
                raise ValueError(f"Unerwartetes Zeichen {c!r} bei Position {i}")
            out.append(("lit", i, m.end()))
            i = m.end()
    return out


def _sig(text):
    return [t for t in _tokens(text) if t[0] != "comment"]


def loads(text):
    """JSONC -> Python (Kommentare und Kommas am Ende ignoriert)."""
    if not text.strip():
        return {}
    sig = _sig(text)
    parts = []
    for i, t in enumerate(sig):
        if t[0] == "," and i + 1 < len(sig) and sig[i + 1][0] in "}]":
            continue
        parts.append(text[t[1]:t[2]])
    return json.loads(" ".join(parts))


def _value_end(sig, i):
    if sig[i][0] in "{[":
        depth = 0
        for j in range(i, len(sig)):
            if sig[j][0] in "{[":
                depth += 1
            elif sig[j][0] in "}]":
                depth -= 1
                if depth == 0:
                    return j
        raise ValueError("Klammer nicht geschlossen")
    return i


def _members(text, sig, i):
    out, j = [], i + 1
    while sig[j][0] != "}":
        if sig[j][0] == ",":
            j += 1
            continue
        if sig[j][0] != "string" or sig[j + 1][0] != ":":
            raise ValueError("Objekt kaputt")
        vs = j + 2
        ve = _value_end(sig, vs)
        comma = ve + 1 if sig[ve + 1][0] == "," else None
        out.append({"key": json.loads(text[sig[j][1]:sig[j][2]]), "k": j, "vs": vs, "ve": ve, "comma": comma})
        j = (comma or ve) + 1
    return out, j


def _find(text, path):
    sig = _sig(text)
    if not sig or sig[0][0] != "{":
        raise ValueError("Kein JSON-Objekt")
    i = 0
    for n, key in enumerate(path):
        mem, close = _members(text, sig, i)
        hit = next((m for m in mem if m["key"] == key), None)
        if n == len(path) - 1:
            return sig, i, mem, close, hit
        if not hit or sig[hit["vs"]][0] != "{":
            raise KeyError("/".join(path[:n + 1]))
        i = hit["vs"]


def _line_start(text, pos):
    return text.rfind("\n", 0, pos) + 1


def _line_end(text, pos):
    j = text.find("\n", pos)
    return len(text) if j < 0 else j


def _indent_of(text, pos):
    ls = _line_start(text, pos)
    return re.match(r"[ \t]*", text[ls:]).group(0)


def get(text, path, default=None):
    cur = loads(text)
    for key in path:
        if not isinstance(cur, dict) or key not in cur:
            return default
        cur = cur[key]
    return cur


def comment_before(text, path):
    """Kommentartext direkt über/vor dem Schlüssel (für Markierungen), sonst ''."""
    sig, open_i, mem, close, hit = _find(text, path)
    if not hit:
        return ""
    prev = sig[hit["k"] - 1]
    return text[prev[2]:sig[hit["k"]][1]]


def set_key(text, path, value, comment=None, before=None):
    sig, open_i, mem, close, hit = _find(text, path)
    unit = "\t" if "\n\t" in text else "  "
    if mem:
        indent = _indent_of(text, sig[mem[0]["k"]][1])
    else:
        indent = _indent_of(text, sig[open_i][1]) + unit
    rendered = json.dumps(value, indent=unit, ensure_ascii=False).replace("\n", "\n" + indent)
    key = json.dumps(path[-1], ensure_ascii=False)
    if hit:
        s, e = sig[hit["vs"]][1], sig[hit["ve"]][2]
        new = text[:s] + rendered + text[e:]
    else:
        head = f"{indent}// {comment}\n" if comment else ""
        b = next((m for m in mem if m["key"] == before), None) if before else None
        if b:
            pos = _line_start(text, sig[b["k"]][1])
            # Kommentarzeilen direkt über dem Ziel gehören zu ihm -> davor einfügen
            while pos > 0:
                prev_ls = _line_start(text, pos - 1)
                line = text[prev_ls:pos - 1].strip()
                if line.startswith("//") and prev_ls > sig[open_i][2]:
                    pos = prev_ls
                else:
                    break
            new = text[:pos] + head + f"{indent}{key}: {rendered},\n" + text[pos:]
        elif mem:
            last = mem[-1]
            trail = last["comma"] is not None
            end_tok = sig[last["comma"]] if trail else sig[last["ve"]]
            new = text
            if not trail:
                new = new[:end_tok[2]] + "," + new[end_tok[2]:]
            shift = 0 if trail else 1
            le = _line_end(new, end_tok[2] + shift)
            cpos = sig[close][1] + shift
            member = f"{indent}{key}: {rendered}{',' if trail else ''}"
            if cpos > le:
                new = new[:le + 1] + head + member + "\n" + new[le + 1:]
            else:
                outer = _indent_of(new, sig[open_i][1])
                new = new[:cpos].rstrip(" \t") + "\n" + head + member + "\n" + outer + new[cpos:]
        else:
            outer = _indent_of(text, sig[open_i][1])
            s, e = sig[open_i][2], sig[close][1]
            new = text[:s] + "\n" + head + f"{indent}{key}: {rendered}\n" + outer + text[e:]
    if get(new, path) != value:
        raise ValueError("Prüfung nach dem Setzen fehlgeschlagen")
    return new


def del_key(text, path, marker=None):
    """Schlüssel entfernen (samt Markierungs-Kommentar darüber, wenn `marker` darin vorkommt)."""
    sig, open_i, mem, close, hit = _find(text, path)
    if not hit:
        return text
    s = sig[hit["k"]][1]
    end_tok = sig[hit["comma"]] if hit["comma"] is not None else sig[hit["ve"]]
    e = end_tok[2]
    ls = _line_start(text, s)
    if not text[ls:s].strip():
        s = ls
        if marker:
            while s > 0:
                pls = _line_start(text, s - 1)
                line = text[pls:s - 1].strip()
                if line.startswith("//") and marker in line:
                    s = pls
                else:
                    break
    le = _line_end(text, e)
    if not text[e:le].strip():
        e = min(le + 1, len(text))
    new = text[:s] + text[e:]
    # war es das letzte Element ohne Komma: Komma des Vorgängers weg (strenges JSON bleibt streng)
    if hit["comma"] is None and len(mem) > 1:
        prev = mem[-2]
        if prev["comma"] is not None:
            c = sig[prev["comma"]][1]
            new = new[:c] + new[c + 1:]
    if len(mem) == 1:  # Objekt jetzt leer -> wieder "{}"
        sig2, oi, _, cl, _ = _find(new, path)
        a, b = sig2[oi][2], sig2[cl][1]
        if not new[a:b].strip():
            new = new[:a] + new[b:]
    if get(new, path, default=KeyError) is not KeyError:
        raise ValueError("Prüfung nach dem Löschen fehlgeschlagen")
    loads(new)
    return new
