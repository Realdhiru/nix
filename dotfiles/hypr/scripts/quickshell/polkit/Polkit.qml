import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: polkitWindow

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: polkitService.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: polkitService.isActive
    color: polkitService.isActive ? Qt.rgba(0, 0, 0, 0.55) : "transparent"

    Theme {
        id: _theme
    }

    PolkitService {
        id: polkitService
    }

    property bool isAuthenticating: false

    function grabInputFocus() {
        passwordInput.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible) {
            polkitWindow.isAuthenticating = false;
            passwordInput.text = "";
            focusRetryTimer.restart();
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 50
        repeat: false
        onTriggered: {
            polkitWindow.grabInputFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: polkitWindow.visible
        onActivated: polkitService.cancel()
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: polkitWindow.visible && passwordInput.text.length > 0
        onActivated: polkitWindow.submitPassword()
    }

    function submitPassword() {
        if (!polkitService.flow || polkitWindow.isAuthenticating) return;
        polkitWindow.isAuthenticating = true;
        polkitService.submit(passwordInput.text);
    }

    Connections {
        target: polkitService

        function onRequestStarted() {
            polkitWindow.isAuthenticating = false;
            passwordInput.text = "";
            focusRetryTimer.restart();
        }

        function onAuthenticationFailed() {
            polkitWindow.isAuthenticating = false;
            passwordInput.text = "";
            shakeAnim.restart();
            focusRetryTimer.restart();
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: dialogCard; property: "anchors.horizontalCenterOffset"; from: 0; to: -10; duration: 50 }
        NumberAnimation { target: dialogCard; property: "anchors.horizontalCenterOffset"; from: -10; to: 10; duration: 50 }
        NumberAnimation { target: dialogCard; property: "anchors.horizontalCenterOffset"; from: 10; to: -6; duration: 50 }
        NumberAnimation { target: dialogCard; property: "anchors.horizontalCenterOffset"; from: -6; to: 6; duration: 50 }
        NumberAnimation { target: dialogCard; property: "anchors.horizontalCenterOffset"; from: 6; to: 0; duration: 50 }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: polkitService.cancel()
    }

    // Frosted Glass Card Container
    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: 480
        implicitHeight: cardLayout.implicitHeight + 36
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.88)
        radius: 16
        border.color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.5)
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Prevent backdrop click cancel when clicking inside card
        }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    Layout.alignment: Qt.AlignTop
                    radius: 12
                    color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.6)

                    Text {
                        anchors.centerIn: parent
                        text: "󰌾"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: _theme.mauve
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    Text {
                        text: {
                            if (polkitService.flow && polkitService.flow.message) return polkitService.flow.message;
                            return "Authentication Required";
                        }
                        color: _theme.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            if (polkitService.flow && polkitService.flow.actionId) return polkitService.flow.actionId;
                            return "Authentication is needed to execute action as superuser.";
                        }
                        color: _theme.subtext0
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignTop
                    radius: 8
                    color: closeHover.hovered ? Qt.rgba(_theme.red.r, _theme.red.g, _theme.red.b, 0.25) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: closeHover.hovered ? _theme.red : _theme.subtext0
                    }

                    HoverHandler { id: closeHover }
                    TapHandler { onTapped: polkitService.cancel() }
                }
            }

            // Error banner if auth failed
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: errorText.implicitHeight + 12
                radius: 8
                color: Qt.rgba(_theme.red.r, _theme.red.g, _theme.red.b, 0.15)
                border.color: Qt.rgba(_theme.red.r, _theme.red.g, _theme.red.b, 0.4)
                border.width: 1
                visible: polkitService.errorMessage !== ""

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Text {
                        text: "󰅚"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: _theme.red
                    }

                    Text {
                        id: errorText
                        text: polkitService.errorMessage
                        color: _theme.red
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            // Password Field
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 10
                color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.5)
                border.color: passwordInput.activeFocus ? _theme.mauve : Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.4)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "󰌾"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: _theme.subtext0
                    }

                    TextField {
                        id: passwordInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: _theme.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: 13
                        placeholderText: "Enter password..."
                        placeholderTextColor: _theme.subtext0
                        background: null
                        enabled: !polkitWindow.isAuthenticating
                        onAccepted: polkitWindow.submitPassword()
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 6
                        color: submitHover.hovered ? _theme.mauve : Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.6)

                        Text {
                            anchors.centerIn: parent
                            text: "󰄬"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: submitHover.hovered ? _theme.base : _theme.text
                        }

                        HoverHandler { id: submitHover }
                        TapHandler { onTapped: polkitWindow.submitPassword() }
                    }
                }
            }
        }
    }
}
