import Quickshell
import QtQuick
import QtQuick.Layouts

import "."

PanelWindow {

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 40

    Rectangle {
        anchors.fill: parent

        color: "#111827"
        opacity: 0.9

        RowLayout {

            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20

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
}
