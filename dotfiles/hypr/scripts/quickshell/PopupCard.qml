import QtQuick
import QtQuick.Controls
import "./"

Rectangle {
    id: cardRoot

    default property alias content: innerContainer.data
    property real cardRadius: 20
    property bool showSpecular: true
    property color cardColor: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, Config.cardOpacity > 0 ? Config.cardOpacity : 0.22)
    property color cardBorderColor: Config.borderWidth > 0 ? Qt.rgba(255, 255, 255, 0.18) : "transparent"
    property real cardBorderWidth: Config.borderWidth > 0 ? Config.borderWidth : 0

    MatugenColors { id: theme }

    color: cardColor
    radius: cardRadius
    border.width: cardBorderWidth
    border.color: cardBorderColor

    // Top frosted specular reflection highlight
    Rectangle {
        id: specularLine
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - cardRoot.radius * 2)
        anchors.topMargin: 1
        height: 1
        color: Qt.rgba(255, 255, 255, 0.22)
        radius: 1
        visible: cardRoot.showSpecular && cardRoot.cardBorderWidth > 0
    }

    Item {
        id: innerContainer
        anchors.fill: parent
    }
}
