import QtQuick

Text {

    id: clock

    color: "#ffffff"

    font.pixelSize: 14

    function updateTime() {
        text = Qt.formatDateTime(
            new Date(),
            "hh:mm AP"
        )
    }

    Timer {

        interval: 1000

        running: true

        repeat: true

        onTriggered: clock.updateTime()
    }

    Component.onCompleted: updateTime()
}
