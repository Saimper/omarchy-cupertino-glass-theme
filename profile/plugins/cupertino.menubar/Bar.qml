import QtQuick
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "file:///usr/share/omarchy/shell/plugins/bar" as Native

// Extend the installed bar so popup coordination, tray actions, settings,
// accessibility and native plugin lifecycles keep their original implementation.
Native.Bar {
    id: root
    readonly property var audioState: {
        const slot=moduleSlots.find(s=>s.moduleName==="omarchy.audio");
        return slot ? slot.activeItem : null;
    }
    property bool accessoriesExpanded: false
    function accessory(slot) {
        const explicit = slot.moduleSettings.cupertinoAccessory;
        if (explicit !== undefined) return explicit === true;
        // Some native widgets persist only their own keys. Keep them folded
        // after, for example, pinning a tray app rewrites its inline settings.
        return ["", "cupertino.application", "omarchy.power", "omarchy.network",
                "cupertino.desktop", "cupertino.profiles", "omarchy.clock"].indexOf(slot.moduleName) < 0;
    }

    IpcHandler {
        target: "cupertino.menubar"
        function toggleExtras(): void { root.accessoriesExpanded = false; }
        function closeExtras(): void { root.accessoriesExpanded = false; }
        function state(): string { return JSON.stringify({expanded:root.accessoriesExpanded,slots:root.debugBarGeometry()}); }
    }

    function iconButton(item) {
        if (!item) return null;
        if ("iconComponent" in item) return item;
        const children = item.children || [];
        for (let i=0;i<children.length;i++) {
            const button = iconButton(children[i]);
            if (button) return button;
        }
        return null;
    }
    function decorate(slot) {
        if (!slot || !slot.activeItem) return;
        const icons={"omarchy.network":wifiIcon,"omarchy.power":batteryIcon,"omarchy.bluetooth":bluetoothIcon,"omarchy.audio":audioIcon,"omarchy.monitor":displayIcon};
        if (!icons[slot.moduleName]) return;
        const button = iconButton(slot.activeItem);
        if (!button) return;
        button.iconComponent = icons[slot.moduleName];
        button.opticalSize = slot.moduleName === "omarchy.power" ? 26 : 20;
        button.slotSize = slot.moduleName === "omarchy.power" ? 34 : 28;
    }
    Repeater {
        model: root.moduleSlots
        delegate: Item {
            id: decorator
            required property var modelData
            // The slot remains instantiated. Only its bar presence collapses;
            // native panels still respond to shortcuts and Control Center.
            Binding {
                target: modelData
                property: "visible"
                value: !root.accessory(modelData)
                restoreMode: Binding.RestoreBindingOrValue
            }
            Connections {
                target: modelData
                function onActiveItemChanged() { decorationTimer.restart(); }
                function onModuleSettingsChanged() { decorationTimer.restart(); }
            }
            // A delegate-owned timer is cancelled when the registry changes.
            // Queued closures can otherwise outlive destroyed QML contexts.
            Timer { id:decorationTimer;interval:0;onTriggered:root.decorate(decorator.modelData) }
            Component.onCompleted: decorationTimer.start()
        }
    }
    Component {
        id: wifiIcon
        StatusGlyph {
            kind: "wifi"
            ink: root.barForeground
            enabledState: Networking.wifiEnabled
            value: {
                const device = Networking.devices.values.find(d=>d.type===DeviceType.Wifi);
                const network = device && device.networks ? device.networks.values.find(n=>n.connected) : null;
                return network ? network.signalStrength : 0;
            }
        }
    }
    Component {
        id: batteryIcon
        StatusGlyph {
            kind: "battery"
            ink: root.barForeground
            value: UPower.displayDevice ? UPower.displayDevice.percentage : 0
            charging: UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.Charging
        }
    }
    Component {id:bluetoothIcon;BarSymbol{symbolName:Bluetooth.defaultAdapter&&Bluetooth.defaultAdapter.enabled?"bluetooth":"bluetooth.slash";ink:root.barForeground}}
    Component {id:displayIcon;BarSymbol{symbolName:"display";ink:root.barForeground}}
    Component {id:audioIcon;BarSymbol{
        symbolName:!root.audioState||root.audioState.outputMuted?"speaker.slash.fill":root.audioState.outputVolume<0.01?"speaker.fill":root.audioState.outputVolume<0.34?"speaker.wave.1.fill":root.audioState.outputVolume<0.67?"speaker.wave.2.fill":"speaker.wave.3.fill"
        ink:root.barForeground
    }}
}
