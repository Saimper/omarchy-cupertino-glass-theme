import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../cupertino.desktop" as Cupertino
import "../cupertino.menubar" as MenuBar

Panel {
    id: root
    moduleName: "cupertino.profiles"
    ipcTarget: "cupertino.profiles"
    implicitWidth: selected === "omarchy" ? Style.bar.iconSlot : 28
    implicitHeight: bar ? bar.barSize : 28
    readonly property bool dark: Color.background.hslLightness < 0.5
    readonly property string executable: Quickshell.env("HOME") + "/.local/bin/cupertino"
    property string selected: "omarchy"
    property string originalTheme: "Omarchy"
    property bool busy: false
    property string errorText: ""
    readonly property string currentLabel: selected === "light" ? "Cupertino claro" : selected === "dark" ? "Cupertino oscuro" : "Omarchy original"

    function refresh() { if (!statusRead.running) statusRead.running = true; }
    function choose(profile) {
        if (busy || selected === profile) return;
        busy = true;
        errorText = "";
        Quickshell.execDetached(profile === "omarchy" ? [executable,"restore"] : [executable,"apply",profile]);
    }
    Component.onCompleted: refresh()
    onOpenedChanged: if (opened) refresh()
    Process {
        id: statusRead
        command: [root.executable,"status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let state = JSON.parse(text);
                    root.selected = state.profile ? state.profile.mode || "omarchy" : "omarchy";
                    root.originalTheme = state.profile ? state.profile.theme : state.theme;
                    root.busy = state.busy;
                    root.errorText = state.error || "";
                } catch (error) { root.errorText = "No se pudo leer el estado del perfil."; }
            }
        }
    }
    Timer { interval: root.busy ? 500 : 2000; repeat: true; running: root.opened; onTriggered: root.refresh() }
    BarIconButton {
        id: trigger
        anchors.fill: parent
        bar: root.bar
        opticalSize: 16
        tooltipText: "Perfiles · " + (root.busy ? "Cambiando…" : root.currentLabel)
        iconComponent: Component {
            Item {
                MenuBar.BarSymbol {anchors.fill:parent;symbolName:"rectangle.on.rectangle";ink:root.barForeground;visible:root.selected!=="omarchy"}
                Item {anchors.fill:parent;visible:root.selected==="omarchy"
                    Rectangle { x:1;y:1;width:10;height:10;radius:2.5;color:"transparent";border.width:1.2;border.color:root.barForeground;opacity:0.65 }
                    Rectangle { x:5;y:5;width:10;height:10;radius:2.5;color:"transparent";border.width:1.2;border.color:root.barForeground }
                    Rectangle { x:8;y:8;width:4;height:4;radius:1;color:root.barForeground }
                }
            }
        }
        onPressed: root.toggle()
    }
    KeyboardPanel {
        anchorItem: trigger
        bar: root.bar
        owner: root
        open: root.opened
        focusTarget: content
        contentWidth: fittedContentWidth(310)
        contentHeight: fittedContentHeight(column.implicitHeight)
        padding: 16
        Item {
            id: content
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()
            Keys.onDownPressed: choices.itemAt(0).forceActiveFocus()
            ColumnLayout {
                id: column
                width: parent.width
                spacing: 9
                Text { text: "Perfiles de escritorio"; color: Color.foreground; font { family: "Inter Variable"; pixelSize: 17; weight: Font.DemiBold } }
                Text { text: root.busy ? "Cambiando perfil…" : "Cada perfil conserva sus ajustes"; color: Color.foreground; opacity: 0.65; font { family: "Inter Variable"; pixelSize: 11 } Layout.bottomMargin: 6 }
                Repeater {
                    id: choices
                    model: [
                        {key:"omarchy",name:"Omarchy original",detail:root.originalTheme,background:"#322842",accent:"#cfb1ff"},
                        {key:"light",name:"Cupertino claro",detail:"Vidrio luminoso · Tahoe",background:"#e7f0fa",accent:"#1479e7"},
                        {key:"dark",name:"Cupertino oscuro",detail:"Vidrio profundo · Tahoe",background:"#293346",accent:"#80b8ff"}
                    ]
                    delegate: Controls.Button {
                        id: option
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 66
                        enabled: !root.busy
                        Accessible.name: modelData.name
                        Accessible.description: root.selected === modelData.key ? "Perfil activo" : "Cambiar y conservar la configuración actual"
                        onClicked: root.choose(modelData.key)
                        Keys.onUpPressed: choices.itemAt(Math.max(0,index-1)).forceActiveFocus()
                        Keys.onDownPressed: choices.itemAt(Math.min(2,index+1)).forceActiveFocus()
                        background: Rectangle {
                            radius: 13
                            color: option.hovered || root.selected === option.modelData.key
                                ? Qt.rgba(Color.accent.r,Color.accent.g,Color.accent.b,root.dark ? 0.18 : 0.10)
                                : (root.dark ? "#18ffffff" : "#99ffffff")
                            border.width: option.activeFocus ? 2 : 1
                            border.color: option.activeFocus || root.selected === option.modelData.key ? Color.accent : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        contentItem: RowLayout {
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 55; Layout.preferredHeight: 41
                                Layout.leftMargin: 4
                                radius: 8; color: option.modelData.background
                                Rectangle { x: 5; y: 5; width: 45; height: 3; radius: 1.5; color: option.modelData.accent; opacity: 0.7 }
                                Rectangle { x: 12; y: 14; width: 32; height: 18; radius: 4; color: option.modelData.key === "light" ? "#ffffff" : "#405065" }
                                Rectangle { visible: option.modelData.key !== "omarchy"; x: 15; y: 35; width: 26; height: 3; radius: 1.5; color: option.modelData.accent }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                Text { text: option.modelData.name; color: Color.foreground; font { family:"Inter Variable";pixelSize:13;weight:Font.DemiBold } }
                                Text { Layout.fillWidth: true; text: option.modelData.detail; elide: Text.ElideRight; color: Color.foreground; opacity: 0.6; font { family:"Inter Variable";pixelSize:11 } }
                            }
                            Text { text: root.selected === option.modelData.key ? "✓" : ""; color: Color.accent; font.pixelSize: 19; Layout.rightMargin: 7 }
                        }
                    }
                }
                Text {
                    visible: root.errorText !== ""
                    text: "No se completó el cambio. " + root.errorText
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    color: Color.urgent
                    font { family: "Inter Variable"; pixelSize: 11 }
                }
                Controls.Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    enabled: !root.busy
                    text: "Explorar temas de Omarchy…"
                    font { family:"Inter Variable";pixelSize:12 }
                    background: Rectangle { radius: 9; color: parent.hovered ? (root.dark ? "#25ffffff" : "#ccffffff") : "transparent"; border.width: parent.activeFocus ? 2 : 0; border.color: Color.accent }
                    contentItem: Text { text:parent.text; font:parent.font; color:Color.foreground; horizontalAlignment:Text.AlignHCenter; verticalAlignment:Text.AlignVCenter }
                    onClicked: { root.close(); Quickshell.execDetached(["omarchy-theme-switcher"]); }
                }
            }
        }
    }
}
