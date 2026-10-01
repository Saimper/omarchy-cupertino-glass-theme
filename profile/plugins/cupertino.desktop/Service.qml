import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

Item {
    id: root
    property var shell: null
    property var settings: ({})
    property string omarchyPath: ""
    readonly property bool profileActive: true

    // Binding restoration leaves the native typography in place on profile exit.
    Binding {
        target: Style
        property: "fontFamily"
        value: "Inter Variable"
        restoreMode: Binding.RestoreBindingOrValue
    }
    IpcHandler {
        target: "cupertino.profile"
        function ping(): string { return "ok"; }
    }
    AppLibrary {}
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if(event.name!=="minimized")return;
            const fields=event.data.split(",");
            if(fields.length!==2 || !/^[0-9a-f]+$/i.test(fields[0]))return;
            Quickshell.execDetached([Quickshell.env("HOME")+"/.local/share/cupertino-glass/bin/cupertino-window",fields[1]==="1"?"minimize":"restore",fields[0]]);
        }
    }
    WallpaperSource { id: wallpaper }
    Process { command: [Quickshell.env("HOME")+"/.local/bin/cupertino", "chime"]; running: true }
    Variants {
        model: Quickshell.screens
        delegate: Dock {
            required property var modelData
            screen: modelData
            wallpaperSource: wallpaper.source
        }
    }
}
