import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: toastWindow
            required property var modelData
            screen: modelData

            property bool isIslandActive: (Config.topBarPosition === "left" || !Config.topBarVisible) && NotifTicker.tickerVisible
            property bool windowVisible: false

            onIsIslandActiveChanged: {
                if (isIslandActive) {
                    exitTimer.stop();
                    windowVisible = true;
                } else {
                    exitTimer.restart();
                }
            }

            Timer {
                id: exitTimer
                interval: 170
                onTriggered: {
                    if (!toastWindow.isIslandActive) {
                        toastWindow.windowVisible = false;
                    }
                }
            }

            visible: windowVisible

            anchors {
                top: true
            }

            margins {
                top: toastWindow.s(Config.barEdgeMargin || 8)
            }

            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "qs-notif-toast"
            WlrLayershell.layer: WlrLayer.Overlay

            Scaler {
                id: scaler
                currentWidth: Screen.width
            }

            function s(val) {
                return scaler.s(val);
            }

            Theme {
                id: mocha
            }

            readonly property color pillBorder: (Config.borderWidth > 0 && Config.borderOpacity > 0)
                ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, Config.borderOpacity)
                : "transparent"

            readonly property color pillBorderHover: (Config.borderWidth > 0 && Config.borderOpacity > 0)
                ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, Config.borderOpacity * 2)
                : "transparent"

            property var n: NotifTicker.tickerNotif
            property var actionArray: {
                try { return n && n.actionsJson ? JSON.parse(n.actionsJson) : []; }
                catch (e) { return []; }
            }

            // Fixed layer surface bounds; Region mask restricts input to the active card
            implicitWidth: toastWindow.s(600)
            implicitHeight: toastWindow.s(60)

            mask: Region { item: toastCard }

            Rectangle {
                id: toastCard
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                height: toastWindow.s(40)
                width: Math.max(toastWindow.s(180), contentRow.implicitWidth + toastWindow.s(28))
                radius: toastWindow.s(14)
                color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Config.toastOpacity)
                border.width: Config.borderWidth
                border.color: Config.borderWidth > 0 ? (cardMa.containsMouse ? toastWindow.pillBorderHover : toastWindow.pillBorder) : Qt.rgba(1, 1, 1, Config.glassSpecular)
                clip: true

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Behavior on width {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                    }
                }

                opacity: toastWindow.isIslandActive ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: toastWindow.isIslandActive ? 240 : 160
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: toastWindow.isIslandActive ? [0.16, 1.0, 0.3, 1.0, 1.0, 1.0] : [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
                    }
                }

                transform: [
                    Scale {
                        origin.x: toastCard.width / 2
                        origin.y: toastCard.height / 2
                        xScale: toastWindow.isIslandActive ? 1.0 : 0.94
                        yScale: toastWindow.isIslandActive ? 1.0 : 0.94
                        Behavior on xScale {
                            NumberAnimation {
                                duration: toastWindow.isIslandActive ? 240 : 160
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: toastWindow.isIslandActive ? [0.16, 1.0, 0.3, 1.0, 1.0, 1.0] : [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
                            }
                        }
                        Behavior on yScale {
                            NumberAnimation {
                                duration: toastWindow.isIslandActive ? 240 : 160
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: toastWindow.isIslandActive ? [0.16, 1.0, 0.3, 1.0, 1.0, 1.0] : [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
                            }
                        }
                    },
                    Translate {
                        y: toastWindow.isIslandActive ? 0 : toastWindow.s(-6)
                        Behavior on y {
                            NumberAnimation {
                                duration: toastWindow.isIslandActive ? 240 : 160
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: toastWindow.isIslandActive ? [0.16, 1.0, 0.3, 1.0, 1.0, 1.0] : [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
                            }
                        }
                    }
                ]

                // Anti-bleed base layer
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                    z: -1
                }

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                    onClicked: {
                        if (toastWindow.actionArray.length === 0) {
                            NotifTicker.invokeDefault();
                        }
                    }
                }

                RowLayout {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: toastWindow.s(10)

                    Image {
                        Layout.alignment: Qt.AlignVCenter
                        visible: toastWindow.n && toastWindow.n.iconPath !== ""
                        source: toastWindow.n && toastWindow.n.iconPath !== "" ? toastWindow.n.iconPath : ""
                        sourceSize: Qt.size(toastWindow.s(20), toastWindow.s(20))
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: toastWindow.n ? toastWindow.n.appName : ""
                        font.family: "JetBrains Mono"
                        font.weight: Font.Medium
                        font.pixelSize: toastWindow.s(10)
                        color: mocha.subtext1
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "\u2022"
                        font.pixelSize: toastWindow.s(10)
                        color: mocha.overlay0
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: toastWindow.n ? toastWindow.n.summary : ""
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: toastWindow.s(13)
                        color: mocha.text
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        visible: text !== ""
                        text: toastWindow.n ? toastWindow.n.body : ""
                        font.family: "JetBrains Mono"
                        font.weight: Font.Medium
                        font.pixelSize: toastWindow.s(13)
                        color: mocha.subtext0
                    }

                    // Native action chips (Directly from TopBar.qml:948-982)
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: toastWindow.s(6)
                        visible: toastWindow.actionArray.length > 0

                        Repeater {
                            model: toastWindow.actionArray
                            delegate: Rectangle {
                                height: toastWindow.s(24)
                                width: actLabel.implicitWidth + toastWindow.s(14)
                                radius: toastWindow.s(7)
                                property bool isPrimary: index === 0
                                color: isPrimary ? (actMa.containsMouse ? mocha.blue : Qt.darker(mocha.blue, 1.2)) : (actMa.containsMouse ? mocha.surface2 : mocha.surface1)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: actLabel
                                    anchors.centerIn: parent
                                    text: modelData.text || "Action"
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: toastWindow.s(10)
                                    color: isPrimary ? mocha.crust : mocha.text
                                }

                                MouseArea {
                                    id: actMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotifTicker.invokeAction(modelData.id)
                                }
                            }
                        }
                    }

                    // Trailing close button (Directly from TopBar.qml:984-1012)
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        height: toastWindow.s(22)
                        width: toastWindow.s(22)
                        radius: toastWindow.s(11)
                        color: closeMa.containsMouse ? mocha.surface2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: toastWindow.s(11)
                            color: closeMa.containsMouse ? mocha.red : mocha.overlay1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (toastWindow.n) {
                                    NotifTicker.dismiss(toastWindow.n.uid);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
