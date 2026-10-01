import QtQuick
import qs.Commons
import "MaterialPresets.js" as MaterialPresets

Item {
    id: surface
    property bool dark: Color.background.hslLightness < 0.5
    property bool highlighted: false
    property string materialName: ""
    readonly property var recipe: MaterialPresets.resolve(materialName,dark)
    property real tint: recipe && recipe.rgba ? recipe.rgba[3] : dark ? 0.40 : 0.35
    readonly property color materialColor: dark ? Qt.rgba(36/255,39/255,58/255,1)
        : recipe && recipe.rgba ? Qt.rgba(recipe.rgba[0],recipe.rgba[1],recipe.rgba[2],1)
        : Qt.rgba(0.98,0.98,0.98,1)
    property real radius: 24
    property real shadowOpacity: 0.09
    property real shadowPadding: 12
    property url backdropSource: ""
    property vector2d backdropSize: Qt.vector2d(1,1)
    property vector2d backdropOrigin: Qt.vector2d(0,0)
    property real refraction: 0
    property real lightFocus: 0.5
    property real lightActivity: highlighted ? 1 : 0
    property real edgeStrength: 1
    property real opticalLift: 0
    // Optional wallpaper lens for the dock; panels use only neutral reflections.
    property real lensWidth: Math.sqrt(22)
    property real lensOpacity: 0.36
    property real panelOptics: 0
    readonly property bool backdropReady: backdropTexture.status === Image.Ready
    // Only surfaces that explicitly supply a wallpaper enable the texture lens.
    // Panel interiors and edges retain the actual backdrop from the compositor.
    Image {
        id: backdropTexture
        visible: false
        source: surface.backdropSource
        sourceSize.width: 1920
        asynchronous: true
        smooth: true
        mipmap: true
    }
    ShaderEffect {
        anchors.fill: parent
        anchors.margins: -surface.shadowPadding
        property vector2d surfaceSize: Qt.vector2d(Math.max(1,surface.width),Math.max(1,surface.height))
        property real cornerRadius: Math.min(surface.radius,surface.height/2,surface.width/2)
        property real materialOpacity: surface.tint
        property real darkMode: surface.dark ? 1 : 0
        property real emphasis: surface.highlighted ? 1 : 0
        property real shadowStrength: surface.shadowOpacity
        property real shadowPadding: surface.shadowPadding
        property var backdrop: backdropTexture
        property vector2d backdropSize: surface.backdropSize
        property vector2d backdropImageSize: Qt.vector2d(Math.max(1,backdropTexture.implicitWidth),Math.max(1,backdropTexture.implicitHeight))
        property vector2d backdropOrigin: surface.backdropOrigin
        property real refraction: surface.refraction
        property real backdropEnabled: surface.backdropReady ? 1 : 0
        property real lightFocus: surface.lightFocus
        property real lightActivity: surface.lightActivity
        property real edgeStrength: surface.edgeStrength
        property real opticalLift: surface.opticalLift
        property real lensWidth: surface.lensWidth
        property real lensOpacity: surface.lensOpacity
        property real panelOptics: surface.panelOptics
        property color materialColor: surface.materialColor
        property real backdropSaturation: surface.recipe ? surface.recipe.saturation : 1
        property real backdropBrightness: surface.recipe && surface.recipe.brightness !== undefined ? surface.recipe.brightness : 0
        fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
    }
}
