import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import qs.Commons
import qs.Ui
import "../cupertino.menubar" as MenuBar

Panel {
    id: root
    moduleName: "cupertino.desktop"
    ipcTarget: "cupertino.controls"
    implicitWidth: 56
    implicitHeight: bar ? bar.barSize : 28
    readonly property bool dark: Color.background.hslLightness < 0.5
    readonly property color ink: dark ? "#f2f2f3" : "#202124"
    readonly property var sinks: Pipewire.nodes.values.filter(n=>n && n.isSink && !n.isStream)
    property string sinkName: ""
    readonly property var sink: sinks.find(n=>n.name===sinkName) || Pipewire.defaultAudioSink
    property int brightness: 50
    property bool brightnessAvailable: false
    property string wifiState: "Redes"
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p=>p.isPlaying) || players[0] || null
    PwObjectTracker { objects: root.sinks }
    component ControlGlass: GlassSurface {
        dark: root.dark
        materialName: "ultrathin"
        // Material recipes are inputs, not macOS runtime output. The compositor
        // already supplies the blur; this thin film avoids double-darkening it.
        tint: recipe.rgba[3] * (root.dark ? 0.8 : 0.95)
        edgeStrength: 1.15
        opticalLift: root.dark ? 0.012 : 0.008
        shadowOpacity: 0.075
        panelOptics: 0.7
        // Content beneath a popover may be an application, not the wallpaper.
        // Keep its optical edge neutral; the compositor blurs the real backdrop.
        refraction: 0
    }
    function run(args) { Quickshell.execDetached(args); }
    function panel(target) { close();run(["omarchy-shell",target,"toggle"]); }
    function refresh() {
        if(!brightnessRead.running) brightnessRead.running=true;
        if(!sinkRead.running) sinkRead.running=true;
        if(!wifiRead.running) wifiRead.running=true;
    }
    onOpenedChanged: {
        if(opened){refresh();Qt.callLater(()=>content.forceActiveFocus());focusPrime.restart();if(bar)bar.requestPopout(root);}
        else{focusPrime.stop();overlay.primed=false;if(bar&&bar.activePopout===root)bar.releasePopout(root);}
    }
    Timer{id:focusPrime;interval:70;onTriggered:overlay.primed=true}
    Process {id:sinkRead;command:["omarchy-audio-output-sink"];stdout:StdioCollector{onStreamFinished:root.sinkName=text.trim()}}
    Process {
        id:brightnessRead;command:["omarchy","brightness","display"]
        stdout:StdioCollector{onStreamFinished:{let value=parseInt(text.trim());root.brightnessAvailable=isFinite(value);if(isFinite(value))root.brightness=value;}}
    }
    Process {
        id:wifiRead;command:["env","LC_ALL=C","nmcli","-t","-f","TYPE,STATE","device"]
        stdout:StdioCollector{onStreamFinished:root.wifiState=text.indexOf("wifi:connected")>=0?"Conectado":"Redes disponibles"}
    }
    Timer {interval:5000;running:root.opened;repeat:true;onTriggered:root.refresh()}
    Timer {id:brightnessWrite;interval:100;onTriggered:root.run(["omarchy","brightness","display","--no-osd",root.brightness+"%"])}
    BarIconButton {
        id:search;anchors.left:parent.left;width:28;height:parent.height;bar:root.bar;tooltipText:"Buscar aplicaciones";opticalSize:16
        iconComponent:Component { MenuBar.BarSymbol {symbolName:"magnifyingglass";ink:root.barForeground} }
        onPressed:root.run(["omarchy-shell","cupertino.apps","toggle"])
    }
    BarIconButton {
        id:button;anchors.right:parent.right;width:28;height:parent.height;bar:root.bar;tooltipText:"Centro de control";opticalSize:16
        iconComponent:Component { MenuBar.BarSymbol {symbolName:"switch.2";ink:root.barForeground} }
        onPressed:root.toggle()
    }
    component Capsule: Controls.Button {
        id:cap
        property string glyph:""
        property string title:""
        property string detail:""
        property bool blue:false
        padding:0
        leftInset:0;rightInset:0;topInset:0;bottomInset:0
        implicitHeight:64
        Accessible.name: title || detail
        background:ControlGlass{radius:height/2;highlighted:cap.hovered || cap.down}
        contentItem:Item {
            Rectangle {
                x:cap.title?10:(parent.width-width)/2;anchors.verticalCenter:parent.verticalCenter
                width:34;height:34;radius:17;color:cap.blue?"#f8ffffff":"transparent"
                Symbol {anchors.centerIn:parent;width:21;height:21;glyph:cap.glyph;ink:cap.blue?"#007aff":root.ink}
            }
            Column {
                visible:cap.title!=="";x:51;width:parent.width-56;anchors.verticalCenter:parent.verticalCenter;spacing:2
                Text {style:root.dark?Text.Raised:Text.Normal;styleColor:"#80000000";width:parent.width;text:cap.title;color:root.ink;elide:Text.ElideRight;font{family:"Inter Variable";pixelSize:12;weight:Font.DemiBold}}
                Text {style:root.dark?Text.Raised:Text.Normal;styleColor:"#80000000";visible:text!=="";width:parent.width;text:cap.detail;color:root.ink;opacity:0.85;elide:Text.ElideRight;font{family:"Inter Variable";pixelSize:11}}
            }
        }
    }
    PanelWindow {
        id:overlay
        // Region.item does not track an ancestor's scale animation in Quickshell
        // 0.3.1. Fixed final bounds include the shadow and avoid a stale 97% crop.
        BackgroundEffect.blurRegion: Region {
            x: content.x-14; y: content.y-14
            width: content.width+28; height: content.height+28
        }
        visible:root.opened || content.opacity>0
        screen:button.QsWindow.window ? button.QsWindow.window.screen : null
        anchors{left:true;right:true;top:true;bottom:true}
        exclusionMode:ExclusionMode.Ignore
        color:"transparent"
        WlrLayershell.namespace:"cupertino-controls"
        WlrLayershell.layer:WlrLayer.Overlay
        property bool primed:false
        WlrLayershell.keyboardFocus:root.opened ? (primed?WlrKeyboardFocus.OnDemand:WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
        mask:Region {y:root.bar?root.bar.barSize:28;width:root.opened?overlay.width:0;height:root.opened?overlay.height-y:0}
        onBackingWindowVisibleChanged:if(backingWindowVisible&&root.opened)Qt.callLater(()=>content.forceActiveFocus())
        MouseArea{anchors.fill:parent;onClicked:root.close()}
        Item {
            id:content
            enabled:root.opened
            width:294;height:444
            anchors.right:parent.right;anchors.rightMargin:12
            y:(root.bar ? root.bar.barSize : 28)+9
            opacity:root.opened?1:0
            scale:root.opened?1:0.97
            transformOrigin:Item.TopRight
            Behavior on opacity{NumberAnimation{duration:root.opened?200:140;easing.type:Easing.OutCubic}}
            Behavior on scale{NumberAnimation{duration:220;easing.type:Easing.OutCubic}}
            focus:true
            Keys.onEscapePressed:root.close()
            MouseArea{anchors.fill:parent}
            ColumnLayout {
                anchors.fill:parent;spacing:12
                RowLayout {
                    Layout.fillWidth:true;spacing:12
                    ColumnLayout {
                        Layout.fillWidth:true;spacing:12
                        Capsule{Layout.fillWidth:true;title:"Wi-Fi";detail:root.wifiState;glyph:"󰤨";blue:root.wifiState==="Conectado";onClicked:root.panel("omarchy.network")}
                        RowLayout {
                            Layout.fillWidth:true;spacing:12
                            Capsule{Layout.fillWidth:true;glyph:"󰂯";detail:"Bluetooth";blue:!!Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled;onClicked:root.panel("omarchy.bluetooth")}
                            Capsule{Layout.fillWidth:true;glyph:"󰁹";detail:"Batería y energía";onClicked:root.panel("omarchy.power")}
                        }
                    }
                    ControlGlass {
                        Layout.preferredWidth:141;Layout.preferredHeight:140
                        radius:29
                        Column {
                            anchors.fill:parent;anchors.margins:12;spacing:5
                            Row {
                                spacing:8;width:parent.width;height:38
                                Rectangle {
                                    width:36;height:36;radius:9;color:"#24ffffff"
                                    Image{anchors.fill:parent;anchors.margins:1;source:root.player?root.player.trackArtUrl:"";fillMode:Image.PreserveAspectFit;visible:status===Image.Ready}
                                    NativeSymbol{anchors.centerIn:parent;width:26;height:26;symbolName:"music.note";ink:root.ink;visible:!root.player || !root.player.trackArtUrl}
                                }
                                Text{style:root.dark?Text.Raised:Text.Normal;styleColor:"#50000000";width:parent.width-44;anchors.verticalCenter:parent.verticalCenter;text:root.player?root.player.identity:"Música";color:root.ink;opacity:0.8;elide:Text.ElideRight;font{family:"Inter Variable";pixelSize:10}}
                            }
                            Text{style:root.dark?Text.Raised:Text.Normal;styleColor:"#50000000";width:parent.width;text:root.player?(root.player.trackTitle||"Sin reproducción"):"Sin reproducción";color:root.ink;elide:Text.ElideRight;font{family:"Inter Variable";pixelSize:11;weight:Font.DemiBold}}
                            Text{style:root.dark?Text.Raised:Text.Normal;styleColor:"#50000000";width:parent.width;height:13;text:root.player?root.player.trackArtist:"";color:root.ink;opacity:0.8;elide:Text.ElideRight;font{family:"Inter Variable";pixelSize:11}}
                            Row {
                                anchors.horizontalCenter:parent.horizontalCenter;spacing:3
                                Repeater {
                                    model:[{glyph:"󰒮",name:"Anterior"},{glyph:root.player&&root.player.isPlaying?"󰏤":"󰐊",name:"Reproducir o pausar"},{glyph:"󰒭",name:"Siguiente"}]
                                    delegate:Controls.Button {
                                        required property var modelData
                                        required property int index
                                        width:34;height:26
                                        enabled:!!root.player&&(index===0?root.player.canGoPrevious:index===2?root.player.canGoNext:root.player.canTogglePlaying)
                                        Accessible.name:modelData.name
                                        onClicked:index===0?root.player.previous():index===2?root.player.next():root.player.togglePlaying()
                                        background:Rectangle{radius:10;color:parent.hovered?"#24ffffff":"transparent"}
                                        contentItem:Item {Symbol{anchors.centerIn:parent;width:19;height:19;glyph:parent.parent.modelData.glyph;ink:root.ink;opacity:parent.parent.enabled?1:0.3}}
                                    }
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth:true;spacing:12
                    Capsule{Layout.preferredWidth:141;title:"Enfoque";glyph:"󰂛";onClicked:{root.close();root.run(["omarchy","toggle","notification","silencing"]);}}
                    Capsule{Layout.fillWidth:true;glyph:"󰍹";detail:"Pantallas";onClicked:root.panel("omarchy.monitor")}
                    Capsule{Layout.fillWidth:true;glyph:"󰕾";detail:"Dispositivos de sonido";onClicked:root.panel("omarchy.audio")}
                }
                ControlGlass {
                    Layout.fillWidth:true;Layout.preferredHeight:64;radius:30
                    Column {
                        anchors.fill:parent;anchors.leftMargin:18;anchors.rightMargin:18;anchors.topMargin:11;spacing:2
                        Text{style:root.dark?Text.Raised:Text.Normal;styleColor:"#50000000";text:"Pantalla";color:root.ink;font{family:"Inter Variable";pixelSize:11;weight:Font.DemiBold}}
                        GlassSlider{width:parent.width;glyph:"󰃠";from:5;to:100;stepSize:1;enabled:root.brightnessAvailable;value:root.brightness;Accessible.name:"Brillo de pantalla";onMoved:{root.brightness=Math.round(value);brightnessWrite.restart();}}
                    }
                }
                ControlGlass {
                    Layout.fillWidth:true;Layout.preferredHeight:64;radius:30
                    Column {
                        anchors.fill:parent;anchors.leftMargin:18;anchors.rightMargin:18;anchors.topMargin:11;spacing:2
                        Text{style:root.dark?Text.Raised:Text.Normal;styleColor:"#50000000";text:root.sink&&root.sink.audio&&root.sink.audio.muted?"Sonido · silenciado":"Sonido";color:root.ink;font{family:"Inter Variable";pixelSize:11;weight:Font.DemiBold}}
                        GlassSlider{width:parent.width;glyph:"󰕾";from:0;to:1;stepSize:0.01;enabled:!!(root.sink&&root.sink.audio);value:enabled?root.sink.audio.volume:0;Accessible.name:"Volumen de salida";onMoved:if(root.sink&&root.sink.audio){root.sink.audio.volume=value;root.sink.audio.muted=false;}}
                    }
                }
                RowLayout {
                    Layout.fillWidth:true;spacing:12
                    Repeater {
                        model:[{name:"Luz nocturna",glyph:"󰖔",command:["omarchy","toggle","nightlight"]},{name:"Captura",glyph:"󰹑",command:["omarchy","capture","screenshot"]},{name:"Aplicaciones",glyph:"󰀻",command:["omarchy-shell","cupertino.apps","toggle"]},{name:"Cambiar perfil",glyph:"󰏘",command:["omarchy-shell","cupertino.profiles","toggle"]}]
                        delegate:Capsule{required property var modelData;Layout.fillWidth:true;glyph:modelData.glyph;detail:modelData.name;onClicked:{root.close();root.run(modelData.command);}}
                    }
                }
            }
        }
    }
}
