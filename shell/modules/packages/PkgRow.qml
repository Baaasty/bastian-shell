import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components

// Eine Zeile der Paketliste (Paket, COPR-Repo, COPR-Treffer, AppImage, Remote …) + aufklappbare Details.
Item {
    id: row

    required property var modelData
    required property int index
    property var pk

    readonly property var r: modelData
    readonly property string kind: r.kind
    readonly property bool isHeader: kind === "header"
    readonly property bool isNote: kind === "note"
    readonly property bool expanded: !isHeader && !isNote && pk.expandedKey === r.key
    readonly property bool selected: pk.sel === index
    readonly property var info: pk.infos[r.key] || null
    readonly property bool onUpdates: pk.page === "updates"
    readonly property int base: isHeader ? 46 : isNote ? 44 : 56
    readonly property string iconSrc: {
        if (kind === "pkg")
            return Quickshell.iconPath(r.src === "flatpak" ? r.id : r.name, true);
        if (kind === "appimage")
            return Quickshell.iconPath(String(r.name).toLowerCase().split("-")[0], true);
        return "";
    }
    readonly property string glyph: ({
        pkg: r.src === "flatpak" ? "deployed_code" : "package_2", repo: "groups", coprresult: "groups", coprsearch: "travel_explore",
        appimage: "folder_zip", dnfrepo: "dns", remote: "cloud", vendor: "storefront", addrepo: "add_link"
    })[kind] || "package_2"

    width: ListView.view ? ListView.view.width - 14 : 600
    height: base + (expanded ? detail.implicitHeight + 6 : 0)
    clip: true
    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // ---------------------------------------------------------------- Überschrift (Updates-Seite)
    Item {
        visible: row.isHeader
        anchors.fill: parent

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.right: parent.right
            anchors.rightMargin: row.r.updateAll ? 140 : 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            spacing: 12
            Label {
                id: hl
                text: row.r.title + " · " + row.r.count
            }
            Txt {
                width: parent.width - hl.width - 12
                visible: !!row.r.sub
                text: row.r.sub || ""
                color: Theme.textFaint
                font.pixelSize: Theme.fontXs
                font.weight: Font.Normal
            }
        }
        Button {
            small: true
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            visible: !!row.r.updateAll
            enabled: !row.pk.busy
            kind: "primary"
            icon: "download"
            text: "Update all"
            onClicked: row.pk.runExec("Update all " + row.r.title, row.r.updateAll, !row.r.noRoot && (row.r.updateAll[0] === "system" || row.r.updateAll[2] === "all"))
        }
    }

    Txt {
        visible: row.isNote
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: row.r.text || ""
        color: Theme.textFaint
        font.pixelSize: Theme.fontSm
        font.weight: Font.Normal
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        maximumLineCount: 2
    }

    // ---------------------------------------------------------------- normale Zeile
    Rectangle {
        id: card
        visible: !row.isHeader && !row.isNote
        x: 0
        y: 2
        width: parent.width
        height: row.base - 4
        radius: Theme.radiusMd
        // gewählt = deckende Akzentfläche (Listenauswahl), aufgeklappt = eine Stufe dunkler, Hover leise
        color: row.selected ? Theme.accentFill : row.expanded ? Theme.surface : hover.containsMouse ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                row.pk.sel = row.index;
                if (row.kind === "coprsearch")
                    row.pk.searchCopr();
                else
                    row.pk.toggleExpand(row.r);
            }
        }

        // Symbol
        Rectangle {
            id: ico
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: Theme.radiusSm
            color: Theme.raise
            IconImage {
                anchors.centerIn: parent
                width: 24
                height: 24
                visible: row.iconSrc !== ""
                source: row.iconSrc
            }
            Icon {
                anchors.centerIn: parent
                visible: row.iconSrc === ""
                name: row.glyph
                size: 20
                color: row.r.upgrade || row.kind === "coprsearch" ? Theme.accentText : Theme.textMuted
            }
        }

        // Rechts: Plaketten + Knöpfe
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // --- Plaketten
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "pkg" && !!row.r.upgrade
                mono: true
                text: (row.onUpdates && row.r.current ? row.r.current + "  →  " : "→ ") + row.r.upgrade
                fg: Theme.accentText
                bg: Theme.accentSoft
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "pkg" && row.r.src === "flatpak"
                text: row.r.scope || ""
                icon: row.r.scope === "system" ? "computer" : "person"
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "pkg" && (!!row.r.copr || (row.r.src === "system" && !!row.r.repo && !["fedora", "updates", "image", "updates-testing"].includes(row.r.repo) && !row.r.repo.startsWith("copr:")))
                text: row.r.copr || row.r.repo || ""
                icon: row.r.copr ? "groups" : "dns"
                fg: row.r.copr ? Theme.accentText : Theme.textMuted
                bg: row.r.copr ? Theme.accentSoft : Theme.raise
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "pkg" && !!row.r.installed && !row.r.upgrade && !row.onUpdates && row.pk.resultsReady
                text: "installed"
                icon: "check"
                fg: Theme.success
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "pkg" && row.r.src === "flatpak" && !!row.r.group && row.r.group !== "Flathub"
                text: row.r.group || ""
                icon: "cloud"
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "repo" || row.kind === "coprresult" || (row.kind === "vendor" && row.r.section === "community")
                text: "community"
                icon: "groups"
                fg: Theme.warning
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "dnfrepo" && !!row.r.trust
                text: row.r.trust || ""
                icon: row.r.trust === "official" ? "verified" : row.r.trust === "community" ? "groups" : row.r.trust === "local" ? "folder_special" : "storefront"
                fg: row.r.trust === "official" ? Theme.success : row.r.trust === "local" ? Theme.textMuted : Theme.warning
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "vendor"
                text: row.r.present ? (row.r.enabled ? "set up" : "set up · off") : "not set up"
                icon: row.r.present ? "check" : ""
                fg: row.r.present ? (row.r.enabled ? Theme.success : Theme.warning) : Theme.textFaint
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "repo"
                text: row.r.installed + " installed"
                mono: true
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "repo" || row.kind === "dnfrepo" || row.kind === "remote"
                text: row.r.enabled ? "on" : "off"
                fg: row.r.enabled ? Theme.success : Theme.textFaint
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "remote"
                text: row.r.scope || ""
                icon: row.r.scope === "system" ? "computer" : "person"
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "appimage" && row.r.desktop
                text: "menu entry"
                icon: "check"
                fg: Theme.success
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "appimage" && !row.r.executable
                text: "not executable"
                icon: "warning"
                fg: Theme.warning
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "appimage"
                text: row.r.size || ""
                mono: true
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "coprresult" && !!row.r.installed
                text: row.r.enabled ? "enabled" : "added"
                icon: "check"
                fg: Theme.success
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "pkg" && row.r.src === "flatpak" && !row.r.installed && !row.r.installable
                text: "no remote"
                fg: Theme.warning
            }

            // --- Knöpfe
            PkgSpinner {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "coprsearch" && row.r.busy
            }
            PkgBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "coprsearch" && row.r.done && !row.r.busy
                text: "results below"
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "coprsearch" && !row.r.busy && !row.r.done
                kind: "on"
                icon: "search"
                text: "Search"
                onClicked: row.pk.searchCopr()
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "pkg" && !!row.r.upgrade
                enabled: !row.pk.busy
                kind: "on"
                icon: "download"
                text: "Update"
                onClicked: row.pk.request("update", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "pkg" && !row.r.installed && (row.r.src === "system" || !!row.r.installable)
                enabled: !row.pk.busy
                kind: "on"
                icon: "add"
                text: "Install"
                onClicked: row.pk.request("install", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "pkg" && !!row.r.installed && !row.onUpdates && row.r.src !== "devtools"
                enabled: !row.pk.busy
                kind: "danger"
                icon: "delete"
                onClicked: row.pk.request("remove", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "repo"
                enabled: !row.pk.busy
                text: row.r.enabled ? "Disable" : "Enable"
                onClicked: row.pk.request(row.r.enabled ? "disable" : "enable", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "repo"
                enabled: !row.pk.busy
                kind: "danger"
                icon: "delete"
                onClicked: row.pk.request("remove", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "coprresult" && !row.r.installed
                enabled: !row.pk.busy
                kind: "on"
                icon: "add"
                text: "Enable"
                onClicked: row.pk.request("enable", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "dnfrepo" && !row.r.copr
                enabled: !row.pk.busy
                text: row.r.enabled ? "Disable" : "Enable"
                onClicked: row.pk.request("repo-toggle", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: (row.kind === "vendor" && !row.r.present) || row.kind === "addrepo"
                enabled: !row.pk.busy
                kind: "on"
                icon: "add"
                text: "Add repo"
                onClicked: row.pk.request("add", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "remote"
                enabled: !row.pk.busy
                text: row.r.enabled ? "Disable" : "Enable"
                onClicked: row.pk.request("remote-toggle", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "appimage"
                enabled: !row.pk.busy && !!row.r.executable
                kind: "on"
                icon: "play_arrow"
                text: "Run"
                onClicked: row.pk.request("run", row.r)
            }
            Button {
                small: true
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "appimage"
                enabled: !row.pk.busy
                kind: "danger"
                icon: "delete"
                onClicked: row.pk.request("remove", row.r)
            }
        }

        // Text
        Column {
            anchors.left: ico.right
            anchors.leftMargin: 14
            anchors.right: right.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Row {
                id: titleRow
                width: parent.width
                spacing: 10
                Txt {
                    id: nameT
                    width: Math.min(implicitWidth, parent.width - (verT.visible ? verT.width + parent.spacing : 0))
                    text: row.kind === "coprsearch" ? "Search COPR for “" + row.r.q + "”" : row.kind === "addrepo" ? "Add repo from this file" : (row.r.name || row.r.id || "")
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.DemiBold
                }
                MonoTxt {
                    id: verT
                    visible: text !== "" && row.kind === "pkg" && !row.r.upgrade
                    width: Math.min(implicitWidth, 200)
                    elide: Text.ElideRight
                    anchors.verticalCenter: nameT.verticalCenter
                    text: row.r.version || ""
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                }
            }
            Txt {
                width: parent.width
                text: row.kind === "coprsearch" ? "Community repos on copr.fedorainfracloud.org (needs network, a few seconds)" : row.kind === "addrepo" ? row.r.url : (row.r.desc || "")
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
            }
        }
    }

    // ---------------------------------------------------------------- Details
    Column {
        id: detail
        visible: row.expanded
        x: 60
        y: row.base
        width: parent.width - 60 - 16
        spacing: 8
        opacity: row.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        // Paket / COPR-Repo: Info vom Backend
        Row {
            visible: !!(row.info && row.info.loading)
            spacing: 8
            PkgSpinner { size: 16 }
            Txt { text: "Loading details…"; color: Theme.textFaint; font.pixelSize: Theme.fontSm }
        }
        Txt {
            visible: !!(row.info && row.info.error)
            width: parent.width
            text: row.info && row.info.error ? row.info.error : ""
            color: Theme.warning
            font.pixelSize: Theme.fontSm
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Txt {
            visible: !!(row.info && row.info.description)
            width: parent.width
            text: row.info && row.info.description ? row.info.description : ""
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
            font.weight: Font.Normal
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            maximumLineCount: 6
        }
        Flow {
            visible: row.kind === "pkg" && !!(row.info && row.info.info)
            width: parent.width
            spacing: 6
            Repeater {
                model: row.info && row.info.info ? Object.keys(row.info.info).filter(k => row.info.info[k]) : []
                PkgBadge {
                    required property string modelData
                    text: modelData + "  " + row.info.info[modelData]
                    mono: true
                }
            }
        }

        // COPR-Treffer / Remote / dnf-Repo: nur die Rohdaten
        Flow {
            visible: row.kind === "coprresult" || row.kind === "remote" || row.kind === "dnfrepo"
            width: parent.width
            spacing: 6
            PkgBadge { visible: !!row.r.homepage; text: row.r.homepage || ""; mono: true }
            PkgBadge { visible: !!row.r.repoid; text: row.r.repoid || ""; mono: true }
            PkgBadge { visible: !!row.r.url; text: row.r.url || ""; mono: true }
            PkgBadge { visible: row.kind === "dnfrepo"; text: row.r.id || ""; mono: true }
        }
        Txt {
            visible: row.kind === "coprresult" && !!row.r.desc
            width: parent.width
            text: row.r.desc || ""
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
            font.weight: Font.Normal
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            maximumLineCount: 6
        }

        // COPR-Repo: Pakete (installiert zuerst)
        Txt {
            visible: row.kind === "repo" && !!(row.info && row.info.items)
            text: row.info && row.info.items ? row.info.items.length + " packages in this repo" : ""
            color: Theme.textFaint
            font.pixelSize: Theme.fontSm
        }
        ListView {
            id: repoPkgs
            visible: row.kind === "repo" && !!(row.info && row.info.items)
            width: parent.width
            height: visible ? Math.min(210, count * 30) : 0
            clip: true
            model: row.info && row.info.items ? row.info.items : []
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: pr
                required property var modelData
                width: ListView.view.width
                height: 30
                Txt {
                    anchors.left: parent.left
                    anchors.right: pv.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: pr.modelData.name + "  ·  " + pr.modelData.desc
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                    color: pr.modelData.installed ? Theme.text : Theme.textMuted
                }
                MonoTxt {
                    id: pv
                    anchors.right: pb.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: pr.modelData.version
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontXs
                }
                Button {
                    small: true
                    id: pb
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 24
                    height: 24
                    enabled: !row.pk.busy && !pr.modelData.installed && row.r.enabled
                    text: pr.modelData.installed ? "installed" : "Install"
                    kind: pr.modelData.installed ? "secondary" : "on"
                    onClicked: row.pk.request("install-pkg", { src: "copr", id: pr.modelData.id, name: pr.modelData.name })
                }
            }
        }

        // AppImage
        MonoTxt {
            visible: row.kind === "appimage"
            width: parent.width
            text: row.r.path || ""
            elide: Text.ElideMiddle
            color: Theme.textMuted
            font.pixelSize: Theme.fontXs
        }
        Flow {
            visible: row.kind === "appimage"
            width: parent.width
            spacing: 6
            PkgBadge { text: "modified  " + Qt.formatDateTime(new Date((row.r.mtime || 0) * 1000), "yyyy-MM-dd"); mono: true }
        }
        Row {
            visible: row.kind === "appimage"
            spacing: 8
            Button {
                small: true
                enabled: !row.pk.busy
                icon: row.r.desktop ? "link_off" : "add_link"
                text: row.r.desktop ? "Remove menu entry" : "Add menu entry"
                onClicked: row.pk.request(row.r.desktop ? "desktop-remove" : "desktop-add", row.r)
            }
            Button {
                small: true
                visible: !!row.r.updater
                enabled: !row.pk.busy
                icon: "download"
                text: "Update (AppImageUpdate)"
                onClicked: row.pk.request("update", row.r)
            }
            Button {
                small: true
                visible: !row.r.executable
                enabled: !row.pk.busy
                icon: "lock_open"
                text: "Make executable"
                onClicked: row.pk.request("chmod", row.r)
            }
        }
        Item { width: 1; height: 8 }
    }
}
