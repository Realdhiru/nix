import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    focus: true

    property real layoutWidth: 720
    property real layoutHeight: 640
    width: s(layoutWidth)
    height: s(layoutHeight)

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    function s(val) { return scaler.s(val); }

    Theme { id: mocha }

    // Modes state tracking
    property bool wpKillActive: false
    property bool gamingActive: false
    property bool powerSaverActive: false
    property bool coffeeActive: SysData.coffeeActive
    property bool broadcastActive: false

    function parseModesJson(txt) {
        if (!txt || txt === "") return;
        try {
            let data = JSON.parse(txt);
            if (data.active) {
                root.wpKillActive = !!data.active["wallpaper-kill"];
                root.gamingActive = !!data.active["gaming"];
                root.powerSaverActive = !!data.active["power-saver"];
                root.coffeeActive = !!data.active["coffee"];
            }
        } catch(e) {}
    }

    FileView {
        id: modesFileView
        path: Caching.modesJsonFile
        watchChanges: true
        onLoadedChanged: root.parseModesJson(modesFileView.text())
        onTextChanged: root.parseModesJson(modesFileView.text())
        onFileChanged: {
            modesFileView.reload();
            root.parseModesJson(modesFileView.text());
        }
    }

    // Top process monitor list & broadcast check (gated to run only while visible)
    ListModel { id: processModel }

    Process {
        id: psPoller
        command: ["bash", "-c", "[ -f \"${XDG_RUNTIME_DIR:-/run/user/$UID}/pw_broadcast_active\" ] && echo '__BC_ON__' || echo '__BC_OFF__'; ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 7 | tail -n +2 | awk '{printf \"%s\\t%s\\t%s\\t%s\\n\", $1, $2, $3, $4}'"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let trimmed = line.trim();
                if (!trimmed) return;
                if (trimmed === "__BC_ON__") {
                    root.broadcastActive = true;
                    return;
                }
                if (trimmed === "__BC_OFF__") {
                    root.broadcastActive = false;
                    return;
                }
                let parts = trimmed.split("\t");
                if (parts.length >= 4) {
                    processModel.append({
                        "pid": parts[0],
                        "name": parts[1].replace(/^\./, "").replace(/-wrapp$/, ""),
                        "cpu": parts[2],
                        "mem": parts[3]
                    });
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: root.visible
        onTriggered: {
            processModel.clear();
            psPoller.running = false;
            psPoller.running = true;
        }
    }

    // Lifecycle subscription to SysData telemetry
    onVisibleChanged: {
        if (visible) {
            SysData.subscribe();
            modesFileView.reload();
            root.parseModesJson(modesFileView.text());
            processModel.clear();
            psPoller.running = true;
            pollTimer.restart();
            root.forceActiveFocus();
        } else {
            SysData.unsubscribe();
            pollTimer.stop();
            psPoller.running = false;
        }
    }

    Component.onCompleted: {
        if (visible) {
            SysData.subscribe();
            modesFileView.reload();
            root.parseModesJson(modesFileView.text());
            psPoller.running = true;
            pollTimer.restart();
            root.forceActiveFocus();
        }
    }

    Component.onDestruction: {
        SysData.unsubscribe();
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            closeWidget();
            event.accepted = true;
        }
    }

    function closeWidget() {
        Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh close"]);
    }

    // Main Card Surface
    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: root.s(16)
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Config.effectivePopupOpacity)
        border.width: Config.borderWidth
        border.color: (Config.borderWidth > 0 && Config.borderOpacity > 0)
            ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, Config.borderOpacity)
            : Qt.rgba(255, 255, 255, Config.glassSpecular)
        clip: true

        Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
        Behavior on border.color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

        // Anti-bleed base layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(20)
            spacing: root.s(16)

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(12)

                Text {
                    text: "󰄛"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: root.s(22)
                    color: mocha.mauve
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    Text {
                        text: "System Dashboard"
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: root.s(16)
                        color: mocha.text
                    }

                    Text {
                        text: "ASUS Vivobook OLED • Core i5-13500H • Intel Iris Xe"
                        font.family: "JetBrains Mono"
                        font.weight: Font.Medium
                        font.pixelSize: root.s(11)
                        color: mocha.subtext0
                    }
                }

                // Close Button
                Rectangle {
                    width: root.s(28)
                    height: root.s(28)
                    radius: width / 2
                    color: closeMa.containsMouse ? mocha.surface2 : "transparent"
                    border.width: root.s(1)
                    border.color: closeMa.containsMouse ? mocha.red : mocha.surface1
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: root.s(14)
                        color: closeMa.containsMouse ? mocha.red : mocha.overlay1
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeWidget()
                    }
                }
            }

            // Modes Overview & Control Strip
            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Text {
                    text: "ACTIVE MODES & TOGGLES"
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    font.pixelSize: root.s(10)
                    color: mocha.overlay1
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(8)

                    // 1. Wallpaper Kill
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(36)
                        radius: root.s(10)
                        color: root.wpKillActive ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.25) : mocha.surface0
                        border.width: root.s(1)
                        border.color: root.wpKillActive ? mocha.mauve : (wpMa.containsMouse ? mocha.surface2 : mocha.surface1)
                        Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: root.s(6)

                            Text {
                                text: "󰸉"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(14)
                                color: root.wpKillActive ? mocha.mauve : mocha.subtext1
                            }

                            Text {
                                text: "No Wallpaper"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: root.wpKillActive ? mocha.text : mocha.subtext0
                            }
                        }

                        MouseArea {
                            id: wpMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/mode_ctl.sh toggle wallpaper-kill"])
                        }
                    }

                    // 2. Gaming Mode
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(36)
                        radius: root.s(10)
                        color: root.gamingActive ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.25) : mocha.surface0
                        border.width: root.s(1)
                        border.color: root.gamingActive ? mocha.red : (gameMa.containsMouse ? mocha.surface2 : mocha.surface1)
                        Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: root.s(6)

                            Text {
                                text: "󰊖"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(14)
                                color: root.gamingActive ? mocha.red : mocha.subtext1
                            }

                            Text {
                                text: "Gaming"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: root.gamingActive ? mocha.text : mocha.subtext0
                            }
                        }

                        MouseArea {
                            id: gameMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/mode_ctl.sh toggle gaming"])
                        }
                    }

                    // 3. Power Saver
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(36)
                        radius: root.s(10)
                        color: root.powerSaverActive ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.25) : mocha.surface0
                        border.width: root.s(1)
                        border.color: root.powerSaverActive ? mocha.green : (psMa.containsMouse ? mocha.surface2 : mocha.surface1)
                        Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: root.s(6)

                            Text {
                                text: "󰌪"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(14)
                                color: root.powerSaverActive ? mocha.green : mocha.subtext1
                            }

                            Text {
                                text: "Power Saver"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: root.powerSaverActive ? mocha.text : mocha.subtext0
                            }
                        }

                        MouseArea {
                            id: psMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/mode_ctl.sh toggle power-saver"])
                        }
                    }

                    // 4. Coffee (Idle Inhibit)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(36)
                        radius: root.s(10)
                        color: root.coffeeActive ? Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.25) : mocha.surface0
                        border.width: root.s(1)
                        border.color: root.coffeeActive ? mocha.yellow : (coffeeMa.containsMouse ? mocha.surface2 : mocha.surface1)
                        Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: root.s(6)

                            Text {
                                text: "󰅶"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(14)
                                color: root.coffeeActive ? mocha.yellow : mocha.subtext1
                            }

                            Text {
                                text: "Coffee"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: root.coffeeActive ? mocha.text : mocha.subtext0
                            }
                        }

                        MouseArea {
                            id: coffeeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SysData.setCoffee(!root.coffeeActive)
                        }
                    }

                    // 5. Audio Broadcast
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(36)
                        radius: root.s(10)
                        color: root.broadcastActive ? Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.25) : mocha.surface0
                        border.width: root.s(1)
                        border.color: root.broadcastActive ? mocha.blue : (bcMa.containsMouse ? mocha.surface2 : mocha.surface1)
                        Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: root.s(6)

                            Text {
                                text: "󰍫"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(14)
                                color: root.broadcastActive ? mocha.blue : mocha.subtext1
                            }

                            Text {
                                text: "Broadcast"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: root.broadcastActive ? mocha.text : mocha.subtext0
                            }
                        }

                        MouseArea {
                            id: bcMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/toggle_multi_sink.sh"])
                        }
                    }
                }
            }

            // Real-Time Hardware Telemetry Grid (2x2)
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: root.s(12)
                rowSpacing: root.s(12)

                // Card 1: CPU
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(72)
                    radius: root.s(12)
                    color: mocha.surface0
                    border.width: root.s(1)
                    border.color: mocha.surface1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰍛 CPU Usage"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(12)
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: SysData.cpu + "%  •  " + SysData.temp + "°C"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(12)
                                color: mocha.blue
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(6)
                            radius: height / 2
                            color: mocha.surface2

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * (SysData.cpu / 100.0)))
                                height: parent.height
                                radius: height / 2
                                color: SysData.cpu > 80 ? mocha.red : (SysData.cpu > 50 ? mocha.yellow : mocha.blue)
                                Behavior on width { NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }
                            }
                        }
                    }
                }

                // Card 2: RAM
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(72)
                    radius: root.s(12)
                    color: mocha.surface0
                    border.width: root.s(1)
                    border.color: mocha.surface1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰘚 Memory (RAM)"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(12)
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: SysData.ramGb.toFixed(1) + " GB  (" + SysData.ramPercent + "%)"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(12)
                                color: mocha.mauve
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(6)
                            radius: height / 2
                            color: mocha.surface2

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * (SysData.ramPercent / 100.0)))
                                height: parent.height
                                radius: height / 2
                                color: SysData.ramPercent > 85 ? mocha.red : mocha.mauve
                                Behavior on width { NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }
                            }
                        }
                    }
                }

                // Card 3: Battery & Power
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(72)
                    radius: root.s(12)
                    color: mocha.surface0
                    border.width: root.s(1)
                    border.color: mocha.surface1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: (SysData.acOnline ? "󰂄 Battery (AC Connected)" : "󰁹 Battery (Discharging)")
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(12)
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: SysData.batCapacity + "%  •  " + (SysData.batWattsText || "")
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(12)
                                color: SysData.batCapacity <= 20 ? mocha.red : mocha.green
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(6)
                            radius: height / 2
                            color: mocha.surface2

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * (SysData.batCapacity / 100.0)))
                                height: parent.height
                                radius: height / 2
                                color: SysData.batCapacity <= 20 ? mocha.red : mocha.green
                                Behavior on width { NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }
                            }
                        }
                    }
                }

                // Card 4: Network & I/O
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(72)
                    radius: root.s(12)
                    color: mocha.surface0
                    border.width: root.s(1)
                    border.color: mocha.surface1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰖩 Network I/O"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(12)
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (SysData.onBattery ? "60Hz" : "120Hz") + " • OLED 2.8K"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: mocha.teal
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "↓ " + (SysData.netRx > 0 ? SysData.netRx.toFixed(1) : "0.0") + " KB/s"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(12)
                                color: mocha.peach
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "↑ " + (SysData.netTx > 0 ? SysData.netTx.toFixed(1) : "0.0") + " KB/s"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(12)
                                color: mocha.sapphire
                            }
                        }
                    }
                }
            }

            // Task Manager Top Processes Table
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.s(8)

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "TOP ACTIVE TASKS"
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: root.s(10)
                        color: mocha.overlay1
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Auto-refresh: 2s"
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(10)
                        color: mocha.overlay0
                    }
                }

                // Table Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(26)
                    radius: root.s(6)
                    color: mocha.surface0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.s(12)
                        anchors.rightMargin: root.s(12)
                        spacing: root.s(8)

                        Text { Layout.preferredWidth: root.s(220); text: "NAME"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.overlay2 }
                        Text { Layout.preferredWidth: root.s(80); text: "PID"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.overlay2 }
                        Text { Layout.preferredWidth: root.s(80); text: "CPU %"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.overlay2; horizontalAlignment: Text.AlignRight }
                        Text { Layout.preferredWidth: root.s(80); text: "MEM %"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.overlay2; horizontalAlignment: Text.AlignRight }
                        Item { Layout.fillWidth: true }
                        Text { Layout.preferredWidth: root.s(60); text: "ACTION"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.overlay2; horizontalAlignment: Text.AlignCenter }
                    }
                }

                // Process ListView
                ListView {
                    id: procList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: root.s(4)
                    model: processModel

                    delegate: Rectangle {
                        width: procList.width
                        height: root.s(32)
                        radius: root.s(6)
                        color: rowMa.containsMouse ? mocha.surface1 : "transparent"
                        border.width: root.s(1)
                        border.color: rowMa.containsMouse ? mocha.surface2 : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.s(12)
                            anchors.rightMargin: root.s(12)
                            spacing: root.s(8)

                            Text {
                                Layout.preferredWidth: root.s(220)
                                text: model.name || ""
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: mocha.text
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.preferredWidth: root.s(80)
                                text: model.pid || ""
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(11)
                                color: mocha.subtext0
                            }

                            Text {
                                Layout.preferredWidth: root.s(80)
                                text: (model.cpu || "0.0") + "%"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: parseFloat(model.cpu) > 10.0 ? mocha.red : mocha.blue
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                Layout.preferredWidth: root.s(80)
                                text: (model.mem || "0.0") + "%"
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(11)
                                color: mocha.subtext0
                                horizontalAlignment: Text.AlignRight
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredWidth: root.s(22)
                                Layout.preferredHeight: root.s(22)
                                radius: root.s(4)
                                color: killMa.containsMouse ? mocha.red : mocha.surface1
                                Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: root.s(11)
                                    color: killMa.containsMouse ? mocha.crust : mocha.overlay1
                                }

                                MouseArea {
                                    id: killMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let targetPid = model.pid;
                                        if (targetPid) {
                                            Quickshell.execDetached(["kill", "-15", targetPid]);
                                            processModel.remove(index);
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }
                }
            }
        }
    }
}
