import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root
    property string linkPath: Quickshell.env("HOME")+"/.local/state/omarchy/current/background"
    property url source: ""
    function refresh() { if (!resolve.running) resolve.running=true; }
    FileView {
        path: root.linkPath.substring(0,root.linkPath.lastIndexOf("/"))
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }
    Process {
        id: resolve
        command: ["readlink","-f",root.linkPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const path=text.trim();
                root.source=path ? Util.fileUrl(path) : "";
            }
        }
    }
    Component.onCompleted: refresh()
}
