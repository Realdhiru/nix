import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../"
import "../WindowRegistry.js" as Registry

PanelWindow {
    id: osdWindow
    property real uiScale: 1.0

    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        bottom: true
        horizontalCenter: true
    }
    
    // Position slightly above bottom edge
    margins.bottom: 100 * uiScale 

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    width: 240 * uiScale
    height: 56 * uiScale

    opacity: osdTimer.running ? 1.0 : 0.0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    MatugenColors { id: _theme }

    property string osdType: "volume"
    property real osdValue: 0
    property string osdText: ""

    function show(type, valStr) {
        osdType = type;
        let numVal = parseFloat(valStr);
        
        if (!isNaN(numVal) && valStr !== "On" && valStr !== "Off") {
            osdValue = numVal;
            osdText = Math.round(numVal) + "%";
        } else {
            osdValue = (valStr === "On" || valStr === "Unmuted") ? 100 : 0;
            osdText = valStr;
        }
        osdTimer.restart();
    }

    Timer {
        id: osdTimer
        interval: 1500
    }

    Rectangle {
        anchors.fill: parent
        radius: 28 * uiScale
        color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 0.95)
        border.color: _theme.surface1
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16 * uiScale
            spacing: 12 * uiScale

            Text {
                text: {
                    if (osdType === "volume") return "";
                    if (osdType === "mic") return "";
                    if (osdType === "brightness") return "󰃠";
                    if (osdType === "kbd") return "󰌌";
                    if (osdType === "caps") return "󰪛";
                    if (osdType === "num") return "󰎦";
                    return "󰋋";
                }
                font.family: "Symbols Nerd Font"
                font.pixelSize: 20 * uiScale
                color: _theme.text
            }

            Rectangle {
                Layout.fillWidth: true
                height: 6 * uiScale
                radius: 3 * uiScale
                color: _theme.surface0
                clip: true

                Rectangle {
                    height: parent.height
                    width: parent.width * (Math.max(0, Math.min(100, osdWindow.osdValue)) / 100)
                    radius: 3 * uiScale
                    color: _theme.blue
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                text: osdWindow.osdText
                font.family: "JetBrains Mono"
                font.pixelSize: 14 * uiScale
                font.weight: Font.Bold
                color: _theme.text
                Layout.minimumWidth: 40 * uiScale
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}