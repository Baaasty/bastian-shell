pragma Singleton
import QtQuick
import Quickshell

// Ein Eingabefeld unter der Bar für alles Kurze: Aufgabe setzen, Desktop umbenennen …
Singleton {
    id: root

    property bool open: false
    property string icon: "edit"
    property string placeholder: ""
    property string initial: ""
    property var _accept: null
    property string where: "top"   // top = unter der Bar, bottom = über der Arbeitsplatz-Leiste

    function ask(icon: string, placeholder: string, initial: string, accept: var): void {
        askAt("top", icon, placeholder, initial, accept);
    }
    function askAt(where: string, icon: string, placeholder: string, initial: string, accept: var): void {
        root.where = where;
        root.icon = icon;
        root.placeholder = placeholder;
        root.initial = initial;
        root._accept = accept;
        root.open = true;
    }
    function accept(text: string): void {
        open = false;
        if (_accept)
            _accept(text);
        _accept = null;
    }
    function cancel(): void {
        open = false;
        _accept = null;
    }
}
