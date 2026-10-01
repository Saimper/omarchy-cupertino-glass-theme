import QtQuick

NativeSymbol {
    property string glyph: ""
    symbolName: ({"󰤨":"wifi","󰂯":"bluetooth","󰁹":"battery.100percent","󰍹":"display","󰕾":"speaker.wave.2.fill","󰃠":"sun.max.fill","󰂛":"moon.fill","󰖔":"moon.fill","󰹑":"menubar.dock.rectangle","󰀻":"square.grid.2x2","󰏘":"rectangle.on.rectangle","󰏤":"pause.fill","󰐊":"play.fill","󰒮":"backward.fill","󰒭":"forward.fill"})[glyph] || glyph
}
