import QtQuick

BarSymbol {
    id: root
    property string kind: "wifi"
    property real value: 1
    property bool charging: false
    property bool enabledState: true
    symbolName: {
        if(kind==="wifi")return !enabledState ? "wifi.slash" : value>0 ? "wifi" : "wifi.exclamationmark";
        if(kind==="battery") {
            if(charging)return "battery.100percent.bolt";
            const p=Math.max(0,Math.min(1,value));
            return p<=0.05 ? "battery.5percent.trianglebadge.exclamationmark" : "battery."+(p<0.13?0:p<0.38?25:p<0.63?50:p<0.88?75:100)+"percent";
        }
        return kind;
    }
}
