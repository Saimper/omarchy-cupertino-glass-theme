import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Controls.Slider {
    id:control
    property string glyph:""
    readonly property color ink:Color.background.hslLightness<0.5?"#f2f2f3":"#202124"
    implicitHeight:29
    leftPadding:0;rightPadding:24;topPadding:0;bottomPadding:0
    opacity:enabled?1:0.35
    background:Item {
        Rectangle {
            y:(control.height-height)/2;width:control.availableWidth;height:6;radius:3;color:Color.background.hslLightness<0.5?"#40000000":"#30000000"
            Rectangle{height:parent.height;width:Math.max(3,control.visualPosition*parent.width);radius:3;color:control.ink}
        }
        Symbol{x:control.width-18;y:5;width:18;height:18;glyph:control.glyph;ink:control.ink;opacity:0.8}
    }
    handle:Rectangle {
        x:control.visualPosition*(control.availableWidth-width);y:(control.height-height)/2
        width:16;height:16;radius:8;color:control.pressed?"#d3e9ff":"white"
        border.width:control.activeFocus?2:0;border.color:"#148aff"
        scale:control.pressed?1.15:1
        Behavior on scale{NumberAnimation{duration:120}}
    }
}
