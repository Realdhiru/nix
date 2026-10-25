import QtQuick

Item {
    id: root

    property real amplitude: 10
    property real offset: 0
    property var trigger: function () {
        seq.restart();
    }

    readonly property real leg: Motion.moveMs / 5

    SequentialAnimation {
        id: seq

        loops: 1

        NumberAnimation {
            from: 0
            to: -root.amplitude
            duration: root.leg
            easing.type: Motion.moveEasing
            target: root
            property: "offset"
        }
        NumberAnimation {
            from: -root.amplitude
            to: root.amplitude
            duration: root.leg
            easing.type: Motion.moveEasing
            target: root
            property: "offset"
        }
        NumberAnimation {
            from: root.amplitude
            to: -root.amplitude / 2
            duration: root.leg
            easing.type: Motion.moveEasing
            target: root
            property: "offset"
        }
        NumberAnimation {
            from: -root.amplitude / 2
            to: root.amplitude / 2
            duration: root.leg
            easing.type: Motion.moveEasing
            target: root
            property: "offset"
        }
        NumberAnimation {
            from: root.amplitude / 2
            to: 0
            duration: root.leg
            easing.type: Motion.moveEasing
            target: root
            property: "offset"
        }
    }
}
