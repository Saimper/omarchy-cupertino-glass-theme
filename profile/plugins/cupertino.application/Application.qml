import QtQuick
import QtQuick.Controls as Controls
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "../cupertino.desktop" as Cupertino
import "../cupertino.menubar" as MenuBar

BarWidget {
    id: root
    moduleName: "cupertino.application"
    implicitHeight: barSize
    implicitWidth: row.implicitWidth
    readonly property var focused: ToplevelManager.activeToplevel
    property var lastActive: null
    property var menuTarget: null
    property string menuAddress: ""
    onFocusedChanged: {
        if (focused) {
            if (lastActive && focused !== lastActive) closeMenus();
            lastActive = focused;
        }
    }
    Component.onCompleted: if (focused) lastActive = focused
    readonly property var active: focused || (ToplevelManager.toplevels.values.indexOf(lastActive) >= 0 ? lastActive : null)
    readonly property var entry: active ? DesktopEntries.heuristicLookup(active.appId) : null
    readonly property string appId: String(active ? active.appId : "").toLowerCase()
    readonly property bool terminal: /^(foot|footclient|alacritty|kitty|wezterm|com\.mitchellh\.ghostty|org\.codeberg\.dnkl\.foot|org\.omarchy\.|tui\.)/.test(appId)
    readonly property bool footTerminal: /foot|^org\.omarchy\.|^tui\./.test(appId)
    readonly property bool files: /nautilus|thunar|dolphin|nemo/.test(appId)
    readonly property bool browser: /brave|chromium|chrome|firefox/.test(appId)
    readonly property bool editor: /^(code|code-oss|codium|obsidian|org\.gnome\.texteditor|org\.gnome\.gedit)$/.test(appId)
    readonly property bool supportedDocument: browser || files || editor
    readonly property bool dark: Color.background.hslLightness < 0.5
    readonly property color ink: bar ? bar.barForeground : Color.foreground
    readonly property string family: "Inter Variable"
    readonly property string appName: terminal ? "Terminal" : (entry ? entry.name : (active ? active.appId : "Escritorio")).replace(/ Desktop$/, "")
    function run(args) { Quickshell.execDetached(args); }
    function closeMenus() {
        for (const menu of [appleMenu, applicationMenu, fileMenu, editMenu, viewMenu, windowMenu, helpMenu]) menu.close();
    }
    function prepare(menu) {
        menuTarget = active;
        menuAddress = active ? String(active.HyprlandToplevel.address) : "";
        menu.popup();
    }
    function targetAlive() { return menuTarget && ToplevelManager.toplevels.values.indexOf(menuTarget) >= 0; }
    function windowAction(action) {
        if (!targetAlive() || !/^(0x)?[0-9a-f]+$/i.test(menuAddress)) return;
        run([Quickshell.env("HOME")+"/.local/share/cupertino-glass/bin/cupertino-window", action, menuAddress]);
    }
    // Exact window targeting prevents an open menu from sending keys to another app.
    // Explicit up/down follows Omarchy's workaround for held synthetic modifiers.
    function shortcut(mods, key) {
        if (!targetAlive() || !/^(0x)?[0-9a-f]+$/i.test(menuAddress)) return;
        const address = "address:"+(menuAddress.startsWith("0x") ? menuAddress : "0x"+menuAddress);
        const keyArguments = 'window="'+address+'",mods="'+mods+'",key="'+key+'"';
        run(["hyprctl", "eval", 'hl.dispatch(hl.dsp.send_key_state({'+keyArguments+',state="down"})); hl.timer(function() hl.dispatch(hl.dsp.send_key_state({'+keyArguments+',state="up"})) end, {timeout=50,type="oneshot"})']);
    }
    function newWindow() {
        if (terminal) run(["omarchy", "launch", "terminal"]);
        else if (supportedDocument) shortcut("CTRL", "N");
    }
    function helpUrl() {
        if (terminal) return "https://codeberg.org/dnkl/foot/wiki";
        if (files) return "https://help.gnome.org/users/gnome-help/stable/files.html.es";
        if (/brave/.test(appId)) return "https://support.brave.com/hc/es";
        if (/firefox/.test(appId)) return "https://support.mozilla.org/es/products/firefox";
        if (/obsidian/.test(appId)) return "https://help.obsidian.md/";
        if (/code|codium/.test(appId)) return "https://code.visualstudio.com/docs";
        return "https://learn.omacom.io/2/the-omarchy-manual";
    }
    component Menu: Controls.Menu {
        width: 244
        padding: 5
        topMargin: 4
        font { family: root.family; pixelSize: 13 }
        popupType: Controls.Popup.Window
        background: Cupertino.GlassSurface {
            dark: root.dark; radius: 9; shadowPadding: 0; shadowOpacity: 0
            materialName: "ultrathin"; tint: root.dark ? 0.84 : 0.86
        }
    }
    component MenuItem: Controls.MenuItem {
        id: item
        property string keyHint: ""
        implicitHeight: 26
        font { family: root.family; pixelSize: 13 }
        leftPadding: 10; rightPadding: 9
        background: Rectangle { radius: 4; color: item.highlighted && item.enabled ? "#0a74f5" : "transparent" }
        contentItem: Item {
            implicitWidth: title.implicitWidth+hint.implicitWidth+30
            Text { id:title; anchors.left:parent.left;anchors.right:hint.left;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter
                text:item.text; font:item.font; elide:Text.ElideRight
                color: !item.enabled ? (root.dark ? "#78787d" : "#8e8e93") : item.highlighted ? "white" : (root.dark ? "#f5f5f7" : "#202124") }
            Text { id:hint;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;text:item.keyHint;font:item.font
                color: item.highlighted && item.enabled ? "#e5f0ff" : root.dark ? "#98989e" : "#717176" }
        }
    }
    component MenuButton: Controls.Button {
        height: root.barSize
        leftPadding: 8; rightPadding: 8
        font { family: root.family; pixelSize: 11; weight: Font.Medium }
        background: Rectangle { radius: 4; color: parent.hovered || parent.down ? Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.15) : "transparent" }
        contentItem: Text { text:parent.text;font:parent.font;color:root.ink;verticalAlignment:Text.AlignVCenter }
    }
    Row {
        id: row
        height: parent.height
        spacing: 0
        Controls.Button {
            width: 31; height: parent.height
            Accessible.name: "Menú del escritorio"
            onClicked: root.prepare(appleMenu)
            background: Rectangle { radius: 4; color: parent.hovered || parent.down ? Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.15) : "transparent" }
            contentItem: Item { MenuBar.BarSymbol { anchors.centerIn:parent;width:17;height:18;symbolName:"apple.logo";ink:root.ink } }
            Menu {
                id: appleMenu
                MenuItem { text:"Ajustes del escritorio…"; onTriggered:root.run(["omarchy","menu","toggle"]) }
                MenuItem { text:"Centro de control"; onTriggered:root.run(["omarchy-shell","cupertino.controls","toggle"]) }
                MenuItem { text:"Perfiles de escritorio…"; onTriggered:root.run(["omarchy-shell","cupertino.profiles","toggle"]) }
                Controls.MenuSeparator {}
                MenuItem { text:"Aplicaciones"; keyHint:"Super A"; onTriggered:root.run(["omarchy-shell","cupertino.apps","toggle"]) }
                MenuItem { text:"Carpeta personal"; onTriggered:root.run(["omarchy","launch","nautilus"]) }
                Controls.MenuSeparator {}
                MenuItem { text:"Bloquear pantalla"; onTriggered:root.run(["omarchy","system","lock"]) }
            }
        }
        MenuButton {
            text: root.appName
            font.weight: Font.Bold
            implicitWidth: Math.min(148,contentItem.implicitWidth+16)
            contentItem: Text {text:parent.text;font:parent.font;color:root.ink;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
            onClicked:root.prepare(applicationMenu)
            Menu {
                id: applicationMenu
                MenuItem {text:"Todas las ventanas de "+root.appName;enabled:!!root.active;onTriggered:{if(!root.targetAlive())return;for(const w of ToplevelManager.toplevels.values)if(w.appId===root.menuTarget.appId){root.run([Quickshell.env("HOME")+"/.local/share/cupertino-glass/bin/cupertino-window","restore",String(w.HyprlandToplevel.address)]);}}}
                MenuItem {text:"Minimizar ventana";enabled:!!root.active;onTriggered:root.windowAction("minimize")}
                Controls.MenuSeparator {}
                MenuItem {text:"Ayuda de "+root.appName;onTriggered:root.run(["xdg-open",root.helpUrl()])}
                MenuItem {text:"Cerrar ventana";enabled:!!root.active;onTriggered:root.windowAction("close")}
            }
        }
        MenuButton {
            text:"Archivo"
            onClicked:root.prepare(fileMenu)
            Menu {
                id:fileMenu
                MenuItem {text:"Nueva ventana";enabled:root.terminal||root.supportedDocument;keyHint:root.terminal?"Super T":"Ctrl N";onTriggered:root.newWindow()}
                MenuItem {text:"Nueva pestaña";visible:root.browser||root.files;enabled:visible;keyHint:"Ctrl T";onTriggered:root.shortcut("CTRL","T")}
                MenuItem {text:root.files?"Ir a la ubicación…":"Abrir archivo…";visible:root.supportedDocument;enabled:visible;keyHint:root.files?"Ctrl L":"Ctrl O";onTriggered:root.shortcut("CTRL",root.files?"L":"O")}
                MenuItem {text:"Guardar";visible:root.editor||root.browser;enabled:visible;keyHint:"Ctrl S";onTriggered:root.shortcut("CTRL","S")}
                Controls.MenuSeparator {}
                MenuItem {text:"Cerrar ventana";enabled:!!root.active;onTriggered:root.windowAction("close")}
            }
        }
        MenuButton {
            text:"Edición"
            onClicked:root.prepare(editMenu)
            Menu {
                id:editMenu
                MenuItem {text:"Deshacer";enabled:!!root.active&&!root.terminal;keyHint:"Ctrl Z";onTriggered:root.shortcut("CTRL","Z")}
                MenuItem {text:"Rehacer";enabled:root.editor||root.files;keyHint:"Ctrl Shift Z";onTriggered:root.shortcut("CTRL SHIFT","Z")}
                Controls.MenuSeparator {}
                MenuItem {text:"Cortar";enabled:!!root.active&&!root.terminal;keyHint:"Super X";onTriggered:root.shortcut("CTRL","X")}
                MenuItem {text:"Copiar";enabled:!!root.active;keyHint:"Super C";onTriggered:root.shortcut("CTRL",root.terminal&&!root.footTerminal?"Insert":"C")}
                MenuItem {text:"Pegar";enabled:!!root.active;keyHint:"Super V";onTriggered:root.shortcut(root.terminal&&!root.footTerminal?"SHIFT":"CTRL",root.terminal&&!root.footTerminal?"Insert":"V")}
                MenuItem {text:"Seleccionar todo";enabled:!!root.active&&!root.terminal;keyHint:"Ctrl A";onTriggered:root.shortcut("CTRL","A")}
                Controls.MenuSeparator {}
                MenuItem {text:"Historial del portapapeles";keyHint:"Super Ctrl V";onTriggered:root.run(["omarchy-shell","shell","toggle","omarchy.clipboard"])}
            }
        }
        MenuButton {
            text:"Ver"
            onClicked:root.prepare(viewMenu)
            Menu {
                id:viewMenu
                MenuItem {text:"Ampliar";enabled:root.terminal||root.supportedDocument;keyHint:"Ctrl +";onTriggered:root.shortcut("CTRL","plus")}
                MenuItem {text:"Reducir";enabled:root.terminal||root.supportedDocument;keyHint:"Ctrl −";onTriggered:root.shortcut("CTRL","minus")}
                MenuItem {text:"Tamaño real";enabled:root.terminal||root.supportedDocument;keyHint:"Ctrl 0";onTriggered:root.shortcut("CTRL","0")}
                Controls.MenuSeparator {}
                MenuItem {text:root.active&&root.active.fullscreen?"Salir de pantalla completa":"Entrar en pantalla completa";enabled:!!root.active;onTriggered:{if(root.targetAlive())root.menuTarget.fullscreen=!root.menuTarget.fullscreen}}
            }
        }
        MenuButton {
            text:"Ventana"
            onClicked:root.prepare(windowMenu)
            Menu {
                id:windowMenu
                MenuItem {text:"Minimizar";enabled:!!root.active;onTriggered:root.windowAction("minimize")}
                MenuItem {text:root.active&&root.active.maximized?"Restaurar tamaño":"Maximizar";keyHint:"Super O";enabled:!!root.active;onTriggered:root.windowAction("maximize")}
                Controls.MenuSeparator {}
                Instantiator {
                    model:ToplevelManager.toplevels.values
                    delegate:MenuItem {
                        required property var modelData
                        text:(modelData===root.active?"✓  ":"")+(modelData.title||modelData.appId)
                        onTriggered:root.run([Quickshell.env("HOME")+"/.local/share/cupertino-glass/bin/cupertino-window","restore",String(modelData.HyprlandToplevel.address)])
                    }
                    onObjectAdded:(index,object)=>windowMenu.insertItem(index+3,object)
                    onObjectRemoved:(index,object)=>windowMenu.removeItem(object)
                }
            }
        }
        MenuButton {
            text:"Ayuda"
            onClicked:root.prepare(helpMenu)
            Menu {
                id:helpMenu
                MenuItem {text:"Ayuda de "+root.appName;onTriggered:root.run(["xdg-open",root.helpUrl()])}
                MenuItem {text:"Manual de Omarchy";onTriggered:root.run(["xdg-open","https://learn.omacom.io/2/the-omarchy-manual"])}
                Controls.MenuSeparator {}
                MenuItem {text:"Atajos de teclado";onTriggered:root.run(["omarchy","menu","keybindings"])}
            }
        }
    }
}
