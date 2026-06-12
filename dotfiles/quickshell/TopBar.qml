import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 32

    color: "#202020"

    Text {
        anchors.centerIn: parent

        color: "white"

        text: "Quickshell works!"
    }
}