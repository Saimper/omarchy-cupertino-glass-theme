.pragma library
var presets = {
  "ultrathin light": {
    "rgba": [
      0.9646,
      0.9648,
      0.9646,
      0.360000014305115
    ],
    "saturation": 1.8,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / ultrathin light"
  },
  "ultrathin dark": {
    "rgba": [
      0.1569,
      0.1569,
      0.1569,
      0.400000005960464
    ],
    "saturation": 1.6,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / ultrathin dark"
  },
  "thin light": {
    "rgba": [
      0.9646,
      0.9648,
      0.9646,
      0.479999989271164
    ],
    "saturation": 1.9,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / thin light"
  },
  "thin dark": {
    "rgba": [
      0.1569,
      0.1569,
      0.1569,
      0.5
    ],
    "saturation": 1.8,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / thin dark"
  },
  "medium light": {
    "rgba": [
      0.9646,
      0.9648,
      0.9646,
      0.600000023841858
    ],
    "saturation": 2,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / medium light"
  },
  "medium dark": {
    "rgba": [
      0.1569,
      0.1569,
      0.1569,
      0.600000023841858
    ],
    "saturation": 2,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / medium dark"
  },
  "thick light": {
    "rgba": [
      0.9646,
      0.9648,
      0.9646,
      0.720000028610229
    ],
    "saturation": 2.1,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / thick light"
  },
  "thick dark": {
    "rgba": [
      0.1569,
      0.1569,
      0.1569,
      0.699999988079071
    ],
    "saturation": 2.2,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / thick dark"
  },
  "ultrathick light": {
    "rgba": [
      0.9647,
      0.9647,
      0.9647,
      0.839999973773956
    ],
    "saturation": 2.2,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / ultrathick light"
  },
  "ultrathick dark": {
    "rgba": [
      0.1569,
      0.1569,
      0.1569,
      0.800000011920929
    ],
    "saturation": 2.4,
    "appleBlurRadius": 60,
    "source": "SwiftUI.framework/mac-materials.json / normal / ultrathick dark"
  },
  "dock light": {
    "saturation": 1.8,
    "brightness": 0.08,
    "appleBlurRadius": 30,
    "source": "CoreMaterial.framework/dockLight.materialrecipe.json"
  },
  "dock dark": {
    "saturation": 1.6,
    "brightness": 0,
    "appleBlurRadius": 30,
    "source": "CoreMaterial.framework/dockDark.materialrecipe.json"
  }
};
function resolve(name,dark) { return presets[name+" "+(dark?"dark":"light")] || null; }
