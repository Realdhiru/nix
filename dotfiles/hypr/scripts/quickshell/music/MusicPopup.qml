import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    focus: true

    property real layoutWidth
    property real layoutHeight
    width: layoutWidth
    height: layoutHeight

    onVisibleChanged: {
        if (visible) {
            if (!musicProc.running) musicProc.running = true;
            if (!eqProc.running) eqProc.running = true;
        }
    }

    property var presetList: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            let currentIdx = root.presetList.indexOf(root.eqData.preset);
            if (currentIdx === -1) currentIdx = 0;

            if (event.key === Qt.Key_Left) {
                currentIdx = (currentIdx - 1 + root.presetList.length) % root.presetList.length;
            } else {
                currentIdx = (currentIdx + 1) % root.presetList.length;
            }
            root.applyPresetOptimistically(root.presetList[currentIdx]);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
            event.accepted = true;
        }
    }

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(val) {
        return scaler.s(val);
    }

    Theme { id: _theme }

    readonly property color base: _theme.base
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color overlay0: _theme.overlay0
    readonly property color overlay1: _theme.overlay1
    readonly property color overlay2: _theme.overlay2
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color subtext1: _theme.subtext1
    readonly property color blue: _theme.blue
    readonly property color sapphire: _theme.sapphire
    readonly property color lavender: _theme.blue 
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color red: _theme.red
    readonly property color yellow: _theme.yellow
    readonly property color primary: _theme.primary

    property var musicData: {
        "title": "Loading...", "artist": "", "status": "Stopped", "percent": 0,
        "lengthStr": "00:00", "positionStr": "00:00", "timeStr": "--:-- / --:--",
        "source": "Offline", "playerName": "", "blur": "", "grad": "",
        "textColor": _theme.text.toString(), "deviceIcon": "󰓃", "deviceName": "Speaker",
        "artUrl": ""
    }

    property var eqData: {
        "b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0,
        "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0,
        "preset": "Flat", "pending": false
    }

    property string accumulatedMusicOut: ""
    property string accumulatedEqOut: ""

    property bool userIsSeeking: false
    property bool userToggledPlay: false
    property real lastEqUpdate: 0

    Component.onCompleted: {
        console.log("MUSICPOPUP_TOKEN_CHECK: root.base=" + root.base);
        root.execCmd("$HOME/.config/hypr/scripts/quickshell/music/equalizer.sh --init");
    }

    StackView.onActivated: {
        eqProc.running = false;
        eqProc.running = true;
    }

    property var borderColors: {
        var defaultColors = [root.mauve, root.primary, root.red, root.mauve];
        if (!root.musicData || !root.musicData.grad) return defaultColors;

        var hexRegex = /#[0-9a-fA-F]{6}/g;
        var matches = root.musicData.grad.match(hexRegex);

        if (matches && matches.length >= 3) {
            return [matches[0], matches[1], matches[2], matches[0]]; 
        }
        return defaultColors;
    }

    property color bc1: (borderColors && borderColors.length > 0) ? borderColors[0] : root.mauve
    property color bc2: (borderColors && borderColors.length > 1) ? borderColors[1] : root.primary
    property color bc3: (borderColors && borderColors.length > 2) ? borderColors[2] : root.red
    property color bc4: (borderColors && borderColors.length > 3) ? borderColors[3] : root.mauve

    property color dynamicTextColor: {
        if (root.musicData && root.musicData.textColor) {
            var c = String(root.musicData.textColor).trim();
            var match = c.match(/^(#[0-9a-fA-F]{6})/);
            if (match) return match[1];
        }
        return root.text;
    }

    function execCmd(cmdStr) {
        var safeCmd = cmdStr.replace(/`/g, "\\`");
        var p = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "-c", \`${safeCmd}\`]
                running: true
                onExited: (exitCode) => destroy()
            }
        `, root);
    }

    function applyPresetOptimistically(presetName) {
        var presets = {
            "Flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "Bass": [4, 5, 3, 0, -1, 0, 1, 1, 2, 1],
            "Treble": [-2, -1, 0, 0, 1, 2, 3, 4, 5, 4],
            "Vocal": [-3, -2, -1, 1, 3, 4, 3, 2, 1, 0],
            "Pop": [2, 3, 1, -1, 0, 2, 3, 3, 2, 2],
            "Rock": [4, 3, 1, -2, -1, 1, 2, 3, 4, 3],
            "Jazz": [2, 2, 1, 1, 2, 2, 2, 2, 1, 1],
            "Classic": [1, 1, 0, 0, 1, 1, 1, 2, 3, 3]
        };
        if (presets[presetName]) {
            var temp = Object.assign({}, root.eqData);
            for (var i = 0; i < 10; i++) {
                temp["b" + (i + 1)] = presets[presetName][i];
            }
            temp.preset = presetName;
            temp.pending = false;
            root.eqData = temp;

            root.lastEqUpdate = Date.now();

            execCmd(`$HOME/.config/hypr/scripts/quickshell/music/equalizer.sh preset ${presetName}`);
        }
    }

    Timer {
        id: seekDebounceTimer
        interval: 2500
        onTriggered: root.userIsSeeking = false
    }

    Timer {
        id: playDebounceTimer
        interval: 1500
        onTriggered: root.userToggledPlay = false
    }

    Timer {
        interval: 500
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!musicProc.running) musicProc.running = true;
            if (!eqProc.running) eqProc.running = true;
        }
    }

    Process {
        id: musicProc
        running: true
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/quickshell/music/music_info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) {
                    var outStr = this.text.trim();
                    if (outStr.length > 0) {
                        try {
                            var newData = JSON.parse(outStr);
                            if (root.userToggledPlay) {
                                newData.status = root.musicData.status;
                            }
                            root.musicData = newData;
                        } catch(e) {}
                    }
                }
            }
        }
    }

    Process {
        id: eqProc
        running: true
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/quickshell/music/equalizer.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) {
                    if (Date.now() - root.lastEqUpdate < 2000) return;

                    var outStr = this.text.trim();
                    if (outStr.length > 0) {
                        try { root.eqData = JSON.parse(outStr); } catch(e) {}
                    }
                }
            }
        }
    }

    Item {
        id: mainWrapper
        anchors.fill: parent

        transformOrigin: Item.Center
        opacity: root.visible ? 1.0 : 0.0
        scale: root.visible ? 1.0 : 0.96

        Behavior on opacity {
            NumberAnimation { duration: root.visible ? Motion.enterMs : Motion.exitMs; easing.type: root.visible ? Motion.enterEasing : Motion.exitEasing }
        }
        Behavior on scale {
            NumberAnimation { duration: root.visible ? Motion.enterMs : Motion.exitMs; easing.type: root.visible ? Motion.enterEasing : Motion.exitEasing }
        }

        // Anti-bleed base (sits behind innerBg)
        Rectangle {
            anchors.fill: innerBg
            radius: innerBg.radius
            color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, Config.antiBleedOpacity)
            z: -1
        }

        Rectangle {
            id: innerBg
            anchors.fill: parent
            anchors.margins: 0
            clip: true
            color: Qt.rgba(root.base.r, root.base.g, root.base.b, Config.effectivePopupOpacity)
            border.width: 0
            border.color: "transparent"
            radius: root.s(10)


            layer.enabled: true

            Rectangle {
                id: innerBgMask
                anchors.fill: parent
                radius: root.s(10)
                visible: false

                layer.enabled: true
            }

            Item {
                id: bgEffectsLayer
                anchors.fill: parent

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: innerBgMask
                }

                Rectangle {
                    width: parent.width * 0.8; height: width; radius: width / 2
                    x: (parent.width / 2 - width / 2)
                    y: (parent.height / 2 - height / 2)

                    opacity: root.musicData.status === "Playing" ? 0.08 : (root.musicData.status === "Paused" ? 0.04 : 0.0)
                    color: root.musicData.status === "Playing" ? root.mauve : root.surface2
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                    Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                }

                Rectangle {
                    width: parent.width * 0.9; height: width; radius: width / 2
                    x: (parent.width / 2 - width / 2)
                    y: (parent.height / 2 - height / 2)

                    opacity: root.musicData.status === "Playing" ? 0.08 : (root.musicData.status === "Paused" ? 0.02 : 0.0)
                    color: root.musicData.status === "Playing" ? root.primary : root.surface1
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                    Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.s(20)
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(220)
                    spacing: root.s(25)

                    Item {
                        Layout.preferredWidth: root.s(220)
                        Layout.preferredHeight: root.s(220)
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: root.s(110)
                            color: root.surface1
                            border.width: root.s(4)
                            border.color: root.musicData.status === "Playing" ? root.mauve : root.overlay0
                            Behavior on border.color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                            Rectangle {
                                z: -1
                                anchors.centerIn: parent
                                width: parent.width + root.s(20)
                                height: parent.height + root.s(20)
                                radius: width / 2
                                color: root.mauve
                                opacity: root.musicData.status === "Playing" ? 0.5 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    blurEnabled: true
                                    blurMax: 32
                                    blur: 1.0
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: root.s(4)
                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: root.musicData.artUrl ? "file://" + root.musicData.artUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                }
                                Rectangle {
                                    id: maskRect
                                    anchors.fill: parent
                                    radius: width / 2
                                    visible: false
                                    layer.enabled: true
                                }
                                MultiEffect {
                                    anchors.fill: parent
                                    source: artImg
                                    maskEnabled: true
                                    maskSource: maskRect
                                    opacity: artImg.status === Image.Ready ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.2)
                                    opacity: artImg.status === Image.Ready ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                }

                                Rectangle {
                                    width: root.s(40); height: root.s(40)
                                    radius: root.s(20); color: "#000000"
                                    opacity: 0.8; anchors.centerIn: parent
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: root.s(15)

                        ColumnLayout {
                            spacing: root.s(6)

                            Item {
                                id: titleClipRect
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(28)
                                clip: true

                                property int marqueeSpacing: root.s(60)

                                Item {
                                    id: marqueeContainer
                                    height: parent.height

                                    Row {
                                        spacing: titleClipRect.marqueeSpacing
                                        Text {
                                            id: titleTextMain
                                            text: root.musicData.title
                                            color: root.dynamicTextColor
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: root.s(20)
                                            font.bold: true
                                            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                                            onTextChanged: {
                                                marqueeContainer.x = 0;
                                                if (implicitWidth > titleClipRect.width) {
                                                    titleAnim.restart();
                                                } else {
                                                    titleAnim.stop();
                                                }
                                            }
                                        }
                                        Text {
                                            id: titleTextClone
                                            text: root.musicData.title
                                            color: root.dynamicTextColor
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: root.s(20)
                                            font.bold: true
                                            visible: titleTextMain.implicitWidth > titleClipRect.width
                                        }
                                    }

                                    SequentialAnimation on x {
                                        id: titleAnim
                                        loops: Animation.Infinite
                                        running: titleTextMain.implicitWidth > titleClipRect.width

                                        PauseAnimation { duration: Motion.marqueePauseMs }

                                        NumberAnimation {
                                            from: 0
                                            to: -(titleTextMain.implicitWidth + titleClipRect.marqueeSpacing)
                                            duration: (titleTextMain.implicitWidth + titleClipRect.marqueeSpacing) * Motion.marqueeMsPerPx
                                        }

                                        PropertyAction { target: marqueeContainer; property: "x"; value: 0 }
                                    }
                                }
                            }

                            Text {
                                text: root.musicData.artist ? "BY " + root.musicData.artist : ""
                                color: root.subtext0 
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(14)
                                font.bold: true
                                elide: Text.ElideRight
                                maximumLineCount: 1 
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(20)
                            }
                            RowLayout {
                                spacing: root.s(10)
                                Rectangle {
                                    id: devicePill
                                    color: devicePillMa.containsMouse ? Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.25) : "#1AFFFFFF"
                                    radius: root.s(4)
                                    Layout.preferredHeight: root.s(24)
                                    Layout.preferredWidth: pillContent.width + root.s(20)

                                    Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                                    RowLayout {
                                        id: pillContent
                                        anchors.centerIn: parent
                                        spacing: root.s(6)
                                        Text { text: root.musicData.deviceIcon || "󰓃"; color: root.mauve; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14) }
                                        Text { text: root.musicData.deviceName || "Speaker"; color: devicePillMa.containsMouse ? root.text : root.overlay2; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); font.bold: true }
                                    }

                                    MouseArea {
                                        id: devicePillMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.execCmd("bash " + Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/music/cycle_audio_sink.sh");
                                        }
                                    }
                                }
                                Text {
                                    text: "VIA " + (root.musicData.source || "Offline")
                                    color: root.overlay2 
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: root.s(12)
                                    font.bold: true
                                    font.italic: true
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.s(5)

                            Slider {
                                id: progBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(20)
                                from: 0; to: 100

                                Connections {
                                    target: root
                                    function onMusicDataChanged() {
                                        if (!progBar.pressed && !root.userIsSeeking) {
                                            if (root.musicData && root.musicData.percent !== undefined) {
                                                var p = Number(root.musicData.percent);
                                                if (!isNaN(p)) progBar.value = p;
                                            }
                                        }
                                    }
                                }

                                Behavior on value {
                                    enabled: !progBar.pressed && !root.userIsSeeking
                                    NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing }
                                }

                                onPressedChanged: {
                                    if (pressed) {
                                        root.userIsSeeking = true;
                                        seekDebounceTimer.stop();
                                    } else {
                                        var temp = Object.assign({}, root.musicData);
                                        temp.percent = value;
                                        root.musicData = temp;

                                        var safePlayer = root.musicData.playerName ? root.musicData.playerName : "";
                                        root.execCmd(`$HOME/.config/hypr/scripts/quickshell/music/player_control.sh seek ${value.toFixed(2)} ${root.musicData.length} "${safePlayer}"`);

                                        seekDebounceTimer.restart();
                                    }
                                }

                                background: Item {
                                    x: progBar.leftPadding
                                    y: progBar.topPadding + (progBar.availableHeight - root.s(12)) / 2
                                    width: progBar.availableWidth
                                    height: root.s(12)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: root.s(6)
                                        color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.7)

                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            shadowEnabled: true
                                            shadowColor: "#000000"
                                            shadowOpacity: 0.9
                                            shadowBlur: 0.5
                                            shadowVerticalOffset: 1
                                        }
                                    }

                                    Item {
                                        width: progBar.handle.x - progBar.leftPadding + (progBar.handle.width / 2)
                                        height: parent.height

                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: sliderFillMask
                                        }

                                        Rectangle {
                                            id: sliderFillMask
                                            width: parent.width
                                            height: parent.height
                                            radius: root.s(6)
                                            visible: false
                                            layer.enabled: true
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0000; color: Qt.lighter(root.primary, 1.2); Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                GradientStop { position: 0.1666; color: Qt.lighter(root.primary, 1.15); Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                GradientStop { position: 0.3333; color: Qt.lighter(root.mauve, 1.15); Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                GradientStop { position: 0.5000; color: Qt.lighter(root.primary, 1.2); Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                GradientStop { position: 0.6666; color: Qt.lighter(root.primary, 1.15); Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                GradientStop { position: 0.8333; color: Qt.lighter(root.mauve, 1.15); Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                GradientStop { position: 1.0000; color: Qt.lighter(root.primary, 1.2); Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                            }
                                        }
                                    }
                                }

                                handle: Rectangle {
                                    x: progBar.leftPadding + progBar.visualPosition * (progBar.availableWidth - width)
                                    y: progBar.topPadding + (progBar.availableHeight - height) / 2
                                    implicitWidth: root.s(18)
                                    implicitHeight: root.s(18)
                                    width: root.s(18); height: root.s(18)
                                    radius: root.s(9); color: root.text
                                    scale: progBar.pressed ? 1.3 : 1.0
                                    Behavior on scale { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: root.musicData.positionStr || "00:00"; color: root.overlay2; font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: root.s(13) }
                                Item { Layout.fillWidth: true }
                                Text { text: root.musicData.lengthStr || "00:00"; color: root.overlay2; font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: root.s(13) }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: root.s(20)

                            // Seek -10s
                            MouseArea {
                                width: root.s(30); height: root.s(30)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.execCmd("playerctl position 10-")
                                Text { anchors.centerIn: parent; text: "󰑎"; color: parent.pressed ? root.text : root.overlay2; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20) }
                            }

                            MouseArea {
                                width: root.s(30); height: root.s(30)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.execCmd("playerctl previous")
                                Text { anchors.centerIn: parent; text: ""; color: parent.pressed ? root.text : root.overlay2; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(24) }
                            }
                            MouseArea {
                                id: playPauseBtn
                                width: root.s(50); height: root.s(50)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.userToggledPlay = true;
                                    playDebounceTimer.restart();
                                    var temp = Object.assign({}, root.musicData);
                                    temp.status = (temp.status === "Playing" ? "Paused" : "Playing");
                                    root.musicData = temp;
                                    root.execCmd("playerctl play-pause");
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.musicData.status === "Playing" ? "" : ""
                                    color: parent.pressed ? root.pink : root.mauve
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: root.s(42)
                                    scale: parent.pressed ? 0.8 : 1.0
                                    Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                    Behavior on scale { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                }
                            }
                            MouseArea {
                                width: root.s(30); height: root.s(30)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.execCmd("playerctl next")
                                Text { anchors.centerIn: parent; text: ""; color: parent.pressed ? root.text : root.overlay2; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(24) }
                            }

                            // Seek +10s
                            MouseArea {
                                width: root.s(30); height: root.s(30)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.execCmd("playerctl position 10+")
                                Text { anchors.centerIn: parent; text: "󰑋"; color: parent.pressed ? root.text : root.overlay2; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20) }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(2)
                    Layout.topMargin: root.s(20)
                    Layout.bottomMargin: root.s(20)
                    color: "#1AFFFFFF"
                    radius: root.s(1)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.s(15)

                    RowLayout {
                        Layout.fillWidth: true

                        Text { text: "Equalizer"; color: root.mauve; font.family: "JetBrains Mono"; font.pixelSize: root.s(16); font.bold: true; Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredHeight: root.s(28)
                            Layout.preferredWidth: applyTxt.width + root.s(30)
                            radius: root.s(10)
                            color: root.eqData.pending ? root.mauve : root.surface1
                            border.color: root.eqData.pending ? root.mauve : root.surface2
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                            Behavior on border.color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                            layer.enabled: root.eqData.pending
                            layer.effect: MultiEffect {
                                shadowEnabled: true; shadowColor: root.mauve; shadowOpacity: 0.4; shadowBlur: 0.6
                            }

                            Text {
                                id: applyTxt
                                anchors.centerIn: parent
                                text: root.eqData.pending ? "Apply" : "Saved"
                                color: root.eqData.pending ? root.base : root.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(12)
                                font.bold: true
                                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: root.eqData.pending ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (root.eqData.pending) {
                                        var temp = Object.assign({}, root.eqData);
                                        temp.pending = false;
                                        root.eqData = temp;

                                        root.lastEqUpdate = Date.now();

                                        root.execCmd("$HOME/.config/hypr/scripts/quickshell/music/equalizer.sh apply");
                                    }
                                }
                            }
                        }
                        Text { text: root.eqData.preset || "Flat"; color: root.subtext0; font.family: "JetBrains Mono"; font.pixelSize: root.s(14); font.bold: true; Layout.leftMargin: root.s(15) }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(180)

                        Row {
                            id: eqSliderRow
                            anchors.fill: parent
                            z: 1 

                            Repeater {
                                model: [
                                    {"idx": 1, "lbl": "31"}, {"idx": 2, "lbl": "63"}, {"idx": 3, "lbl": "125"},
                                    {"idx": 4, "lbl": "250"}, {"idx": 5, "lbl": "500"}, {"idx": 6, "lbl": "1k"},
                                    {"idx": 7, "lbl": "2k"}, {"idx": 8, "lbl": "4k"}, {"idx": 9, "lbl": "8k"},
                                    {"idx": 10, "lbl": "16k"}
                                ]
                                delegate: Item {
                                    id: sliderDelegate
                                    width: eqSliderRow.width / 10
                                    height: eqSliderRow.height

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: root.s(5)
                                        Slider {
                                            id: eqSlider
                                            Layout.fillHeight: true
                                            Layout.alignment: Qt.AlignHCenter
                                            orientation: Qt.Vertical
                                            from: -12; to: 12
                                            stepSize: 1

                                            Connections {
                                                target: root
                                                function onEqDataChanged() {
                                                    if (!eqSlider.pressed) {
                                                        if (root.eqData && root.eqData["b" + modelData.idx] !== undefined) {
                                                            var p = Number(root.eqData["b" + modelData.idx]);
                                                            if (!isNaN(p)) eqSlider.value = p;
                                                        }
                                                    }
                                                }
                                            }

                                            Behavior on value {
                                                enabled: !eqSlider.pressed
                                                NumberAnimation {
                                                    duration: Motion.moveMs
                                                    easing.type: Motion.moveEasing
                                                }
                                            }

                                            onPressedChanged: {
                                                if (!pressed) {
                                                    var temp = Object.assign({}, root.eqData);
                                                    temp["b" + modelData.idx] = Math.round(value);
                                                    temp.preset = "Custom";
                                                    temp.pending = true;
                                                    root.eqData = temp;

                                                    root.lastEqUpdate = Date.now();

                                                    root.execCmd(`$HOME/.config/hypr/scripts/quickshell/music/equalizer.sh set_band ${modelData.idx} ${Math.round(value)}`);
                                                }
                                            }

                                            background: Rectangle {
                                                id: trackBg
                                                x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                                y: eqSlider.topPadding
                                                implicitWidth: root.s(10)
                                                implicitHeight: root.s(150)
                                                width: root.s(10); height: eqSlider.availableHeight
                                                radius: root.s(4);

                                                color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.7)

                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    id: trackEffect
                                                    shadowEnabled: true
                                                    shadowColor: "#000000"
                                                    shadowOpacity: 0.9
                                                    shadowBlur: 0.5
                                                    shadowVerticalOffset: 1
                                                }

                                                Item {
                                                    width: parent.width
                                                    height: (1 - eqSlider.visualPosition) * parent.height
                                                    y: eqSlider.visualPosition * parent.height

                                                    layer.enabled: true
                                                    layer.effect: MultiEffect {
                                                        maskEnabled: true
                                                        maskSource: eqFillMask
                                                    }

                                                    Rectangle {
                                                        id: eqFillMask
                                                        anchors.fill: parent
                                                        radius: root.s(4)
                                                        visible: false
                                                        layer.enabled: true
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: root.primary
                                                    }
                                                }
                                            }

                                            handle: Rectangle {
                                                x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                                y: eqSlider.topPadding + eqSlider.visualPosition * (eqSlider.availableHeight - height)
                                                implicitWidth: root.s(18)
                                                implicitHeight: root.s(18)
                                                width: root.s(18); height: root.s(18)
                                                radius: root.s(9); color: root.text
                                            }
                                        }
                                        Text {
                                            text: modelData.lbl
                                            color: root.overlay1
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: root.s(10)
                                            font.bold: true
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }

                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.s(8)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            Repeater {
                                model: ["Flat", "Bass", "Treble", "Vocal"]
                                delegate: PresetButton { name: modelData }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            Repeater {
                                model: ["Pop", "Rock", "Jazz", "Classic"]
                                delegate: PresetButton { name: modelData }
                            }
                        }
                    }
                }
            }
        }
    }

    component PresetButton : Rectangle {
        property string name: ""
        Layout.fillWidth: true
        Layout.preferredHeight: root.s(32)
        radius: root.s(8)

        property bool isActivePreset: root.eqData && root.eqData.preset === name
        property bool isHovered: hoverMa.containsMouse

        color: isActivePreset ? root.mauve : (isHovered ? root.surface1 : Qt.rgba(root.base.r, root.base.g, root.base.b, 0.75))
        scale: isHovered && !isActivePreset ? 1.05 : 1.0

        Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
        Behavior on scale { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

        Text {
            anchors.centerIn: parent
            text: parent.name
            color: parent.isActivePreset ? root.base : (parent.isHovered ? root.text : root.subtext0)
            font.family: "JetBrains Mono"
            font.pixelSize: root.s(12)
            font.bold: true
            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
        }

        MouseArea {
            id: hoverMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyPresetOptimistically(parent.name)
        }
    }
}