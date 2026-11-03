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
                    console.log("[NOTIF_BENCH] TOAST_FRAME ts=" + Date.now());
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
                left: true
                right: true
            }

            margins {
                top: toastWindow.s(Config.barEdgeMargin || 8)
            }

            exclusiveZone: -1
            exclusionMode: ExclusionMode.Ignore
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

            readonly property color notifAccent: (Config.accentColorSource && mocha[Config.accentColorSource]) ? mocha[Config.accentColorSource] : mocha.primary

            readonly property color pillBorder: Qt.rgba(toastWindow.notifAccent.r, toastWindow.notifAccent.g, toastWindow.notifAccent.b, 0.35)

            readonly property color pillBorderHover: Qt.rgba(toastWindow.notifAccent.r, toastWindow.notifAccent.g, toastWindow.notifAccent.b, 0.70)

            property var n: NotifTicker.tickerNotif
            onNChanged: {
                if (n && (Config.topBarPosition === "left" || !Config.topBarVisible)) console.log("[NOTIF_BENCH] TOAST_FRAME ts=" + Date.now());
            }
            property var actionArray: {
                try { return n && n.actionsJson ? JSON.parse(n.actionsJson) : []; }
                catch (e) { return []; }
            }

            readonly property bool isOsd: n && n.appName === "System" && (n.summary === "Volume" || n.summary === "Brightness" || n.summary === "Microphone")

            implicitHeight: toastCard.height + toastWindow.s(20)

            mask: Region { item: toastCard }

            Rectangle {
                id: toastCard
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                height: toastWindow.s(40)
                width: toastWindow.isOsd
                    ? toastWindow.s(320)
                    : Math.min(toastWindow.s(820), Math.max(toastWindow.s(180), contentRow.implicitWidth + toastWindow.s(32)))
                radius: toastWindow.s(14)
                color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Config.toastOpacity)
                border.width: Config.borderWidth
                border.color: Config.borderWidth > 0 ? (cardMa.containsMouse ? toastWindow.pillBorderHover : toastWindow.pillBorder) : Qt.rgba(1, 1, 1, Config.glassSpecular)
                clip: true

                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                Behavior on border.color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                Behavior on width {
                    NumberAnimation {
                        duration: toastWindow.isIslandActive ? Motion.enterMs : Motion.exitMs
                        easing.type: toastWindow.isIslandActive ? Motion.enterEasing : Motion.exitEasing
                    }
                }

                opacity: toastWindow.isIslandActive ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: toastWindow.isIslandActive ? Motion.enterMs : Motion.exitMs
                        easing.type: toastWindow.isIslandActive ? Motion.enterEasing : Motion.exitEasing
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
                                duration: toastWindow.isIslandActive ? Motion.enterMs : Motion.exitMs
                                easing.type: toastWindow.isIslandActive ? Motion.enterEasing : Motion.exitEasing
                            }
                        }
                        Behavior on yScale {
                            NumberAnimation {
                                duration: toastWindow.isIslandActive ? Motion.enterMs : Motion.exitMs
                                easing.type: toastWindow.isIslandActive ? Motion.enterEasing : Motion.exitEasing
                            }
                        }
                    },
                    Translate {
                        y: toastWindow.isIslandActive ? 0 : toastWindow.s(-6)
                        Behavior on y {
                            NumberAnimation {
                                duration: toastWindow.isIslandActive ? Motion.enterMs : Motion.exitMs
                                easing.type: toastWindow.isIslandActive ? Motion.enterEasing : Motion.exitEasing
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

                // OSD slider row (Volume / Brightness / Microphone - identical to TopBar.qml:1010-1090)
                RowLayout {
                    anchors.centerIn: parent
                    spacing: toastWindow.s(16)
                    visible: toastWindow.isOsd

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: toastWindow.s(18)
                        color: mocha.text
                        text: {
                            if (!toastWindow.n) return "";
                            if (toastWindow.n.summary === "Volume") {
                                if (toastWindow.n.body.indexOf("Muted") !== -1 || toastWindow.n.body === "Muted") return "󰝟";
                                return "󰕾";
                            }
                            if (toastWindow.n.summary === "Brightness") return "󰃠";
                            if (toastWindow.n.summary === "Microphone") {
                                if (toastWindow.n.body.indexOf("Muted") !== -1 || toastWindow.n.body === "Muted") return "󰍭";
                                return "󰍬";
                            }
                            return "";
                        }
                    }

                    Item {
                        id: osdSliderContainer
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: toastWindow.s(180)
                        Layout.preferredHeight: toastWindow.s(8)

                        property bool isMuted: toastWindow.n && (toastWindow.n.body.indexOf("Muted") !== -1 || toastWindow.n.body === "Muted")
                        property real pct: {
                            if (!toastWindow.n) return 0;
                            let v = parseInt(toastWindow.n.body);
                            return isNaN(v) ? 0 : Math.max(0, Math.min(100, v)) / 100.0;
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: mocha.surface1
                        }

                        Item {
                            anchors.fill: parent
                            property real fillW: osdSliderContainer.pct > 0 ? Math.max(parent.height, osdSliderContainer.pct * parent.width) : 0
                            Behavior on fillW { NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }

                            Rectangle {
                                width: parent.fillW
                                height: parent.height
                                radius: height / 2
                                color: osdSliderContainer.isMuted ? mocha.subtext1 : toastWindow.notifAccent
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: toastWindow.n ? toastWindow.n.body : ""
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: toastWindow.s(13)
                        color: mocha.text
                    }
                }

                RowLayout {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: toastWindow.s(10)
                    visible: !toastWindow.isOsd

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
                        font.weight: Font.Bold
                        font.pixelSize: toastWindow.s(10.5)
                        color: mocha.subtext0
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "\u2022"
                        font.pixelSize: toastWindow.s(10)
                        color: mocha.subtext1
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
                        Layout.maximumWidth: toastWindow.s(360)
                        elide: Text.ElideRight
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
                                color: isPrimary ? (actMa.containsMouse ? Qt.lighter(toastWindow.notifAccent, 1.15) : toastWindow.notifAccent) : (actMa.containsMouse ? Qt.rgba(toastWindow.notifAccent.r, toastWindow.notifAccent.g, toastWindow.notifAccent.b, 0.30) : Qt.rgba(toastWindow.notifAccent.r, toastWindow.notifAccent.g, toastWindow.notifAccent.b, 0.15))
                                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

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
                        color: closeMa.containsMouse ? Qt.rgba(toastWindow.notifAccent.r, toastWindow.notifAccent.g, toastWindow.notifAccent.b, 0.20) : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: toastWindow.s(11)
                            color: closeMa.containsMouse ? mocha.red : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.5)
                            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
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
