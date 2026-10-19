/*
    Desktop: nur für `scripts/loginscreen shot` – macht im echten Greeter (Testmodus, offscreen, ohne root)
    Bildschirmfotos: Ruhe, aktiv, beim Tippen, „Other user“. @OUT@ und @WALLPAPER@ setzt das Skript ein.
    Wird nie installiert.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window

import org.kde.plasma.login as PlasmaLogin

Item {
    id: hook

    // oberstes Item von Main.qml (contentItem des Fensters selbst lässt sich nicht abgreifen)
    readonly property Item mainRoot: {
        let r = hook;
        while (r.parent && r.parent.parent) {
            r = r.parent;
        }
        return r;
    }

    // Wallpaper hinter die Oberfläche (im echten Login malt das ein eigener Prozess)
    Image {
        parent: hook.mainRoot
        z: -1000
        anchors.fill: parent
        source: "@WALLPAPER@"
        fillMode: Image.PreserveAspectCrop
    }

    function shot(name, next) {
        hook.mainRoot.grabToImage(result => {
            result.saveToFile("@OUT@/" + name + ".png");
            console.info("desktop-shot:", name);
            next();
        });
    }

    SequentialAnimation {
        running: true
        PauseAnimation { duration: 2500 }
        ScriptAction { script: hook.shot("1-idle", () => PlasmaLogin.GreeterState.activateWindow(hook.Window.window)) }
        PauseAnimation { duration: 2000 }
        ScriptAction { script: hook.shot("2-active", () => { PlasmaLogin.GreeterState.userListPassword = "abc"; }) }
        PauseAnimation { duration: 800 }
        ScriptAction { script: hook.shot("3-typing", () => {
            PlasmaLogin.GreeterState.userListPassword = "";
            PlasmaLogin.Authenticator.loginFailed();
        }) }
        PauseAnimation { duration: 900 }
        ScriptAction { script: hook.shot("4-failed", () => { PlasmaLogin.GreeterState.loginState = 1; }) }
        PauseAnimation { duration: 2000 }
        // Mock-Login mit dem Test-Passwort beendet den Greeter (Qt.quit hat hier keinen Empfänger)
        ScriptAction { script: hook.shot("5-other-user", () => PlasmaLogin.Authenticator.login("shot", "mypassword", 0, "")) }
    }
}
