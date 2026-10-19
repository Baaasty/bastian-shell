import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

Kirigami.FormLayout {
    id: configForm

    // TODO Plasma 7: Make this an enum.
    property bool cfg_alwaysShowClock
    property bool cfg_hideClockWhenIdle
    property bool cfg_alwaysShowClockDefault: true
    property bool cfg_hideClockWhenIdleDefault: false

    property alias cfg_showMediaControls: showMediaControls.checked
    property bool cfg_showMediaControlsDefault: false

    twinFormLayouts: parentLayout

    QQC2.RadioButton {
        Kirigami.FormData.label: "Show clock:"
        text: "Always"
        Accessible.name: "Always show clock"
        checked: configForm.cfg_alwaysShowClock && !configForm.cfg_hideClockWhenIdle
        onToggled: {
            configForm.cfg_alwaysShowClock = true;
            configForm.cfg_hideClockWhenIdle = false;
        }

        KCM.SettingHighlighter {
            id: clockAlwaysHighlighter
            highlight: configForm.cfg_alwaysShowClock != configForm.cfg_alwaysShowClockDefault
                || configForm.cfg_hideClockWhenIdle != configForm.cfg_hideClockWhenIdleDefault
        }
    }

    QQC2.RadioButton {
        text: "On unlocking prompt"
        Accessible.name: "Show clock only on unlocking prompt"
        checked: configForm.cfg_alwaysShowClock && configForm.cfg_hideClockWhenIdle
        onToggled: {
            configForm.cfg_alwaysShowClock = true;
            configForm.cfg_hideClockWhenIdle = true;
        }

        KCM.SettingHighlighter {
            highlight: clockAlwaysHighlighter.highlight
        }
    }

    QQC2.RadioButton {
        text: "Never"
        Accessible.name: "Never show clock"
        checked: !configForm.cfg_alwaysShowClock
        onToggled: {
            configForm.cfg_alwaysShowClock = false;
        }

        KCM.SettingHighlighter {
            highlight: clockAlwaysHighlighter.highlight
        }
    }

    QQC2.CheckBox {
        id: showMediaControls
        Kirigami.FormData.label: "Media controls:"
        text: "Show under unlocking prompt"

        KCM.SettingHighlighter {
            highlight: configForm.cfg_showMediaControlsDefault != configForm.cfg_showMediaControls
        }
    }
}
