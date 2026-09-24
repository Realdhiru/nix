import QtQuick
import QtQuick.Controls
import "./"

Rectangle {
    id: cardRoot

    default property alias content: innerContainer.data
    property real cardRadius: 20
    property bool showSpecular: true
    // Options: cardColor adapts to Config.cardColorSource & Config.effectiveCardOpacity
    property color cardColor: {
        if (Config.cardColorSource === "glass") {
            return Qt.rgba(1, 1, 1, Config.effectiveCardOpacity > 0 ? Config.effectiveCardOpacity : Config.glassSpecular);
        }
        let col = theme[Config.cardColorSource] || theme.surface0;
        return Qt.rgba(col.r, col.g, col.b, Config.effectiveCardOpacity > 0 ? Config.effectiveCardOpacity : 0.20);
    }
    property color cardBorderColor: (Config.borderWidth > 0 && Config.borderOpacity > 0) ? Qt.rgba(1, 1, 1, Config.borderOpacity) : "transparent"
    property real cardBorderWidth: Config.borderWidth

    Theme { id: theme }

    color: cardColor
    radius: cardRadius
    border.width: cardBorderWidth
    border.color: cardBorderColor

    Item {
        id: innerContainer
        anchors.fill: parent
    }
}
