import Quickshell
import QtQuick
import QtQuick.Layouts

PanelWindow {
    anchors.top: true

    implicitHeight: 32

    RowLayout {
        anchors.fill: parent

        Left {}
        Item {
            Layout.fillWidth: true
        }
        Center {}
        Item {
            Layout.fillWidth: true
        }
        Right {}
    }
}
