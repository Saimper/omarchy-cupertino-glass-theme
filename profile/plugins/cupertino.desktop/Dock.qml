import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

PanelWindow {
    id: root
    color: "transparent"
    property url wallpaperSource: ""
    anchors.bottom: true
    // The surface includes the full shadow, including below the plate.
    // A layer margin leaves that area outside the buffer and cuts it at a straight line.
    readonly property real shadowPadding: 6
    readonly property real bottomInset: shadowPadding
    margins.bottom: 0
    implicitHeight: 148+bottomInset
    implicitWidth: Math.min(screen ? screen.width-20 : 1180, baseWidth+165)
    exclusiveZone: baseSize+16+bottomInset+3
    WlrLayershell.namespace: "cupertino-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { x: plate.x; y: plate.y-root.currentPeak; width: plate.width; height: plate.height+root.currentPeak }
    readonly property var windows: ToplevelManager.toplevels.values
    readonly property var applications: DesktopEntries.applications.values
    readonly property var active: ToplevelManager.activeToplevel
    visible: !(active && active.fullscreen && active.screens.indexOf(screen) !== -1)
    readonly property bool dark: Color.background.hslLightness < 0.5
    readonly property var pins: [
        {key:"files",label:"Archivos",ids:["org.gnome.Nautilus"],icon:"org.gnome.Nautilus",command:["omarchy","launch","nautilus"]},
        {key:"browser",label:"Navegador",ids:["brave-browser","brave","chromium","firefox"],icon:"brave",command:["omarchy","launch","browser"]},
        {key:"terminal",label:"Terminal",ids:["foot","footclient","Alacritty","com.mitchellh.ghostty"],icon:"utilities-terminal",command:["omarchy","launch","terminal"]},
        {key:"codex",label:"Codex",ids:["codex","Codex","chatgpt","ChatGPT"],icon:"chatgpt",desktop:"codex"},
        {key:"notes",label:"Notas",ids:["obsidian","Obsidian"],icon:"obsidian",desktop:"obsidian"}
    ]
    readonly property var items: {
        let result=pins.filter(p=>p.command || !!DesktopEntries.byId(p.desktop));
        let claimed={};
        for(let p of result) for(let id of p.ids) claimed[id.toLowerCase()]=true;
        for(let w of windows) {
            let id=String(w.appId||"");
            if(!id || claimed[id.toLowerCase()] || w.parent) continue;
            claimed[id.toLowerCase()]=true;
            let d=entryFor(id);
            result.push({key:id,label:d?d.name:id,ids:[id],icon:d?d.icon:"application-x-executable",desktop:d?d.id:""});
        }
        // Keep every running application; size adapts instead of silently dropping entries.
        result.push({key:"apps",label:"Aplicaciones",ids:[],icon:"view-app-grid",command:["omarchy-shell","cupertino.apps","toggle"]});
        result.push({key:"trash",separator:true,label:"Papelera",ids:[],icon:"user-trash",command:["nautilus","trash:///"]});
        return result;
    }
    readonly property real baseSize: Math.max(16,Math.min(32,((screen?screen.width:1200)-205)/Math.max(1,items.length)-8))
    readonly property real pitch: baseSize+8
    readonly property real baseWidth: items.length*pitch+34
    readonly property real magnification: Math.min(36,baseSize*1.125)
    property bool motionActive: false
    property real currentPeak: 0
    property var pendingLaunches: ({})
    function clearPending(key) {
        if(!pendingLaunches[key])return;
        const pending=Object.assign({},pendingLaunches);delete pending[key];pendingLaunches=pending;
    }
    onPointerIndexChanged: motionActive=true
    function advance(dt) {
        const factor=1-Math.exp(-Math.min(dt,0.05)/0.055);
        let unsettled=false,peak=0;
        for(let i=0;i<tiles.count;i++) {
            const tile=tiles.itemAt(i);if(!tile)continue;
            const target=influence(i)*magnification;
            const delta=target-tile.growth;
            tile.growth=Math.abs(delta)<0.025?target:tile.growth+delta*factor;
            if(Math.abs(delta)>=0.025)unsettled=true;
            peak=Math.max(peak,tile.growth);
        }
        currentPeak=peak;motionActive=unsettled;
    }
    FrameAnimation {running:root.visible && root.motionActive;onTriggered:root.advance(frameTime)}
    readonly property real pointerIndex: focusAt(hover.point.position.x)
    // Invert the expanded layout: the largest icon stays directly under the pointer,
    // including near either end, without feeding animated geometry back into itself.
    function peakPosition(focus) {
        let widths=[],total=0;
        for(let i=0;i<items.length;i++) {
            let size=baseSize+6+(items[i].separator?10:0)+magnification*Math.exp(-Math.pow((focus-i)/1.1,2)/2);
            widths.push(size);total+=size;
        }
        total+=2*(items.length-1);
        let start=(width-total)/2,centers=[];
        for(let i=0;i<widths.length;i++){let size=widths[i],extra=items[i].separator?10:0;centers.push(start+extra+(size-extra)/2);start+=size+2;}
        if(focus<0)return centers[0]+focus*pitch;
        if(focus>=centers.length-1)return centers[centers.length-1]+(focus-centers.length+1)*pitch;
        let i=Math.floor(focus);return centers[i]+(focus-i)*(centers[i+1]-centers[i]);
    }
    function focusAt(x) {
        let low=-2,high=items.length+1;
        for(let i=0;i<16;i++){let mid=(low+high)/2;if(peakPosition(mid)<x)low=mid;else high=mid;}
        return (low+high)/2;
    }
    function metrics() {
        let sizes=[];
        for(let i=0;i<tiles.count;i++)sizes.push(tiles.itemAt(i).iconSize);
        return {base:baseSize,hovered:hover.hovered,pointerIndex:pointerIndex,sizes:sizes,width:plate.width,plateHeight:plate.height,iconBottomInset:8,centreOffset:plate.height/2-8-baseSize/2,indicatorSize:2.5,motionActive:motionActive,radius:plate.radius,backdropReady:plate.backdropReady,wallpaperSource:String(wallpaperSource),bottomInset:bottomInset,surface:[width,height],paintBounds:[plate.x-shadowPadding,plate.y-shadowPadding,plate.width+shadowPadding*2,plate.height+shadowPadding*2]};
    }
    IpcHandler {
        target:"cupertino.dock."+(root.screen?root.screen.name:"default")
        function metrics():string{return JSON.stringify(root.metrics());}
    }
    property string hoveredLabel: ""
    property bool tooltipReady:false
    onHoveredLabelChanged:{tooltipReady=false;tooltipDelay.restart();}
    Timer{id:tooltipDelay;interval:500;onTriggered:root.tooltipReady=hover.hovered}

    property int hoveredIndex:-1
    readonly property real labelCenter: {
        const tile=tiles.itemAt(hoveredIndex);
        return tile ? icons.x+tile.x+tile.iconCenter : width/2;
    }
    function influence(index) { return hover.hovered ? Math.exp(-Math.pow((pointerIndex-index)/1.1,2)/2) : 0; }
    function entryFor(id) {
        let lower=String(id).toLowerCase();
        let exact=applications.find(d=>String(d.startupClass||"").toLowerCase()===lower);
        if(exact) return exact;
        if(lower.startsWith("chrome-")) {
            let host=lower.substring(7).split("__")[0];
            let web=applications.find(d=>String(d.execString).toLowerCase().indexOf("https://"+host)>=0);
            if(web) return web;
        }
        return DesktopEntries.heuristicLookup(id);
    }
    function matches(item) { return windows.filter(w=>item.ids.some(id=>id.toLowerCase()===String(w.appId).toLowerCase())); }
    function activateWindow(target) {
        const handle=target.HyprlandToplevel.handle;
        if(handle && handle.address)
            Quickshell.execDetached([Quickshell.env("HOME")+"/.local/share/cupertino-glass/bin/cupertino-window","restore",handle.address]);
        else { target.minimized=false;target.activate(); }
    }
    function openItem(item,newWindow) {
        let found=matches(item);
        if(!newWindow && found.length) {
            let current=found.findIndex(w=>w.activated);
            let target=found[(current+1)%found.length];
            activateWindow(target);
            return false;
        }
        let now=Date.now();
        if(!newWindow && now-(pendingLaunches[item.key]||0)<8000)return false;
        if(item.command) Quickshell.execDetached(item.command);
        else { let d=DesktopEntries.byId(item.desktop); if(d)d.execute();else return false; }
        if(item.ids.length)pendingLaunches=Object.assign({},pendingLaunches,{[item.key]:now});
        return true;
    }
    HoverHandler { id:hover; acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad;onHoveredChanged:{root.motionActive=true;root.tooltipReady=false;if(hovered)tooltipDelay.restart();else tooltipDelay.stop();} }
    GlassSurface {
        id: plate
        dark: root.dark
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomInset
        anchors.horizontalCenter: parent.horizontalCenter
        width: icons.width+22
        height: root.baseSize+16
        radius: Math.min(14,(root.baseSize+16)*0.3)
        shadowPadding: root.shadowPadding
        materialName: "dock"
        tint: root.dark ? 0.20 : 0.22
        shadowOpacity:0.09
        backdropSource: root.wallpaperSource
        backdropSize: Qt.vector2d(root.screen ? root.screen.width : 1200,root.screen ? root.screen.height : 675)
        backdropOrigin: Qt.vector2d((backdropSize.x-root.width)/2+x,backdropSize.y-root.height+y)
        refraction: 5.5
        lightFocus: Math.max(0,Math.min(1,(hover.point.position.x-x)/width))
        lightActivity: hover.hovered ? 1 : 0
        Behavior on lightActivity { NumberAnimation { duration:180 } }
    }
    Row {
        id: icons
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomInset
        height: 100
        spacing: 2
        Repeater {
            id: tiles
            model: root.items
            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                property real growth:0
                readonly property real iconSize:root.baseSize+growth
                readonly property real separatorWidth:modelData.separator?10:0
                readonly property real iconCenter:separatorWidth+(width-separatorWidth)/2
                onAppWindowsChanged:if(appWindows.length){root.clearPending(modelData.key);bounce.stop();lift.y=0;}
                readonly property var appWindows: root.matches(modelData)
                width: iconSize+6+separatorWidth
                height: parent.height
                Component.onCompleted:root.motionActive=true
                Rectangle {visible:tile.separatorWidth>0;x:3;y:parent.height-35;width:1;height:22;color:root.dark?"#30ffffff":"#25000000"}
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.onPressAction: root.openItem(modelData,false)
                AppIcon {
                    id: icon
                    x:tile.iconCenter-width/2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    width: tile.iconSize; height: width
                    scale:mouse.pressed?0.96:1
                    Behavior on scale {NumberAnimation{duration:65}}
                    iconName: tile.modelData.icon
                    appId: tile.modelData.key
                    visible: tile.modelData.key!=="trash"
                    transform: Translate { id: lift; y:0 }
                }
                Image {
                    visible: tile.modelData.key==="trash"
                    x:tile.iconCenter-width/2
                    anchors.bottom: parent.bottom; anchors.bottomMargin:8
                    width:tile.iconSize; height:width
                    source: "file://"+(Quickshell.env("CUPERTINO_ASSET_ROOT") || Quickshell.env("HOME")+"/.local/share/cupertino-glass/assets")+"/icons/Cupertino-Glass/places/scalable/user-trash.svg"
                    sourceSize:Qt.size(144,144); smooth:true; mipmap:true
                }
                SequentialAnimation {
                    id:bounce
                    NumberAnimation {target:lift;property:"y";to:-14;duration:220;easing.type:Easing.OutCubic}
                    NumberAnimation {target:lift;property:"y";to:0;duration:300;easing.type:Easing.InOutCubic}
                }
                Rectangle {
                    visible:tile.appWindows.length>0
                    x:tile.iconCenter-width/2
                    anchors.bottom:parent.bottom;anchors.bottomMargin:2.5
                    width:2.5;height:2.5;radius:1.25
                    color:root.dark?"#baffffff":"#99000000"
                }
                MouseArea {
                    id: mouse
                    anchors.left: parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
                    height:tile.iconSize+13
                    hoverEnabled:true
                    acceptedButtons:Qt.LeftButton|Qt.MiddleButton|Qt.RightButton
                    onEntered: {root.hoveredLabel=tile.modelData.label;root.hoveredIndex=tile.index;}
                    onClicked:function(event) {
                        root.tooltipReady=false;
                        if(event.button===Qt.RightButton) context.popup();
                        else if(root.openItem(tile.modelData,event.button===Qt.MiddleButton) && tile.modelData.key!=="apps") bounce.restart();
                    }
                }
                Controls.Menu {
                    id:context
                    font {family:"Inter Variable";pixelSize:12}
                    background: Rectangle {radius:10;color:root.dark?"#f02d3440":"#f3edf4fc";border.color:root.dark?"#50ffffff":"#ffffff";border.width:1}
                    Controls.MenuItem {text:"Abrir";onTriggered:root.openItem(tile.modelData,false)}
                    Controls.MenuItem {text:"Nueva ventana";visible:tile.modelData.ids.length>0;enabled:!!tile.modelData.command||!!tile.modelData.desktop;onTriggered:root.openItem(tile.modelData,true)}
                    Repeater {
                        model:tile.appWindows
                        delegate:Controls.MenuItem {required property var modelData;text:modelData.title||tile.modelData.label;onTriggered:root.activateWindow(modelData)}
                    }
                }
            }
        }
    }
    Rectangle {
        x:Math.max(0,Math.min(root.width-width,root.labelCenter-width/2))
        y:root.height-root.bottomInset-8-root.baseSize-root.currentPeak-height-9
        width:hint.implicitWidth+18;height:25;radius:8
        color:root.dark?"#f0303030":"#f5fafafa"
        border.width:1;border.color:root.dark?"#24ffffff":"#18000000"
        opacity:hover.hovered && root.tooltipReady && root.hoveredLabel!=="" ? 1 : 0
        Behavior on opacity {NumberAnimation {duration:100}}
        Text {id:hint;anchors.centerIn:parent;text:root.hoveredLabel;color:root.dark?"#f2f2f3":"#202124";font{family:"Inter Variable";pixelSize:12}}
    }
}
