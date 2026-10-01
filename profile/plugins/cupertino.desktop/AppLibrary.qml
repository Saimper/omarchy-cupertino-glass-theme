import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: root
    BackgroundEffect.blurRegion: Region {
        x: card.x-14; y: card.y-14
        width: card.width+28; height: card.height+28
    }
    property bool opened: false
    property string category: "Todas"
    readonly property bool dark: Color.background.hslLightness < 0.5
    readonly property color ink: dark ? "#f2f2f3" : "#202124"
    readonly property var categories: ["Todas","Trabajo","Creatividad","Internet","Multimedia","Sistema"]
    readonly property var entries: DesktopEntries.applications.values.filter(d=>!d.noDisplay).slice().sort((a,b)=>a.name.localeCompare(b.name))
    readonly property var filtered: {
        let query=search.text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
        let groups={Trabajo:["Office","Development","Education"],Creatividad:["Graphics"],Internet:["Network"],Multimedia:["AudioVideo","Audio","Video","Game"],Sistema:["System","Settings","Utility"]};
        return entries.filter(d=> {
            let text=(d.name+" "+d.genericName+" "+d.keywords.join(" ")).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
            return (!query || text.indexOf(query)>=0) && (category==="Todas" || d.categories.some(c=>groups[category].indexOf(c)>=0));
        });
    }
    function open() { category="Todas";search.text="";opened=true;Qt.callLater(()=>search.forceActiveFocus()); }
    function close() { opened=false; }
    function launch(entry) { if(!entry) return;close();entry.execute(); }
    IpcHandler {
        target:"cupertino.apps"
        function toggle(): void {root.opened?root.close():root.open();}
        function open(): void {root.open();}
        function close(): void {root.close();}
        function count(): string {return String(root.entries.length);}
    }
    visible: opened || card.opacity>0
    color:"transparent"
    anchors {left:true;right:true;top:true;bottom:true}
    exclusionMode:ExclusionMode.Ignore
    mask:Region{width:root.opened?root.width:0;height:root.opened?root.height:0}
    WlrLayershell.namespace:"cupertino-app-library"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onBackingWindowVisibleChanged: if(backingWindowVisible&&opened) Qt.callLater(()=>search.forceActiveFocus())
    Rectangle {anchors.fill:parent;color:root.dark?"#10000000":"#08000000";opacity:card.opacity}
    MouseArea {anchors.fill:parent;onClicked:root.close()}
    GlassSurface {
        id:card
        enabled:root.opened
        anchors.centerIn:parent
        width:Math.min(760,root.width-60)
        height:Math.min(538,root.height-84)
        radius:30
        dark:root.dark
        materialName:"thin"
        tint: recipe.rgba[3] * (root.dark ? 0.82 : 0.92)
        edgeStrength: 1.1
        opticalLift: root.dark ? 0.012 : 0.008
        shadowOpacity: 0.12
        panelOptics: 0.7
        // No wallpaper replacement over app windows: retain their real blur.
        refraction: 0
        opacity:root.opened?1:0
        scale:root.opened?1:0.98
        Behavior on opacity {NumberAnimation{duration:180;easing.type:Easing.OutCubic}}
        Behavior on scale {NumberAnimation{duration:180;easing.type:Easing.OutCubic}}
        MouseArea {anchors.fill:parent}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:24;spacing:16
            RowLayout {
                Layout.fillWidth:true;spacing:12
                NativeSymbol {symbolName:"magnifyingglass";ink:root.ink;Layout.preferredWidth:26;Layout.preferredHeight:26}
                Controls.TextField {
                    id:search
                    Layout.fillWidth:true
                    placeholderText:"Buscar aplicaciones"
                    font{family:"Inter Variable";pixelSize:21}
                    color:root.ink
                    placeholderTextColor:Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.55)
                    selectByMouse:true
                    background:Item{}
                    Accessible.name:"Buscar aplicaciones"
                    onTextChanged:grid.currentIndex=0
                    onAccepted:root.launch(root.filtered[Math.max(0,grid.currentIndex)])
                    Keys.onDownPressed:{grid.forceActiveFocus();grid.currentIndex=0;}
                    Keys.onEscapePressed:root.close()
                }
                Controls.Button {
                    text:"×";implicitWidth:30;implicitHeight:30
                    Accessible.name:"Cerrar aplicaciones"
                    onClicked:root.close()
                    background:Rectangle{radius:15;color:parent.hovered?"#40ffffff":"#20ffffff"}
                    contentItem:Item{NativeSymbol{anchors.centerIn:parent;width:19;height:19;symbolName:"xmark";ink:root.ink}}
                }
            }
            RowLayout {
                Layout.fillWidth:true;spacing:4
                Repeater {
                    model:root.categories
                    delegate:Controls.Button {
                        required property string modelData
                        text:modelData
                        Layout.fillWidth:true
                        implicitHeight:29
                        font{family:"Inter Variable";pixelSize:11;weight:root.category===modelData?Font.DemiBold:Font.Normal}
                        onClicked:{root.category=modelData;grid.currentIndex=0;}
                        background:Rectangle{radius:14;color:root.category===parent.modelData?(root.dark?"#40ffffff":"#b0ffffff"):(parent.hovered?"#24ffffff":"transparent");border.width:parent.activeFocus?1:0;border.color:Color.accent}
                        contentItem:Text{text:parent.text;font:parent.font;color:root.ink;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
                    }
                }
            }
            GridView {
                id:grid
                Layout.fillWidth:true;Layout.fillHeight:true
                clip:true
                model:root.filtered
                cellWidth:width/Math.max(4,Math.floor(width/104))
                cellHeight:108
                cacheBuffer:300
                boundsBehavior:Flickable.StopAtBounds
                maximumFlickVelocity:1700
                highlightMoveDuration:130
                keyNavigationEnabled:true
                Keys.onReturnPressed:root.launch(root.filtered[currentIndex])
                Keys.onEnterPressed:root.launch(root.filtered[currentIndex])
                Keys.onEscapePressed:root.close()
                Keys.onPressed:function(event){
                    if(event.text&&event.text.length===1&&!event.modifiers){search.text+=event.text;search.forceActiveFocus();event.accepted=true;}
                }
                delegate:Item {
                    id:tile
                    required property var modelData
                    required property int index
                    width:grid.cellWidth;height:grid.cellHeight
                    Rectangle {anchors.fill:parent;anchors.margins:3;radius:16;color:mouse.containsMouse || (grid.activeFocus&&grid.currentIndex===tile.index)?(root.dark?"#24ffffff":"#80ffffff"):"transparent";border.width:grid.activeFocus&&grid.currentIndex===tile.index?1:0;border.color:Color.accent}
                    AppIcon {id:art;anchors.horizontalCenter:parent.horizontalCenter;y:10;width:56;height:56;iconName:tile.modelData.icon;appId:tile.modelData.id;scale:mouse.pressed?0.91:mouse.containsMouse?1.06:1;Behavior on scale{NumberAnimation{duration:140;easing.type:Easing.OutCubic}}}
                    Text {x:5;y:73;width:parent.width-10;text:tile.modelData.name;color:root.ink;style:root.dark?Text.Raised:Text.Normal;styleColor:"#90000000";horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;font{family:"Inter Variable";pixelSize:11;weight:Font.Medium}}
                    MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;onClicked:root.launch(tile.modelData)}
                    Accessible.role:Accessible.Button
                    Accessible.name:modelData.name
                    Accessible.onPressAction:root.launch(modelData)
                }
                Controls.ScrollBar.vertical:Controls.ScrollBar {width:5;policy:Controls.ScrollBar.AsNeeded}
                Text {anchors.centerIn:parent;visible:root.filtered.length===0;text:"No hay aplicaciones con ese nombre";color:root.ink;opacity:0.7;font{family:"Inter Variable";pixelSize:13}}
            }
            RowLayout {
                Layout.fillWidth:true
                Text{text:root.filtered.length+" aplicaciones";color:root.ink;opacity:0.6;font{family:"Inter Variable";pixelSize:10} Layout.fillWidth:true}
                Text{text:"↵ Abrir    Esc Cerrar";color:root.ink;opacity:0.6;font{family:"Inter Variable";pixelSize:10}}
            }
        }
    }
}
