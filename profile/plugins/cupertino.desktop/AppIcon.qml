import QtQuick
import Quickshell
import "IconIndex.js" as Index

Item {
    id: root
    property string iconName: "application-x-executable"
    property string appId: ""
    readonly property string assetRoot: "file://" + (Quickshell.env("CUPERTINO_ASSET_ROOT") || Quickshell.env("HOME") + "/.local/share/cupertino-glass/assets")
    readonly property string token: {
        let key = (appId + " " + iconName).toLowerCase();
        if (key.indexOf("chatgpt") >= 0 || key.indexOf("codex") >= 0) return "chatgpt";
        if (key.indexOf("nautilus") >= 0) return "org.gnome.Nautilus";
        if (key.indexOf("foot") >= 0 || key.indexOf("ghostty") >= 0 || key.indexOf("alacritty") >= 0) return "utilities-terminal";
        if (key.indexOf("whatsapp") >= 0) return "whatsapp";
        return iconName || "application-x-executable";
    }
    readonly property bool originalFinder: false
    readonly property bool themed: originalFinder || !!Index.known[token]
    Rectangle {
        anchors.fill: parent; anchors.margins: parent.width*0.05
        radius: width*0.23
        visible: !root.themed
        gradient: Gradient { GradientStop { position: 0; color: "#ffffff" } GradientStop { position: 1; color: "#e1e9f3" } }
        border.width: 0.7; border.color: "#b3ffffff"
    }
    Image {
        anchors.fill: parent
        anchors.margins: root.originalFinder ? parent.width*0.0625 : root.themed ? 0 : parent.width*0.13
        source: root.themed ? root.assetRoot + "/icons/Cupertino-Glass/apps/scalable/"+root.token+".svg" : Quickshell.iconPath(root.token,"application-x-executable")
        sourceSize: Qt.size(144,144)
        fillMode: Image.PreserveAspectFit
        smooth: true; mipmap: true
        onStatusChanged: if (status === Image.Error) source = Quickshell.iconPath("application-x-executable")
    }
}
