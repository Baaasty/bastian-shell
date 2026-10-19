pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Spotify über MPRIS (Flatpak meldet sich als org.mpris.MediaPlayer2.spotify)
Singleton {
    readonly property var spotify: Mpris.players.values.find(p => p.identity === "Spotify" || (p.dbusName || "").indexOf("spotify") >= 0) ?? null
    // Medientasten und Sperrbildschirm: was gerade spielt, sonst Spotify, sonst der erste Spieler
    readonly property var active: Mpris.players.values.find(p => p.isPlaying) ?? spotify ?? Mpris.players.values[0] ?? null
}
