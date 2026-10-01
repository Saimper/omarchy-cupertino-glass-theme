import QtQuick

// Public distribution: scalable, openly licensed Nerd Font glyphs.
Item {
    id: root
    property string symbolName: ""
    property string weight: "regular"
    property color ink: "white"
    readonly property bool ready: true
    readonly property var glyphs: {"wifi": "󰤨", "wifi.slash": "󰤭", "wifi.exclamationmark": "󰤫", "bluetooth": "󰂯", "bluetooth.slash": "󰂲", "display": "󰍹", "speaker.slash.fill": "󰝟", "speaker.fill": "󰕿", "speaker.wave.1.fill": "󰖀", "speaker.wave.2.fill": "󰕾", "speaker.wave.3.fill": "󰕾", "sun.max.fill": "󰃠", "moon.fill": "󰖔", "menubar.dock.rectangle": "󰹑", "square.grid.2x2": "󰀻", "rectangle.on.rectangle": "󰏘", "pause.fill": "󰏤", "play.fill": "󰐊", "backward.fill": "󰒮", "forward.fill": "󰒭", "magnifyingglass": "󰍉", "switch.2": "󰒓", "music.note": "󰎆", "xmark": "󰅖", "apple.logo": "", "battery.100percent": "󰁹", "battery.100percent.bolt": "󰂄", "battery.75percent": "󰂁", "battery.50percent": "󰁾", "battery.25percent": "󰁻", "battery.0percent": "󰂎", "battery.5percent.trianglebadge.exclamationmark": "󰂃"}
    Text {
        anchors.fill: parent
        text: root.glyphs[root.symbolName] || "󰋗"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.min(root.width, root.height)
        color: root.ink
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
    }
}
