import QtQuick

Item {
    id: root

    property real targetCoord: 0
    property real targetSpan: 0

    property real coord: targetCoord
    property real span: targetSpan

    Behavior on coord {
        NumberAnimation {
            duration: Motion.moveMs
            easing.type: Motion.moveEasing
        }
    }
    Behavior on span {
        NumberAnimation {
            duration: Motion.moveMs
            easing.type: Motion.moveEasing
        }
    }
}
