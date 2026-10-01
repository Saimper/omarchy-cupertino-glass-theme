import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Controls.Button {
    id: control
    readonly property bool dark: Color.background.hslLightness < 0.5
    implicitHeight: 34
    implicitWidth: Math.max(34, label.implicitWidth + 24)
    horizontalPadding: 12
    verticalPadding: 7
    font { family: "Inter Variable"; pixelSize: 12 }
    opacity: enabled ? 1 : 0.42
    background: Rectangle {
        radius: 10
        color: control.down ? (control.dark ? "#805e6b80" : "#c9d9ec")
            : control.hovered ? (control.dark ? "#80525763" : "#f2ffffff")
            : (control.dark ? "#50454954" : "#99ffffff")
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Color.accent : (control.dark ? "#25ffffff" : "#aaffffff")
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    contentItem: Text {
        id: label
        text: control.text
        color: Color.foreground
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
